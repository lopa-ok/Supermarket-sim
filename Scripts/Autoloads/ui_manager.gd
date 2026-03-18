extends Node

signal panel_opened(panel_name: String)
signal panel_closed(panel_name: String)

var _panels: Dictionary = {}
var _current_panel: String = ""
var _mouse_was_captured: bool = true
var _settings_panel: Control = null

func register_panel(panel_name: String, panel_node: Control) -> void:
	_panels[panel_name] = panel_node
	panel_node.visible = false
	panel_node.modulate.a = 0.0

func unregister_panel(panel_name: String) -> void:
	if _current_panel == panel_name:
		_close_immediate(panel_name)
	_panels.erase(panel_name)

func toggle_panel(panel_name: String) -> void:
	if _current_panel == panel_name:
		close_current_panel()
	else:
		open_panel(panel_name)

func open_panel(panel_name: String) -> void:
	if not _panels.has(panel_name):
		return
	if _current_panel == panel_name:
		return
	if _current_panel != "":
		_close_immediate(_current_panel)
	_mouse_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var panel: Control = _panels[panel_name]
	panel.visible = true
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.12)
	_current_panel = panel_name
	if panel.has_method("on_panel_opened"):
		panel.on_panel_opened()
	panel_opened.emit(panel_name)

func close_current_panel() -> void:
	if _current_panel == "":
		return
	var panel_name := _current_panel
	if not _panels.has(panel_name):
		_current_panel = ""
		return
	var panel: Control = _panels[panel_name]
	_current_panel = ""
	if panel.has_method("on_panel_closed"):
		panel.on_panel_closed()
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, 0.08)
	tw.tween_callback(func():
		panel.visible = false
		if _current_panel == "":
			if _mouse_was_captured:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	panel_closed.emit(panel_name)

func get_current_panel() -> String:
	return _current_panel

func is_any_panel_open() -> bool:
	return _current_panel != ""

func _ready() -> void:
	_register_keybinds()
	_instantiate_settings_panel()

func _instantiate_settings_panel() -> void:
	var settings_scene: PackedScene = load("res://Scenes/UI/settings_panel.tscn")
	if settings_scene:
		_settings_panel = settings_scene.instantiate()
		add_child(_settings_panel)
		register_panel("settings", _settings_panel)

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("toggle_panel"):
		toggle_panel("stock")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_upgrade_panel"):
		toggle_panel("upgrades")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_worker_panel"):
		toggle_panel("workers")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_stats_panel"):
		toggle_panel("stats")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if _current_panel != "":
			close_current_panel()
			get_viewport().set_input_as_handled()
		else:
			toggle_panel("settings")
			get_viewport().set_input_as_handled()

func _close_immediate(panel_name: String) -> void:
	if not _panels.has(panel_name):
		return
	var panel: Control = _panels[panel_name]
	if panel.has_method("on_panel_closed"):
		panel.on_panel_closed()
	panel.modulate.a = 0.0
	panel.visible = false
	panel_closed.emit(panel_name)

func _register_keybinds() -> void:
	if not InputMap.has_action("ui_stats_panel"):
		InputMap.add_action("ui_stats_panel")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_K
		InputMap.action_add_event("ui_stats_panel", ev)
	if not InputMap.has_action("ui_worker_panel"):
		InputMap.add_action("ui_worker_panel")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_J
		InputMap.action_add_event("ui_worker_panel", ev)
	if not InputMap.has_action("toggle_panel"):
		InputMap.add_action("toggle_panel")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_TAB
		InputMap.action_add_event("toggle_panel", ev)
	if not InputMap.has_action("ui_upgrade_panel"):
		InputMap.add_action("ui_upgrade_panel")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_U
		InputMap.action_add_event("ui_upgrade_panel", ev)
