class_name StockroomPath
extends Node3D

var _waypoints: Array[Vector3] = []
var _collected: bool = false

func _ready() -> void:
	add_to_group("stockroom_path")
	call_deferred("_collect_ordered_waypoints")

func _collect_ordered_waypoints() -> void:
	var indexed: Array[Dictionary] = []
	for child in get_children():
		if child is Marker3D:
			var idx: int = child.get_meta("order", -1)
			if idx < 0:
				var parts: PackedStringArray = child.name.split("_")
				var last: String = parts[parts.size() - 1]
				if last.is_valid_int():
					idx = last.to_int()
				else:
					idx = indexed.size()
			indexed.append({"pos": child.global_position, "order": idx})
	indexed.sort_custom(func(a, b): return a["order"] < b["order"])
	_waypoints.clear()
	for entry in indexed:
		_waypoints.append(entry["pos"])
	_collected = true

func _ensure_collected() -> void:
	if not _collected:
		_collect_ordered_waypoints()

func get_waypoint_count() -> int:
	_ensure_collected()
	return _waypoints.size()

func get_waypoint(index: int) -> Vector3:
	_ensure_collected()
	if index < 0 or index >= _waypoints.size():
		return global_position
	return _waypoints[index]

func get_all_waypoints() -> Array[Vector3]:
	_ensure_collected()
	return _waypoints.duplicate()

func get_last_waypoint() -> Vector3:
	_ensure_collected()
	if _waypoints.is_empty():
		return global_position
	return _waypoints[_waypoints.size() - 1]

func get_reversed_waypoints() -> Array[Vector3]:
	_ensure_collected()
	var rev: Array[Vector3] = _waypoints.duplicate()
	rev.reverse()
	return rev
