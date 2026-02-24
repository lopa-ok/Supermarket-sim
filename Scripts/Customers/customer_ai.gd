class_name CustomerAI
extends CharacterBody3D

enum State {
	ENTERING,
	WANDERING,
	BROWSING_SHELF,
	IDLE_LOOK,
	DECIDING,
	WALKING_TO_SHELF,
	AT_SHELF,
	WALKING_TO_CHECKOUT,
	QUEUING,
	WALKING_TO_SERVICE,
	AT_CHECKOUT,
	LEAVING,
	WALKING_TO_AISLE,
	BROWSING_AISLE,
	INSPECTING_SHELF,
}

@export_group("Customer Settings")
@export var walk_speed: float = 2.5
@export var browse_speed: float = 1.8
@export var patience_seconds: float = 45.0
@export var max_items: int = 3

@export_group("Browsing Behavior")
@export var wander_steps_min: int = 1
@export var wander_steps_max: int = 3
@export var browse_shelf_chance: float = 0.5
@export var browse_pause_min: float = 1.0
@export var browse_pause_max: float = 3.0
@export var wander_between_items_chance: float = 0.4

var state: State = State.ENTERING
var shopping_list: Array[String] = []
var shopping_cart: Array[Dictionary] = []

var _entrance_pos: Vector3 = Vector3.ZERO
var _exit_pos: Vector3 = Vector3.ZERO
var _browse_target: Vector3 = Vector3.ZERO
var _target_shelf: Node = null
var _target_counter: Node = null
var _state_timer: float = 0.0
var _patience_timer: float = 0.0
var _idle_yaw_target: float = 0.0
var _initialized: bool = false

var _wander_budget: int = 0
var _browse_pause_duration: float = 0.0
var _browsing_at_shelf: Node = null

var _fidget_timer: float = 0.0
var _fidget_yaw_offset: float = 0.0
var _sway_phase: float = 0.0

var _current_aisle: Node = null
var _aisle_waypoints: Array[Vector3] = []
var _aisle_wp_index: int = 0
var _aisles_visited: Array[Node] = []
var _inspect_shelf_target: Node = null

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var carried_item: MeshInstance3D = $CarriedItem if has_node("CarriedItem") else null

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _desired_velocity: Vector3 = Vector3.ZERO

var _store_waypoints: Node = null   # StoreWaypoints manager (found at runtime)

func _ready() -> void:
	add_to_group("customers")

	# --- Collision layers ---------------------------------------------------
	# Layer 4 = Customers.  Customers exist on layer 4 but do NOT detect
	# other customers (mask bit 4 off), so they never physically push each
	# other.  The NavigationAgent3D avoidance system steers them apart instead.
	collision_layer = 1 << 3          # layer 4 (0-indexed bit 3)
	collision_mask  = (1 << 0) | (1 << 2)  # detect World (1) + Interactables (3)

	# --- Navigation avoidance -----------------------------------------------
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.5
	nav_agent.neighbor_distance = 10.0
	nav_agent.max_neighbors = 15
	nav_agent.time_horizon_agents = 1.5
	nav_agent.time_horizon_obstacles = 0.5
	nav_agent.max_speed = walk_speed
	nav_agent.avoidance_layers = 1 << 3     # layer 4
	nav_agent.avoidance_mask  = 1 << 3      # avoid other layer-4 agents

	nav_agent.path_desired_distance = 0.6
	nav_agent.target_desired_distance = 0.8

	nav_agent.velocity_computed.connect(_on_velocity_computed)

	if carried_item:
		carried_item.visible = false

	# Cache the store waypoints manager (found via group)
	await get_tree().physics_frame
	var wps := get_tree().get_nodes_in_group("store_waypoints")
	if not wps.is_empty():
		_store_waypoints = wps[0]

