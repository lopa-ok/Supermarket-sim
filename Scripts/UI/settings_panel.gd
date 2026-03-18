extends Control

@onready var card_container: VBoxContainer = %CardContainer

var _listening_action: String = ""
var _listen_btn: Button = null

func _ready() -> void:
	visible = false

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
		["Move Forward", "move_forward"],
		["Move Backward", "move_back"],
		["Move Left", "move_left"],
		["Move Right", "move_right"],
		["Sprint", "sprint"],
		["Jump", "jump"],
		["Interact", "interact"],
		["Drop Item", "drop"],
		["Open Store", "open_store"],
		["Stock Panel", "toggle_panel"],
		["Upgrades Panel", "ui_upgrade_panel"],
		["Workers Panel", "ui_worker_panel"],
		["Store Stats", "ui_stats_panel"],
		["Pause", "pause"]
	]

	for bind in binds:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var action_lbl := Label.new()
		action_lbl.text = bind[0]
		action_lbl.add_theme_font_size_override("font_size", 14)
		action_lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
		action_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(action_lbl)

		var action_name: String = bind[1]
		var key_str := "Unassigned"
		if InputMap.has_action(action_name):
			var events := InputMap.action_get_events(action_name)
			if events.size() > 0 and events[0] is InputEventKey:
				key_str = OS.get_keycode_string((events[0] as InputEventKey).physical_keycode)
				
		var key_lbl := Label.new()
		key_lbl.text = key_str
		key_lbl.add_theme_font_size_override("font_size", 14)
		key_lbl.add_theme_color_override("font_color", Color(0.82, 0.84, 0.90))
		row.add_child(key_lbl)

		var change_btn := Button.new()
		change_btn.text = "Change"
		change_btn.custom_minimum_size = Vector2(80, 26)
		change_btn.add_theme_font_size_override("font_size", 13)
		change_btn.pressed.connect(func(): _start_listening(action_name, change_btn, key_lbl))
		row.add_child(change_btn)

		vbox.add_child(row)

	card_container.add_child(card)

func _start_listening(action_name: String, btn: Button, lbl: Label) -> void:
	if _listening_action != "":
		return
	_listening_action = action_name
	_listen_btn = btn
	btn.text = "Press..."
	lbl.text = "..."

func _input(event: InputEvent) -> void:
	if _listening_action != "" and event is InputEventKey:
		if event.pressed:
			get_viewport().set_input_as_handled()
			var key_event := event as InputEventKey
			
			var old_events = InputMap.action_get_events(_listening_action)
			var old_event = old_events[0] if old_events.size() > 0 else null
			
			var conflict_action := ""
			for act in InputMap.get_actions():
				if act == _listening_action: continue
				for ev in InputMap.action_get_events(act):
					if ev is InputEventKey and ev.physical_keycode == key_event.physical_keycode:
						conflict_action = act
						break
				if conflict_action != "": break
				
			if conflict_action != "" and old_event != null:
				InputMap.action_erase_events(conflict_action)
				InputMap.action_add_event(conflict_action, old_event)
			
			InputMap.action_erase_events(_listening_action)
			var new_ev := InputEventKey.new()
			new_ev.physical_keycode = key_event.physical_keycode
			InputMap.action_add_event(_listening_action, new_ev)
			
			_save_keybinds()
			EventBus.keybinds_changed.emit()
			_listening_action = ""
			if _listen_btn:
				_listen_btn.text = "Change"
				_listen_btn = null
			_rebuild()
	elif event.is_action_pressed("ui_cancel") and _listening_action == "":
		var ui_mgr = get_node_or_null("/root/UIManager")
		if ui_mgr and visible:
			get_viewport().set_input_as_handled()
			ui_mgr.close_current_panel()
	elif event.is_action_pressed("pause") and _listening_action == "":
		var ui_mgr = get_node_or_null("/root/UIManager")
		if ui_mgr and visible:
			get_viewport().set_input_as_handled()
			ui_mgr.close_current_panel()

func _save_keybinds() -> void:
	var config := ConfigFile.new()
	var binds: Array = ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump", "interact", "drop", "open_store", "toggle_panel", "ui_upgrade_panel", "ui_worker_panel", "ui_stats_panel", "pause"]
	for action in binds:
		if InputMap.has_action(action):
			var events = InputMap.action_get_events(action)
			if events.size() > 0 and events[0] is InputEventKey:
				config.set_value("keybinds", action, (events[0] as InputEventKey).physical_keycode)
	config.save("user://settings.cfg")

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
