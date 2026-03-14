extends SceneTree

var _done := false

func _initialize():
	pass

func _process(_delta):
	if _done:
		return
	_done = true
	var scenes = [
		"res://Scenes/Products/bread.tscn",
		"res://Scenes/Products/milk.tscn",
		"res://Scenes/Products/apple.tscn",
		"res://Scenes/Products/cheese.tscn",
		"res://Scenes/Products/cereal.tscn",
		"res://Scenes/Products/water.tscn",
		"res://Scenes/Products/chips.tscn",
		"res://Scenes/Products/soap.tscn",
	]
	for p in scenes:
		var scene = load(p) as PackedScene
		if scene == null:
			print("FAIL load: %s" % p)
			continue
		var inst = scene.instantiate()
		if inst == null:
			print("FAIL instantiate: %s" % p)
			continue
		var mesh_found := false
		for child in inst.get_children():
			if child is MeshInstance3D:
				mesh_found = true
				var has_mat = child.material_override != null
				print("OK: %s -> mesh=%s mat_override=%s" % [p, child.name, has_mat])
		if not mesh_found:
			print("WARN no mesh child: %s" % p)
		inst.queue_free()
	quit()