func initialize(entrance: Vector3, exit_pos: Vector3) -> void:
	_entrance_pos = entrance
	_exit_pos = exit_pos

	var map_rid := get_world_3d().navigation_map
	var snap_pos := NavigationServer3D.map_get_closest_point(map_rid, entrance)
	global_position = snap_pos

	var store_center := Vector3.ZERO
	var inward_dir := (store_center - entrance).normalized()
	_browse_target = NavigationServer3D.map_get_closest_point(
		map_rid, entrance + inward_dir * randf_range(3.0, 5.0))

	_wander_budget = randi_range(wander_steps_min, wander_steps_max)

	_initialized = true
	_change_state(State.ENTERING)
	EventBus.customer_entered.emit(self)

func _physics_process(delta: float) -> void:
	if not _initialized:
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	_state_timer += delta
	match state:
		State.ENTERING:            _tick_entering(delta)
		State.WANDERING:           _tick_wandering(delta)
		State.BROWSING_SHELF:      _tick_browsing_shelf(delta)
		State.IDLE_LOOK:           _tick_idle_look(delta)
		State.DECIDING:            _tick_deciding(delta)
		State.WALKING_TO_SHELF:    _tick_walking(delta, State.AT_SHELF)
		State.AT_SHELF:            _tick_at_shelf(delta)
		State.WALKING_TO_CHECKOUT: _tick_walking(delta, State.QUEUING)
		State.QUEUING:             _tick_idle_fidget(delta)
		State.WALKING_TO_SERVICE:  _tick_walking(delta, State.AT_CHECKOUT)
		State.AT_CHECKOUT:         _tick_idle_fidget(delta)
		State.LEAVING:             _tick_leaving(delta)
		State.WALKING_TO_AISLE:    _tick_walking(delta, State.BROWSING_AISLE)
		State.BROWSING_AISLE:      _tick_browsing_aisle(delta)
		State.INSPECTING_SHELF:    _tick_inspecting_shelf(delta)

	if state in [State.BROWSING_SHELF, State.IDLE_LOOK, State.AT_SHELF,
				 State.QUEUING, State.AT_CHECKOUT, State.INSPECTING_SHELF,
				 State.DECIDING]:
		if nav_agent.avoidance_enabled:
			nav_agent.set_velocity(Vector3.ZERO)

	move_and_slide()

	_patience_timer += delta
	if _patience_timer > patience_seconds \
		and state not in [State.AT_CHECKOUT, State.LEAVING]:
		EventBus.customer_unsatisfied.emit(self, "out_of_patience")
		_go_leave()

func _tick_entering(_delta: float) -> void:
	if _state_timer < 0.1:
		_navigate_to(_browse_target)
		return
	if _tick_walk(_delta):
		_begin_wander_or_decide()

func _tick_wandering(delta: float) -> void:
	if _tick_walk(delta):
		_wander_budget -= 1
		if randf() < browse_shelf_chance:
			var nearby_shelf := _find_nearest_shelf()
			if nearby_shelf:
				_browsing_at_shelf = nearby_shelf
				_browse_pause_duration = randf_range(browse_pause_min, browse_pause_max)
				_idle_yaw_target = _yaw_toward(nearby_shelf.global_position)
				_change_state(State.BROWSING_SHELF)
				return
		_begin_wander_or_decide()

