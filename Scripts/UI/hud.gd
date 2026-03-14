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
var _rep_label: Label = null
var _milestone_label: Label = null
var _milestone_tween: Tween = null
var _worker_label: Label = null
var _alert_container: VBoxContainer = null

func _ready() -> void:
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.store_opened.connect(func(): _set_status(true))
	EventBus.store_closed.connect(func(): _set_status(false))
	EventBus.customer_entered.connect(func(_c): _refresh_customers())
	EventBus.customer_left.connect(func(_c): _refresh_customers())
	EventBus.interaction_prompt_show.connect(_show_prompt)
	EventBus.interaction_prompt_hide.connect(_hide_prompt)
	EventBus.product_picked_up.connect(_on_picked_up)
	EventBus.product_dropped.connect(func(_d): _set_held(null))
	EventBus.product_placed.connect(func(_d, _s): _set_held(null))
	EventBus.transaction_completed.connect(_on_transaction)
	EventBus.reputation_milestone.connect(_on_reputation_milestone)
	EventBus.customer_group_entered.connect(_on_group_entered)
	EventBus.theft_succeeded.connect(_on_theft_alert)
	EventBus.shelf_emptied.connect(_on_shelf_empty_alert)
	EventBus.workers_changed.connect(_refresh_workers)
	_create_rep_label()
	_create_milestone_label()
	_create_worker_label()
	_create_alert_container()
	_sync_all()

func _process(_delta: float) -> void:
	_update_timer()
	_update_reputation()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_store"):
		var gm = get_node_or_null("/root/GameManager")
		if gm and not gm.store_is_open:
			gm.open_store()
		get_viewport().set_input_as_handled()

func _create_rep_label() -> void:
	_rep_label = Label.new()
	_rep_label.add_theme_font_size_override("font_size", 14)
	_rep_label.anchor_left = 1.0
	_rep_label.anchor_right = 1.0
	_rep_label.anchor_top = 0.0
	_rep_label.anchor_bottom = 0.0
	_rep_label.offset_left = -180.0
	_rep_label.offset_right = -10.0
	_rep_label.offset_top = 50.0
	_rep_label.offset_bottom = 70.0
	_rep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_rep_label)

func _create_milestone_label() -> void:
	_milestone_label = Label.new()
	_milestone_label.add_theme_font_size_override("font_size", 20)
	_milestone_label.anchor_left = 0.5
	_milestone_label.anchor_right = 0.5
	_milestone_label.anchor_top = 0.15
	_milestone_label.anchor_bottom = 0.15
	_milestone_label.offset_left = -200.0
	_milestone_label.offset_right = 200.0
	_milestone_label.offset_top = 0.0
	_milestone_label.offset_bottom = 30.0
	_milestone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_milestone_label.visible = false
	add_child(_milestone_label)

func _update_reputation() -> void:
	if _rep_label == null:
		return
	var rm = get_node_or_null("/root/ReputationManager")
	if rm == null:
		_rep_label.visible = false
		return
	var rep: float = rm.reputation
	var tier_name: String = _get_rep_tier_name(rep)
	var tier_color: Color = _get_rep_tier_color(rep)
	_rep_label.text = "Rep: %d  %s" % [int(rep), tier_name]
	_rep_label.add_theme_color_override("font_color", tier_color)
	_rep_label.visible = true

func _get_rep_tier_name(rep: float) -> String:
	if rep >= 90.0:
		return "★★★★★"
	if rep >= 70.0:
		return "★★★★"
	if rep >= 50.0:
		return "★★★"
	if rep >= 30.0:
		return "★★"
	return "★"

func _get_rep_tier_color(rep: float) -> Color:
	if rep >= 90.0:
		return Color(1.0, 0.85, 0.0)
	if rep >= 70.0:
		return Color(0.3, 0.88, 0.48)
	if rep >= 50.0:
		return Color(0.6, 0.75, 0.9)
	if rep >= 30.0:
		return Color(1.0, 0.65, 0.2)
	return Color(1.0, 0.3, 0.3)

func _on_reputation_milestone(level: String) -> void:
	if _milestone_label == null:
		return
	var display: String = level.capitalize()
	var col: Color = Color.WHITE
	match level:
		"excellent":
			col = Color(1.0, 0.85, 0.0)
		"good":
			col = Color(0.3, 0.88, 0.48)
		"average":
			col = Color(0.6, 0.75, 0.9)
		"poor":
			col = Color(1.0, 0.65, 0.2)
		"terrible":
			col = Color(1.0, 0.3, 0.3)
	_milestone_label.text = "Reputation: %s!" % display
	_milestone_label.add_theme_color_override("font_color", col)
	_milestone_label.visible = true
	_milestone_label.modulate.a = 1.0
	if _milestone_tween:
		_milestone_tween.kill()
	_milestone_tween = create_tween()
	_milestone_tween.tween_property(_milestone_label, "modulate:a", 0.0, 2.0).set_delay(2.0)
	_milestone_tween.tween_callback(func(): _milestone_label.visible = false)

