class_name ThoughtBubble3D
extends Node3D

enum ThoughtType {
	NONE,
	SHOPPING,
	QUEUE,
	PRICING,
	THEFT,
	EXIT,
	QUESTION,
	EXCLAMATION,
	HOURGLASS,
	ANGRY,
	HEART,
	BROWSING,
	SATISFIED,
	ANGRY_CLOUD,
	PRODUCT_SEARCH,
}

const ICON_CHARS: Dictionary = {
	ThoughtType.SHOPPING: "🛒",
	ThoughtType.QUEUE: "🧍",
	ThoughtType.PRICING: "💲",
	ThoughtType.THEFT: "🫣",
	ThoughtType.EXIT: "🚪",
	ThoughtType.QUESTION: "❓",
	ThoughtType.EXCLAMATION: "❗",
	ThoughtType.HOURGLASS: "⏳",
	ThoughtType.ANGRY: "😠",
	ThoughtType.HEART: "❤️",
	ThoughtType.BROWSING: "👀",
	ThoughtType.SATISFIED: "😊",
	ThoughtType.ANGRY_CLOUD: "💢",
	ThoughtType.PRODUCT_SEARCH: "🔍",
}

const BUBBLE_COLOR := Color(1.0, 1.0, 1.0, 0.92)
const OUTLINE_COLOR := Color(0.35, 0.35, 0.35, 0.9)
const BUBBLE_SIZE := 64
const BOB_AMPLITUDE := 0.04
const BOB_SPEED := 2.5

var _current_thought: ThoughtType = ThoughtType.NONE
var _sprite: Sprite3D = null
var _phase: float = 0.0
var _base_y: float = 0.0
var _anim_progress: float = 0.0
var _fading_out: bool = false
var _fade_timer: float = 0.0
var _duration: float = 0.0
var _duration_timer: float = 0.0
var _has_duration: bool = false

var _texture_cache: Dictionary = {}

func _ready() -> void:
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.pixel_size = 0.008
	_sprite.no_depth_test = false
	_sprite.transparent = true
	_sprite.modulate = Color(1, 1, 1, 0)
	_sprite.render_priority = 10
	_sprite.double_sided = true
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	add_child(_sprite)

	_base_y = position.y
	visible = false

func _process(delta: float) -> void:
	if _current_thought == ThoughtType.NONE:
		return

	if _has_duration:
		_duration_timer += delta
		if _duration_timer >= _duration and not _fading_out:
			hide_thought()

	if _fading_out:
		_fade_timer += delta
		var fade_duration := 0.3
		var alpha := 1.0 - clampf(_fade_timer / fade_duration, 0.0, 1.0)
		_sprite.modulate.a = alpha
		var s := 0.5 + 0.5 * alpha
		_sprite.scale = Vector3(s, s, s)
		if alpha <= 0.0:
			_current_thought = ThoughtType.NONE
			visible = false
			_fading_out = false
		return

	if _anim_progress < 1.0:
		_anim_progress += delta * 4.0
		_anim_progress = minf(_anim_progress, 1.0)
		var t := _ease_out_back(_anim_progress)
		_sprite.scale = Vector3(t, t, t)
		_sprite.modulate.a = clampf(_anim_progress * 2.0, 0.0, 1.0)

	_phase += delta * BOB_SPEED
	_sprite.position.y = _base_y + sin(_phase) * BOB_AMPLITUDE

func show_thought(thought_type: ThoughtType, duration: float = 0.0) -> void:
	if thought_type == ThoughtType.NONE:
		hide_thought()
		return

	_current_thought = thought_type
	_fading_out = false
	_fade_timer = 0.0
	_anim_progress = 0.0
	_phase = 0.0
	_sprite.scale = Vector3(0.01, 0.01, 0.01)
	_sprite.modulate.a = 0.0
	_sprite.position.y = _base_y

	var tex := _get_or_create_texture(thought_type)
	_sprite.texture = tex

	if duration > 0.0:
		_has_duration = true
		_duration = duration
		_duration_timer = 0.0
	else:
		_has_duration = false
		_duration = 0.0
		_duration_timer = 0.0

	visible = true

func hide_thought() -> void:
	if _current_thought == ThoughtType.NONE:
		return
	_fading_out = true
	_fade_timer = 0.0

func get_current_thought() -> ThoughtType:
	return _current_thought

