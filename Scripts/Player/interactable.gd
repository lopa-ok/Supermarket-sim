class_name Interactable
extends Node3D

@export var prompt_text: String = "Interact"

@export var is_interactable: bool = true

func interact(_player: Node) -> void:
	pass

func get_prompt() -> String:
	return prompt_text