func _on_group_entered(_group_id: int, members: Array) -> void:
	if members.size() >= 3 and _milestone_label:
		_milestone_label.text = "A group of %d entered!" % members.size()
		_milestone_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
		_milestone_label.visible = true
		_milestone_label.modulate.a = 1.0
		if _milestone_tween:
			_milestone_tween.kill()
		_milestone_tween = create_tween()
		_milestone_tween.tween_property(_milestone_label, "modulate:a", 0.0, 1.5).set_delay(1.5)
		_milestone_tween.tween_callback(func(): _milestone_label.visible = false)

func _sync_all() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		money_label.text = "$%.2f" % gm.money
		day_label.text = "Day %d" % gm.day_number
		_set_status(gm.store_is_open)
	_refresh_customers()
	_set_held(null)
	_hide_prompt()
	transaction_label.visible = false
	crosshair.color = Color(0.75, 0.75, 0.75, 0.35)
	_refresh_hints()

func _on_money_changed(amount: float) -> void:
	money_label.text = "$%.2f" % amount
	_pop(money_label)

func _on_day_started(day: int) -> void:
	day_label.text = "Day %d" % day
	_refresh_hints()

func _set_status(is_open: bool) -> void:
	if is_open:
		status_label.text = "OPEN"
		status_label.add_theme_color_override("font_color", Color(0.3, 0.92, 0.5))
	else:
		status_label.text = "CLOSED"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
	_refresh_hints()

func _refresh_customers() -> void:
	customer_label.text = "%d" % get_tree().get_nodes_in_group("customers").size()

func _refresh_hints() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var is_open: bool = gm.store_is_open if gm else false
	var parts: PackedStringArray = []
	if not is_open:
		parts.append("[O] Open")
	parts.append("[Tab] Stock")
	parts.append("[U] Upgrades")
	parts.append("[J] Workers")
	parts.append("[K] Stats")
	parts.append("[E] Interact")
	parts.append("[Q] Drop")
	parts.append("[Esc] Menu")
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
	crosshair.color = Color(0.35, 0.95, 0.55, 0.85)

func _hide_prompt() -> void:
	prompt_label.visible = false
	crosshair.color = Color(0.75, 0.75, 0.75, 0.35)

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
	transaction_label.modulate = Color(0.35, 1.0, 0.5, 1.0)
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
	tw.tween_property(node, "scale", Vector2(1.12, 1.12), 0.07)
	tw.tween_property(node, "scale", Vector2.ONE, 0.09)

func _create_worker_label() -> void:
	_worker_label = Label.new()
	_worker_label.add_theme_font_size_override("font_size", 14)
	_worker_label.anchor_left = 1.0
	_worker_label.anchor_right = 1.0
	_worker_label.anchor_top = 0.0
	_worker_label.anchor_bottom = 0.0
	_worker_label.offset_left = -180.0
	_worker_label.offset_right = -10.0
	_worker_label.offset_top = 72.0
	_worker_label.offset_bottom = 92.0
	_worker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_worker_label.add_theme_color_override("font_color", Color(0.55, 0.70, 0.88))
	add_child(_worker_label)
	_refresh_workers()

func _refresh_workers() -> void:
	if _worker_label == null:
		return
	var wm = get_node_or_null("/root/WorkerManager")
	if wm == null:
		_worker_label.visible = false
		return
	var count: int = wm.workers.size()
	_worker_label.text = "Workers: %d" % count
	_worker_label.visible = count > 0

func _create_alert_container() -> void:
	_alert_container = VBoxContainer.new()
	_alert_container.add_theme_constant_override("separation", 4)
	_alert_container.anchor_left = 1.0
	_alert_container.anchor_right = 1.0
	_alert_container.anchor_top = 0.0
	_alert_container.anchor_bottom = 0.0
	_alert_container.offset_left = -260.0
	_alert_container.offset_right = -10.0
	_alert_container.offset_top = 96.0
	_alert_container.offset_bottom = 300.0
	add_child(_alert_container)

func _show_alert(text: String, color: Color) -> void:
	if _alert_container == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_alert_container.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 0.0, 2.0).set_delay(3.0)
	tw.tween_callback(func(): lbl.queue_free())

func _on_theft_alert(_customer: Node, value: float) -> void:
	_show_alert("⚠ Theft! Lost $%.2f" % value, Color(1.0, 0.35, 0.30))

func _on_shelf_empty_alert(_shelf: Node) -> void:
	_show_alert("⚠ A shelf is empty!", Color(1.0, 0.65, 0.20))
