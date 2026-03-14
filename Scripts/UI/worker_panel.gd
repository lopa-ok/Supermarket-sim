extends Control

@onready var card_container: VBoxContainer = %CardContainer

func _ready() -> void:
	visible = false
	EventBus.money_changed.connect(func(_a): _refresh())
	EventBus.workers_changed.connect(_refresh)
	var ui_mgr = get_node_or_null("/root/UIManager")
	if ui_mgr:
		ui_mgr.register_panel("workers", self)

func on_panel_opened() -> void:
	_rebuild()

func on_panel_closed() -> void:
	pass

func _refresh() -> void:
	if visible:
		_rebuild()

func _rebuild() -> void:
	for ch in card_container.get_children():
		ch.queue_free()

	var wm = get_node_or_null("/root/WorkerManager")
	if wm == null:
		return
	var gm = get_node_or_null("/root/GameManager")

	_build_hire_section(wm, gm)

	var sep := HSeparator.new()
	card_container.add_child(sep)

	_build_worker_list(wm, gm)

	var sep2 := HSeparator.new()
	card_container.add_child(sep2)

	_build_active_tasks(wm)

	var sep3 := HSeparator.new()
	card_container.add_child(sep3)

	_build_summary(wm)

func _build_hire_section(wm: Node, gm: Node) -> void:
	for role_val in [0, 1, 2]:
		var def: Dictionary = wm.ROLE_DEFS[role_val]
		var card := _make_card(Color(0.10, 0.11, 0.14, 0.85), Color(0.24, 0.26, 0.32, 0.5))

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 10)

		var name_lbl := Label.new()
		name_lbl.text = "Hire %s" % def["name"]
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(name_lbl)

		var cost_lbl := Label.new()
		cost_lbl.text = "$%.0f" % def["hire_cost"]
		cost_lbl.add_theme_font_size_override("font_size", 14)
		cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
		top_row.add_child(cost_lbl)
		vbox.add_child(top_row)

		var desc_lbl := Label.new()
		desc_lbl.text = "Salary: $%.0f/day" % def["base_salary"]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.52, 0.54, 0.60))
		vbox.add_child(desc_lbl)

		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 10)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_row.add_child(spacer)

		var btn := Button.new()
		btn.text = "Hire"
		btn.custom_minimum_size = Vector2(72, 32)
		var can_afford: bool = gm != null and gm.money >= def["hire_cost"]
		btn.disabled = not can_afford
		btn.pressed.connect(_on_hire.bind(role_val))
		btn_row.add_child(btn)

		vbox.add_child(btn_row)
		card_container.add_child(card)

func _build_worker_list(wm: Node, gm: Node) -> void:
	var workers_arr: Array = wm.workers
	if workers_arr.is_empty():
		var lbl := Label.new()
		lbl.text = "No workers hired yet."
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.50, 0.52, 0.58))
		card_container.add_child(lbl)
		return

	for worker in workers_arr:
		var def: Dictionary = wm.ROLE_DEFS[worker["role"]]
		var card := _make_card(Color(0.10, 0.11, 0.14, 0.85), Color(0.24, 0.26, 0.32, 0.5))

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 10)

		var name_lbl := Label.new()
		name_lbl.text = "%s #%d" % [worker["role_name"], worker["id"]]
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(name_lbl)

		var maxed: bool = worker["level"] >= def["max_level"]
		var level_lbl := Label.new()
		level_lbl.text = "Lv %d / %d" % [worker["level"], def["max_level"]]
		level_lbl.add_theme_font_size_override("font_size", 13)
		if maxed:
			level_lbl.add_theme_color_override("font_color", Color(0.50, 0.72, 1.0))
		else:
			level_lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
		top_row.add_child(level_lbl)
		vbox.add_child(top_row)

		var info_lbl := Label.new()
		var eff: float = wm.get_worker_efficiency(worker)
		var bot_status: String = wm.get_bot_state_name(worker["id"]) if wm.has_method("get_bot_state_name") else ""
		var status_text := "  [%s]" % bot_status if bot_status != "" and bot_status != "—" else ""
		info_lbl.text = "Salary: $%.0f/day   Efficiency: %.1f%s" % [worker["salary"], eff, status_text]
		info_lbl.add_theme_font_size_override("font_size", 12)
		info_lbl.add_theme_color_override("font_color", Color(0.52, 0.54, 0.60))
		vbox.add_child(info_lbl)

		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 8)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_row.add_child(spacer)

		if not maxed:
			var up_cost: float = wm.get_worker_upgrade_cost(worker)
			var up_btn := Button.new()
			up_btn.text = "Upgrade $%.0f" % up_cost
			up_btn.custom_minimum_size = Vector2(120, 32)
			var can_up: bool = gm != null and gm.money >= up_cost
			up_btn.disabled = not can_up
			up_btn.pressed.connect(_on_upgrade.bind(worker["id"]))
			btn_row.add_child(up_btn)

		var fire_btn := Button.new()
		fire_btn.text = "Fire"
		fire_btn.custom_minimum_size = Vector2(60, 32)
		fire_btn.pressed.connect(_on_fire.bind(worker["id"]))
		btn_row.add_child(fire_btn)

		vbox.add_child(btn_row)
		card_container.add_child(card)