func _tick_browsing_shelf(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	rotation.y = lerp_angle(rotation.y, _idle_yaw_target, 3.0 * delta)

	_sway_phase += delta
	var body_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if body_mesh:
		body_mesh.rotation.z = sin(_sway_phase * 1.0) * 0.012

	if _state_timer > _browse_pause_duration:
		_browsing_at_shelf = null
		_begin_wander_or_decide()

func _tick_idle_look(delta: float) -> void:
	if _state_timer < delta * 2.0:
		_idle_yaw_target = randf_range(-PI, PI)
	rotation.y = lerp_angle(rotation.y, _idle_yaw_target, 3.0 * delta)
	velocity.x = 0.0
	velocity.z = 0.0

	if _state_timer > randf_range(1.0, 2.5):
		_change_state(State.DECIDING)

func _tick_deciding(_delta: float) -> void:
	if shopping_list.is_empty() and shopping_cart.is_empty():
		_build_shopping_list_from_stock()

	if shopping_list.is_empty():
		if shopping_cart.is_empty():
			EventBus.customer_unsatisfied.emit(self, "nothing_available")
			_go_leave()
		else:
			_go_to_checkout()
		return

	var pid: String = shopping_list[0]

	var aisle := _find_aisle_for_product(pid)
	if aisle and aisle not in _aisles_visited:
		_start_aisle_browse(aisle)
		return

	_target_shelf = _find_shelf_for_product(pid)
	if _target_shelf:
		_navigate_to(_target_shelf.global_position)
		_change_state(State.WALKING_TO_SHELF)
	else:
		EventBus.customer_unsatisfied.emit(self, "product_not_found:%s" % pid)
		shopping_list.remove_at(0)

func _start_aisle_browse(aisle: Node) -> void:
	_current_aisle = aisle
	_aisles_visited.append(aisle)
	_aisle_waypoints = aisle.get_waypoint_positions()
	_aisle_wp_index = 0
	nav_agent.max_speed = browse_speed
	if not _aisle_waypoints.is_empty():
		_navigate_to(_aisle_waypoints[0])
	EventBus.customer_entered_aisle.emit(self, aisle)
	_change_state(State.WALKING_TO_AISLE)

func _tick_browsing_aisle(delta: float) -> void:
	if _tick_walk(delta):
		var nearby := _find_shelf_in_aisle(_current_aisle)
		if nearby and randf() < 0.6:
			_inspect_shelf_target = nearby
			_idle_yaw_target = _yaw_toward(nearby.global_position)
			_browse_pause_duration = randf_range(browse_pause_min, browse_pause_max)
			_change_state(State.INSPECTING_SHELF)
			return

		_aisle_wp_index += 1
		if _aisle_wp_index < _aisle_waypoints.size():
			_navigate_to(_aisle_waypoints[_aisle_wp_index])
		else:
			_finish_aisle_browse()

func _tick_inspecting_shelf(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	rotation.y = lerp_angle(rotation.y, _idle_yaw_target, 3.0 * delta)

	_sway_phase += delta
	var body_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if body_mesh:
		body_mesh.rotation.z = sin(_sway_phase * 1.0) * 0.012

	if _state_timer > _browse_pause_duration:
		if _inspect_shelf_target and not shopping_list.is_empty():
			var pid: String = shopping_list[0]
			if _inspect_shelf_target.get_stock_of(pid) > 0:
				_inspect_shelf_target.remove_stock(pid, 1)
				shopping_cart.append({"product_id": pid, "quantity": 1})
				shopping_list.remove_at(0)
				EventBus.customer_satisfied.emit(self)
				_show_carried_item(true)
		_inspect_shelf_target = null

		_aisle_wp_index += 1
		if _aisle_wp_index < _aisle_waypoints.size():
			_navigate_to(_aisle_waypoints[_aisle_wp_index])
			_change_state(State.BROWSING_AISLE)
		else:
			_finish_aisle_browse()

func _finish_aisle_browse() -> void:
	if _current_aisle:
		EventBus.customer_left_aisle.emit(self, _current_aisle)
	_current_aisle = null
	_aisle_waypoints.clear()
	_aisle_wp_index = 0
	nav_agent.max_speed = walk_speed

	if shopping_list.is_empty() or shopping_cart.size() >= max_items:
		_go_to_checkout()
	else:
		if randf() < wander_between_items_chance:
			_wander_budget = randi_range(1, 2)
			_begin_wander_or_decide()
		else:
			_change_state(State.IDLE_LOOK)

func _find_aisle_for_product(product_id: String) -> Node:
	var aisles := get_tree().get_nodes_in_group("aisles")
	if aisles.is_empty():
		return null
	var best: Node = null
	var best_dist: float = INF
	for aisle in aisles:
		if aisle.has_product(product_id):
			var dist := global_position.distance_to(aisle.global_position)
			if dist < best_dist:
				best_dist = dist
				best = aisle
	if best == null:
		var db = get_node_or_null("/root/ProductDatabase")
		if db:
			var p = db.get_product(product_id)
			if p:
				for aisle in aisles:
					if aisle.has_tag(p.shelf_tag):
						var dist := global_position.distance_to(aisle.global_position)
						if dist < best_dist:
							best_dist = dist
							best = aisle
	return best

func _find_shelf_in_aisle(aisle: Node) -> Node:
	if aisle == null or not aisle.has_method("get_shelves"):
		return null
	var shelves: Array = aisle.get_shelves()
	var best: Node = null
	var best_dist: float = INF
	for shelf in shelves:
		var dist := global_position.distance_to(shelf.global_position)
		if dist < best_dist and dist < 5.0:
			best_dist = dist
			best = shelf
	return best

func _tick_walking(delta: float, next_state: State) -> void:
	if _tick_walk(delta):
		_change_state(next_state)

func _tick_at_shelf(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _state_timer < 0.8:
		return

	if _target_shelf and not shopping_list.is_empty():
		var pid: String = shopping_list[0]
		if _target_shelf.get_stock_of(pid) > 0:
			_target_shelf.remove_stock(pid, 1)
			shopping_cart.append({"product_id": pid, "quantity": 1})
			shopping_list.remove_at(0)
			EventBus.customer_satisfied.emit(self)
			_show_carried_item(true)
		else:
			EventBus.customer_unsatisfied.emit(self, "shelf_empty:%s" % pid)
			shopping_list.remove_at(0)

	_target_shelf = null

	if shopping_list.is_empty() or shopping_cart.size() >= max_items:
		_go_to_checkout()
	else:
		if randf() < wander_between_items_chance:
			_wander_budget = randi_range(1, 2)
			_begin_wander_or_decide()
		else:
			_change_state(State.IDLE_LOOK)

func _tick_leaving(delta: float) -> void:
	if _tick_walk(delta):
		EventBus.customer_left.emit(self)
		queue_free()

func _tick_idle_fidget(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	_sway_phase += delta
	var body_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if body_mesh:
		body_mesh.rotation.z = sin(_sway_phase * 1.2) * 0.015

	_fidget_timer += delta
	if _fidget_timer > randf_range(2.5, 5.0):
		_fidget_timer = 0.0
		_fidget_yaw_offset = randf_range(-0.35, 0.35)
	rotation.y = lerp_angle(rotation.y, rotation.y + _fidget_yaw_offset, 2.0 * delta)
	_fidget_yaw_offset = lerp(_fidget_yaw_offset, 0.0, 1.5 * delta)

func _begin_wander_or_decide() -> void:
	if _wander_budget > 0:
		_start_wander()
	else:
		_change_state(State.IDLE_LOOK)

func _start_wander() -> void:
	var target := _pick_wander_target()
	_navigate_to(target)
	nav_agent.max_speed = browse_speed
	_change_state(State.WANDERING)

func _pick_wander_target() -> Vector3:
	var map_rid := get_world_3d().navigation_map

	# --- Prefer store-wide waypoints if the manager exists ---
	if _store_waypoints and _store_waypoints.has_method("get_random_waypoint_away_from"):
		var wp: Vector3 = _store_waypoints.get_random_waypoint_away_from(
			global_position, 3.0)
		# Snap to nav-mesh so the agent can always reach it
		return NavigationServer3D.map_get_closest_point(map_rid, wp)

	# --- Fallback: pick a spot near a random shelf or anywhere on the nav mesh ---
	var shelves := get_tree().get_nodes_in_group("shelves")
	if not shelves.is_empty() and randf() < 0.6:
		var shelf: Node3D = shelves[randi() % shelves.size()]
		var offset := Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.0, 2.0))
		var candidate := shelf.global_position + offset
		candidate.y = 0.0
		return NavigationServer3D.map_get_closest_point(map_rid, candidate)
	else:
		# Pick a random point on the nav-mesh via a random edge query
		var random_pos := NavigationServer3D.map_get_random_point(
			map_rid, 1, false)
		return random_pos

func _find_nearest_shelf() -> Node:
	var shelves := get_tree().get_nodes_in_group("shelves")
	var best: Node = null
	var best_dist: float = INF
	for shelf in shelves:
		var dist := global_position.distance_to(shelf.global_position)
		if dist < best_dist:
			best_dist = dist
			best = shelf
	return best if best_dist < 5.0 else null

func _yaw_toward(target_pos: Vector3) -> float:
	var dir := (target_pos - global_position)
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		return rotation.y
	return atan2(dir.x, dir.z)

func _tick_walk(delta: float) -> bool:
	if nav_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		nav_agent.max_speed = walk_speed
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

	var current_speed := nav_agent.max_speed
	_desired_velocity = direction * current_speed

	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(_desired_velocity)
	else:
		velocity.x = _desired_velocity.x
		velocity.z = _desired_velocity.z

	var target_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 5.0 * delta)
	return false

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z

func _navigate_to(target: Vector3) -> void:
	nav_agent.target_position = target

func _change_state(new_state: State) -> void:
	state = new_state
	_state_timer = 0.0

func _go_leave() -> void:
	if _target_counter:
		_target_counter.leave_queue(self)
		_target_counter = null
	if _current_aisle:
		EventBus.customer_left_aisle.emit(self, _current_aisle)
		_current_aisle = null
	nav_agent.max_speed = walk_speed
	_navigate_to(_exit_pos)
	_change_state(State.LEAVING)

func _go_to_checkout() -> void:
	_target_counter = _find_best_checkout()
	if _target_counter == null:
		_go_leave()
		return
	nav_agent.max_speed = walk_speed
	var pos_node: Node3D = _target_counter.join_queue(self)
	if pos_node:
		_navigate_to(pos_node.global_position)
	else:
		_navigate_to(_target_counter.global_position + Vector3(0, 0, 2))
	_change_state(State.WALKING_TO_CHECKOUT)

func on_checkout_ready(counter: Node) -> void:
	_navigate_to(counter.get_service_position())
	_change_state(State.WALKING_TO_SERVICE)

func on_checkout_completed(_total: float) -> void:
	_show_carried_item(false)
	_go_leave()

func move_to_queue_position(pos: Vector3) -> void:
	_navigate_to(pos)

func get_shopping_cart() -> Array:
	return shopping_cart

func _build_shopping_list_from_stock() -> void:
	shopping_list.clear()
	var available_pids: Array[String] = []
	var shelves := get_tree().get_nodes_in_group("shelves")
	for shelf in shelves:
		if "stock" in shelf:
			var shelf_stock = shelf.stock
			if shelf_stock is Dictionary:
				for side_key in shelf_stock:
					var side_data = shelf_stock[side_key]
					if side_data is Dictionary:
						for pid in side_data:
							if side_data[pid] > 0 and pid not in available_pids:
								available_pids.append(pid)

	if available_pids.is_empty():
		return

	available_pids.shuffle()
	var count := mini(randi_range(1, max_items), available_pids.size())
	for i in count:
		shopping_list.append(available_pids[i])

func _find_shelf_for_product(product_id: String) -> Node:
	var shelves := get_tree().get_nodes_in_group("shelves")
	var best_shelf: Node = null
	var best_dist: float = INF
	for shelf in shelves:
		if shelf.get_stock_of(product_id) > 0:
			var dist := global_position.distance_to(shelf.global_position)
			if dist < best_dist:
				best_dist = dist
				best_shelf = shelf
	return best_shelf

func _find_best_checkout() -> Node:
	var counters := get_tree().get_nodes_in_group("checkout_counters")
	var best: Node = null
	var best_queue: int = 999
	for counter in counters:
		var qs: int = counter.get_queue_size()
		if qs < best_queue:
			best_queue = qs
			best = counter
	return best

func _show_carried_item(visible_flag: bool) -> void:
	if carried_item:
		carried_item.visible = visible_flag
