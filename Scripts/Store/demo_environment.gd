class_name DemoEnvironment
extends Node3D

## Loads _Demo.glb, hides non-supermarket sections, and generates static
## collision from every visible MeshInstance3D so the player and customers
## can't walk through demo geometry.

const SUPERMARKET_PREFIXES: Array[String] = [
	"SI_Prop_Shelf_Isle",
	"SI_Prop_Shelf_Freezer",
	"SI_Prop_CheckoutCounter",
	"SI_Prop_SelfCheckout",
	"SI_Prop_SecurityScanner",
	"SI_Prop_AlcoholShelf",
	"SI_Prop_ButcherCounter",
	"SI_Prop_ProduceSection",
	"SI_Prop_ShoppingTrolley",
	"SI_Prop_Basket",
	"SI_Prop_Freezer",
	"SI_Prop_RubbishBin",
	"SI_Prop_CardScanner",
	"SI_Prop_Scanner",
	"SI_Prop_ElectronicRegister",
	"SI_Prop_Sign_Alcohol",
	"SI_Prop_Sign_Organic",
	"SI_Prop_Sign_Meats",
	"SI_Prop_Sign_General",
	"SI_Prop_Sign_Frozen",
	"SI_Prop_Sign_Groceries",
	"SI_Prop_Sign_Bakery",
	"SI_Prop_Sign_BuyNow",
	"SI_Prop_Sign_Sale",
	"SI_Prop_Sign_HalfPrice",
	"SI_Prop_Sign_Welcome",
	"SI_Prop_SignCaution",
	"SI_Prop_Mat",
	"SI_Prop_Plant",
	"SI_Prop_FireExtinguisher",
	"SI_Prop_MopBin",
	"SI_Prop_WaterSpill",
	"SI_Prop_Bench",
	"SI_Prop_ConcreteBench",
	"SI_Prop_TrashBins",
	"SI_Prop_CarboardBox",
	"SI_Prop_Ladder",
	"SI_Prop_MoneyStack",
	"SI_Prop_Safe",
	"SI_Env_Wall",
	"SI_Env_Floor",
	"SI_Env_Door_01",
	"SI_Env_Pillar",
	"SI_Env_Wall_CornerBlock",
	"SI_Food_",
	"SI_Prop_Shelf_Isle_End",
	"SI_Prop_Briefcase",
]

## Bounding box for the supermarket area (centimetre-scale coords from _Demo.glb).
## Props with matching prefixes but outside this AABB are hidden, except
## structural pieces (floors, walls) which are always kept.
const SUPERMARKET_X_MIN := -12.0
const SUPERMARKET_X_MAX := 18.0
const SUPERMARKET_Z_MIN := -10.0
const SUPERMARKET_Z_MAX := 46.0

## Prefixes for props that should receive trimesh collision bodies.
## Small decorative items (signs, spills, money, etc.) are excluded to keep
## the physics broadphase lean.
const COLLISION_PREFIXES: Array[String] = [
	"SI_Prop_Shelf_Isle",
	"SI_Prop_Shelf_Freezer",
	"SI_Prop_CheckoutCounter",
	"SI_Prop_SelfCheckout",
	"SI_Prop_SecurityScanner",
	"SI_Prop_AlcoholShelf",
	"SI_Prop_ButcherCounter",
	"SI_Prop_ProduceSection",
	"SI_Prop_Freezer",
	"SI_Prop_Bench",
	"SI_Prop_ConcreteBench",
	"SI_Env_Wall",
	"SI_Env_Floor",
	"SI_Env_Door_01",
	"SI_Env_Pillar",
	"SI_Env_Wall_CornerBlock",
	"SI_Prop_Shelf_Isle_End",
]

var _demo_instance: Node3D = null

func _ready() -> void:
	var demo_scene: PackedScene = load("res://Resources/Models/_Demo.glb")
	if demo_scene == null:
		push_error("DemoEnvironment: Failed to load _Demo.glb")
		return
	_demo_instance = demo_scene.instantiate()
	add_child(_demo_instance)
	_filter_to_supermarket()
	_generate_mesh_collision()
	_generate_boundary_collision()


# ---------------------------------------------------------------------------
# Filtering
# ---------------------------------------------------------------------------

