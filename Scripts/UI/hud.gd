extends Control

@onready var money_label: Label = %MoneyLabel
@onready var day_label: Label = %DayLabel
@onready var status_label: Label = %StatusLabel
@onready var customer_label: Label = %CustomerLabel
@onready var hints_label: Label = %HintsLabel
@onready var timer_bar: ProgressBar = %TimerBar

@onready var crosshair: ColorRect = %Crosshair
@onready var prompt_label: Label = %PromptLabel
@onready var held_label: Label = %HeldLabel
@onready var transaction_label: Label = %TransactionLabel

var _tx_tween: Tween = null

const COL_GREEN := Color(0.3, 0.95, 0.45)
const COL_RED := Color(1.0, 0.35, 0.35)
const COL_YELLOW := Color(1.0, 0.9, 0.3)
const COL_MUTED := Color(0.5, 0.5, 0.55)
const COL_CROSSHAIR_IDLE := Color(0.7, 0.7, 0.7, 0.4)
const COL_CROSSHAIR_ACTIVE := Color(0.3, 1.0, 0.5, 0.9)

func _ready() -> void:
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.store_opened.connect(_on_store_opened)
	EventBus.store_closed.connect(_on_store_closed)
	EventBus.customer_entered.connect(func(_c): _refresh_customers())
	EventBus.customer_left.connect(func(_c): _refresh_customers())
	EventBus.interaction_prompt_show.connect(_show_prompt)
	EventBus.interaction_prompt_hide.connect(_hide_prompt)
	EventBus.product_picked_up.connect(_on_picked_up)
	EventBus.product_dropped.connect(func(_d): _set_held(null))
	EventBus.product_placed.connect(func(_d, _s): _set_held(null))
	EventBus.transaction_completed.connect(_on_transaction)

	_refresh_money()
	_refresh_day()
	_refresh_status()
	_refresh_customers()
	_set_held(null)
	_hide_prompt()
	transaction_label.visible = false
	crosshair.color = COL_CROSSHAIR_IDLE
	_refresh_hints()

func _process(_delta: float) -> void:
	_update_timer()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_store"):
		var gm = get_node_or_null("/root/GameManager")
		if gm and not gm.store_is_open:
			gm.open_store()
		get_viewport().set_input_as_handled()

func _on_money_changed(amount: float) -> void:
	money_label.text = "$%.2f" % amount
	_pop(money_label)

func _refresh_money() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		money_label.text = "$%.2f" % gm.money

func _on_day_started(day: int) -> void:
	day_label.text = "Day %d" % day
	_refresh_status()
	_refresh_hints()

func _refresh_day() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		day_label.text = "Day %d" % gm.day_number

func _on_store_opened() -> void:
	status_label.text = "OPEN"
	status_label.add_theme_color_override("font_color", COL_GREEN)
	_refresh_hints()

func _on_store_closed() -> void:
	status_label.text = "CLOSED"
	status_label.add_theme_color_override("font_color", COL_RED)
	_refresh_day()
	_refresh_hints()

func _refresh_status() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.store_is_open:
		_on_store_opened()
	else:
		_on_store_closed()

func _refresh_customers() -> void:
	var c := get_tree().get_nodes_in_group("customers").size()
	customer_label.text = "%d" % c

func _refresh_hints() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var open: bool = gm.store_is_open if gm else false
	var parts: PackedStringArray = []
	if not open:
		parts.append("[O] Open Store")
	parts.append("[Tab] Stock")
	parts.append("[E] Interact")
	parts.append("[Q] Drop")
	parts.append("[Esc] Pause")
	hints_label.text = "   ".join(parts)

func _update_timer() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.store_is_open:
		timer_bar.visible = true
		var sms := get_tree().get_nodes_in_group("store_manager")
		if not sms.is_empty() and "_day_timer" in sms[0]:
			timer_bar.value = (sms[0]._day_timer / gm.day_duration_seconds) * 100.0
	else:
		timer_bar.visible = false

func _show_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = true
	crosshair.color = COL_CROSSHAIR_ACTIVE

func _hide_prompt() -> void:
	prompt_label.visible = false
	crosshair.color = COL_CROSSHAIR_IDLE

func _on_picked_up(data: Resource) -> void:
	_set_held(data)
	_pop(held_label)

func _set_held(data: Resource) -> void:
	if data and "product_name" in data:
		held_label.text = "Holding: %s" % data.product_name
		held_label.visible = true
	else:
		held_label.text = ""
		held_label.visible = false

func _on_transaction(amount: float) -> void:
	transaction_label.text = "+$%.2f" % amount
	transaction_label.visible = true
	transaction_label.modulate = Color(0.3, 1.0, 0.4, 1.0)
	transaction_label.position.y = 0
	if _tx_tween:
		_tx_tween.kill()
	_tx_tween = create_tween()
	_tx_tween.set_parallel(true)
	_tx_tween.tween_property(transaction_label, "position:y", -30.0, 2.0).set_delay(0.5)
	_tx_tween.tween_property(transaction_label, "modulate:a", 0.0, 1.5).set_delay(1.0)
	_tx_tween.set_parallel(false)
	_tx_tween.tween_callback(func():
		transaction_label.visible = false
		transaction_label.position.y = 0)

func _pop(node: Control) -> void:
	if node == null:
		return
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.1, 1.1), 0.08)
	tw.tween_property(node, "scale", Vector2.ONE, 0.1)
