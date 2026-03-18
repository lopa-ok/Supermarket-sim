class_name WorkerBot
extends CharacterBody3D

enum Role { STOCKER, CASHIER, SECURITY }

enum BotState {
	IDLE,
	MOVING_TO_STOCKROOM,
	PICKING_UP_STOCK,
	MOVING_TO_SHELF,
	RESTOCKING,
	MOVING_TO_CHECKOUT,
	OPERATING_CHECKOUT,
	PATROLLING,
	INTERCEPTING,
}

const ROLE_COLORS: Dictionary = {
	Role.STOCKER:  Color(0.30, 0.75, 0.40),
	Role.CASHIER:  Color(0.35, 0.55, 0.95),
	Role.SECURITY: Color(0.90, 0.35, 0.30),
}

var role: Role = Role.STOCKER
var worker_id: int = -1
var level: int = 1
var salary: float = 25.0

@export var walk_speed: float = 3.0
var _desired_velocity: Vector3 = Vector3.ZERO

var bot_state: BotState = BotState.IDLE
var _state_timer: float = 0.0
var _setup_done: bool = false

var _carried_product_id: String = ""
var _target_crate: Node = null
var _target_shelf: Node = null
var _target_side: String = ""
var _stockroom_waypoints: Array[Vector3] = []
var _stockroom_wp_index: int = 0
var _return_waypoints: Array[Vector3] = []
var _return_wp_index: int = 0
var _stockroom_path_node: Node = null

var _assigned_counter: Node = null

var _patrol_target: Vector3 = Vector3.ZERO
var detection_radius: float = 8.0

var _intercept_target: Node = null

var _action_duration: float = 0.0
var _idle_cooldown: float = 0.0

var _hand_socket: Node3D = null
var _held_product_instance: Node3D = null

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var body_mesh: MeshInstance3D = $MeshInstance3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _store_waypoints: Node = null

func _ready() -> void:
	add_to_group("worker_bots")
	collision_layer = 1 << 4
	collision_mask  = (1 << 0) | (1 << 2)
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.375
	nav_agent.neighbor_distance = 10.0
	nav_agent.max_neighbors = 15
	nav_agent.time_horizon_agents = 1.5
	nav_agent.time_horizon_obstacles = 0.5
	nav_agent.max_speed = walk_speed
	nav_agent.path_desired_distance = 0.45
	nav_agent.target_desired_distance = 0.6
	nav_agent.avoidance_layers = (1 << 3) | (1 << 4)
	nav_agent.avoidance_mask  = (1 << 3) | (1 << 4)
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	_hand_socket = get_node_or_null("HandSocket")
	EventBus.theft_attempted.connect(_on_theft_attempted)

func setup(p_role: int, p_id: int, p_level: int, p_salary: float, spawn_pos: Vector3) -> void:
	role = p_role as Role
	worker_id = p_id
	level = p_level
	salary = p_salary
	_apply_role_color()
	await _wait_for_nav_map()
	if not is_inside_tree():
		return
	var map_rid := get_world_3d().navigation_map
	var nav_pos := NavigationServer3D.map_get_closest_point(map_rid, spawn_pos)
	if nav_pos.distance_to(Vector3.ZERO) < 0.5:
		nav_pos = spawn_pos
		nav_pos.y += 1.0
	global_position = nav_pos
	var wps := get_tree().get_nodes_in_group("store_waypoints")
	if not wps.is_empty():
		_store_waypoints = wps[0]
	var paths := get_tree().get_nodes_in_group("stockroom_path")
	if not paths.is_empty():
		_stockroom_path_node = paths[0]
	_setup_done = true
	_change_state(BotState.IDLE)

func _wait_for_nav_map() -> void:
	var test_pos := Vector3(5.0, 3.0, 10.0)
	for i in 60:
		await get_tree().physics_frame
		if not is_inside_tree():
			return
		var map_rid := get_world_3d().navigation_map
		var result := NavigationServer3D.map_get_closest_point(map_rid, test_pos)
		if result.distance_to(Vector3.ZERO) > 1.0:
			return

