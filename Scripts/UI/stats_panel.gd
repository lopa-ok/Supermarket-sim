extends Control

@onready var card_container: VBoxContainer = %CardContainer

var _dirty: bool = true

func _ready() -> void:
	visible = false
	EventBus.money_changed.connect(func(_a): _mark_dirty())
	EventBus.transaction_completed.connect(func(_a): _mark_dirty())
	EventBus.customer_entered.connect(func(_c): _mark_dirty())
	EventBus.customer_left.connect(func(_c): _mark_dirty())
	EventBus.reputation_changed.connect(func(_v): _mark_dirty())
	EventBus.theft_succeeded.connect(func(_c, _v): _mark_dirty())
	EventBus.theft_prevented.connect(func(_c, _g): _mark_dirty())
	EventBus.workers_changed.connect(func(): _mark_dirty())
	var ui_mgr = get_node_or_null("/root/UIManager")
	if ui_mgr:
		ui_mgr.register_panel("stats", self)

func _mark_dirty() -> void:
	_dirty = true

func on_panel_opened() -> void:
	_rebuild()

func on_panel_closed() -> void:
	pass

func _process(_delta: float) -> void:
	if visible and _dirty:
		_dirty = false
		_rebuild()

func _rebuild() -> void:
	for ch in card_container.get_children():
		ch.queue_free()

	_build_reputation_section()

	var sep1 := HSeparator.new()
	card_container.add_child(sep1)

	_build_financials_section()

	var sep2 := HSeparator.new()
	card_container.add_child(sep2)

	_build_customers_section()

	var sep3 := HSeparator.new()
	card_container.add_child(sep3)

	_build_workers_section()

	var sep4 := HSeparator.new()
	card_container.add_child(sep4)

	_build_security_section()

