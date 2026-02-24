extends Node

var money: float = 500.0 : set = set_money
var day_number: int = 1
var store_is_open: bool = false
var total_customers_served: int = 0
var total_revenue: float = 0.0

var day_duration_seconds: float = 180.0

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
