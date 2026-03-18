class_name UpgradeCard
extends PanelContainer

signal upgrade_requested(upgrade_id: String)

var _upgrade_id: String

@onready var name_label: Label = %CardName
@onready var desc_label: Label = %CardDesc
@onready var level_label: Label = %CardLevel
@onready var effect_label: Label = %CardEffect
@onready var cost_label: Label = %CardCost
@onready var buy_btn: Button = %CardBuyBtn

func setup(upgrade_id: String) -> void:
	_upgrade_id = upgrade_id

func _ready() -> void:
	buy_btn.pressed.connect(_on_buy_pressed)
	refresh()

func refresh() -> void:
	var um := _get_upgrade_manager()
	if um == null:
		return
	var def: Dictionary = um.UPGRADE_DEFS.get(_upgrade_id, {})
	if def.is_empty():
		return

	name_label.text = def.get("name", _upgrade_id)
	desc_label.text = def.get("description", "")
	var level: int = um.get_level(_upgrade_id)
	var max_level: int = um.get_max_level(_upgrade_id)
	level_label.text = "Lv %d / %d" % [level, max_level]

	var maxed: bool = um.is_maxed(_upgrade_id)
	if maxed:
		effect_label.text = "MAX"
		cost_label.text = ""
		buy_btn.text = "Maxed"
		buy_btn.disabled = true
	else:
		var next_val: float = um.get_next_value(_upgrade_id)
		effect_label.text = "Next: %.2f" % next_val
		var cost: float = um.get_upgrade_cost(_upgrade_id)
		cost_label.text = "$%.2f" % cost
		var gm = get_node_or_null("/root/GameManager")
		var can_afford: bool = gm != null and gm.money >= cost
		buy_btn.text = "Upgrade"
		buy_btn.disabled = not can_afford

func _on_buy_pressed() -> void:
	upgrade_requested.emit(_upgrade_id)

func _get_upgrade_manager() -> Node:
	return get_node_or_null("/root/UpgradeManager")
