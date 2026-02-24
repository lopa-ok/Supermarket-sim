class_name PauseMenu
extends Control

@onready var resume_btn: Button = %ResumeBtn
@onready var settings_btn: Button = %SettingsBtn
@onready var quit_btn: Button = %QuitBtn
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var main_panel: PanelContainer = %MainPanel
@onready var vol_slider: HSlider = %VolSlider
@onready var sens_slider: HSlider = %SensSlider
@onready var back_btn: Button = %BackBtn

var _was_captured: bool = true

const COL_TITLE := Color(0.9, 0.9, 0.95)
const COL_LABEL := Color(0.78, 0.78, 0.82)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_btn.pressed.connect(_unpause)
	settings_btn.pressed.connect(_show_settings)
	quit_btn.pressed.connect(_quit)
	back_btn.pressed.connect(_hide_settings)
	settings_panel.visible = false
	vol_slider.value = 100.0
	vol_slider.value_changed.connect(_on_vol)
	sens_slider.value = 50.0
	sens_slider.value_changed.connect(_on_sens)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if get_tree().paused:
			_unpause()
		else:
			_pause()
		get_viewport().set_input_as_handled()

func _pause() -> void:
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	visible = true
	settings_panel.visible = false
	main_panel.visible = true
	resume_btn.grab_focus()

func _unpause() -> void:
	get_tree().paused = false
	visible = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_settings() -> void:
	main_panel.visible = false
	settings_panel.visible = true
	back_btn.grab_focus()

func _hide_settings() -> void:
	settings_panel.visible = false
	main_panel.visible = true
	resume_btn.grab_focus()

func _quit() -> void:
	get_tree().paused = false
	get_tree().quit()

func _on_vol(val: float) -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(val / 100.0))

func _on_sens(val: float) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if "mouse_sensitivity" in p:
			p.mouse_sensitivity = remap(val, 0.0, 100.0, 0.0005, 0.005)
