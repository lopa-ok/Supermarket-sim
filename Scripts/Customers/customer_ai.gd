class_name CustomerAI
extends CharacterBody3D

const ThoughtBubbleScript = preload("res://Scripts/Customers/thought_bubble_3d.gd")

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
	STEALING,
}

enum Personality { NORMAL, IMPATIENT, RICH, BARGAIN, THIEF }

const PERSONALITY_COLORS: Dictionary = {
	Personality.NORMAL: Color(1.0, 1.0, 1.0),
	Personality.IMPATIENT: Color(1.0, 0.35, 0.30),
	Personality.RICH: Color(1.0, 0.85, 0.25),
	Personality.BARGAIN: Color(0.35, 0.65, 1.0),
	Personality.THIEF: Color(0.65, 0.30, 0.85),
}

const PERSONALITY_WEIGHTS: Array[float] = [0.40, 0.20, 0.15, 0.15, 0.10]

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
var personality: Personality = Personality.NORMAL
var shopping_list: Array[String] = []
var shopping_cart: Array[Dictionary] = []
var stolen_items: Array[Dictionary] = []

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

var _leaving_unhappy: bool = false

var group_id: int = -1
var is_group_leader: bool = false
var group_members: Array[Node] = []
var _leader_ref: Node = null

var _hand_socket: Node3D = null
var _held_product_instance: Node3D = null
var _held_product_id: String = ""

var _decision_delay: float = 0.0
var _decision_waiting: bool = false

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var carried_item: MeshInstance3D = $CarriedItem if has_node("CarriedItem") else null
@onready var thought_bubble: Node3D = $ThoughtBubble3D if has_node("ThoughtBubble3D") else null

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _desired_velocity: Vector3 = Vector3.ZERO

var _store_waypoints: Node = null

func _ready() -> void:
	add_to_group("customers")
	_assign_personality()
	_apply_personality_modifiers()
	_apply_color_tint()

	collision_layer = 1 << 3
	collision_mask  = (1 << 0) | (1 << 2)

	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.375
	nav_agent.neighbor_distance = 10.0
	nav_agent.max_neighbors = 15
	nav_agent.time_horizon_agents = 1.5
	nav_agent.time_horizon_obstacles = 0.5
	nav_agent.max_speed = walk_speed
	nav_agent.avoidance_layers = 1 << 3
	nav_agent.avoidance_mask  = 1 << 3

	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.7

	nav_agent.velocity_computed.connect(_on_velocity_computed)

	if carried_item:
		carried_item.visible = false

	_hand_socket = get_node_or_null("HandSocket")

	await get_tree().physics_frame
	var wps := get_tree().get_nodes_in_group("store_waypoints")
	if not wps.is_empty():
		_store_waypoints = wps[0]

func _assign_personality() -> void:
	var roll := randf()
	var cumulative := 0.0
	for i in PERSONALITY_WEIGHTS.size():
		cumulative += PERSONALITY_WEIGHTS[i]
		if roll <= cumulative:
			personality = i as Personality
			return
	personality = Personality.NORMAL

func _apply_personality_modifiers() -> void:
	match personality:
		Personality.IMPATIENT:
			patience_seconds *= 0.5
			walk_speed *= 1.3
			browse_speed *= 1.3
			max_items = maxi(1, max_items - 1)
		Personality.RICH:
			max_items += 2
			patience_seconds *= 1.3
		Personality.BARGAIN:
			max_items += 1
		Personality.THIEF:
			patience_seconds *= 0.8

func _apply_color_tint() -> void:
	var body_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if body_mesh == null:
		return
	var tint: Color = PERSONALITY_COLORS.get(personality, Color.WHITE)
	if tint == Color.WHITE:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	body_mesh.material_override = mat

func get_personality_name() -> String:
	match personality:
		Personality.NORMAL: return "Normal"
		Personality.IMPATIENT: return "Impatient"
		Personality.RICH: return "Rich"
		Personality.BARGAIN: return "Bargain Hunter"
		Personality.THIEF: return "Thief"
	return "Unknown"

func initialize(entrance: Vector3, exit_pos: Vector3) -> void:
	_entrance_pos = entrance
	_exit_pos = exit_pos

	var map_rid := get_world_3d().navigation_map
	var snap_pos := NavigationServer3D.map_get_closest_point(map_rid, entrance)
	if snap_pos.distance_to(Vector3.ZERO) < 0.5 and entrance.distance_to(Vector3.ZERO) > 1.0:
		snap_pos = entrance
		snap_pos.y += 0.5
	global_position = snap_pos

	var store_center := Vector3.ZERO
	var inward_dir := (store_center - entrance).normalized()
	_browse_target = NavigationServer3D.map_get_closest_point(
		map_rid, entrance + inward_dir * randf_range(3.0, 5.0))

	_wander_budget = randi_range(wander_steps_min, wander_steps_max)

	_build_shopping_list_from_stock()

	_initialized = true
	_change_state(State.ENTERING)
	EventBus.customer_entered.emit(self)

