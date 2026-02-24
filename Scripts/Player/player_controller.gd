class_name PlayerController
extends CharacterBody3D

@export_group("Movement")
@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002

@export_group("Interaction")
@export var highlight_color: Color = Color(1.0, 1.0, 1.0, 0.15)

@onready var camera: Camera3D = $Camera3D
@onready var interaction_ray: RayCast3D = $Camera3D/InteractionRay

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _current_interactable: Interactable = null
var held_product_data: Resource = null

var _highlighted_mesh: MeshInstance3D = null
var _highlight_mat: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_mat.albedo_color = highlight_color
	_highlight_mat.no_depth_test = true
	_highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	if event.is_action_pressed("interact"):
		_try_interact()

	if event.is_action_pressed("drop"):
		_drop_product()

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement()
	move_and_slide()
	_check_interaction_ray()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func _apply_movement() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var speed := sprint_speed if Input.is_action_pressed("sprint") else move_speed

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

func _check_interaction_ray() -> void:
	var found: Interactable = null

	if interaction_ray and interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if is_instance_valid(collider):
			found = _find_interactable(collider)
			if found and not found.is_interactable:
				found = null

	if found:
		if found != _current_interactable:
			_clear_highlight()
			_current_interactable = found
			_apply_highlight(_current_interactable)
			EventBus.interaction_prompt_show.emit(_current_interactable.get_prompt())
		else:
			EventBus.interaction_prompt_show.emit(_current_interactable.get_prompt())
	else:
		if _current_interactable:
			_clear_highlight()
			_current_interactable = null
			EventBus.interaction_prompt_hide.emit()

func _find_interactable(node: Node) -> Interactable:
	if node == null or not is_instance_valid(node):
		return null
	if node is Interactable:
		return node as Interactable
	var parent := node.get_parent()
	if parent != null and is_instance_valid(parent) and parent is Interactable:
		return parent as Interactable
	return null

func _try_interact() -> void:
	if _current_interactable and is_instance_valid(_current_interactable) \
		and _current_interactable.is_interactable:
		_current_interactable.interact(self)
		EventBus.player_interacted.emit(_current_interactable)

func _apply_highlight(target: Node) -> void:
	var mesh := _find_mesh(target)
	if mesh == null:
		return
	_highlighted_mesh = mesh
	mesh.material_overlay = _highlight_mat

func _clear_highlight() -> void:
	if _highlighted_mesh and is_instance_valid(_highlighted_mesh):
		_highlighted_mesh.material_overlay = null
	_highlighted_mesh = null

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null

func pick_up_product(data: Resource) -> void:
	held_product_data = data
	EventBus.product_picked_up.emit(data)

func _drop_product() -> void:
	if held_product_data:
		var dropped := held_product_data
		held_product_data = null
		EventBus.product_dropped.emit(dropped)

func is_holding_product() -> bool:
	return held_product_data != null

func get_held_product() -> Resource:
	return held_product_data

func clear_held_product() -> void:
	var prev := held_product_data
	held_product_data = null
	if prev:
		EventBus.product_dropped.emit(prev)