func _get_or_create_texture(thought_type: ThoughtType) -> ImageTexture:
	if thought_type in _texture_cache:
		return _texture_cache[thought_type]

	var img := Image.create(BUBBLE_SIZE, BUBBLE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var center := Vector2(BUBBLE_SIZE / 2.0, BUBBLE_SIZE / 2.0)
	var radius := (BUBBLE_SIZE / 2.0) - 2.0
	var outline_radius := radius + 1.5

	for x in BUBBLE_SIZE:
		for y in BUBBLE_SIZE:
			var pos := Vector2(x + 0.5, y + 0.5)
			var dist := pos.distance_to(center)
			if dist <= outline_radius:
				if dist <= radius:
					img.set_pixel(x, y, BUBBLE_COLOR)
				else:
					img.set_pixel(x, y, OUTLINE_COLOR)

	var tail_points: Array[Vector2i] = []
	var tail_cx := int(center.x)
	for ty in range(BUBBLE_SIZE - 8, BUBBLE_SIZE):
		var half_w := maxi(1, int((BUBBLE_SIZE - ty) / 3.0))
		for tx in range(tail_cx - half_w, tail_cx + half_w + 1):
			if tx >= 0 and tx < BUBBLE_SIZE and ty >= 0 and ty < BUBBLE_SIZE:
				img.set_pixel(tx, ty, BUBBLE_COLOR)
				tail_points.append(Vector2i(tx, ty))

	_draw_icon_on_image(img, thought_type)

	var tex := ImageTexture.create_from_image(img)
	_texture_cache[thought_type] = tex
	return tex

func _draw_icon_on_image(img: Image, thought_type: ThoughtType) -> void:
	@warning_ignore("INTEGER_DIVISION")
	var cx := BUBBLE_SIZE / 2
	@warning_ignore("INTEGER_DIVISION")
	var cy := BUBBLE_SIZE / 2 - 2
	var icon_color := _get_icon_color(thought_type)

	match thought_type:
		ThoughtType.SHOPPING:
			_draw_rect_on_img(img, cx - 8, cy - 4, 16, 10, icon_color)
			_draw_rect_on_img(img, cx - 6, cy - 6, 12, 2, icon_color)
			_draw_pixel_safe(img, cx - 5, cy + 8, icon_color)
			_draw_pixel_safe(img, cx + 5, cy + 8, icon_color)
		ThoughtType.QUEUE:
			for i in 3:
				var ox := cx - 8 + i * 8
				_draw_rect_on_img(img, ox - 1, cy - 6, 3, 3, icon_color)
				_draw_rect_on_img(img, ox - 2, cy - 3, 5, 8, icon_color)
		ThoughtType.PRICING:
			_draw_rect_on_img(img, cx - 1, cy - 10, 3, 20, icon_color)
			_draw_rect_on_img(img, cx - 6, cy - 7, 12, 3, icon_color)
			_draw_rect_on_img(img, cx - 6, cy + 0, 12, 3, icon_color)
			_draw_rect_on_img(img, cx - 6, cy + 5, 12, 3, icon_color)
		ThoughtType.THEFT:
			_draw_rect_on_img(img, cx - 10, cy - 3, 20, 3, icon_color)
			_draw_rect_on_img(img, cx - 5, cy - 8, 3, 5, icon_color)
			_draw_rect_on_img(img, cx + 3, cy - 8, 3, 5, icon_color)
			_draw_rect_on_img(img, cx - 4, cy + 2, 8, 6, Color(0.2, 0.2, 0.2, 0.6))
		ThoughtType.EXIT:
			_draw_rect_on_img(img, cx - 6, cy - 10, 12, 20, icon_color)
			_draw_rect_on_img(img, cx + 2, cy - 1, 3, 3, Color(0.8, 0.7, 0.2))
			_draw_rect_on_img(img, cx + 7, cy - 5, 4, 2, icon_color)
			_draw_rect_on_img(img, cx + 9, cy - 3, 2, 6, icon_color)
			_draw_rect_on_img(img, cx + 7, cy + 3, 4, 2, icon_color)
		ThoughtType.QUESTION:
			_draw_rect_on_img(img, cx - 4, cy - 10, 9, 3, icon_color)
			_draw_rect_on_img(img, cx + 3, cy - 7, 3, 6, icon_color)
			_draw_rect_on_img(img, cx - 1, cy - 1, 3, 4, icon_color)
			_draw_rect_on_img(img, cx - 1, cy + 5, 3, 3, icon_color)
		ThoughtType.EXCLAMATION:
			_draw_rect_on_img(img, cx - 2, cy - 10, 4, 13, icon_color)
			_draw_rect_on_img(img, cx - 2, cy + 5, 4, 4, icon_color)
		ThoughtType.HOURGLASS:
			_draw_rect_on_img(img, cx - 7, cy - 10, 15, 2, icon_color)
			_draw_rect_on_img(img, cx - 7, cy + 8, 15, 2, icon_color)
			_draw_rect_on_img(img, cx - 5, cy - 8, 11, 3, Color(0.9, 0.85, 0.6))
			_draw_rect_on_img(img, cx - 3, cy - 5, 7, 3, Color(0.9, 0.85, 0.6))
			_draw_rect_on_img(img, cx - 1, cy - 2, 3, 4, Color(0.9, 0.85, 0.6))
			_draw_rect_on_img(img, cx - 3, cy + 2, 7, 3, Color(0.9, 0.85, 0.6))
			_draw_rect_on_img(img, cx - 5, cy + 5, 11, 3, Color(0.9, 0.85, 0.6))
		ThoughtType.ANGRY:
			_draw_rect_on_img(img, cx - 8, cy - 5, 5, 3, icon_color)
			_draw_rect_on_img(img, cx + 4, cy - 5, 5, 3, icon_color)
			_draw_rect_on_img(img, cx - 6, cy + 2, 13, 3, icon_color)
			_draw_rect_on_img(img, cx - 4, cy + 5, 3, 3, icon_color)
			_draw_rect_on_img(img, cx + 2, cy + 5, 3, 3, icon_color)
		ThoughtType.HEART:
			_draw_rect_on_img(img, cx - 8, cy - 5, 5, 5, icon_color)
			_draw_rect_on_img(img, cx + 4, cy - 5, 5, 5, icon_color)
			_draw_rect_on_img(img, cx - 8, cy, 17, 4, icon_color)
			_draw_rect_on_img(img, cx - 6, cy + 4, 13, 3, icon_color)
			_draw_rect_on_img(img, cx - 4, cy + 7, 9, 2, icon_color)
			_draw_rect_on_img(img, cx - 2, cy + 9, 5, 2, icon_color)
		ThoughtType.BROWSING:
			_draw_rect_on_img(img, cx - 8, cy - 6, 6, 6, icon_color)
			_draw_rect_on_img(img, cx + 3, cy - 6, 6, 6, icon_color)
			_draw_rect_on_img(img, cx - 8, cy + 2, 6, 2, icon_color)
			_draw_rect_on_img(img, cx + 3, cy + 2, 6, 2, icon_color)
		ThoughtType.SATISFIED:
			_draw_rect_on_img(img, cx - 8, cy - 5, 4, 4, icon_color)
			_draw_rect_on_img(img, cx + 5, cy - 5, 4, 4, icon_color)
			_draw_rect_on_img(img, cx - 7, cy + 3, 3, 2, icon_color)
			_draw_rect_on_img(img, cx - 4, cy + 5, 9, 2, icon_color)
			_draw_rect_on_img(img, cx + 5, cy + 3, 3, 2, icon_color)
		ThoughtType.ANGRY_CLOUD:
			_draw_rect_on_img(img, cx - 8, cy - 8, 16, 12, icon_color)
			_draw_rect_on_img(img, cx - 10, cy - 5, 2, 6, icon_color)
			_draw_rect_on_img(img, cx + 8, cy - 5, 2, 6, icon_color)
			_draw_rect_on_img(img, cx - 5, cy - 3, 3, 2, Color(0.95, 0.2, 0.2))
			_draw_rect_on_img(img, cx + 3, cy - 3, 3, 2, Color(0.95, 0.2, 0.2))
			_draw_rect_on_img(img, cx - 3, cy + 1, 7, 2, Color(0.95, 0.2, 0.2))
			_draw_rect_on_img(img, cx - 1, cy + 5, 3, 3, icon_color)
		ThoughtType.PRODUCT_SEARCH:
			_draw_rect_on_img(img, cx - 6, cy - 8, 10, 10, icon_color)
			_draw_rect_on_img(img, cx - 4, cy - 6, 6, 6, Color(0.85, 0.92, 1.0))
			_draw_rect_on_img(img, cx + 2, cy + 2, 3, 3, icon_color)
			_draw_rect_on_img(img, cx + 4, cy + 4, 3, 3, icon_color)

func _get_icon_color(thought_type: ThoughtType) -> Color:
	match thought_type:
		ThoughtType.SHOPPING: return Color(0.2, 0.55, 0.9)
		ThoughtType.QUEUE: return Color(0.5, 0.5, 0.5)
		ThoughtType.PRICING: return Color(0.15, 0.65, 0.15)
		ThoughtType.THEFT: return Color(0.55, 0.2, 0.7)
		ThoughtType.EXIT: return Color(0.65, 0.45, 0.25)
		ThoughtType.QUESTION: return Color(0.2, 0.5, 0.85)
		ThoughtType.EXCLAMATION: return Color(0.9, 0.2, 0.2)
		ThoughtType.HOURGLASS: return Color(0.6, 0.5, 0.2)
		ThoughtType.ANGRY: return Color(0.85, 0.15, 0.15)
		ThoughtType.HEART: return Color(0.9, 0.2, 0.35)
		ThoughtType.BROWSING: return Color(0.3, 0.3, 0.3)
		ThoughtType.SATISFIED: return Color(0.95, 0.75, 0.1)
		ThoughtType.ANGRY_CLOUD: return Color(0.45, 0.45, 0.5)
		ThoughtType.PRODUCT_SEARCH: return Color(0.3, 0.5, 0.8)
	return Color.BLACK

func _draw_rect_on_img(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for px in range(x, x + w):
		for py in range(y, y + h):
			_draw_pixel_safe(img, px, py, color)

func _draw_pixel_safe(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, color)

func _ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3) + c1 * pow(t - 1.0, 2)