func _apply_role_color() -> void:
	if body_mesh == null:
		return
	var tint: Color = ROLE_COLORS.get(role, Color.WHITE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	body_mesh.material_override = mat

func _physics_process(delta: float) -> void:
	if not _setup_done:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
	_state_timer += delta
	match bot_state:
		BotState.IDLE:                _tick_idle(delta)
		BotState.MOVING_TO_STOCKROOM: _tick_moving_to_stockroom(delta)
		BotState.PICKING_UP_STOCK:    _tick_timed_action(delta)
		BotState.MOVING_TO_SHELF:     _tick_moving_to_shelf(delta)
		BotState.RESTOCKING:          _tick_timed_action(delta)
		BotState.MOVING_TO_CHECKOUT:  _tick_moving_generic(delta, BotState.OPERATING_CHECKOUT)
		BotState.OPERATING_CHECKOUT:  _tick_operating_checkout(delta)
		BotState.PATROLLING:          _tick_patrolling(delta)
		BotState.INTERCEPTING:        _tick_intercepting(delta)
	move_and_slide()

func _change_state(new_state: BotState) -> void:
	bot_state = new_state
	_state_timer = 0.0

func _navigate_to(target: Vector3) -> void:
	nav_agent.target_position = target

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z

func _tick_walk(delta: float) -> bool:
	if nav_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		if nav_agent.avoidance_enabled:
			nav_agent.set_velocity(Vector3.ZERO)
		return true
	var next_pos := nav_agent.get_next_path_position()
	var direction := (next_pos - global_position)
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		velocity.x = 0.0
		velocity.z = 0.0
		if nav_agent.avoidance_enabled:
			nav_agent.set_velocity(Vector3.ZERO)
		return true
	direction = direction.normalized()
	_desired_velocity = direction * walk_speed
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(_desired_velocity)
	else:
		velocity.x = _desired_velocity.x
		velocity.z = _desired_velocity.z
	var target_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 5.0 * delta)
	return false

func _walk_directly_toward(target: Vector3, delta: float) -> void:
	var dir := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if dir.length_squared() < 0.001:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	dir = dir.normalized()
	velocity.x = dir.x * walk_speed
	velocity.z = dir.z * walk_speed
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(dir * walk_speed)
	var yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, 5.0 * delta)

