class_name StoreWaypoints
extends Node3D
## Holds Marker3D waypoints scattered throughout the entire store.
## Customers query this node for random or nearest waypoints to wander to,
## instead of using a hardcoded bounding box.

## Optional: tag waypoints for zone-based filtering (e.g. "entrance", "aisle",
## "open_floor", "checkout_area", "back_room").  If a Marker3D has metadata
## "zone" it will be indexed.  Otherwise it is treated as "general".

var _waypoints: Array[Vector3] = []
var _zone_map: Dictionary = {}          # zone_name -> Array[Vector3]

func _ready() -> void:
	add_to_group("store_waypoints")
	_collect_waypoints(self)
	if _waypoints.is_empty():
		push_warning("StoreWaypoints: No waypoint children found!")

# ---------------------------------------------------------------
# Public API
# ---------------------------------------------------------------

## Return a random waypoint position from anywhere in the store.
func get_random_waypoint() -> Vector3:
	if _waypoints.is_empty():
		return global_position
	return _waypoints[randi() % _waypoints.size()]

## Return a random waypoint that is at least `min_dist` away from `from_pos`.
func get_random_waypoint_away_from(from_pos: Vector3, min_dist: float = 3.0) -> Vector3:
	if _waypoints.is_empty():
		return global_position
	var candidates: Array[Vector3] = []
	for wp in _waypoints:
		if wp.distance_to(from_pos) >= min_dist:
			candidates.append(wp)
	if candidates.is_empty():
		return _waypoints[randi() % _waypoints.size()]
	return candidates[randi() % candidates.size()]

## Return the closest waypoint to `from_pos`.
func get_nearest_waypoint(from_pos: Vector3) -> Vector3:
	if _waypoints.is_empty():
		return global_position
	var best: Vector3 = _waypoints[0]
	var best_dist: float = from_pos.distance_squared_to(best)
	for wp in _waypoints:
		var d := from_pos.distance_squared_to(wp)
		if d < best_dist:
			best_dist = d
			best = wp
	return best

## Return a random waypoint in a specific zone (e.g. "entrance", "open_floor").
func get_random_waypoint_in_zone(zone: String) -> Vector3:
	if zone in _zone_map and not _zone_map[zone].is_empty():
		var arr: Array = _zone_map[zone]
		return arr[randi() % arr.size()]
	return get_random_waypoint()

## Return all waypoint positions.
func get_all_waypoints() -> Array[Vector3]:
	return _waypoints

# ---------------------------------------------------------------
# Internal
# ---------------------------------------------------------------

func _collect_waypoints(node: Node) -> void:
	for child in node.get_children():
		if child is Marker3D:
			var pos: Vector3 = child.global_position
			_waypoints.append(pos)
			var zone: String = child.get_meta("zone", "general")
			if zone not in _zone_map:
				_zone_map[zone] = []
			_zone_map[zone].append(pos)
		if child.get_child_count() > 0 and not (child is StoreWaypoints):
			_collect_waypoints(child)
