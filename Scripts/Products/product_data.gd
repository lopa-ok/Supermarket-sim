class_name ProductData
extends Resource

@export var product_id: String = ""
@export var product_name: String = ""
@export var category: String = ""
@export var shelf_tag: String = ""
@export var base_price: float = 1.0
@export var sell_price: float = 1.5
@export var current_price: float = 0.0
@export var demand_factor: float = 1.0
@export var weight: float = 1.0
@export var description: String = ""
@export var icon: Texture2D = null
@export var mesh_scene: PackedScene = null
@export var mesh_path: String = ""
@export var freshness: float = 100.0
@export var expiration_time: float = 300.0
@export var freshness_decay_rate: float = 0.15
@export var product_scene: PackedScene = null

func get_product_id() -> String:
	return product_id

func get_effective_price() -> float:
	if current_price > 0.0:
		return current_price
	return sell_price

func get_profit() -> float:
	return sell_price - base_price

func get_profit_margin() -> float:
	var effective := get_effective_price()
	if base_price <= 0.0:
		return 0.0
	return (effective - base_price) / base_price

func get_mesh_scene() -> PackedScene:
	if product_scene:
		return product_scene
	if mesh_scene:
		return mesh_scene
	if not mesh_path.is_empty() and ResourceLoader.exists(mesh_path):
		var loaded = load(mesh_path)
		if loaded is PackedScene:
			return loaded as PackedScene
	return null