func _build_active_tasks(wm: Node) -> void:
	var tasks: Array = wm.get_active_tasks()

	var header := Label.new()
	header.text = "Active Tasks"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
	card_container.add_child(header)

	if tasks.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No active tasks."
		none_lbl.add_theme_font_size_override("font_size", 13)
		none_lbl.add_theme_color_override("font_color", Color(0.50, 0.52, 0.58))
		card_container.add_child(none_lbl)
		return

	for task in tasks:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var role_lbl := Label.new()
		role_lbl.text = "%s #%d" % [task["role_name"], task["worker_id"]]
		role_lbl.add_theme_font_size_override("font_size", 13)
		role_lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
		role_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(role_lbl)

		var task_lbl := Label.new()
		task_lbl.text = task["task"]
		task_lbl.add_theme_font_size_override("font_size", 13)
		task_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90))
		row.add_child(task_lbl)

		card_container.add_child(row)

func _build_summary(wm: Node) -> void:
	var card := _make_card(Color(0.10, 0.11, 0.14, 0.85), Color(0.30, 0.50, 0.80, 0.5))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	var lbl1 := Label.new()
	lbl1.text = "Total Workers"
	lbl1.add_theme_font_size_override("font_size", 16)
	lbl1.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
	lbl1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(lbl1)
	var cnt_lbl := Label.new()
	cnt_lbl.text = "%d" % wm.workers.size()
	cnt_lbl.add_theme_font_size_override("font_size", 14)
	cnt_lbl.add_theme_color_override("font_color", Color(0.55, 0.70, 0.88))
	row1.add_child(cnt_lbl)
	vbox.add_child(row1)

	var stocker_count: int = wm.get_worker_count_by_role(0)
	var cashier_count: int = wm.get_worker_count_by_role(1)
	var security_count: int = wm.get_worker_count_by_role(2)

	var role_row := HBoxContainer.new()
	role_row.add_theme_constant_override("separation", 16)

	var s_lbl := Label.new()
	s_lbl.text = "Stockers: %d" % stocker_count
	s_lbl.add_theme_font_size_override("font_size", 13)
	s_lbl.add_theme_color_override("font_color", Color(0.30, 0.75, 0.40))
	role_row.add_child(s_lbl)

	var c_lbl := Label.new()
	c_lbl.text = "Cashiers: %d" % cashier_count
	c_lbl.add_theme_font_size_override("font_size", 13)
	c_lbl.add_theme_color_override("font_color", Color(0.35, 0.55, 0.95))
	role_row.add_child(c_lbl)

	var g_lbl := Label.new()
	g_lbl.text = "Security: %d" % security_count
	g_lbl.add_theme_font_size_override("font_size", 13)
	g_lbl.add_theme_color_override("font_color", Color(0.90, 0.35, 0.30))
	role_row.add_child(g_lbl)

	vbox.add_child(role_row)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	var lbl2 := Label.new()
	lbl2.text = "Daily Wages"
	lbl2.add_theme_font_size_override("font_size", 14)
	lbl2.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
	lbl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(lbl2)
	var wage_lbl := Label.new()
	wage_lbl.text = "$%.0f" % wm.get_total_daily_wages()
	wage_lbl.add_theme_font_size_override("font_size", 14)
	wage_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
	row2.add_child(wage_lbl)
	vbox.add_child(row2)

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 10)
	var lbl3 := Label.new()
	lbl3.text = "Detection Chance"
	lbl3.add_theme_font_size_override("font_size", 14)
	lbl3.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
	lbl3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(lbl3)
	var det_lbl := Label.new()
	det_lbl.text = "%.0f%%" % (wm.get_total_detection_chance() * 100.0)
	det_lbl.add_theme_font_size_override("font_size", 14)
	det_lbl.add_theme_color_override("font_color", Color(0.65, 0.30, 0.85))
	row3.add_child(det_lbl)
	vbox.add_child(row3)

	card_container.add_child(card)

func _make_card(bg: Color, border: Color) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
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

func _on_hire(role_val: int) -> void:
	var wm = get_node_or_null("/root/WorkerManager")
	if wm:
		wm.hire_worker(role_val)

func _on_upgrade(worker_id: int) -> void:
	var wm = get_node_or_null("/root/WorkerManager")
	if wm:
		wm.upgrade_worker(worker_id)

func _on_fire(worker_id: int) -> void:
	var wm = get_node_or_null("/root/WorkerManager")
	if wm:
		wm.fire_worker(worker_id)
