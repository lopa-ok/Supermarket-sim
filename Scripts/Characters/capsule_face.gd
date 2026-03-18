class_name CapsuleFace
extends MeshInstance3D

enum FaceExpression { NEUTRAL, HAPPY, ANGRY, SURPRISED, SLEEPY }

var _expression: FaceExpression = FaceExpression.NEUTRAL
var _eye_color: Color = Color(0.15, 0.15, 0.18)
var _blink_timer: float = 0.0
var _blink_interval: float = 3.5
var _is_blinking: bool = false
var _blink_duration: float = 0.12
var _blink_elapsed: float = 0.0
var _viewport: SubViewport = null
var _texture_rect: TextureRect = null
var _image: Image = null
var _image_texture: ImageTexture = null

const FACE_SIZE: int = 64

func _ready() -> void:
	_setup_face_quad()
	_blink_interval = randf_range(2.5, 5.0)
	_draw_face()

func set_expression(expr: FaceExpression) -> void:
	if _expression == expr:
		return
	_expression = expr
	_draw_face()

func set_eye_color(col: Color) -> void:
	_eye_color = col
	_draw_face()

func _process(delta: float) -> void:
	_blink_timer += delta
	if _is_blinking:
		_blink_elapsed += delta
		if _blink_elapsed >= _blink_duration:
			_is_blinking = false
			_blink_elapsed = 0.0
			_draw_face()
	elif _blink_timer >= _blink_interval:
		_blink_timer = 0.0
		_blink_interval = randf_range(2.5, 5.0)
		_is_blinking = true
		_blink_elapsed = 0.0
		_draw_face()

func _setup_face_quad() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	mesh = quad
	_image = Image.create(FACE_SIZE, FACE_SIZE, false, Image.FORMAT_RGBA8)
	_image_texture = ImageTexture.create_from_image(_image)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _image_texture
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.no_depth_test = false
	material_override = mat

func _draw_face() -> void:
	if _image == null:
		return
	_image.fill(Color(0, 0, 0, 0))
	match _expression:
		FaceExpression.NEUTRAL:
			_draw_neutral()
		FaceExpression.HAPPY:
			_draw_happy()
		FaceExpression.ANGRY:
			_draw_angry()
		FaceExpression.SURPRISED:
			_draw_surprised()
		FaceExpression.SLEEPY:
			_draw_sleepy()
	_image_texture.update(_image)

func _draw_neutral() -> void:
	if _is_blinking:
		_draw_line_h(18, 24, 26, _eye_color)
		_draw_line_h(38, 24, 26, _eye_color)
	else:
		_draw_eye(18, 24, 4, 5)
		_draw_eye(38, 24, 4, 5)
	_draw_line_h(22, 40, 42, _eye_color)

func _draw_happy() -> void:
	if _is_blinking:
		_draw_arc_down(18, 24, 4, _eye_color)
		_draw_arc_down(38, 24, 4, _eye_color)
	else:
		_draw_arc_down(18, 24, 4, _eye_color)
		_draw_arc_down(38, 24, 4, _eye_color)
	_draw_smile(32, 40, 10)

func _draw_angry() -> void:
	if _is_blinking:
		_draw_line_h(18, 24, 26, _eye_color)
		_draw_line_h(38, 24, 26, _eye_color)
	else:
		_draw_eye(18, 25, 4, 4)
		_draw_eye(38, 25, 4, 4)
	_draw_brow_angry(18, 20)
	_draw_brow_angry_r(38, 20)
	_draw_frown(32, 42, 8)

func _draw_surprised() -> void:
	_draw_circle_outline(18, 24, 5, _eye_color)
	_draw_circle_outline(38, 24, 5, _eye_color)
	_draw_pixel(18, 24, _eye_color)
	_draw_pixel(38, 24, _eye_color)
	_draw_circle_outline(28, 42, 3, _eye_color)

func _draw_sleepy() -> void:
	_draw_line_h(18, 24, 26, _eye_color)
	_draw_line_h(38, 24, 26, _eye_color)
	_draw_line_h(22, 42, 44, _eye_color)

func _draw_eye(cx: int, cy: int, rx: int, ry: int) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var dx: float = float(x - cx) / float(rx)
			var dy: float = float(y - cy) / float(ry)
			if dx * dx + dy * dy <= 1.0:
				_draw_pixel(x, y, _eye_color)
	var hx: int = cx - 1
	var hy: int = cy - 1
	_draw_pixel(hx, hy, Color(1, 1, 1, 0.85))
	_draw_pixel(hx + 1, hy, Color(1, 1, 1, 0.5))

func _draw_smile(cx: int, cy: int, width: int) -> void:
	for i in range(-width, width + 1):
		var x: int = cx + i
		var curve: int = int(abs(float(i)) * abs(float(i)) / float(width * 2))
		var y: int = cy - curve
		_draw_pixel(x, y, _eye_color)

func _draw_frown(cx: int, cy: int, width: int) -> void:
	for i in range(-width, width + 1):
		var x: int = cx + i
		var curve: int = int(abs(float(i)) * abs(float(i)) / float(width * 2))
		var y: int = cy + curve
		_draw_pixel(x, y, _eye_color)

func _draw_arc_down(cx: int, cy: int, r: int, col: Color) -> void:
	for i in range(-r, r + 1):
		var x: int = cx + i
		var curve: int = int(abs(float(i)) * abs(float(i)) / float(r * 2))
		var y: int = cy - r + curve
		_draw_pixel(x, y, col)
		if i > -r and i < r:
			_draw_pixel(x, y + 1, col)

func _draw_brow_angry(cx: int, cy: int) -> void:
	for i in range(0, 7):
		var x: int = cx - 3 + i
		var y: int = cy - int(float(i) * 0.5)
		_draw_pixel(x, y, _eye_color)
		_draw_pixel(x, y + 1, _eye_color)

func _draw_brow_angry_r(cx: int, cy: int) -> void:
	for i in range(0, 7):
		var x: int = cx + 3 - i
		var y: int = cy - int(float(i) * 0.5)
		_draw_pixel(x, y, _eye_color)
		_draw_pixel(x, y + 1, _eye_color)

func _draw_circle_outline(cx: int, cy: int, r: int, col: Color) -> void:
	for angle_step in range(0, 32):
		var a: float = float(angle_step) / 32.0 * TAU
		var x: int = cx + int(cos(a) * float(r))
		var y: int = cy + int(sin(a) * float(r))
		_draw_pixel(x, y, col)

func _draw_line_h(cx: int, cy: int, y2: int, col: Color) -> void:
	for x in range(cx - 3, cx + 4):
		_draw_pixel(x, cy, col)

func _draw_pixel(x: int, y: int, col: Color) -> void:
	if x >= 0 and x < FACE_SIZE and y >= 0 and y < FACE_SIZE:
		_image.set_pixel(x, y, col)
