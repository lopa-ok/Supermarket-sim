class_name DaySummary
extends Control

@onready var title_label: Label = %SummaryTitle
@onready var revenue_label: Label = %RevenueLabel
@onready var customers_label: Label = %CustomersLabel
@onready var balance_label: Label = %BalanceLabel
@onready var continue_label: Label = %ContinueLabel

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.day_ended.connect(_on_day_ended)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_dismiss()
		get_viewport().set_input_as_handled()

func _on_day_ended(day_number: int) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	title_label.text = "Day %d Complete" % day_number
	revenue_label.text = "$%.2f" % gm.total_revenue
	customers_label.text = "%d" % gm.total_customers_served
	balance_label.text = "$%.2f" % gm.money
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)

func _dismiss() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func(): visible = false)
