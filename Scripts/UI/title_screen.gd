class_name TitleScreen
extends Control

@onready var play_btn: Button = %PlayBtn
@onready var settings_btn: Button = %SettingsBtn
@onready var quit_btn: Button = %QuitBtn
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var main_panel: VBoxContainer = %MainPanel
@onready var vol_slider: HSlider = %VolSlider
@onready var sens_slider: HSlider = %SensSlider
@onready var keybinds_btn: Button = %KeybindsBtn
@onready var back_btn: Button = %BackBtn
@onready var camera: Camera3D = %TitleCamera

var _cam_t: float = 0.0
var _cam_origin: Vector3
var _cam_look_target: Vector3 = Vector3(0, 1, 20)

const STORE_SCENE := "res://Scenes/Store/main_store_v3.tscn"

const CAM_SWAY_SPEED := 0.15
const CAM_SWAY_RADIUS := 1.5
const CAM_HEIGHT_SWAY := 0.3

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if settings_panel:
		settings_panel.visible = false
	if main_panel:
		main_panel.visible = true

	play_btn.pressed.connect(_on_play)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	
	if back_btn:
		back_btn.pressed.connect(_on_back)
	
	if keybinds_btn:
		keybinds_btn.pressed.connect(_on_advanced_settings)

	if vol_slider:
		vol_slider.value = 100.0
		vol_slider.value_changed.connect(_on_vol)
	if sens_slider:
		sens_slider.value = 50.0

	play_btn.grab_focus()

	if camera:
		_cam_origin = camera.global_position

func _process(delta: float) -> void:
	if camera == null:
		return
	_cam_t += delta * CAM_SWAY_SPEED
	var offset := Vector3(
		sin(_cam_t) * CAM_SWAY_RADIUS,
		sin(_cam_t * 0.7) * CAM_HEIGHT_SWAY,
		cos(_cam_t * 0.5) * CAM_SWAY_RADIUS * 0.5
	)
	camera.global_position = _cam_origin + offset
	camera.look_at(_cam_look_target, Vector3.UP)

func _on_play() -> void:
	get_tree().change_scene_to_file(STORE_SCENE)

func _on_settings() -> void:
	var ui_mgr = get_node_or_null("/root/UIManager")
	if ui_mgr:
		ui_mgr.toggle_panel("settings")

func _on_back() -> void:
	if settings_panel:
		settings_panel.visible = false
	if main_panel:
		main_panel.visible = true
	play_btn.grab_focus()

func _on_advanced_settings() -> void:
	var ui_mgr = get_node_or_null("/root/UIManager")
	if ui_mgr:
		ui_mgr.toggle_panel("settings")

func _on_quit() -> void:
	get_tree().quit()

func _on_vol(val: float) -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(val / 100.0))
