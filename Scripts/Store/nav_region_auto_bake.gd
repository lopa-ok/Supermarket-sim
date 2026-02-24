extends NavigationRegion3D
## Automatically bakes the navigation mesh on first ready.
## Needed when the scene was authored as text without pre-baked polygon data.

func _ready() -> void:
	# Wait one frame so all child geometry is fully added to the tree.
	await get_tree().physics_frame
	bake_navigation_mesh()
