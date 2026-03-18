extends Node

const INITIAL_REPUTATION := 50.0
const MIN_REP := 0.0
const MAX_REP := 100.0

const REP_SATISFIED := 1.5
const REP_UNSATISFIED := -2.0
const REP_SHELF_EMPTY := -0.5
const REP_THEFT_SUCCESS := -3.0
const REP_THEFT_PREVENTED := 1.0
const REP_LONG_WAIT := -1.0
const REP_CHECKOUT_COMPLETE := 0.5

var reputation: float = INITIAL_REPUTATION : set = _set_reputation
var _previous_milestone: String = ""

func _ready() -> void:
	EventBus.customer_satisfied.connect(_on_customer_satisfied)
	EventBus.customer_unsatisfied.connect(_on_customer_unsatisfied)
	EventBus.shelf_emptied.connect(_on_shelf_emptied)
	EventBus.theft_succeeded.connect(_on_theft_succeeded)
	EventBus.theft_prevented.connect(_on_theft_prevented)
	EventBus.checkout_completed.connect(_on_checkout_completed)
	EventBus.day_started.connect(_on_day_started)
	_sync_to_game_manager()

func _set_reputation(value: float) -> void:
	reputation = clampf(value, MIN_REP, MAX_REP)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.reputation = reputation
	_check_milestone()

func get_spawn_rate_multiplier() -> float:
	if reputation >= 80.0:
		return 1.4
	elif reputation >= 60.0:
		return 1.2
	elif reputation >= 40.0:
		return 1.0
	elif reputation >= 20.0:
		return 0.7
	return 0.4

func get_max_customer_bonus() -> int:
	if reputation >= 80.0:
		return 4
	elif reputation >= 60.0:
		return 2
	elif reputation >= 40.0:
		return 0
	return -2

func add_reputation(amount: float) -> void:
	self.reputation += amount

func _on_customer_satisfied(_customer: Node) -> void:
	add_reputation(REP_SATISFIED)

func _on_customer_unsatisfied(_customer: Node, reason: String) -> void:
	if reason.begins_with("shelf_empty"):
		add_reputation(REP_SHELF_EMPTY)
	elif reason == "out_of_patience" or reason == "impatient_queue":
		add_reputation(REP_LONG_WAIT)
	else:
		add_reputation(REP_UNSATISFIED)

func _on_shelf_emptied(_shelf: Node) -> void:
	add_reputation(REP_SHELF_EMPTY * 0.5)

func _on_theft_succeeded(_customer: Node, _value: float) -> void:
	add_reputation(REP_THEFT_SUCCESS)

func _on_theft_prevented(_customer: Node, _guard: Variant) -> void:
	add_reputation(REP_THEFT_PREVENTED)

func _on_checkout_completed(_counter: Node, _customer: Node, _total: float) -> void:
	add_reputation(REP_CHECKOUT_COMPLETE)

func _on_day_started(_day: int) -> void:
	var drift := (50.0 - reputation) * 0.02
	add_reputation(drift)

func _check_milestone() -> void:
	var level := ""
	if reputation >= 90.0:
		level = "excellent"
	elif reputation >= 70.0:
		level = "good"
	elif reputation >= 40.0:
		level = "average"
	elif reputation >= 20.0:
		level = "poor"
	else:
		level = "terrible"
	if level != _previous_milestone:
		_previous_milestone = level
		EventBus.reputation_milestone.emit(level)

func _sync_to_game_manager() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.reputation = reputation
