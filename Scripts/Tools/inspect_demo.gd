extends Node3D

func _ready() -> void:
	var demo_scene: PackedScene = load("res://Resources/Models/_Demo.glb")
	if demo_scene == null:
		print("FAILED to load _Demo.glb")
		return
	var demo: Node3D = demo_scene.instantiate()
	add_child(demo)
	print("=== ROOT: %s type=%s ===" % [demo.name, demo.get_class()])
	print("Root transform: ", demo.transform)
	for top_child in demo.get_children():
		print("  TOP: %s type=%s" % [top_child.name, top_child.get_class()])
		if top_child.name == "_Demo_Props":
			var shelf_count := 0
			var floor_count := 0
			var wall_count := 0
			var checkout_count := 0
			var aabb_min := Vector3(INF, INF, INF)
			var aabb_max := Vector3(-INF, -INF, -INF)
			for mesh_child in top_child.get_children():
				var n: String = mesh_child.name
				var pos: Vector3 = mesh_child.position if mesh_child is Node3D else Vector3.ZERO
				aabb_min.x = min(aabb_min.x, pos.x)
				aabb_min.y = min(aabb_min.y, pos.y)
				aabb_min.z = min(aabb_min.z, pos.z)
				aabb_max.x = max(aabb_max.x, pos.x)
				aabb_max.y = max(aabb_max.y, pos.y)
				aabb_max.z = max(aabb_max.z, pos.z)
				if "Shelf_Isle" in n or "Shelf_Preset" in n:
					shelf_count += 1
					print("    SHELF: %s pos=%s" % [n, pos])
				elif "Floor" in n:
					floor_count += 1
				elif "Wall" in n:
					wall_count += 1
				elif "Checkout" in n or "SelfCheckout" in n:
					checkout_count += 1
					print("    CHECKOUT: %s pos=%s" % [n, pos])
				elif "Door" in n:
					print("    DOOR: %s pos=%s" % [n, pos])
				elif "Escalator" in n:
					print("    ESCALATOR: %s pos=%s" % [n, pos])
				elif "SecurityScanner" in n:
					print("    SCANNER: %s pos=%s" % [n, pos])
				elif "Sign" in n:
					print("    SIGN: %s pos=%s" % [n, pos])
				elif "Trolley" in n or "Basket" in n:
					print("    CART: %s pos=%s" % [n, pos])
			print("  Total children: %d" % top_child.get_child_count())
			print("  Shelves: %d, Floors: %d, Walls: %d, Checkouts: %d" % [shelf_count, floor_count, wall_count, checkout_count])
			print("  AABB min: %s" % aabb_min)
			print("  AABB max: %s" % aabb_max)
			print("  AABB size: %s" % (aabb_max - aabb_min))
			print("--- FIRST 30 floor tiles ---")
			var fc := 0
			for mesh_child in top_child.get_children():
				if "Floor" in str(mesh_child.name):
					print("    FLOOR: %s pos=%s" % [mesh_child.name, mesh_child.position])
					fc += 1
					if fc >= 30:
						break
			print("--- FIRST 20 wall pieces ---")
			var wc := 0
			for mesh_child in top_child.get_children():
				if "Wall" in str(mesh_child.name):
					print("    WALL: %s pos=%s" % [mesh_child.name, mesh_child.position])
					wc += 1
					if wc >= 20:
						break
		elif top_child.name == "_Scene_Settings":
			for sc in top_child.get_children():
				print("    SETTINGS: %s type=%s" % [sc.name, sc.get_class()])
				if sc is Camera3D:
					print("      cam pos=%s" % sc.position)
				elif sc is DirectionalLight3D:
					print("      dir light pos=%s" % sc.position)
	demo.queue_free()
	print("=== INSPECTION DONE ===")
	get_tree().quit()
