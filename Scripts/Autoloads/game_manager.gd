extends Node

var money: float = 500.0 : set = set_money
var day_number: int = 1
var store_is_open: bool = false
var total_customers_served: int = 0
var total_revenue: float = 0.0
var reputation: float = 50.0

var day_duration_seconds: float = 180.0

func _ready() -> void:
	_load_keybinds()

func _load_keybinds() -> void:
	var config := ConfigFile.new()
	var err := config.load("user://settings.cfg")
	if err != OK:
		return
	for action in config.get_section_keys("keybinds"):
		var keycode: int = config.get_value("keybinds", action)
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode as Key
			InputMap.action_add_event(action, ev)

func set_money(value: float) -> void:
	money = snapped(value, 0.01)
	EventBus.money_changed.emit(money)

func add_money(amount: float) -> void:
	self.money += amount
	total_revenue += amount

func spend_money(amount: float) -> bool:
	if money >= amount:
		self.money -= amount
		return true
	return false

func apply_theft_loss(_value: float) -> void:
	pass

func open_store() -> void:
	if store_is_open:
		return
	store_is_open = true
	EventBus.store_opened.emit()
	EventBus.day_started.emit(day_number)

func close_store() -> void:
	if not store_is_open:
		return
	store_is_open = false
	EventBus.store_closed.emit()
	EventBus.day_ended.emit(day_number)
	day_number += 1

func record_customer_served() -> void:
	total_customers_served += 1
