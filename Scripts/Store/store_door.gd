class_name StoreDoor
extends Interactable

func interact(_player: Node) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	if gm.store_is_open:
		gm.close_store()
	else:
		gm.open_store()

func get_prompt() -> String:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.store_is_open:
		return "Close Store [E]"
	return "Open Store [E]"
