class_name UpgradeMenu
extends Control

@onready var card_container: VBoxContainer = %CardContainer
@onready var close_btn: Button = %CloseBtn
@onready var title_label: Label = %MenuTitle

var _cards: Dictionary = {}
var _card_scene: PackedScene

func _ready() -> void:
	visible = false
	_card_scene = preload("res://Scenes/UI/upgrade_card.tscn")
	close_btn.pressed.connect(hide_menu)
	EventBus.money_changed.connect(_on_money_changed)
	_build_cards()

func show_menu() -> void:
	_refresh_all()
	visible = true
	close_btn.grab_focus()

func hide_menu() -> void:
	visible = false

func _build_cards() -> void:
	var um = get_node_or_null("/root/UpgradeManager")
	if um == null:
		return
	for id in um.get_all_upgrade_ids():
		var card: UpgradeCard = _card_scene.instantiate()
		card.setup(id)
		card.upgrade_requested.connect(_on_upgrade_requested)
		card_container.add_child(card)
		_cards[id] = card

func _on_upgrade_requested(upgrade_id: String) -> void:
	var um = get_node_or_null("/root/UpgradeManager")
	if um == null:
		return
	um.purchase_upgrade(upgrade_id)
	var card: UpgradeCard = _cards.get(upgrade_id)
	if card:
		card.refresh()
	_refresh_affordability()

func _on_money_changed(_amount: float) -> void:
	if visible:
		_refresh_affordability()

func _refresh_all() -> void:
	for card: UpgradeCard in _cards.values():
		card.refresh()

func _refresh_affordability() -> void:
	for card: UpgradeCard in _cards.values():
		card.refresh()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide_menu()
		get_viewport().set_input_as_handled()
