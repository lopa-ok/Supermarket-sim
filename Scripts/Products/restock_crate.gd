class_name RestockCrate
extends Interactable

@export_group("Restock Settings")
@export var product_id: String = ""
@export var cost_per_unit: float = 0.0
@export var use_product_base_price: bool = true

var _product_data: Resource = null

func _ready() -> void:
	call_deferred("_load_product_data")

func _load_product_data() -> void:
	var db = get_node_or_null("/root/ProductDatabase")
	if db:
		_product_data = db.get_product(product_id)
		if _product_data and use_product_base_price:
			cost_per_unit = _product_data.base_price

func get_effective_cost() -> float:
	var base := cost_per_unit
	var um = get_node_or_null("/root/UpgradeManager")
	if um:
		var discount: float = um.get_upgrade_value("restock_discount")
		base *= (1.0 - clampf(discount, 0.0, 0.9))
	return snapped(base, 0.01)

func interact(player: Node) -> void:
	if player.is_holding_product():
		return

	if _product_data == null:
		_load_product_data()
	if _product_data == null:
		return

	var effective_cost := get_effective_cost()
	if effective_cost > 0:
		var gm = get_node_or_null("/root/GameManager")
		if gm and not gm.spend_money(effective_cost):
			EventBus.interaction_prompt_show.emit("Not enough money! ($%.2f)" % effective_cost)
			return

	player.pick_up_product(_product_data)

func get_prompt() -> String:
	if _product_data:
		var effective := get_effective_cost()
		var cost_text := " (Free)" if effective <= 0 else " ($%.2f)" % effective
		return "Pick up %s%s [E]" % [_product_data.product_name, cost_text]
	return "Pick up product [E]"