func _build_reputation_section() -> void:
	var card := _make_card()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "Store Reputation"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
	vbox.add_child(header)

	var rm = get_node_or_null("/root/ReputationManager")
	var rep: float = rm.reputation if rm else 50.0

	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(0, 20)
	bar_bg.color = Color(0.15, 0.16, 0.20)
	vbox.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.custom_minimum_size = Vector2(0, 20)
	var fill_ratio: float = clampf(rep / 100.0, 0.0, 1.0)
	bar_fill.color = _rep_color(rep)
	bar_fill.anchor_right = fill_ratio
	bar_fill.anchor_bottom = 1.0
	bar_bg.add_child(bar_fill)

	var bar_label := Label.new()
	bar_label.text = "%d / 100" % int(rep)
	bar_label.add_theme_font_size_override("font_size", 12)
	bar_label.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
	bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_label.anchor_right = 1.0
	bar_label.anchor_bottom = 1.0
	bar_bg.add_child(bar_label)

	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 8)
	var tier_lbl := Label.new()
	tier_lbl.text = "Rating:"
	tier_lbl.add_theme_font_size_override("font_size", 14)
	tier_lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
	tier_row.add_child(tier_lbl)

	var stars_lbl := Label.new()
	stars_lbl.text = _rep_stars(rep)
	stars_lbl.add_theme_font_size_override("font_size", 14)
	stars_lbl.add_theme_color_override("font_color", _rep_color(rep))
	tier_row.add_child(stars_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_row.add_child(spacer)

	var mult_lbl := Label.new()
	var spawn_mult: float = rm.get_spawn_rate_multiplier() if rm else 1.0
	mult_lbl.text = "Spawn: %.1fx" % spawn_mult
	mult_lbl.add_theme_font_size_override("font_size", 13)
	mult_lbl.add_theme_color_override("font_color", Color(0.55, 0.70, 0.88))
	tier_row.add_child(mult_lbl)

	vbox.add_child(tier_row)
	card_container.add_child(card)

func _build_financials_section() -> void:
	var card := _make_card()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "Financials"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
	vbox.add_child(header)

	var gm = get_node_or_null("/root/GameManager")

	var balance_row := _info_row("Balance", "$%.2f" % (gm.money if gm else 0.0), Color(0.30, 0.92, 0.48))
	vbox.add_child(balance_row)

	var revenue_row := _info_row("Total Revenue", "$%.2f" % (gm.total_revenue if gm else 0.0), Color(0.30, 0.88, 0.48))
	vbox.add_child(revenue_row)

	var wm = get_node_or_null("/root/WorkerManager")
	var wages: float = wm.get_total_daily_wages() if wm and wm.has_method("get_total_daily_wages") else 0.0
	var wages_row := _info_row("Daily Wages", "$%.0f" % wages, Color(1.0, 0.82, 0.30))
	vbox.add_child(wages_row)

	var profit: float = (gm.total_revenue if gm else 0.0) - wages
	var profit_color := Color(0.30, 0.88, 0.48) if profit >= 0.0 else Color(1.0, 0.38, 0.38)
	var profit_row := _info_row("Net Profit", "$%.2f" % profit, profit_color)
	vbox.add_child(profit_row)

	card_container.add_child(card)

func _build_customers_section() -> void:
	var card := _make_card()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "Customers"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
	vbox.add_child(header)

	var gm = get_node_or_null("/root/GameManager")
	var in_store: int = get_tree().get_nodes_in_group("customers").size()

	var current_row := _info_row("In Store", "%d" % in_store, Color(0.55, 0.70, 0.88))
	vbox.add_child(current_row)

	var served_row := _info_row("Total Served", "%d" % (gm.total_customers_served if gm else 0), Color(0.55, 0.70, 0.88))
	vbox.add_child(served_row)

	card_container.add_child(card)

func _build_workers_section() -> void:
	var card := _make_card()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "Workers"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
	vbox.add_child(header)

	var wm = get_node_or_null("/root/WorkerManager")
	if wm == null:
		var none := Label.new()
		none.text = "No worker data."
		none.add_theme_font_size_override("font_size", 13)
		none.add_theme_color_override("font_color", Color(0.50, 0.52, 0.58))
		vbox.add_child(none)
		card_container.add_child(card)
		return

	var total_row := _info_row("Total", "%d" % wm.workers.size(), Color(0.55, 0.70, 0.88))
	vbox.add_child(total_row)

	var stocker_count: int = wm.get_worker_count_by_role(0) if wm.has_method("get_worker_count_by_role") else 0
	var cashier_count: int = wm.get_worker_count_by_role(1) if wm.has_method("get_worker_count_by_role") else 0
	var security_count: int = wm.get_worker_count_by_role(2) if wm.has_method("get_worker_count_by_role") else 0

	var s_row := _info_row("Stockers", "%d" % stocker_count, Color(0.30, 0.75, 0.40))
	vbox.add_child(s_row)
	var c_row := _info_row("Cashiers", "%d" % cashier_count, Color(0.35, 0.55, 0.95))
	vbox.add_child(c_row)
	var g_row := _info_row("Security", "%d" % security_count, Color(0.90, 0.35, 0.30))
	vbox.add_child(g_row)

	card_container.add_child(card)

func _build_security_section() -> void:
	var card := _make_card()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "Security & Theft"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
	vbox.add_child(header)

	var wm = get_node_or_null("/root/WorkerManager")
	var det: float = wm.get_total_detection_chance() * 100.0 if wm and wm.has_method("get_total_detection_chance") else 0.0
	var det_row := _info_row("Detection", "%.0f%%" % det, Color(0.65, 0.30, 0.85))
	vbox.add_child(det_row)

	card_container.add_child(card)

func _info_row(label_text: String, value_text: String, value_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 14)
	val.add_theme_color_override("font_color", value_color)
	row.add_child(val)
	return row

func _make_card() -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.14, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.24, 0.26, 0.32, 0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", style)
	return card

func _rep_color(rep: float) -> Color:
	if rep >= 90.0:
		return Color(1.0, 0.85, 0.0)
	if rep >= 70.0:
		return Color(0.3, 0.88, 0.48)
	if rep >= 50.0:
		return Color(0.6, 0.75, 0.9)
	if rep >= 30.0:
		return Color(1.0, 0.65, 0.2)
	return Color(1.0, 0.3, 0.3)

func _rep_stars(rep: float) -> String:
	if rep >= 90.0:
		return "★★★★★"
	if rep >= 70.0:
		return "★★★★"
	if rep >= 50.0:
		return "★★★"
	if rep >= 30.0:
		return "★★"
	return "★"
