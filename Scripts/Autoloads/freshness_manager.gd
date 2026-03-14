extends Node

const FRESHNESS_CHECK_INTERVAL := 5.0
const DECAY_BASE_RATE := 0.15
const EXPIRED_THRESHOLD := 5.0
const LOW_FRESHNESS_THRESHOLD := 30.0

var _shelf_freshness: Dictionary = {}
var _check_timer: float = 0.0

func _ready() -> void:
	EventBus.shelf_stock_changed.connect(_on_stock_changed)
	EventBus.store_opened.connect(_on_store_opened)

func _process(delta: float) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or not gm.store_is_open:
		return

	_check_timer += delta
	if _check_timer < FRESHNESS_CHECK_INTERVAL:
		return
	_check_timer = 0.0

	_decay_all_shelves(FRESHNESS_CHECK_INTERVAL)
	_remove_expired_items()

func _on_store_opened() -> void:
	_init_freshness_map()

func _on_stock_changed(shelf: Node, product_id: String, _current: int, _max_stock: int, side_name: String) -> void:
	var key := _make_key(shelf, side_name, product_id)
	if key not in _shelf_freshness:
		_shelf_freshness[key] = 100.0

func _init_freshness_map() -> void:
	_shelf_freshness.clear()
	var shelves := get_tree().get_nodes_in_group("shelves")
	for shelf in shelves:
		if not ("stock" in shelf):
			continue
		var shelf_stock = shelf.stock
		if not (shelf_stock is Dictionary):
			continue
		for side_name in shelf_stock:
			var side_data = shelf_stock[side_name]
			if side_data is Dictionary:
				for pid in side_data:
					if side_data[pid] > 0:
						var key := _make_key(shelf, side_name, pid)
						if key not in _shelf_freshness:
							_shelf_freshness[key] = 100.0

func _decay_all_shelves(elapsed: float) -> void:
	var db = get_node_or_null("/root/ProductDatabase")
	var keys_to_remove: Array = []
	for key in _shelf_freshness:
		var parts: Array = key.split("|")
		if parts.size() < 3:
			keys_to_remove.append(key)
			continue
		var pid: String = parts[2]
		var decay_rate := DECAY_BASE_RATE
		if db:
			var p = db.get_product(pid)
			if p and "freshness_decay_rate" in p:
				decay_rate = p.freshness_decay_rate
		_shelf_freshness[key] = maxf(0.0, _shelf_freshness[key] - decay_rate * elapsed)
	for key in keys_to_remove:
		_shelf_freshness.erase(key)

func _remove_expired_items() -> void:
	var shelves := get_tree().get_nodes_in_group("shelves")
	var shelf_map: Dictionary = {}
	for shelf in shelves:
		shelf_map[str(shelf.get_instance_id())] = shelf

	var keys_to_remove: Array = []
	for key in _shelf_freshness:
		if _shelf_freshness[key] > EXPIRED_THRESHOLD:
			continue
		var parts: Array = key.split("|")
		if parts.size() < 3:
			continue
		var shelf_id: String = parts[0]
		var side_name: String = parts[1]
		var pid: String = parts[2]
		if shelf_id in shelf_map:
			var shelf: Node = shelf_map[shelf_id]
			if shelf.has_method("remove_stock_side"):
				var removed: int = shelf.remove_stock_side(side_name, pid, 1)
				if removed > 0:
					EventBus.product_expired.emit(shelf, pid)
					keys_to_remove.append(key)
			elif shelf.has_method("remove_stock"):
				var removed: int = shelf.remove_stock(pid, 1)
				if removed > 0:
					EventBus.product_expired.emit(shelf, pid)
					keys_to_remove.append(key)
		else:
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_shelf_freshness.erase(key)

func get_freshness(shelf: Node, side_name: String, product_id: String) -> float:
	var key := _make_key(shelf, side_name, product_id)
	return _shelf_freshness.get(key, 100.0)

func is_low_freshness(shelf: Node, side_name: String, product_id: String) -> bool:
	return get_freshness(shelf, side_name, product_id) < LOW_FRESHNESS_THRESHOLD

func _make_key(shelf: Node, side_name: String, product_id: String) -> String:
	return "%s|%s|%s" % [str(shelf.get_instance_id()), side_name, product_id]
