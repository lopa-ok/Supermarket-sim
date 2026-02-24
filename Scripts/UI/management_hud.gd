class_name ManagementHUD
extends Control

@onready var money_label: Label = %MoneyLabel
@onready var day_label: Label = %DayLabel
@onready var store_status_label: Label = %StoreStatusLabel
@onready var customer_count_label: Label = %CustomerCountLabel
@onready var day_timer_bar: ProgressBar = %DayTimerBar

@onready var crosshair: TextureRect = %Crosshair
@onready var prompt_label: Label = %PromptLabel
@onready var held_item_label: Label = %HeldItemLabel
@onready var transaction_label: Label = %TransactionLabel

@onready var side_panel: PanelContainer = %SidePanel
@onready var stock_container: VBoxContainer = %StockContainer
@onready var aisle_container: VBoxContainer = %AisleContainer
@onready var alert_container: VBoxContainer = %AlertContainer

@onready var controls_label: Label = %ControlsLabel

var _transaction_tween: Tween = null
var _prompt_tween: Tween = null
var _side_panel_visible: bool = false
var _alert_cooldown: float = 0.0

const CROSSHAIR_ACTIVE := Color(0.3, 1.0, 0.4, 1.0)
const CROSSHAIR_INACTIVE := Color(0.8, 0.8, 0.8, 0.5)
const LOW_STOCK_THRESHOLD := 0.3

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
	_update_customer_count()
	if crosshair:
		crosshair.modulate = CROSSHAIR_INACTIVE
	side_panel.visible = _side_panel_visible
	_update_controls_label()
	_rebuild_stock_display()
	_rebuild_aisle_display()

func _process(delta: float) -> void:
	_update_day_timer()
	_update_customer_count()
	_alert_cooldown -= delta
	if _alert_cooldown <= 0.0:
		_alert_cooldown = 5.0
		_update_alerts()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_panel"):
		_toggle_side_panel()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("open_store"):
		_try_open_store()
		get_viewport().set_input_as_handled()

func _try_open_store() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and not gm.store_is_open:
		gm.open_store()

func _on_money_changed(new_amount: float) -> void:
	money_label.text = "  $%.2f" % new_amount
	_bounce_node(money_label)

func _refresh_money() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		money_label.text = "  $%.2f" % gm.money

func _on_day_started(day_number: int) -> void:
	day_label.text = "  Day %d" % day_number
	_refresh_store_status()
	_update_controls_label()

func _refresh_day() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		day_label.text = "  Day %d" % gm.day_number

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
	store_status_label.text = "  OPEN"
	store_status_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
	_update_controls_label()

func _on_store_closed() -> void:
	store_status_label.text = "  CLOSED"
	store_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_refresh_day()
	_update_controls_label()

func _refresh_store_status() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.store_is_open:
		_on_store_opened()
	else:
		_on_store_closed()

func _update_controls_label() -> void:
	if controls_label == null:
		return
	var gm = get_node_or_null("/root/GameManager")
	var store_open: bool = gm.store_is_open if gm else false
	var lines: PackedStringArray = PackedStringArray()
	if not store_open:
		lines.append("[O] Open Store")
	lines.append("[Tab] Toggle Stock Panel")
	lines.append("[E] Interact  [Q] Drop")
	lines.append("[Esc] Pause")
	controls_label.text = "  ".join(lines)

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
		held_item_label.text = " Holding: %s" % product_data.product_name
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
	customer_count_label.text = "  %d" % count

func _toggle_side_panel() -> void:
	_side_panel_visible = not _side_panel_visible
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if _side_panel_visible:
		side_panel.visible = true
		side_panel.modulate.a = 0.0
		tw.tween_property(side_panel, "modulate:a", 1.0, 0.2)
	else:
		tw.tween_property(side_panel, "modulate:a", 0.0, 0.15)
		tw.tween_callback(func(): side_panel.visible = false)

func _on_shelf_stock_changed(_shelf: Node, _product_id: String, _current: int, _max_stock: int) -> void:
	_rebuild_stock_display()
	_rebuild_aisle_display()