func set_group_info(gid: int, leader: bool, leader_node: Node = null) -> void:
	group_id = gid
	is_group_leader = leader
	_leader_ref = leader_node

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
		State.STEALING:            _tick_stealing(delta)

	if state in [State.BROWSING_SHELF, State.IDLE_LOOK, State.AT_SHELF,
				 State.QUEUING, State.AT_CHECKOUT, State.INSPECTING_SHELF,
				 State.DECIDING, State.STEALING]:
		if nav_agent.avoidance_enabled:
			nav_agent.set_velocity(Vector3.ZERO)

	if not is_group_leader and _leader_ref and is_instance_valid(_leader_ref):
		if state == State.WANDERING or state == State.ENTERING:
			var dist_to_leader := global_position.distance_to(_leader_ref.global_position)
			if dist_to_leader > 5.0:
				_navigate_to(_leader_ref.global_position + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)))

	move_and_slide()

	_patience_timer += delta
	if _patience_timer > patience_seconds \
		and state not in [State.AT_CHECKOUT, State.LEAVING, State.STEALING]:
		_leaving_unhappy = true
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
	if not _decision_waiting:
		_decision_delay = randf_range(0.3, 0.8)
		_decision_waiting = true
		return

	if _state_timer < _decision_delay:
		return
	_decision_waiting = false

	if shopping_list.is_empty() and shopping_cart.is_empty() and stolen_items.is_empty():
		_build_shopping_list_from_stock()

	if shopping_list.is_empty():
		if shopping_cart.is_empty() and stolen_items.is_empty():
			_leaving_unhappy = true
			EventBus.customer_unsatisfied.emit(self, "nothing_available")
			_go_leave()
		else:
			_go_to_checkout()
		return

	var pid: String = shopping_list[0]

	if not _should_buy_at_price(pid):
		shopping_list.remove_at(0)
		if shopping_list.is_empty():
			if shopping_cart.is_empty() and stolen_items.is_empty():
				_leaving_unhappy = true
				EventBus.customer_unsatisfied.emit(self, "prices_too_high")
				_go_leave()
			else:
				_go_to_checkout()
		return

	var aisle := _find_aisle_for_product(pid)
	if aisle and aisle not in _aisles_visited:
		_start_aisle_browse(aisle)
		return

	_target_shelf = _find_shelf_for_product(pid)
	if _target_shelf:
		_navigate_to(_target_shelf.global_position)
		_change_state(State.WALKING_TO_SHELF)
	else:
		_leaving_unhappy = true
		EventBus.customer_unsatisfied.emit(self, "product_not_found:%s" % pid)
		shopping_list.remove_at(0)

func _should_buy_at_price(product_id: String) -> bool:
	var db = get_node_or_null("/root/ProductDatabase")
	if db == null:
		return true
	var p = db.get_product(product_id)
	if p == null:
		return true
	var ratio: float = db.get_price_ratio(product_id)
	match personality:
		Personality.RICH:
			return ratio < 3.0
		Personality.BARGAIN:
			return ratio < 1.3
		Personality.IMPATIENT:
			return ratio < 2.0
		Personality.THIEF:
			return true
		_:
			return ratio < 2.0

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
				_try_pick_item_from_shelf(_inspect_shelf_target, pid)
			else:
				if thought_bubble:
					thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.QUESTION, 1.5)
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

	if shopping_list.is_empty() or shopping_cart.size() + stolen_items.size() >= max_items:
		if personality == Personality.THIEF and not stolen_items.is_empty() and shopping_cart.is_empty():
			_go_leave()
		else:
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

	if _target_shelf:
		var look_yaw := _yaw_toward(_target_shelf.global_position)
		rotation.y = lerp_angle(rotation.y, look_yaw, 5.0 * _delta)

	if _state_timer < 1.0:
		return

	if _target_shelf and not shopping_list.is_empty():
		var pid: String = shopping_list[0]
		if _target_shelf.get_stock_of(pid) > 0:
			_try_pick_item_from_shelf(_target_shelf, pid)
		else:
			_leaving_unhappy = true
			EventBus.customer_unsatisfied.emit(self, "shelf_empty:%s" % pid)
			shopping_list.remove_at(0)
			if thought_bubble:
				thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.QUESTION, 1.5)

	_target_shelf = null

	if shopping_list.is_empty() or shopping_cart.size() + stolen_items.size() >= max_items:
		if personality == Personality.THIEF and not stolen_items.is_empty() and shopping_cart.is_empty():
			_go_leave()
		else:
			_go_to_checkout()
	else:
		if randf() < wander_between_items_chance:
			_wander_budget = randi_range(1, 2)
			_begin_wander_or_decide()
		else:
			_change_state(State.IDLE_LOOK)

