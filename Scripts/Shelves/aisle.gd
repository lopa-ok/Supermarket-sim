class_name Aisle
extends Node3D

@export var aisle_name: String = ""
@export var aisle_tags: Array[String] = []

@onready var waypoints_node: Node3D = $Waypoints if has_node("Waypoints") else null

func _ready() -> void:
	add_to_group("aisles")
	if aisle_tags.is_empty():
		_auto_collect_tags()

func get_shelves() -> Array[Node]:
	var result: Array[Node] = []
	_collect_shelves(self, result)
	return result

func get_waypoint_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	if waypoints_node:
		for child in waypoints_node.get_children():
			if child is Node3D:
				positions.append(child.global_position)
	if positions.is_empty():
		positions.append(global_position)
	return positions

func get_entry_position() -> Vector3:
	var wps := get_waypoint_positions()
	return wps[0]

func get_exit_position() -> Vector3:
	var wps := get_waypoint_positions()
	return wps[wps.size() - 1]

func has_product(product_id: String) -> bool:
	for shelf in get_shelves():
		if shelf.get_stock_of(product_id) > 0:
			return true
	return false

func has_tag(tag: String) -> bool:
	return tag in aisle_tags

func find_shelf_for_product(product_id: String) -> Node:
	var best: Node = null
	var best_stock := 0
	for shelf in get_shelves():
		var s: int = shelf.get_stock_of(product_id)
		if s > best_stock:
			best_stock = s
			best = shelf
	return best

func _collect_shelves(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		if child is Shelf:
			result.append(child)
		elif child is Node3D and not (child is Aisle):
			_collect_shelves(child, result)

func _auto_collect_tags() -> void:
	for shelf in get_shelves():
		if shelf.has_method("get_all_tags"):
			for tag in shelf.get_all_tags():
				if tag not in aisle_tags:
					aisle_tags.append(tag)
