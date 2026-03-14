extends Node

const UPGRADE_DEFS: Dictionary = {
	"customer_spawn_rate": {
		"name": "Customer Flow",
		"description": "Increases the rate at which customers arrive.",
		"base_cost": 50.0,
		"cost_exponent": 1.6,
		"max_level": 10,
		"base_value": 1.0,
		"value_per_level": 0.08,
	},
	"shelf_capacity_bonus": {
		"name": "Shelf Capacity",
		"description": "Each shelf holds more products per side.",
		"base_cost": 75.0,
		"cost_exponent": 1.7,
		"max_level": 8,
		"base_value": 0,
		"value_per_level": 1,
	},
	"checkout_speed": {
		"name": "Checkout Speed",
		"description": "Customers are processed faster at checkouts.",
		"base_cost": 60.0,
		"cost_exponent": 1.65,
		"max_level": 10,
		"base_value": 1.0,
		"value_per_level": 0.1,
	},
	"restock_discount": {
		"name": "Restock Discount",
		"description": "Reduces the cost of restocking products.",
		"base_cost": 40.0,
		"cost_exponent": 1.55,
		"max_level": 10,
		"base_value": 0.0,
		"value_per_level": 0.05,
	},
}

var _levels: Dictionary = {}

func _ready() -> void:
	for id in UPGRADE_DEFS:
		_levels[id] = 0

func get_level(id: String) -> int:
	return _levels.get(id, 0)

func get_max_level(id: String) -> int:
	if id in UPGRADE_DEFS:
		return UPGRADE_DEFS[id]["max_level"]
	return 0

func get_upgrade_value(id: String) -> float:
	if id not in UPGRADE_DEFS:
		return 0.0
	var def: Dictionary = UPGRADE_DEFS[id]
	return def["base_value"] + def["value_per_level"] * _levels.get(id, 0)

func get_next_value(id: String) -> float:
	if id not in UPGRADE_DEFS:
		return 0.0
	var def: Dictionary = UPGRADE_DEFS[id]
	var next_level: int = min(_levels.get(id, 0) + 1, def["max_level"])
	return def["base_value"] + def["value_per_level"] * next_level

func get_upgrade_cost(id: String) -> float:
	if id not in UPGRADE_DEFS:
		return INF
	var def: Dictionary = UPGRADE_DEFS[id]
	var level: int = _levels.get(id, 0)
	if level >= def["max_level"]:
		return INF
	return def["base_cost"] * pow(def["cost_exponent"], float(level))

func purchase_upgrade(id: String) -> bool:
	if id not in UPGRADE_DEFS:
		return false
	var def: Dictionary = UPGRADE_DEFS[id]
	var level: int = _levels.get(id, 0)
	if level >= def["max_level"]:
		return false
	var cost := get_upgrade_cost(id)
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or not gm.spend_money(cost):
		return false
	_levels[id] = level + 1
	EventBus.upgrade_purchased.emit(id, _levels[id])
	return true

func is_maxed(id: String) -> bool:
	return _levels.get(id, 0) >= get_max_level(id)

func get_all_upgrade_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in UPGRADE_DEFS:
		ids.append(id)
	return ids
