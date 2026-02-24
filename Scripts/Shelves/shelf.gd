class_name Shelf
extends Interactable

const FALLBACK_SIZE := Vector3(0.2, 0.2, 0.2)
const FALLBACK_COLOR := Color(0.6, 0.6, 0.7, 0.35)
const PRODUCT_SCALE := 41.23

var sides: Dictionary = {}
var _slot_data: Dictionary = {}
var _interaction_map: Dictionary = {}
var _scene_cache: Dictionary = {}

var stock: Dictionary:
	get:
		var result: Dictionary = {}
		for side_name in _slot_data:
			var counts: Dictionary = {}
			for entry in _slot_data[side_name]:
				var pid: String = entry["product_id"]
				if pid != "":
					counts[pid] = counts.get(pid, 0) + 1
			result[side_name] = counts
		return result

func _ready() -> void:
	add_to_group("shelves")
	scale = Vector3.ONE
	var sides_node: Node = get_node_or_null("Sides")
	if sides_node == null:
		return
	if sides_node is Node3D:
		sides_node.scale = Vector3.ONE
	for child in sides_node.get_children():
		if child is ShelfSide:
			child.scale = Vector3.ONE
			var slots_container: Node = child.get_node_or_null("Slots")
			if slots_container and slots_container is Node3D:
				slots_container.scale = Vector3.ONE
				for marker in slots_container.get_children():
					if marker is Marker3D:
						marker.scale = Vector3.ONE
			_register_side(child)

func _register_side(side_node: ShelfSide) -> void:
	var side_name: String = side_node.name
	sides[side_name] = side_node
	_slot_data[side_name] = []
	var slots_node: Node = side_node.get_node_or_null("Slots")
	if slots_node:
		for marker in slots_node.get_children():
			if marker is Marker3D:
				_slot_data[side_name].append({
					"marker": marker,
					"product_id": "",
					"mesh_instance": null,
				})
	var area: Area3D = side_node.get_node_or_null("InteractionArea")
	if area:
		_interaction_map[area] = side_name

func get_side_names() -> Array:
	return sides.keys()

func get_tag_for_side(side_name: String) -> String:
	if side_name in sides:
		return sides[side_name].shelf_tag
	return ""

func get_all_tags() -> Array[String]:
	var tags: Array[String] = []
	for side_name in sides:
		var tag: String = sides[side_name].shelf_tag
		if not tag.is_empty() and tag not in tags:
			tags.append(tag)
	return tags

func get_side_max(side_name: String) -> int:
	if side_name in sides:
		var base: int = sides[side_name].max_stock
		var um = get_node_or_null("/root/UpgradeManager")
		if um:
			base += int(um.get_upgrade_value("shelf_capacity_bonus"))
		return base
	return 0

func get_total_max() -> int:
	var total := 0
	for side_name in sides:
		total += sides[side_name].max_stock
	return total

func get_total_stock() -> int:
	var total := 0
	for side_name in _slot_data:
		total += _count_filled(side_name)
	return total

func is_full() -> bool:
	return get_total_stock() >= get_total_max()

func get_stock_of(product_id: String) -> int:
	var total := 0
	for side_name in _slot_data:
		for entry in _slot_data[side_name]:
			if entry["product_id"] == product_id:
				total += 1
	return total

func get_side_stock(side_name: String) -> Dictionary:
	var counts: Dictionary = {}
	if side_name in _slot_data:
		for entry in _slot_data[side_name]:
			var pid: String = entry["product_id"]
			if pid != "":
				counts[pid] = counts.get(pid, 0) + 1
	return counts

func get_side_total(side_name: String) -> int:
	return _count_filled(side_name)

func can_accept_product(product_id: String) -> bool:
	for side_name in sides:
		if _can_accept_on_side(side_name, product_id):
			return true
	return false

func can_accept_product_on_side(side_name: String, product_id: String) -> bool:
	return _can_accept_on_side(side_name, product_id)

func add_stock(product_id: String, amount: int = 1) -> bool:
	for side_name in sides:
		if _can_accept_on_side(side_name, product_id):
			return _add_to_side(side_name, product_id, amount)
	return false

func add_stock_side(side_name: String, product_id: String, amount: int = 1) -> bool:
	return _add_to_side(side_name, product_id, amount)

