extends Control

@onready var panel: PanelContainer = $Panel
@onready var card_container: VBoxContainer = %CardContainer

var _panel_open: bool = false
var _current_tab: int = 0

func _ready() -> void:
	panel.visible = false
	EventBus.shelf_stock_changed.connect(func(_a, _b, _c, _d, _e): _refresh())
	var ui_mgr = get_node_or_null("/root/UIManager")
	if ui_mgr:
		ui_mgr.register_panel("stock", self)

func on_panel_opened() -> void:
	_rebuild()
	_panel_open = true
	panel.visible = true

func on_panel_closed() -> void:
	_panel_open = false
	panel.visible = false

func _refresh() -> void:
	if _panel_open:
		_rebuild()

func _rebuild() -> void:
	for ch in card_container.get_children():
		ch.queue_free()

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	card_container.add_child(tab_row)

	var stock_btn := Button.new()
	stock_btn.text = "Stock"
	stock_btn.custom_minimum_size = Vector2(100, 30)
	stock_btn.pressed.connect(func(): _current_tab = 0; _rebuild())
	tab_row.add_child(stock_btn)

	var price_btn := Button.new()
	price_btn.text = "Pricing"
	price_btn.custom_minimum_size = Vector2(100, 30)
	price_btn.pressed.connect(func(): _current_tab = 1; _rebuild())
	tab_row.add_child(price_btn)

	var tab_sep := HSeparator.new()
	card_container.add_child(tab_sep)

	if _current_tab == 0:
		_build_stock_section()
	else:
		_build_pricing_section()

func _build_stock_section() -> void:
	var shelves := get_tree().get_nodes_in_group("shelves")

	if shelves.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No shelves placed yet."
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color(0.50, 0.52, 0.58))
		card_container.add_child(empty_lbl)
		return

	var grand_cur: int = 0
	var grand_max: int = 0

	for shelf in shelves:
		var cur: int = shelf.get_total_stock()
		var mx: int = shelf.get_total_capacity()
		grand_cur += cur
		grand_max += mx

		var card := _make_card()
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 10)

		var name_lbl := Label.new()
		name_lbl.text = _shelf_display_name(shelf)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(name_lbl)

		var ratio: float = float(cur) / float(mx) if mx > 0 else 0.0
		var col := _ratio_color(ratio, cur)

		var count_lbl := Label.new()
		count_lbl.text = "%d / %d" % [cur, mx]
		count_lbl.add_theme_font_size_override("font_size", 14)
		count_lbl.add_theme_color_override("font_color", col)
		top_row.add_child(count_lbl)

		vbox.add_child(top_row)

		var side_names: Array = shelf.get_sides()
		for side_name in side_names:
			var side_cur: int = shelf.get_side_stock(side_name)
			var side_mx: int = shelf.get_side_capacity(side_name)
			var side_tag: String = ""
			if shelf.has_method("get_tag_for_side"):
				side_tag = shelf.get_tag_for_side(side_name)

			var side_row := HBoxContainer.new()
			side_row.add_theme_constant_override("separation", 8)

			var side_label := Label.new()
			var side_text: String = side_name
			if not side_tag.is_empty():
				side_text = "%s [%s]" % [side_name, side_tag.capitalize()]
			side_label.text = side_text
			side_label.add_theme_font_size_override("font_size", 13)
			side_label.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
			side_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			side_row.add_child(side_label)

			var s_ratio: float = float(side_cur) / float(side_mx) if side_mx > 0 else 0.0
			var s_col := _ratio_color(s_ratio, side_cur)

			var s_count := Label.new()
			s_count.text = "%d / %d" % [side_cur, side_mx]
			s_count.add_theme_font_size_override("font_size", 13)
			s_count.add_theme_color_override("font_color", s_col)
			side_row.add_child(s_count)

			vbox.add_child(side_row)

		card_container.add_child(card)

	var sep := HSeparator.new()
	card_container.add_child(sep)

	var summary := _make_card(Color(0.30, 0.50, 0.80, 0.5))
	var sum_row := HBoxContainer.new()
	sum_row.add_theme_constant_override("separation", 10)
	summary.add_child(sum_row)

	var total_lbl := Label.new()
	total_lbl.text = "Total Stock"
	total_lbl.add_theme_font_size_override("font_size", 16)
	total_lbl.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
	total_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sum_row.add_child(total_lbl)

	var t_ratio: float = float(grand_cur) / float(grand_max) if grand_max > 0 else 0.0
	var t_col := _ratio_color(t_ratio, grand_cur)

	var t_count := Label.new()
	t_count.text = "%d / %d" % [grand_cur, grand_max]
	t_count.add_theme_font_size_override("font_size", 14)
	t_count.add_theme_color_override("font_color", t_col)
	sum_row.add_child(t_count)

	card_container.add_child(summary)

