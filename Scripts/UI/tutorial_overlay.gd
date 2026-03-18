extends Control
class_name TutorialOverlay

signal finished

@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel
@onready var next_btn: Button = %NextBtn
@onready var skip_btn: Button = %SkipBtn

var _steps: Array = []
var _idx: int = 0

func _ready() -> void:
	visible = false
	if next_btn:
		next_btn.pressed.connect(_on_next)
	if skip_btn:
		skip_btn.pressed.connect(_on_skip)

# Accept untyped Array to avoid typed-array mismatch when called via call().
func start(steps: Array) -> void:
	_steps = steps
	_idx = 0
	_show_step()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if next_btn:
		next_btn.grab_focus()

func _show_step() -> void:
	if _idx < 0 or _idx >= _steps.size():
		_finish()
		return
	var s = _steps[_idx]
	if typeof(s) != TYPE_DICTIONARY:
		_finish()
		return
	title_label.text = s.get("title", "")
	body_label.text = s.get("body", "")
	var is_last := _idx == _steps.size() - 1
	if next_btn:
		next_btn.text = "Start" if is_last else "Next"

func _on_next() -> void:
	_idx += 1
	_show_step()

func _on_skip() -> void:
	_finish()

func _finish() -> void:
	visible = false
	finished.emit()