func remove_stock(product_id: String, amount: int = 1) -> int:
	var remaining := amount
	for side_name in _slot_data:
		if remaining <= 0:
			break
		remaining -= _remove_from_side(side_name, product_id, remaining)
	return amount - remaining

func remove_stock_side(side_name: String, product_id: String, amount: int = 1) -> int:
	return _remove_from_side(side_name, product_id, amount)

func get_random_stocked_product() -> String:
	var ids: Array = []
	for side_name in _slot_data:
		for entry in _slot_data[side_name]:
			var pid: String = entry["product_id"]
			if pid != "" and pid not in ids:
				ids.append(pid)
	if ids.is_empty():
		return ""
	return ids[randi() % ids.size()]

func get_side_for_area(area: Area3D) -> String:
	return _interaction_map.get(area, "")

func find_side_for_product(product_id: String) -> String:
	for side_name in _slot_data:
		for entry in _slot_data[side_name]:
			if entry["product_id"] == product_id:
				return side_name
	return ""

func find_sides_with_tag(tag: String) -> Array[String]:
	var result: Array[String] = []
	for side_name in sides:
		if sides[side_name].shelf_tag == tag:
			result.append(side_name)
	return result

func interact(player: Node) -> void:
	var side_name := _detect_side(player)
	if side_name.is_empty():
		return
	if player.is_holding_product():
		_try_place(player, side_name)
	else:
		_try_take(player, side_name)

func get_prompt() -> String:
	if not is_interactable:
		return ""
	var player := _get_player()
	if player == null:
		return ""
	var side_name := _detect_side(player)
	if side_name.is_empty():
		return "No side accessible"
	if player.is_holding_product():
		var held = player.get_held_product()
		var pid: String = held.product_id if held else ""
		if _can_accept_on_side(side_name, pid):
			return "Place %s on shelf [E]" % held.product_name
		return "Shelf doesn't accept this product"
	if _count_filled(side_name) > 0:
		return "Take product from shelf [E]"
	return "Shelf is empty"

func _detect_side(player: Node) -> String:
	var best_side := ""
	var best_dist := INF
	var ppos: Vector3 = player.global_position if "global_position" in player else global_position
	for area: Area3D in _interaction_map:
		for body in area.get_overlapping_bodies():
			if body == player:
				var d: float = ppos.distance_to(area.global_position)
				if d < best_dist:
					best_dist = d
					best_side = _interaction_map[area]
	if best_side.is_empty():
		for area: Area3D in _interaction_map:
			var d: float = ppos.distance_to(area.global_position)
			if d < best_dist:
				best_dist = d
				best_side = _interaction_map[area]
	return best_side

func _count_filled(side_name: String) -> int:
	var count := 0
	if side_name in _slot_data:
		for entry in _slot_data[side_name]:
			if entry["product_id"] != "":
				count += 1
	return count

func _ensure_slots(side_name: String) -> void:
	var needed: int = get_side_max(side_name)
	var slots: Array = _slot_data[side_name]
	while slots.size() < needed:
		var last_marker: Marker3D = null
		for i in range(slots.size() - 1, -1, -1):
			if slots[i]["marker"] != null:
				last_marker = slots[i]["marker"]
				break
		var virt_marker: Marker3D = null
		if last_marker:
			virt_marker = Marker3D.new()
			virt_marker.name = "VSlot_%d" % slots.size()
			last_marker.get_parent().add_child(virt_marker)
			var offset_idx := slots.size() - _base_slot_count(side_name)
			virt_marker.global_transform = last_marker.global_transform
			virt_marker.position += Vector3(0.25 * (offset_idx + 1), 0, 0)
		slots.append({
			"marker": virt_marker,
			"product_id": "",
			"mesh_instance": null,
		})

func _base_slot_count(side_name: String) -> int:
	if side_name in sides:
		return sides[side_name].max_stock
	return 0

func _can_accept_on_side(side_name: String, product_id: String) -> bool:
	if side_name not in sides:
		return false
	_ensure_slots(side_name)
	if _count_filled(side_name) >= get_side_max(side_name):
		return false
	var tag: String = sides[side_name].shelf_tag
	if tag.is_empty():
		return true
	var db = get_node_or_null("/root/ProductDatabase")
	if db:
		var p = db.get_product(product_id)
		if p and p.shelf_tag == tag:
			return true
	return false

