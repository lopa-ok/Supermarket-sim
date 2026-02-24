class_name GameHUD
extends Control

@onready var money_label: Label = %MoneyLabel
@onready var day_label: Label = %DayLabel
@onready var store_status_label: Label = %StoreStatusLabel
@onready var prompt_label: Label = %PromptLabel
@onready var held_item_label: Label = %HeldItemLabel
@onready var transaction_label: Label = %TransactionLabel
@onready var customer_count_label: Label = %CustomerCountLabel
@onready var day_timer_bar: ProgressBar = %DayTimerBar
@onready var stock_container: VBoxContainer = %StockContainer
@onready var crosshair: TextureRect = %Crosshair

var _transaction_tween: Tween = null
var _prompt_tween: Tween = null
var _crosshair_default_modulate: Color = Color.WHITE

const CROSSHAIR_ACTIVE := Color(0.3, 1.0, 0.4, 1.0)
const CROSSHAIR_INACTIVE := Color(0.8, 0.8, 0.8, 0.5)

func _ready() -> void:
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.interaction_prompt_show.connect(_on_prompt_show)
	EventBus.interaction_prompt_hide.connect(_on_prompt_hide)
	EventBus.product_picked_up.connect(_on_product_picked_up)
	EventBus.product_dropped.connect(_on_product_dropped)
	EventBus.product_placed.connect(_on_product_placed)
	EventBus.transaction_completed.connect(_on_transaction_completed)
	EventBus.store_opened.connect(_on_store_opened)
	EventBus.store_closed.connect(_on_store_closed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.shelf_stock_changed.connect(_on_shelf_stock_changed)
	EventBus.customer_entered.connect(_on_customer_changed)
	EventBus.customer_left.connect(_on_customer_changed)

	_on_prompt_hide()
	transaction_label.visible = false
	_refresh_money()
	_refresh_day()
	_refresh_store_status()
	_refresh_held_item(null)
	if crosshair:
		_crosshair_default_modulate = crosshair.modulate
		crosshair.modulate = CROSSHAIR_INACTIVE

func _process(_delta: float) -> void:
	_update_day_timer()
	_update_customer_count()

func _on_money_changed(new_amount: float) -> void:
	money_label.text = "$%.2f" % new_amount
	_bounce_node(money_label)

func _refresh_money() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		money_label.text = "$%.2f" % gm.money

func _on_day_started(day_number: int) -> void:
	day_label.text = "Day %d" % day_number

func _refresh_day() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		day_label.text = "Day %d" % gm.day_number

func _update_day_timer() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.store_is_open:
		day_timer_bar.visible = true
		var store_managers := get_tree().get_nodes_in_group("store_manager")
		if not store_managers.is_empty():
			var sm = store_managers[0]
			if "_day_timer" in sm:
				day_timer_bar.value = (sm._day_timer / gm.day_duration_seconds) * 100.0
	else:
		day_timer_bar.visible = false

func _on_store_opened() -> void:
	store_status_label.text = "OPEN"
	store_status_label.add_theme_color_override("font_color", Color.GREEN)

func _on_store_closed() -> void:
	store_status_label.text = "CLOSED"
	store_status_label.add_theme_color_override("font_color", Color.RED)
	_refresh_day()

func _refresh_store_status() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.store_is_open:
		_on_store_opened()
	else:
		_on_store_closed()

func _on_prompt_show(text: String) -> void:
	prompt_label.text = text
	if not prompt_label.visible:
		prompt_label.visible = true
		prompt_label.modulate.a = 0.0
		if _prompt_tween:
			_prompt_tween.kill()
		_prompt_tween = create_tween()
		_prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.15)
	if crosshair:
		crosshair.modulate = CROSSHAIR_ACTIVE

func _on_prompt_hide() -> void:
	prompt_label.visible = false
	if crosshair:
		crosshair.modulate = CROSSHAIR_INACTIVE

func _on_product_picked_up(product_data: Resource) -> void:
	_refresh_held_item(product_data)
	_bounce_node(held_item_label)

func _on_product_dropped(_product_data: Resource) -> void:
	_refresh_held_item(null)

func _on_product_placed(_product_data: Resource, _shelf: Node) -> void:
	_refresh_held_item(null)

func _refresh_held_item(product_data: Resource) -> void:
	if product_data and "product_name" in product_data:
		held_item_label.text = "Holding: %s" % product_data.product_name
		held_item_label.visible = true
	else:
		held_item_label.text = ""
		held_item_label.visible = false

func _on_transaction_completed(amount: float) -> void:
	transaction_label.text = "+$%.2f" % amount
	transaction_label.visible = true
	transaction_label.modulate = Color(0.2, 1.0, 0.2, 1.0)
	transaction_label.position.y = 0

	if _transaction_tween:
		_transaction_tween.kill()
	_transaction_tween = create_tween()
	_transaction_tween.set_parallel(true)
	_transaction_tween.tween_property(transaction_label, "position:y",
		transaction_label.position.y - 30.0, 2.0).set_delay(0.5)
	_transaction_tween.tween_property(transaction_label, "modulate:a", 0.0, 1.5).set_delay(1.0)
	_transaction_tween.set_parallel(false)
	_transaction_tween.tween_callback(func():
		transaction_label.visible = false
		transaction_label.position.y = 0)

func _on_customer_changed(_customer: Node) -> void:
	_update_customer_count()

func _update_customer_count() -> void:
	var count := get_tree().get_nodes_in_group("customers").size()
	customer_count_label.text = "Customers: %d" % count

func _on_shelf_stock_changed(_shelf: Node, _product_id: String, _current: int, _max_stock: int) -> void:
	_rebuild_stock_display()

func _rebuild_stock_display() -> void:
	for child in stock_container.get_children():
		child.queue_free()

	var shelves := get_tree().get_nodes_in_group("shelves")
	for shelf in shelves:
		if shelf.has_method("get_total_stock"):
			var lbl := Label.new()
			var tag: String = ""
			if "front_shelf_tag" in shelf and not shelf.front_shelf_tag.is_empty():
				tag = shelf.front_shelf_tag
			elif "shelf_tag" in shelf:
				tag = shelf.shelf_tag
			else:
				tag = "?"
			var total_stock: int = shelf.get_total_stock()
			var total_max: int = 10
			if "front_max_stock" in shelf and "back_max_stock" in shelf:
				total_max = shelf.front_max_stock + shelf.back_max_stock
			elif "max_stock" in shelf:
				total_max = shelf.max_stock
			lbl.text = "%s: %d/%d" % [tag.capitalize(), total_stock, total_max]
			lbl.add_theme_font_size_override("font_size", 14)
			if total_stock <= 0:
				lbl.add_theme_color_override("font_color", Color.RED)
			elif total_stock < total_max * 0.3:
				lbl.add_theme_color_override("font_color", Color.YELLOW)
			else:
				lbl.add_theme_color_override("font_color", Color.WHITE)
			stock_container.add_child(lbl)

func _bounce_node(node: Control) -> void:
	if node == null:
		return
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.15, 1.15), 0.1)
	tw.tween_property(node, "scale", Vector2.ONE, 0.15)