func _build_pricing_section() -> void:
	var db = get_node_or_null("/root/ProductDatabase")
	if db == null:
		return

	var all_products: Array = db.get_all_products()
	if all_products.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No products registered."
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color(0.50, 0.52, 0.58))
		card_container.add_child(empty_lbl)
		return

	for p in all_products:
		var card := _make_card()
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 10)
		var name_lbl := Label.new()
		name_lbl.text = p.product_name
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(name_lbl)
		vbox.add_child(top_row)

		var cost_row := HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 8)
		var cost_lbl := Label.new()
		cost_lbl.text = "Cost: $%.2f" % p.base_price
		cost_lbl.add_theme_font_size_override("font_size", 13)
		cost_lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
		cost_row.add_child(cost_lbl)
		vbox.add_child(cost_row)

		var price_row := HBoxContainer.new()
		price_row.add_theme_constant_override("separation", 6)

		var minus_btn := Button.new()
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(28, 28)
		var pid_for_minus: String = p.product_id
		minus_btn.pressed.connect(func(): _adjust_price(pid_for_minus, -0.10))
		price_row.add_child(minus_btn)

		var effective: float = p.get_effective_price()
		var margin: float = p.get_profit_margin()
		var price_color := Color(0.3, 0.88, 0.48)
		if effective <= p.base_price:
			price_color = Color(1.0, 0.38, 0.38)
		elif margin < 0.2:
			price_color = Color(1.0, 0.82, 0.28)

		var price_lbl := Label.new()
		price_lbl.text = "$%.2f" % effective
		price_lbl.add_theme_font_size_override("font_size", 15)
		price_lbl.add_theme_color_override("font_color", price_color)
		price_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_row.add_child(price_lbl)

		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(28, 28)
		var pid_for_plus: String = p.product_id
		plus_btn.pressed.connect(func(): _adjust_price(pid_for_plus, 0.10))
		price_row.add_child(plus_btn)

		vbox.add_child(price_row)

		var info_row := HBoxContainer.new()
		info_row.add_theme_constant_override("separation", 12)

		var margin_lbl := Label.new()
		margin_lbl.text = "Margin: %d%%" % int(margin * 100.0)
		margin_lbl.add_theme_font_size_override("font_size", 12)
		margin_lbl.add_theme_color_override("font_color", price_color)
		info_row.add_child(margin_lbl)

		var demand_lbl := Label.new()
		demand_lbl.text = "Demand: %.1fx" % p.demand_factor
		demand_lbl.add_theme_font_size_override("font_size", 12)
		demand_lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
		info_row.add_child(demand_lbl)

		vbox.add_child(info_row)

		card_container.add_child(card)

func _adjust_price(product_id: String, delta: float) -> void:
	var db = get_node_or_null("/root/ProductDatabase")
	if db == null:
		return
	var p = db.get_product(product_id)
	if p == null:
		return
	db.set_product_price(product_id, p.get_effective_price() + delta)
	_rebuild()

func _make_card(border_color: Color = Color(0.24, 0.26, 0.32, 0.5)) -> PanelContainer:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.10, 0.11, 0.14, 0.85)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = border_color
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card_style.content_margin_left = 14.0
	card_style.content_margin_right = 14.0
	card_style.content_margin_top = 10.0
	card_style.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", card_style)
	return card

func _shelf_display_name(shelf: Node) -> String:
	if shelf.has_method("get_all_tags"):
		var tags: Array[String] = shelf.get_all_tags()
		if not tags.is_empty():
			var parts: PackedStringArray = []
			for tag in tags:
				parts.append(tag.capitalize())
			return " / ".join(parts) + " Shelf"
	if "front_shelf_tag" in shelf and not shelf.front_shelf_tag.is_empty():
		return shelf.front_shelf_tag.capitalize() + " Shelf"
	return str(shelf.name) if not shelf.name.is_empty() else "Shelf"

func _ratio_color(ratio: float, val: int) -> Color:
	if val <= 0:
		return Color(1.0, 0.38, 0.38)
	if ratio < 0.3:
		return Color(1.0, 0.82, 0.28)
	return Color(0.3, 0.88, 0.48)