func _add_to_side(side_name: String, product_id: String, amount: int) -> bool:
	if not _can_accept_on_side(side_name, product_id):
		return false
	var slots: Array = _slot_data[side_name]
	var added := 0
	for entry in slots:
		if added >= amount:
			break
		if entry["product_id"] != "":
			continue
		_spawn_at_slot(sides[side_name], entry, product_id)
		added += 1
	if added <= 0:
		return false
	_emit_changed(side_name, product_id)
	return true

func _remove_from_side(side_name: String, product_id: String, amount: int) -> int:
	if side_name not in _slot_data:
		return 0
	var slots: Array = _slot_data[side_name]
	var removed := 0
	for i in range(slots.size() - 1, -1, -1):
		if removed >= amount:
			break
		if slots[i]["product_id"] != product_id:
			continue
		_free_slot(slots[i])
		removed += 1
	if removed > 0:
		_emit_changed(side_name, product_id)
	return removed

func _spawn_at_slot(side_node: Node3D, entry: Dictionary, product_id: String) -> void:
	var marker: Marker3D = entry["marker"]
	var target_xform: Transform3D
	if marker:
		target_xform = marker.global_transform
	else:
		target_xform = side_node.global_transform
	var scene: PackedScene = _get_scene_for_side(side_node, product_id)
	var instance: Node3D
	var is_fallback := false
	if scene:
		instance = scene.instantiate() as Node3D
	if instance == null:
		instance = _make_fallback()
		is_fallback = true
	side_node.add_child(instance)
	instance.global_transform = target_xform
	if not is_fallback:
		instance.scale = Vector3.ONE * PRODUCT_SCALE
	entry["product_id"] = product_id
	entry["mesh_instance"] = instance

func _free_slot(entry: Dictionary) -> void:
	var inst: Node = entry["mesh_instance"]
	if inst and is_instance_valid(inst):
		inst.queue_free()
	entry["product_id"] = ""
	entry["mesh_instance"] = null

func _make_fallback() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = FALLBACK_SIZE
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = FALLBACK_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi

func _emit_changed(side_name: String, product_id: String) -> void:
	EventBus.shelf_stock_changed.emit(self, product_id, get_stock_of(product_id), get_total_max(), side_name)
	if get_total_stock() <= 0:
		EventBus.shelf_emptied.emit(self)

func _try_place(player: Node, side_name: String) -> void:
	var data: Resource = player.get_held_product()
	if data and _can_accept_on_side(side_name, data.product_id):
		if _add_to_side(side_name, data.product_id, 1):
			player.clear_held_product()
			EventBus.product_placed.emit(data, self)

func _try_take(player: Node, side_name: String) -> void:
	if _count_filled(side_name) <= 0:
		return
	var slots: Array = _slot_data[side_name]
	for i in range(slots.size() - 1, -1, -1):
		if slots[i]["product_id"] != "":
			var pid: String = slots[i]["product_id"]
			var db = get_node_or_null("/root/ProductDatabase")
			if db:
				var data = db.get_product(pid)
				if data:
					_free_slot(slots[i])
					_emit_changed(side_name, pid)
					player.pick_up_product(data)
			return

func _get_player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _get_scene_for_side(side_node: Node3D, product_id: String) -> PackedScene:
	if side_node is ShelfSide and side_node.product_scene:
		return side_node.product_scene
	return _get_scene(product_id)

func _get_scene(product_id: String) -> PackedScene:
	if product_id in _scene_cache:
		return _scene_cache[product_id]
	var db = get_node_or_null("/root/ProductDatabase")
	if db == null:
		_scene_cache[product_id] = null
		return null
	var data = db.get_product(product_id)
	if data == null:
		_scene_cache[product_id] = null
		return null
	var scene: PackedScene = null
	if data.mesh_scene:
		scene = data.mesh_scene
	elif not data.mesh_path.is_empty() and ResourceLoader.exists(data.mesh_path):
		var loaded = load(data.mesh_path)
		if loaded is PackedScene:
			scene = loaded as PackedScene
	_scene_cache[product_id] = scene
	return scene