func _rebuild_stock_display() -> void:
	for child in stock_container.get_children():
		child.queue_free()

	var db = get_node_or_null("/root/ProductDatabase")
	var shelves := get_tree().get_nodes_in_group("shelves")
	var product_totals: Dictionary = {}
	var grand_total: int = 0
	var grand_max: int = 0

	for shelf in shelves:
		if not shelf.has_method("get_total_stock"):
			continue

		var total_max: int = 10
		if "front_max_stock" in shelf and "back_max_stock" in shelf:
			total_max = shelf.front_max_stock + shelf.back_max_stock
		elif "max_stock" in shelf:
			total_max = shelf.max_stock
		grand_max += total_max

		if "stock" in shelf and shelf.stock is Dictionary:
			for side_key in shelf.stock:
				var side_data = shelf.stock[side_key]
				if side_data is Dictionary:
					for pid in side_data:
						var count: int = side_data[pid]
						if count > 0:
							product_totals[pid] = product_totals.get(pid, 0) + count
							grand_total += count

	var total_row := HBoxContainer.new()
	total_row.add_theme_constant_override("separation", 6)
	var total_icon := Label.new()
	total_icon.text = "📦"
	total_icon.add_theme_font_size_override("font_size", 12)
	total_row.add_child(total_icon)
	var total_name := Label.new()
	total_name.text = "Total Inventory"
	total_name.add_theme_font_size_override("font_size", 14)
	total_name.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	total_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(total_name)
	var total_count := Label.new()
	total_count.text = "%d/%d" % [grand_total, grand_max]
	total_count.add_theme_font_size_override("font_size", 14)
	total_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var grand_ratio: float = float(grand_total) / float(grand_max) if grand_max > 0 else 0.0
	if grand_total <= 0:
		total_count.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif grand_ratio < LOW_STOCK_THRESHOLD:
		total_count.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		total_count.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	total_row.add_child(total_count)
	var total_bar := _create_progress_bar(grand_total, grand_max, grand_ratio)
	total_row.add_child(total_bar)
	stock_container.add_child(total_row)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	stock_container.add_child(sep)

	var sorted_pids: Array = product_totals.keys()
	sorted_pids.sort()

	for pid in sorted_pids:
		var count: int = product_totals[pid]
		var product_name: String = pid.capitalize()
		if db:
			var pdata = db.get_product(pid)
			if pdata and "product_name" in pdata:
				product_name = pdata.product_name

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var icon_lbl := Label.new()
		icon_lbl.text = "●"
		icon_lbl.add_theme_font_size_override("font_size", 8)
		if count <= 1:
			icon_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		elif count <= 3:
			icon_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			icon_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		row.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = product_name
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		row.add_child(name_lbl)

		var count_lbl := Label.new()
		count_lbl.text = "%d" % count
		count_lbl.add_theme_font_size_override("font_size", 13)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if count <= 1:
			count_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		elif count <= 3:
			count_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			count_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		row.add_child(count_lbl)

		stock_container.add_child(row)

	if product_totals.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No stock"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		stock_container.add_child(empty_lbl)

	var shelf_sep := HSeparator.new()
	shelf_sep.add_theme_constant_override("separation", 4)
	stock_container.add_child(shelf_sep)

	for shelf in shelves:
		if not shelf.has_method("get_total_stock"):
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

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

		var ratio: float = float(total_stock) / float(total_max) if total_max > 0 else 0.0

		var icon_lbl := Label.new()
		icon_lbl.text = "◼" if total_stock > 0 else "◻"
		icon_lbl.add_theme_font_size_override("font_size", 10)
		if total_stock <= 0:
			icon_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		elif ratio < LOW_STOCK_THRESHOLD:
			icon_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			icon_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		row.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = tag.capitalize()
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		row.add_child(name_lbl)

		var count_lbl := Label.new()
		count_lbl.text = "%d/%d" % [total_stock, total_max]
		count_lbl.add_theme_font_size_override("font_size", 13)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if total_stock <= 0:
			count_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		elif ratio < LOW_STOCK_THRESHOLD:
			count_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			count_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		row.add_child(count_lbl)

		var bar := _create_progress_bar(total_stock, total_max, ratio)
		row.add_child(bar)

		stock_container.add_child(row)

