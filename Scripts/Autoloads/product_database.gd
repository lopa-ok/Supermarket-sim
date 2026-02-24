extends Node

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

func get_random_product_id() -> String:
	var ids := get_all_product_ids()
	if ids.is_empty():
		return ""
	return ids[randi() % ids.size()]

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
			"id": "apple", "name": "Apple", "category": "Produce",
			"base_price": 0.75, "shelf_tag": "produce",
			"mesh_path": "res://Scenes/Products/apple.tscn",
		},
		{
			"id": "cheese", "name": "Cheese", "category": "Dairy",
			"base_price": 3.50, "shelf_tag": "dairy",
			"mesh_path": "res://Scenes/Products/cheese.tscn",
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
			"id": "chips", "name": "Chips", "category": "Snacks",
			"base_price": 2.50, "shelf_tag": "snacks",
			"mesh_path": "res://Scenes/Products/chips.tscn",
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
		product.shelf_tag = d["shelf_tag"]
		product.mesh_path = d.get("mesh_path", "")
		register_product(product)