func _tick_idle(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_idle_cooldown -= _delta
	if _idle_cooldown > 0.0:
		return
	match role:
		Role.STOCKER:
			_try_find_restock_task()
		Role.CASHIER:
			_try_find_cashier_task()
		Role.SECURITY:
			_start_patrol()
	if bot_state == BotState.IDLE:
		_idle_cooldown = 1.5

func _try_find_restock_task() -> void:
	var shelves := get_tree().get_nodes_in_group("shelves")
	var db = get_node_or_null("/root/ProductDatabase")
	if db == null:
		return
	var best_shelf: Node = null
	var best_side: String = ""
	var best_product_id: String = ""
	var best_need: int = 0
	for shelf in shelves:
		if shelf.is_full():
			continue
		var side_names: Array = shelf.get_sides()
		for side_name in side_names:
			var side_cur: int = shelf.get_side_stock(side_name)
			var side_mx: int = shelf.get_side_capacity(side_name)
			if side_cur >= side_mx:
				continue
			var need := side_mx - side_cur
			var tag: String = shelf.get_tag_for_side(side_name)
			if tag.is_empty():
				continue
			if _is_shelf_side_claimed(shelf, side_name):
				continue
			if need > best_need:
				var matching_pid := ""
				for pid in db.get_all_product_ids():
					var p = db.get_product(pid)
					if p and p.shelf_tag == tag:
						matching_pid = pid
						break
				if matching_pid.is_empty():
					continue
				best_shelf = shelf
				best_side = side_name
				best_product_id = matching_pid
				best_need = need
	if best_shelf == null:
		return
	var crate := _find_crate_for_product(best_product_id)
	if crate == null:
		return
	_target_shelf = best_shelf
	_target_side = best_side
	_carried_product_id = best_product_id
	_target_crate = crate
	_begin_stockroom_trip()

func _begin_stockroom_trip() -> void:
	if not _stockroom_path_node:
		var paths := get_tree().get_nodes_in_group("stockroom_path")
		if paths.size() > 0:
			_stockroom_path_node = paths[0]
			
	if _stockroom_path_node and _stockroom_path_node.get_waypoint_count() > 0:
		_stockroom_waypoints = _stockroom_path_node.get_all_waypoints()
		_stockroom_wp_index = 0
		_navigate_to(_stockroom_waypoints[0])
		_change_state(BotState.MOVING_TO_STOCKROOM)
	else:
		_stockroom_waypoints.clear()
		_stockroom_wp_index = 0
		_navigate_to(_target_crate.global_position)
		_change_state(BotState.MOVING_TO_STOCKROOM)

func _tick_moving_to_stockroom(delta: float) -> void:
	var on_waypoint_leg := not _stockroom_waypoints.is_empty() and _stockroom_wp_index < _stockroom_waypoints.size()
	if on_waypoint_leg:
		var wp_target := _stockroom_waypoints[_stockroom_wp_index]
		var flat_dist := Vector2(global_position.x - wp_target.x, global_position.z - wp_target.z).length()
		if flat_dist < 0.35:
			if _stockroom_wp_index < _stockroom_waypoints.size() - 1:
				_stockroom_wp_index += 1
				_navigate_to(_stockroom_waypoints[_stockroom_wp_index])
			else:
				_stockroom_waypoints.clear()
				if _target_crate and is_instance_valid(_target_crate):
					_navigate_to(_target_crate.global_position)
				else:
					_action_duration = _get_action_time(2.0)
					_change_state(BotState.PICKING_UP_STOCK)
			return
		if nav_agent.is_navigation_finished():
			_walk_directly_toward(wp_target, delta)
		else:
			_tick_walk(delta)
			# Debug logging only, no skipping
		if nav_agent.is_navigation_finished() and flat_dist > 2.0:
			print("[StockerBot] Stuck at waypoint ", _stockroom_wp_index, " (", wp_target, ") path node: ", _stockroom_path_node)
	else:
		if _tick_walk(delta):
			_action_duration = _get_action_time(2.0)
			_change_state(BotState.PICKING_UP_STOCK)

func _tick_moving_to_shelf(delta: float) -> void:
	var on_return_leg := not _return_waypoints.is_empty() and _return_wp_index < _return_waypoints.size()
	if on_return_leg:
		var wp_target := _return_waypoints[_return_wp_index]
		var flat_dist := Vector2(global_position.x - wp_target.x, global_position.z - wp_target.z).length()
		if flat_dist < 0.35:
			if _return_wp_index < _return_waypoints.size() - 1:
				_return_wp_index += 1
				_navigate_to(_return_waypoints[_return_wp_index])
			else:
				_return_waypoints.clear()
				if _target_shelf and is_instance_valid(_target_shelf):
					_navigate_to(_target_shelf.global_position)
				else:
					_clear_stocker_state()
					_change_state(BotState.IDLE)
			return
		if nav_agent.is_navigation_finished():
			_walk_directly_toward(wp_target, delta)
		else:
			_tick_walk(delta)
	else:
		if _tick_walk(delta):
			_action_duration = _get_action_time(2.5)
			_change_state(BotState.RESTOCKING)

func _tick_timed_action(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _state_timer >= _action_duration:
		if bot_state == BotState.PICKING_UP_STOCK:
			_on_stock_picked_up()
		elif bot_state == BotState.RESTOCKING:
			_on_shelf_restocked()

func _on_stock_picked_up() -> void:
	if not _stockroom_path_node:
		var paths := get_tree().get_nodes_in_group("stockroom_path")
		if paths.size() > 0:
			_stockroom_path_node = paths[0]
			
	if _target_shelf and is_instance_valid(_target_shelf):
		if _stockroom_path_node and _stockroom_path_node.get_waypoint_count() > 0:
			_return_waypoints = _stockroom_path_node.get_reversed_waypoints()
			_return_wp_index = 0
			_navigate_to(_return_waypoints[0])
		else:
			_return_waypoints.clear()
			_return_wp_index = 0
			_navigate_to(_target_shelf.global_position)
		_change_state(BotState.MOVING_TO_SHELF)
	else:
		_clear_stocker_state()
		_change_state(BotState.IDLE)

func _on_shelf_restocked() -> void:
	if _target_shelf == null or _carried_product_id.is_empty():
		_clear_stocker_state()
		_change_state(BotState.IDLE)
		return
	_target_shelf.add_stock_side(_target_side, _carried_product_id, 1)
	EventBus.restock_activity.emit(_target_shelf, _carried_product_id, _get_worker_dict())
	_clear_held_product()
	_clear_stocker_state()
	_change_state(BotState.IDLE)

func _clear_stocker_state() -> void:
	_carried_product_id = ""
	_target_shelf = null
	_target_crate = null
	_target_side = ""
	_stockroom_waypoints.clear()
	_stockroom_wp_index = 0
	_return_waypoints.clear()
	_return_wp_index = 0

func _find_crate_for_product(product_id: String) -> Node:
	var crates := get_tree().get_nodes_in_group("restock_crates")
	if crates.is_empty():
		_find_restock_crates_recursive(get_tree().current_scene, crates)
	var best: Node = null
	var best_dist: float = INF
	for crate in crates:
		if crate is RestockCrate and crate.product_id == product_id:
			var d := global_position.distance_squared_to(crate.global_position)
			if d < best_dist:
				best_dist = d
				best = crate
	return best

func _find_restock_crates_recursive(node: Node, result: Array) -> void:
	if node is RestockCrate:
		result.append(node)
	for child in node.get_children():
		_find_restock_crates_recursive(child, result)

func _is_shelf_side_claimed(shelf: Node, side_name: String) -> bool:
	var bots := get_tree().get_nodes_in_group("worker_bots")
	for bot in bots:
		if bot == self:
			continue
		if bot is WorkerBot and bot.role == Role.STOCKER:
			if bot._target_shelf == shelf and bot._target_side == side_name:
				if bot.bot_state in [BotState.MOVING_TO_STOCKROOM, BotState.PICKING_UP_STOCK,
									 BotState.MOVING_TO_SHELF, BotState.RESTOCKING]:
					return true
	return false

func _tick_moving_generic(delta: float, arrive_state: BotState) -> void:
	if _tick_walk(delta):
		_change_state(arrive_state)

func _try_find_cashier_task() -> void:
	var counters := get_tree().get_nodes_in_group("checkout_counters")
	for counter in counters:
		if _is_counter_claimed(counter):
			continue
		_assigned_counter = counter
		_navigate_to(counter.get_service_position())
		_change_state(BotState.MOVING_TO_CHECKOUT)
		return

func _is_counter_claimed(counter: Node) -> bool:
	var bots := get_tree().get_nodes_in_group("worker_bots")
	for bot in bots:
		if bot == self:
			continue
		if bot is WorkerBot and bot.role == Role.CASHIER:
			if bot._assigned_counter == counter:
				return true
	return false

func _tick_operating_checkout(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _assigned_counter == null:
		_change_state(BotState.IDLE)
		return
	var dir_to_counter: Vector3 = _assigned_counter.global_position - global_position
	dir_to_counter.y = 0.0
	if dir_to_counter.length_squared() > 0.01:
		var yaw := atan2(dir_to_counter.x, dir_to_counter.z)
		rotation.y = lerp_angle(rotation.y, yaw, 5.0 * delta)
	if _assigned_counter.current_customer == null:
		_assigned_counter.try_advance_queue()
		if _assigned_counter.current_customer == null:
			if _state_timer > 10.0:
				_release_counter()
				_change_state(BotState.IDLE)
			return
	if _assigned_counter.current_customer != null and not _assigned_counter._is_processing:
		_assigned_counter._process_transaction(_assigned_counter.current_customer)

func _start_patrol() -> void:
	if _store_waypoints:
		_patrol_target = _store_waypoints.get_random_waypoint_away_from(global_position, 4.0)
	else:
		_patrol_target = global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
	_navigate_to(_patrol_target)
	_change_state(BotState.PATROLLING)

func _tick_patrolling(delta: float) -> void:
	if _tick_walk(delta):
		velocity.x = 0.0
		velocity.z = 0.0
		if _state_timer > 2.0:
			_start_patrol()

func _on_theft_attempted(customer: Node, _item_value: float) -> void:
	if role != Role.SECURITY:
		return
	if bot_state == BotState.INTERCEPTING:
		return
	if not is_instance_valid(customer):
		return
	var dist := global_position.distance_to(customer.global_position)
	if dist > detection_radius:
		return
	var base_chance := 0.15 + 0.10 * (level - 1)
	var proximity_factor := 1.0 - (dist / detection_radius)
	var detect_roll := base_chance * proximity_factor
	if randf() < detect_roll:
		_intercept_target = customer
		_navigate_to(customer.global_position)
		_change_state(BotState.INTERCEPTING)

func _tick_intercepting(delta: float) -> void:
	if _intercept_target == null or not is_instance_valid(_intercept_target):
		_intercept_target = null
		_start_patrol()
		return
	_navigate_to(_intercept_target.global_position)
	var dist := global_position.distance_to(_intercept_target.global_position)
	if dist < 1.5:
		EventBus.theft_prevented.emit(_intercept_target, _get_worker_dict())
		if _intercept_target.has_method("on_theft_intercepted"):
			_intercept_target.on_theft_intercepted(self)
		elif "stolen_items" in _intercept_target:
			var pdb = get_node_or_null("/root/ProductDatabase")
			for item in _intercept_target.stolen_items:
				if pdb:
					var shelves := get_tree().get_nodes_in_group("shelves")
					for shelf in shelves:
						if shelf.can_accept_product(item["product_id"]):
							shelf.add_stock(item["product_id"], item.get("quantity", 1))
							break
			_intercept_target.stolen_items.clear()
		_intercept_target = null
		_start_patrol()
		return
	if _state_timer > 10.0:
		_intercept_target = null
		_start_patrol()
		return
	_tick_walk(delta)

func get_detection_chance_for(target_pos: Vector3) -> float:
	if role != Role.SECURITY:
		return 0.0
	var dist := global_position.distance_to(target_pos)
	if dist > detection_radius:
		return 0.0
	var base_chance := 0.15 + 0.10 * (level - 1)
	var proximity_factor := 1.0 - (dist / detection_radius)
	return clampf(base_chance * proximity_factor, 0.0, 0.95)

func _attach_held_product(product_id: String) -> void:
	_clear_held_product()
	if _hand_socket == null:
		return
	var db = get_node_or_null("/root/ProductDatabase")
	if db == null:
		return
	var p = db.get_product(product_id)
	if p == null:
		return
	var scene: PackedScene = p.get_mesh_scene()
	if scene == null:
		return
	_held_product_instance = scene.instantiate() as Node3D
	if _held_product_instance == null:
		return
	_hand_socket.add_child(_held_product_instance)
	_held_product_instance.scale = Vector3.ONE * 25.0

func _clear_held_product() -> void:
	if _held_product_instance and is_instance_valid(_held_product_instance):
		_held_product_instance.queue_free()
	_held_product_instance = null

func _release_counter() -> void:
	_assigned_counter = null

func _exit_tree() -> void:
	_release_counter()

func _get_action_time(base: float) -> float:
	return base / (1.0 + 0.15 * (level - 1))

func _get_worker_dict() -> Dictionary:
	return {
		"id": worker_id,
		"role": role,
		"role_name": get_role_name(),
		"level": level,
		"salary": salary,
	}

func get_role_name() -> String:
	match role:
		Role.STOCKER: return "Stocker"
		Role.CASHIER: return "Cashier"
		Role.SECURITY: return "Security Guard"
	return "Unknown"

func get_state_name() -> String:
	match bot_state:
		BotState.IDLE: return "Idle"
		BotState.MOVING_TO_STOCKROOM: return "Going to stockroom"
		BotState.PICKING_UP_STOCK: return "Picking up stock"
		BotState.MOVING_TO_SHELF: return "Going to shelf"
		BotState.RESTOCKING: return "Restocking"
		BotState.MOVING_TO_CHECKOUT: return "Going to checkout"
		BotState.OPERATING_CHECKOUT: return "Operating checkout"
		BotState.PATROLLING: return "Patrolling"
		BotState.INTERCEPTING: return "Intercepting thief"
	return "Unknown"
