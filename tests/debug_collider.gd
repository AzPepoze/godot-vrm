extends MainLoop

var frames = 0


func _initialize():
	# Load the AvatarSample_M VRM scene
	var scene = load("res://vrm_samples/AvatarSample_M.vrm")
	if scene == null:
		print("ERROR: Could not load AvatarSample_M.vrm")
		return

	var instance = scene.instantiate()
	# We need a 3D world to process skeleton modifiers
	var viewport = SubViewport.new()
	viewport.world_3d = World3D.new()
	viewport.add_child(instance)
	# MainLoop doesn't have a tree root, but we can manually process
	print("Instance loaded: ", instance.name)


func _process(delta: float) -> bool:
	frames += 1
	if frames > 10:
		return true  # quit
	return false