func _check_freshness_acceptable(shelf: Node, pid: String) -> bool:
	var fm = get_node_or_null("/root/FreshnessManager")
	if fm == null:
		return true
	var side_name: String = ""
	if shelf.has_method("find_side_for_product"):
		side_name = shelf.find_side_for_product(pid)
	if side_name.is_empty():
		return true
	var freshness: float = fm.get_freshness(shelf, side_name, pid)
	if freshness <= 5.0:
		return false
	if freshness < 30.0:
		var accept_chance := 0.5
		match personality:
			Personality.RICH:
				accept_chance = 0.1
			Personality.BARGAIN:
				accept_chance = 0.8
			Personality.IMPATIENT:
				accept_chance = 0.4
			Personality.THIEF:
				accept_chance = 0.9
		return randf() < accept_chance
	return true

func _try_pick_item_from_shelf(shelf: Node, pid: String) -> void:
	if not _check_freshness_acceptable(shelf, pid):
		shopping_list.remove_at(0)
		if thought_bubble:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.ANGRY, 1.5)
		return

	if personality == Personality.THIEF and randf() < 0.6:
		shelf.remove_stock(pid, 1)
		var db = get_node_or_null("/root/ProductDatabase")
		var value := 0.0
		if db:
			var p = db.get_product(pid)
			if p:
				value = p.get_effective_price()
		stolen_items.append({"product_id": pid, "quantity": 1, "value": value})
		shopping_list.remove_at(0)
		_show_carried_item(true)
		_attach_held_product(pid)
	else:
		shelf.remove_stock(pid, 1)
		shopping_cart.append({"product_id": pid, "quantity": 1})
		shopping_list.remove_at(0)
		EventBus.customer_satisfied.emit(self)
		_show_carried_item(true)
		_attach_held_product(pid)
		if thought_bubble:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.SATISFIED, 1.2)

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
	_held_product_id = product_id

func _clear_held_product() -> void:
	if _held_product_instance and is_instance_valid(_held_product_instance):
		_held_product_instance.queue_free()
	_held_product_instance = null
	_held_product_id = ""

func _tick_stealing(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_sway_phase += delta
	var body_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if body_mesh:
		body_mesh.rotation.z = sin(_sway_phase * 2.0) * 0.02
	if _state_timer > 0.5:
		_go_leave()

func _tick_leaving(delta: float) -> void:
	if _tick_walk(delta):
		if not stolen_items.is_empty():
			_attempt_theft()
		EventBus.customer_left.emit(self)
		if group_id >= 0 and is_group_leader:
			EventBus.customer_group_left.emit(group_id)
		queue_free()

func _attempt_theft() -> void:
	var total_value := 0.0
	for item in stolen_items:
		total_value += item.get("value", 0.0)
	EventBus.theft_attempted.emit(self, total_value)

	var wm = get_node_or_null("/root/WorkerManager")
	var detection := 0.0
	if wm and wm.has_method("get_detection_chance_at"):
		detection = wm.get_detection_chance_at(global_position)
	elif wm:
		detection = wm.get_total_detection_chance()

	if randf() < detection:
		var guard_info: Variant = {}
		if wm and wm.has_method("get_nearest_guard_bot"):
			var guard_bot: Node = wm.get_nearest_guard_bot(global_position)
			if guard_bot and guard_bot.has_method("_get_worker_dict"):
				guard_info = guard_bot._get_worker_dict()
		EventBus.theft_prevented.emit(self, guard_info)
		var pdb = get_node_or_null("/root/ProductDatabase")
		for item in stolen_items:
			if pdb:
				var shelves := get_tree().get_nodes_in_group("shelves")
				for shelf in shelves:
					if shelf.can_accept_product(item["product_id"]):
						shelf.add_stock(item["product_id"], item.get("quantity", 1))
						break
		stolen_items.clear()
	else:
		EventBus.theft_succeeded.emit(self, total_value)
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.apply_theft_loss(total_value)
		stolen_items.clear()

func _tick_idle_fidget(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if personality == Personality.IMPATIENT and state == State.QUEUING:
		if _target_counter and _target_counter.get_queue_size() > 2 and _state_timer > 5.0:
			_leaving_unhappy = true
			EventBus.customer_unsatisfied.emit(self, "impatient_queue")
			_go_leave()
			return

	if state == State.QUEUING and _state_timer > 15.0:
		if thought_bubble:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.ANGRY, 3.0)

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

	if _store_waypoints and _store_waypoints.has_method("get_random_waypoint_away_from"):
		var wp: Vector3 = _store_waypoints.get_random_waypoint_away_from(
			global_position, 3.0)
		return NavigationServer3D.map_get_closest_point(map_rid, wp)

	var shelves := get_tree().get_nodes_in_group("shelves")
	if not shelves.is_empty() and randf() < 0.6:
		var shelf: Node3D = shelves[randi() % shelves.size()]
		var offset := Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.0, 2.0))
		var candidate := shelf.global_position + offset
		candidate.y = 0.0
		return NavigationServer3D.map_get_closest_point(map_rid, candidate)
	else:
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
	_decision_waiting = false
	_update_thought_for_state(new_state)