func _filter_to_supermarket() -> void:
	if _demo_instance == null:
		return
	# Remove cameras / directional lights from the demo's scene settings
	var settings_node: Node = _demo_instance.get_node_or_null("_Scene_Settings")
	if settings_node:
		for child in settings_node.get_children():
			if child is Camera3D or child.name.begins_with("Main Camera") or child.name.begins_with("Directional Light"):
				child.queue_free()

	var props_node: Node = _demo_instance.get_node_or_null("_Demo_Props")
	if props_node == null:
		return

	for child in props_node.get_children():
		if not child is Node3D:
			continue
		var n: String = child.name
		var keep := false
		for prefix in SUPERMARKET_PREFIXES:
			if n.begins_with(prefix):
				keep = true
				break
		if keep:
			var pos: Vector3 = child.position
			# Allow structural env pieces everywhere
			var is_structural := n.begins_with("SI_Env_Floor") or n.begins_with("SI_Env_Wall")
			if not is_structural:
				if pos.x < SUPERMARKET_X_MIN or pos.x > SUPERMARKET_X_MAX:
					keep = false
				if pos.z < SUPERMARKET_Z_MIN or pos.z > SUPERMARKET_Z_MAX:
					keep = false
		if not keep:
			child.visible = false
			child.process_mode = Node.PROCESS_MODE_DISABLED


# ---------------------------------------------------------------------------
# Collision generation
# ---------------------------------------------------------------------------

func _generate_mesh_collision() -> void:
	## Walk every visible MeshInstance3D under the demo and generate a
	## StaticBody3D + trimesh CollisionShape3D for each mesh that matches
	## COLLISION_PREFIXES.  This gives pixel-accurate blocking for shelves,
	## freezers, walls, floors, checkout counters, etc.
	var collision_root := StaticBody3D.new()
	collision_root.name = "DemoMeshCollision"
	add_child(collision_root)

	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_demo_instance, meshes)

	var count := 0
	for mi in meshes:
		if not mi.visible:
			continue
		# Check the top-level prop name matches collision prefixes
		var prop_name := _get_prop_name(mi)
		var dominated := false
		for prefix in COLLISION_PREFIXES:
			if prop_name.begins_with(prefix):
				dominated = true
				break
		if not dominated:
			continue

		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue

		# Create trimesh shape from the mesh
		var shape := mesh.create_trimesh_shape()
		if shape == null:
			continue

		var col := CollisionShape3D.new()
		col.shape = shape
		col.name = "Col_%s_%d" % [prop_name.left(30), count]
		# Apply the mesh instance's global transform relative to our collision root
		col.transform = collision_root.global_transform.inverse() * mi.global_transform
		collision_root.add_child(col)
		count += 1

	print("DemoEnvironment: generated %d trimesh collision shapes" % count)


func _generate_boundary_collision() -> void:
	## Fallback boundary walls so the player can't escape the supermarket area.
	var boundary := StaticBody3D.new()
	boundary.name = "DemoBoundaryCollision"
	add_child(boundary)

	# Floor
	_add_box_col(boundary, Vector3(3.0, -2.11, 20.0), Vector3(30.0, 0.2, 56.0))
	# North wall
	_add_box_col(boundary, Vector3(3.0, 0.0, -7.0), Vector3(30.0, 5.0, 0.3))
	# South wall
	_add_box_col(boundary, Vector3(3.0, 0.0, 46.0), Vector3(30.0, 5.0, 0.3))
	# West wall
	_add_box_col(boundary, Vector3(-12.0, 0.0, 20.0), Vector3(0.3, 5.0, 56.0))
	# East wall
	_add_box_col(boundary, Vector3(18.0, 0.0, 20.0), Vector3(0.3, 5.0, 56.0))


func _add_box_col(parent: Node3D, pos: Vector3, sz: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = sz
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	parent.add_child(col)


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)


func _get_prop_name(mi: MeshInstance3D) -> String:
	## Walk up to find the top-level child of _Demo_Props.
	## In the GLB all props are flat children of _Demo_Props, but some meshes
	## may be nested inside them, so we climb until the parent is _Demo_Props.
	var node: Node = mi
	while node.get_parent() != null:
		if node.get_parent().name == "_Demo_Props" or node.get_parent().name == "_Scene_Settings":
			return node.name
		if node.get_parent() == _demo_instance:
			return node.name
		node = node.get_parent()
	return mi.name
