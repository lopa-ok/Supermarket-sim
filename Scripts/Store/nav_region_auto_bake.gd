extends NavigationRegion3D

func _ready() -> void:
	await get_tree().physics_frame
	bake_navigation_mesh()
