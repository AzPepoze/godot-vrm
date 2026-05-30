extends "res://tests/test_base.gd"

const SpringBoneRes = preload("res://addons/vrm/runtime/vrm_spring_bone.gd")
const ColliderGroupRes = preload("res://addons/vrm/runtime/vrm_collider_group.gd")
const ColliderRes = preload("res://addons/vrm/runtime/vrm_collider.gd")


func test_env_collision_pushes_tail_out_of_box():
	if not ClassDB.class_exists("VRMSpringBoneSimulation"):
		print("[SKIP] VRMSpringBoneSimulation not found")
		return

	# Create a skeleton with a simple 2-bone chain
	var skeleton := Skeleton3D.new()
	skeleton.name = "TestSkeleton"
	runner.root.add_child(skeleton)

	# Root bone at origin
	skeleton.add_bone("Root")
	skeleton.set_bone_rest(0, Transform3D(Basis(), Vector3(0, 0, 0)))

	# Child bone 0.5 units below root (Y-down like most VRM bones)
	skeleton.add_bone("Child")
	skeleton.set_bone_rest(1, Transform3D(Basis(), Vector3(0, -0.5, 0)))
	skeleton.set_bone_parent(1, 0)

	# Need a second child for the joint chain (required by parse_spring_bones)
	skeleton.add_bone("Grandchild")
	skeleton.set_bone_rest(2, Transform3D(Basis(), Vector3(0, -0.2, 0)))
	skeleton.set_bone_parent(2, 1)

	# Create spring bone resource for the child bone chain
	var spring := SpringBoneRes.new()
	spring.joint_nodes = PackedStringArray(["Child", "Grandchild"])
	spring.enable_environment_collision = true
	spring.environment_collision_mask = 1
	spring.stiffness_scale = 0.1  # Light stiffness to prevent strong pull-back
	spring.gravity_scale = 0.0  # No gravity

	# Place a StaticBody3D box at the child tail's expected position.
	# The child bone (0.5 long, bone_axis = -Y) has tail at (0, -0.5, 0).
	# Place box at (0, -0.4, 0) so the tail overlaps with it.
	var box := StaticBody3D.new()
	box.name = "TestBox"
	box.collision_layer = 1
	runner.root.add_child(box)

	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.0, 0.1, 1.0)
	var box_collision := CollisionShape3D.new()
	box_collision.shape = box_shape
	box_collision.position = Vector3(0, -0.45, 0)  # Just below the tail
	box.add_child(box_collision)

	await runner.process_frame
	await runner.process_frame

	# Create simulation
	var simulation := ClassDB.instantiate("VRMSpringBoneSimulation") as Node
	simulation.name = "VRMSpringBoneSimulationTest"
	skeleton.add_child(simulation)

	var empty_groups: Array = []
	simulation.setup([spring], empty_groups)
	simulation.set_environment_collision_enabled(true)
	simulation.set_environment_collision_mask(1)
	simulation.active = true

	# Run simulation — the box should push the tail away
	for i in range(15):
		simulation.step_simulation()
		await runner.process_frame

	# The child bone tail should have been pushed away from the box.
	# The tail is in center-local space (identity center = world space here).
	# Box bottom is at y = -0.45, box top at y = -0.35 (size 0.1).
	# Tail should be pushed ABOVE the box (y > -0.35) or at least not
	# deep inside it (y > -0.5).
	var tail_pos: Vector3 = simulation.get_joint_current_tail(0, 0)
	print("[ENV COLLISION TEST] Tail Y position: ", tail_pos.y)

	assert_gt(
		tail_pos.y,
		-0.55,
		"Tail should be pushed away from box, got y=%f (expected > -0.55)" % tail_pos.y
	)

	# Cleanup
	runner.root.remove_child(skeleton)
	skeleton.queue_free()
	runner.root.remove_child(box)
	box.queue_free()


func test_env_collision_tail_settles_without_bounce():
	if not ClassDB.class_exists("VRMSpringBoneSimulation"):
		print("[SKIP] VRMSpringBoneSimulation not found")
		return

	# Same skeleton setup as above
	var skeleton := Skeleton3D.new()
	skeleton.name = "TestSkeleton2"
	runner.root.add_child(skeleton)

	skeleton.add_bone("Root")
	skeleton.set_bone_rest(0, Transform3D(Basis(), Vector3(0, 0, 0)))
	skeleton.add_bone("Child")
	skeleton.set_bone_rest(1, Transform3D(Basis(), Vector3(0, -0.5, 0)))
	skeleton.set_bone_parent(1, 0)
	skeleton.add_bone("Grandchild")
	skeleton.set_bone_rest(2, Transform3D(Basis(), Vector3(0, -0.2, 0)))
	skeleton.set_bone_parent(2, 1)

	var spring := SpringBoneRes.new()
	spring.joint_nodes = PackedStringArray(["Child", "Grandchild"])
	spring.enable_environment_collision = true
	spring.environment_collision_mask = 1
	spring.stiffness_scale = 1.0  # Full stiffness — real test of bounce suppression
	spring.gravity_scale = 0.0

	# Box overlapping with tail rest position
	var box := StaticBody3D.new()
	box.name = "TestBox2"
	box.collision_layer = 1
	runner.root.add_child(box)

	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.0, 0.1, 1.0)
	var box_collision := CollisionShape3D.new()
	box_collision.shape = box_shape
	box_collision.position = Vector3(0, -0.45, 0)
	box.add_child(box_collision)

	await runner.process_frame
	await runner.process_frame

	var simulation := ClassDB.instantiate("VRMSpringBoneSimulation") as Node
	simulation.name = "VRMSpringBoneSimulationTest2"
	skeleton.add_child(simulation)

	simulation.setup([spring], [])
	simulation.set_environment_collision_enabled(true)
	simulation.set_environment_collision_mask(1)
	simulation.active = true

	# Run many steps to let the system settle
	for i in range(50):
		simulation.step_simulation()
		await runner.process_frame

	# Now track tail Y over the next 30 frames to check for bounce/oscillation
	var y_positions: Array[float] = []
	for i in range(30):
		simulation.step_simulation()
		await runner.process_frame
		var tail: Vector3 = simulation.get_joint_current_tail(0, 0)
		y_positions.append(tail.y)

	# Compute variance: if bouncing, max-min will be large
	var y_min: float = y_positions[0]
	var y_max: float = y_positions[0]
	for y in y_positions:
		y_min = min(y_min, y)
		y_max = max(y_max, y)
	var y_range := y_max - y_min

	print("[BOUNCE TEST] Tail Y range over 30 settled frames: ", y_range)
	print("[BOUNCE TEST]   min=%f max=%f" % [y_min, y_max])

	# With bounce suppression, the tail should stay within 0.02 units.
	# Without it, stiffness yanks the tail into the box each frame and
	# collision pushes it out, causing oscillation of 0.05+ units.
	assert_lt(
		y_range, 0.03, "Tail should settle without bounce, range=%f (expected < 0.03)" % y_range
	)

	# Cleanup
	runner.root.remove_child(skeleton)
	skeleton.queue_free()
	runner.root.remove_child(box)
	box.queue_free()