func _update_thought_for_state(s: State) -> void:
	if thought_bubble == null:
		return
	match s:
		State.ENTERING:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.SHOPPING)
		State.WANDERING:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.BROWSING, 2.5)
		State.BROWSING_SHELF:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.BROWSING, _browse_pause_duration)
		State.IDLE_LOOK:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.QUESTION, 2.0)
		State.DECIDING:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.SHOPPING, 1.5)
		State.WALKING_TO_SHELF:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.PRODUCT_SEARCH, 3.0)
		State.AT_SHELF:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.PRODUCT_SEARCH, 1.5)
		State.WALKING_TO_CHECKOUT:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.QUEUE, 3.0)
		State.QUEUING:
			if personality == Personality.IMPATIENT:
				thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.ANGRY)
			else:
				thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.HOURGLASS)
		State.WALKING_TO_SERVICE:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.SATISFIED, 2.0)
		State.AT_CHECKOUT:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.PRICING, 3.0)
		State.LEAVING:
			if _leaving_unhappy:
				thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.ANGRY_CLOUD, 3.0)
			else:
				thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.EXIT, 3.0)
		State.WALKING_TO_AISLE:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.BROWSING, 3.0)
		State.BROWSING_AISLE:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.BROWSING, 3.0)
		State.INSPECTING_SHELF:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.BROWSING, _browse_pause_duration)
		State.STEALING:
			thought_bubble.show_thought(ThoughtBubbleScript.ThoughtType.THEFT, 2.0)
		_:
			thought_bubble.hide_thought()

func _go_leave() -> void:
	if _target_counter:
		_target_counter.leave_queue(self)
		_target_counter = null
	if _current_aisle:
		EventBus.customer_left_aisle.emit(self, _current_aisle)
		_current_aisle = null
	nav_agent.max_speed = walk_speed
	_navigate_to(_exit_pos)
	_show_carried_item(false)
	_clear_held_product()
	_change_state(State.LEAVING)

func _go_to_checkout() -> void:
	if not is_group_leader and _leader_ref and is_instance_valid(_leader_ref):
		if _leader_ref.state != State.WALKING_TO_CHECKOUT and _leader_ref.state != State.QUEUING:
			_change_state(State.IDLE_LOOK)
			return

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
	_clear_held_product()
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
		var fallback_db = get_node_or_null("/root/ProductDatabase")
		if fallback_db:
			var all_ids = fallback_db.get_all_product_ids()
			if not all_ids.is_empty():
				available_pids.assign(all_ids)

	if available_pids.is_empty():
		return

	var db = get_node_or_null("/root/ProductDatabase")
	if db and personality in [Personality.RICH, Personality.BARGAIN]:
		var scored: Array[Dictionary] = []
		for pid in available_pids:
			var p = db.get_product(pid)
			var price := 0.0
			if p:
				price = p.get_effective_price()
			scored.append({"pid": pid, "price": price})
		if personality == Personality.RICH:
			scored.sort_custom(func(a, b): return a["price"] > b["price"])
		else:
			scored.sort_custom(func(a, b): return a["price"] < b["price"])
		var count := mini(randi_range(1, max_items), scored.size())
		for i in count:
			shopping_list.append(scored[i]["pid"])
	else:
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
