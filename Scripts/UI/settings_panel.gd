extends Control

@onready var card_container: VBoxContainer = %CardContainer

func _ready() -> void:
	visible = false
	var ui_mgr = get_node_or_null("/root/UIManager")
	if ui_mgr:
		ui_mgr.register_panel("settings", self)

func on_panel_opened() -> void:
	_rebuild()

func on_panel_closed() -> void:
	pass

func _rebuild() -> void:
	for ch in card_container.get_children():
		ch.queue_free()

	_build_keybinds_section()

	var sep1 := HSeparator.new()
	card_container.add_child(sep1)

	_build_audio_section()

	var sep2 := HSeparator.new()
	card_container.add_child(sep2)

	_build_graphics_section()

func _build_keybinds_section() -> void:
	var card := _make_card()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "Keybinds"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
	vbox.add_child(header)

	var binds: Array = [
		["Move", "W / A / S / D"],
		["Jump", "Space"],
		["Sprint", "Shift"],
		["Interact", "E"],
		["Drop Item", "Q"],
		["Open Store", "O"],
		["Stock Panel", "Tab"],
		["Upgrades Panel", "U"],
		["Workers Panel", "J"],
		["Store Stats", "K"],
		["Settings / Close", "Esc"],
		["Pause", "Esc (when no panel open → pause)"],
	]

	for bind in binds:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var action_lbl := Label.new()
		action_lbl.text = bind[0]
		action_lbl.add_theme_font_size_override("font_size", 13)
		action_lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
		action_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(action_lbl)
		var key_lbl := Label.new()
		key_lbl.text = bind[1]
		key_lbl.add_theme_font_size_override("font_size", 13)
		key_lbl.add_theme_color_override("font_color", Color(0.82, 0.84, 0.90))
		row.add_child(key_lbl)
		vbox.add_child(row)

	card_container.add_child(card)

func _build_audio_section() -> void:
	var card := _make_card()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "Audio"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
	vbox.add_child(header)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 10)
	var vol_lbl := Label.new()
	vol_lbl.text = "Master Volume"
	vol_lbl.add_theme_font_size_override("font_size", 14)
	vol_lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
	vol_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_row.add_child(vol_lbl)

	var vol_slider := HSlider.new()
	vol_slider.custom_minimum_size = Vector2(160, 22)
	vol_slider.min_value = 0.0
	vol_slider.max_value = 100.0
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		vol_slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx)) * 100.0
	else:
		vol_slider.value = 100.0
	vol_slider.value_changed.connect(_on_volume_changed)
	vol_row.add_child(vol_slider)
	vbox.add_child(vol_row)

	var sens_row := HBoxContainer.new()
	sens_row.add_theme_constant_override("separation", 10)
	var sens_lbl := Label.new()
	sens_lbl.text = "Mouse Sensitivity"
	sens_lbl.add_theme_font_size_override("font_size", 14)
	sens_lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
	sens_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sens_row.add_child(sens_lbl)

	var sens_slider := HSlider.new()
	sens_slider.custom_minimum_size = Vector2(160, 22)
	sens_slider.min_value = 0.0
	sens_slider.max_value = 100.0
	sens_slider.value = 50.0
	sens_slider.value_changed.connect(_on_sensitivity_changed)
	sens_row.add_child(sens_slider)
	vbox.add_child(sens_row)

	card_container.add_child(card)

func _build_graphics_section() -> void:
	var card := _make_card()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "Graphics"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
	vbox.add_child(header)

	var fullscreen_row := HBoxContainer.new()
	fullscreen_row.add_theme_constant_override("separation", 10)
	var fs_lbl := Label.new()
	fs_lbl.text = "Fullscreen"
	fs_lbl.add_theme_font_size_override("font_size", 14)
	fs_lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
	fs_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fullscreen_row.add_child(fs_lbl)

	var fs_check := CheckButton.new()
	fs_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs_check.toggled.connect(_on_fullscreen_toggled)
	fullscreen_row.add_child(fs_check)
	vbox.add_child(fullscreen_row)

	var vsync_row := HBoxContainer.new()
	vsync_row.add_theme_constant_override("separation", 10)
	var vs_lbl := Label.new()
	vs_lbl.text = "VSync"
	vs_lbl.add_theme_font_size_override("font_size", 14)
	vs_lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
	vs_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vsync_row.add_child(vs_lbl)

	var vs_check := CheckButton.new()
	vs_check.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	vs_check.toggled.connect(_on_vsync_toggled)
	vsync_row.add_child(vs_check)
	vbox.add_child(vsync_row)

	card_container.add_child(card)

func _on_volume_changed(val: float) -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(val / 100.0))

func _on_sensitivity_changed(val: float) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if "mouse_sensitivity" in p:
			p.mouse_sensitivity = remap(val, 0.0, 100.0, 0.0005, 0.005)

func _on_fullscreen_toggled(on: bool) -> void:
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vsync_toggled(on: bool) -> void:
	if on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

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
