extends Control

@onready var card_container: VBoxContainer = %CardContainer

func _ready() -> void:
	visible = false
	EventBus.money_changed.connect(func(_a): _refresh())
	EventBus.upgrade_purchased.connect(func(_a, _b): _refresh())
	var ui_mgr = get_node_or_null("/root/UIManager")
	if ui_mgr:
		ui_mgr.register_panel("upgrades", self)

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

	var um = get_node_or_null("/root/UpgradeManager")
	if um == null:
		return
	var gm = get_node_or_null("/root/GameManager")

	for id in um.get_all_upgrade_ids():
		var def: Dictionary = um.UPGRADE_DEFS.get(id, {})
		if def.is_empty():
			continue

		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.10, 0.11, 0.14, 0.85)
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(0.24, 0.26, 0.32, 0.5)
		card_style.corner_radius_top_left = 6
		card_style.corner_radius_top_right = 6
		card_style.corner_radius_bottom_left = 6
		card_style.corner_radius_bottom_right = 6
		card_style.content_margin_left = 14.0
		card_style.content_margin_right = 14.0
		card_style.content_margin_top = 10.0
		card_style.content_margin_bottom = 10.0
		card.add_theme_stylebox_override("panel", card_style)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var level: int = um.get_level(id)
		var max_level: int = um.get_max_level(id)
		var maxed: bool = um.is_maxed(id)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 10)
		var name_lbl := Label.new()
		name_lbl.text = def.get("name", id)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(name_lbl)
		var level_lbl := Label.new()
		level_lbl.text = "Lv %d / %d" % [level, max_level]
		level_lbl.add_theme_font_size_override("font_size", 13)
		if maxed:
			level_lbl.add_theme_color_override("font_color", Color(0.50, 0.72, 1.0))
		else:
			level_lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
		top_row.add_child(level_lbl)
		vbox.add_child(top_row)

		var desc_lbl := Label.new()
		desc_lbl.text = def.get("description", "")
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.52, 0.54, 0.60))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_lbl)

		var bottom_row := HBoxContainer.new()
		bottom_row.add_theme_constant_override("separation", 10)

		if maxed:
			var maxed_lbl := Label.new()
			maxed_lbl.text = "MAX LEVEL"
			maxed_lbl.add_theme_font_size_override("font_size", 14)
			maxed_lbl.add_theme_color_override("font_color", Color(0.50, 0.72, 1.0))
			maxed_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bottom_row.add_child(maxed_lbl)
		else:
			var next_val: float = um.get_next_value(id)
			var effect_lbl := Label.new()
			effect_lbl.text = "Next: %.2f" % next_val
			effect_lbl.add_theme_font_size_override("font_size", 13)
			effect_lbl.add_theme_color_override("font_color", Color(0.35, 0.88, 0.52))
			effect_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bottom_row.add_child(effect_lbl)

			var cost: float = um.get_upgrade_cost(id)
			var cost_lbl := Label.new()
			cost_lbl.text = "$%.0f" % cost
			cost_lbl.add_theme_font_size_override("font_size", 14)
			cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
			bottom_row.add_child(cost_lbl)

			var btn := Button.new()
			btn.text = "Buy"
			btn.custom_minimum_size = Vector2(72, 32)
			var can_afford: bool = gm != null and gm.money >= cost
			btn.disabled = not can_afford
			btn.pressed.connect(_on_buy.bind(id))
			bottom_row.add_child(btn)

		vbox.add_child(bottom_row)
		card_container.add_child(card)

func _on_buy(upgrade_id: String) -> void:
	var um = get_node_or_null("/root/UpgradeManager")
	if um:
		um.purchase_upgrade(upgrade_id)