func _create_progress_bar(value_: int, max_: int, ratio: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(60, 8)
	bar.max_value = max_
	bar.value = value_
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.18)
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	bg_style.corner_radius_bottom_left = 2
	bg_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("background", bg_style)
	var fill_style := StyleBoxFlat.new()
	if value_ <= 0:
		fill_style.bg_color = Color(0.8, 0.2, 0.2)
	elif ratio < LOW_STOCK_THRESHOLD:
		fill_style.bg_color = Color(0.9, 0.75, 0.1)
	else:
		fill_style.bg_color = Color(0.2, 0.7, 0.3)
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill_style)
	return bar

func _rebuild_aisle_display() -> void:
	for child in aisle_container.get_children():
		child.queue_free()

	var aisles := get_tree().get_nodes_in_group("aisles")
	if aisles.is_empty():
		var lbl := Label.new()
		lbl.text = "No aisles"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		aisle_container.add_child(lbl)
		return

	for aisle in aisles:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var aisle_name_str: String = aisle.aisle_name if "aisle_name" in aisle else "Aisle"
		var name_lbl := Label.new()
		name_lbl.text = aisle_name_str
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9))
		row.add_child(name_lbl)

		var aisle_stock := 0
		var aisle_max := 0
		if aisle.has_method("get_shelves"):
			for shelf in aisle.get_shelves():
				if shelf.has_method("get_total_stock"):
					aisle_stock += shelf.get_total_stock()
				if "front_max_stock" in shelf and "back_max_stock" in shelf:
					aisle_max += shelf.front_max_stock + shelf.back_max_stock

		var stat_lbl := Label.new()
		stat_lbl.text = "%d/%d" % [aisle_stock, aisle_max]
		stat_lbl.add_theme_font_size_override("font_size", 12)
		stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var aisle_ratio: float = float(aisle_stock) / float(aisle_max) if aisle_max > 0 else 0.0
		if aisle_ratio <= 0.0:
			stat_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		elif aisle_ratio < LOW_STOCK_THRESHOLD:
			stat_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			stat_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		row.add_child(stat_lbl)

		aisle_container.add_child(row)

func _update_alerts() -> void:
	for child in alert_container.get_children():
		child.queue_free()

	var db = get_node_or_null("/root/ProductDatabase")
	var shelves := get_tree().get_nodes_in_group("shelves")
	var product_totals: Dictionary = {}

	for shelf in shelves:
		if not shelf.has_method("get_total_stock"):
			continue
		if "stock" in shelf and shelf.stock is Dictionary:
			for side_key in shelf.stock:
				var side_data = shelf.stock[side_key]
				if side_data is Dictionary:
					for pid in side_data:
						var count: int = side_data[pid]
						if count > 0:
							product_totals[pid] = product_totals.get(pid, 0) + count

	for shelf in shelves:
		if not shelf.has_method("get_total_stock"):
			continue
		var total_stock: int = shelf.get_total_stock()
		var total_max: int = 10
		if "front_max_stock" in shelf and "back_max_stock" in shelf:
			total_max = shelf.front_max_stock + shelf.back_max_stock
		var ratio: float = float(total_stock) / float(total_max) if total_max > 0 else 0.0

		if ratio >= LOW_STOCK_THRESHOLD:
			continue

		var tag: String = ""
		if "front_shelf_tag" in shelf and not shelf.front_shelf_tag.is_empty():
			tag = shelf.front_shelf_tag
		elif "shelf_tag" in shelf:
			tag = shelf.shelf_tag
		else:
			tag = "Unknown"

		var alert := Label.new()
		if total_stock <= 0:
			alert.text = "⚠ %s — EMPTY" % tag.capitalize()
			alert.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			alert.text = "⚠ %s — Low Stock (%d)" % [tag.capitalize(), total_stock]
			alert.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		alert.add_theme_font_size_override("font_size", 13)
		alert_container.add_child(alert)

	if db:
		var all_pids: Array = db.get_all_product_ids()
		for pid in all_pids:
			var total: int = product_totals.get(pid, 0)
			if total <= 0:
				var pdata = db.get_product(pid)
				var pname: String = pdata.product_name if pdata and "product_name" in pdata else pid.capitalize()
				var alert := Label.new()
				alert.text = "⚠ %s — OUT OF STOCK" % pname
				alert.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				alert.add_theme_font_size_override("font_size", 13)
				alert_container.add_child(alert)

func _bounce_node(node: Control) -> void:
	if node == null:
		return
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(node, "scale", Vector2.ONE, 0.12)
