extends Node

signal price_changed(product_id: String, new_price: float)

var products: Dictionary = {}

func _ready() -> void:
	_register_default_products()

func register_product(data: Resource) -> void:
	if data and data.has_method("get_product_id"):
		products[data.get_product_id()] = data
	elif data and "product_id" in data:
		products[data.product_id] = data

func get_product(product_id: String) -> Resource:
	return products.get(product_id, null)

func get_products_by_category(category: String) -> Array:
	var result: Array = []
	for data in products.values():
		if data.category == category:
			result.append(data)
	return result

func get_all_product_ids() -> Array:
	return products.keys()

func get_all_products() -> Array:
	return products.values()

func get_random_product_id() -> String:
	var ids := get_all_product_ids()
	if ids.is_empty():
		return ""
	return ids[randi() % ids.size()]

func set_product_price(product_id: String, new_price: float) -> void:
	var p = get_product(product_id)
	if p:
		p.current_price = maxf(0.01, new_price)
		price_changed.emit(product_id, p.current_price)

func adjust_demand(product_id: String, delta: float) -> void:
	var p = get_product(product_id)
	if p:
		p.demand_factor = clampf(p.demand_factor + delta, 0.1, 3.0)

func get_price_ratio(product_id: String) -> float:
	var p = get_product(product_id)
	if p == null:
		return 1.0
	var effective: float = p.get_effective_price()
	if p.base_price <= 0.0:
		return 1.0
	return effective / p.base_price

func _register_default_products() -> void:
	var defaults := [
		{
			"id": "bread", "name": "Bread", "category": "Bakery",
			"base_price": 1.50, "shelf_tag": "bakery",
			"mesh_path": "res://Scenes/Products/bread.tscn",
		},
		{
			"id": "milk", "name": "Milk", "category": "Dairy",
			"base_price": 2.00, "shelf_tag": "dairy",
			"mesh_path": "res://Scenes/Products/milk.tscn",
		},
		{
			"id": "crackers", "name": "Crackers", "category": "Produce",
			"base_price": 0.75, "shelf_tag": "produce",
			"mesh_path": "res://Scenes/Products/crackers.tscn",
		},
		{
			"id": "Detergent", "name": "Detergent", "category": "Hygiene",
			"base_price": 3.50, "shelf_tag": "hygiene",
			"mesh_path": "res://Scenes/Products/detergent.tscn",
		},
		{
			"id": "cereal", "name": "Cereal", "category": "Dry Goods",
			"base_price": 4.00, "shelf_tag": "dry_goods",
			"mesh_path": "res://Scenes/Products/cereal.tscn",
		},
		{
			"id": "water", "name": "Water Bottle", "category": "Beverages",
			"base_price": 1.00, "shelf_tag": "beverages",
			"mesh_path": "res://Scenes/Products/water.tscn",
		},
		{
			"id": "eggs", "name": "eggs", "category": "eggs",
			"base_price": 2.50, "shelf_tag": "eggs",
			"mesh_path": "res://Scenes/Products/eggs.tscn",
		},
		{
			"id": "soap", "name": "Soap", "category": "Hygiene",
			"base_price": 1.75, "shelf_tag": "hygiene",
			"mesh_path": "res://Scenes/Products/soap.tscn",
		},
	]
	for d in defaults:
		var product := ProductData.new()
		product.product_id = d["id"]
		product.product_name = d["name"]
		product.category = d["category"]
		product.base_price = d["base_price"]
		product.sell_price = d["base_price"] * 1.4
		product.current_price = d["base_price"] * 1.4
		product.shelf_tag = d["shelf_tag"]
		product.mesh_path = d.get("mesh_path", "")
		product.freshness = 100.0
		product.expiration_time = 300.0
		register_product(product)
