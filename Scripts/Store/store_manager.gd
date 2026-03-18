class_name StoreManager
extends Node3D

@export_group("Store Settings")
@export var customer_scene: PackedScene = null
@export var spawn_interval_min: float = 5.0
@export var spawn_interval_max: float = 15.0
@export var max_customers: int = 8

@export_group("Group Settings")
@export var group_spawn_chance: float = 0.25
@export var group_size_min: int = 2
@export var group_size_max: int = 4

@onready var entrance: Marker3D = $Entrance if has_node("Entrance") else null
@onready var exit_marker: Marker3D = $Exit if has_node("Exit") else null
@onready var spawn_timer: Timer = $CustomerSpawnTimer if has_node("CustomerSpawnTimer") else null

var _day_timer: float = 0.0
var _next_group_id: int = 1

func _ready() -> void:
	add_to_group("store_manager")

	if spawn_timer:
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		spawn_timer.one_shot = true

	EventBus.store_opened.connect(_on_store_opened)
	EventBus.store_closed.connect(_on_store_closed)

func _process(delta: float) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or not gm.store_is_open:
		return

	_day_timer += delta
	if _day_timer >= gm.day_duration_seconds:
		gm.close_store()

	_tick_checkouts()

func _on_store_opened() -> void:
	_day_timer = 0.0
	_start_spawn_timer()

func _on_store_closed() -> void:
	if spawn_timer:
		spawn_timer.stop()

func _start_spawn_timer() -> void:
	if spawn_timer == null:
		return
	var wait := randf_range(spawn_interval_min, spawn_interval_max)
	var um = get_node_or_null("/root/UpgradeManager")
	if um:
		var multiplier: float = um.get_upgrade_value("customer_spawn_rate")
		if multiplier > 0.0:
			wait /= multiplier
	var rm = get_node_or_null("/root/ReputationManager")
	if rm:
		var rep_mult: float = rm.get_spawn_rate_multiplier()
		if rep_mult > 0.0:
			wait /= rep_mult
	spawn_timer.start(wait)

func _get_effective_max_customers() -> int:
	var base := max_customers
	var rm = get_node_or_null("/root/ReputationManager")
	if rm:
		base += rm.get_max_customer_bonus()
	return maxi(2, base)

func _on_spawn_timer_timeout() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or not gm.store_is_open:
		return

	var current_customers := get_tree().get_nodes_in_group("customers").size()
	var effective_max := _get_effective_max_customers()
	if current_customers < effective_max:
		if randf() < group_spawn_chance and current_customers + group_size_min <= effective_max:
			var remaining_slots := effective_max - current_customers
			var group_size := mini(randi_range(group_size_min, group_size_max), remaining_slots)
			_spawn_group(group_size)
		else:
			_spawn_customer()

	_start_spawn_timer()

func _spawn_customer() -> Node:
	if customer_scene == null:
		push_warning("StoreManager: No customer_scene assigned!")
		return null

	var customer: Node = customer_scene.instantiate()
	get_tree().current_scene.add_child(customer)

	var entrance_pos := entrance.global_position if entrance else Vector3(0, 0, 10)
	var exit_pos := exit_marker.global_position if exit_marker else Vector3(0, 0, 15)

	if customer.has_method("initialize"):
		customer.initialize(entrance_pos, exit_pos)

	return customer

func _spawn_group(count: int) -> void:
	var gid := _next_group_id
	_next_group_id += 1

	var members: Array[Node] = []
	var leader: Node = null

	for i in count:
		var customer := _spawn_customer()
		if customer == null:
			continue
		members.append(customer)
		if i == 0:
			leader = customer

	if members.is_empty():
		return

	for member in members:
		if member.has_method("set_group_info"):
			if member == leader:
				member.set_group_info(gid, true)
				member.group_members.assign(members)
			else:
				member.set_group_info(gid, false, leader)

	EventBus.customer_group_entered.emit(gid, members)

func _tick_checkouts() -> void:
	var counters := get_tree().get_nodes_in_group("checkout_counters")
	for counter in counters:
		if counter.has_method("try_advance_queue"):
			counter.try_advance_queue()
