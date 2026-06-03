extends "res://tests/test_base.gd"

const SpringBoneRes = preload("res://addons/vrm/runtime/vrm_spring_bone.gd")
const ColliderGroupRes = preload("res://addons/vrm/runtime/vrm_collider_group.gd")
const ColliderRes = preload("res://addons/vrm/runtime/vrm_collider.gd")


# --- TEST 1: Basic Push Detection ---
func test_env_collision_pushes_tail_out_of_box():
	if not ClassDB.class_exists("VRMSpringBoneSimulation"):
		test_completed = true
		return

	var skeleton := Skeleton3D.new()
	skeleton.name = "TestSkeleton1"
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
	spring.stiffness_scale = 0.1
	spring.gravity_scale = 0.0

	var box := StaticBody3D.new()
	box.collision_layer = 1
	runner.root.add_child(box)
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.0, 0.1, 1.0)
	var box_collision := CollisionShape3D.new()
	box_collision.shape = box_shape
	box_collision.position = Vector3(0, -0.45, 0)
	box.add_child(box_collision)

	await runner.process_frame

	var simulation := ClassDB.instantiate("VRMSpringBoneSimulation") as Node
	skeleton.add_child(simulation)
	simulation.setup([spring], [])
	simulation.set_environment_collision_enabled(true)
	simulation.active = true

	for i in range(15):
		simulation.step_simulation()
		await runner.process_frame

	var tail_pos: Vector3 = simulation.get_joint_current_tail(0, 0)
	assert_gt(tail_pos.y, -0.55, "Tail should be pushed away from box")

	runner.root.remove_child(skeleton)
	skeleton.queue_free()
	runner.root.remove_child(box)
	box.queue_free()
	test_completed = true


# --- TEST 2: Static Settling (High Gravity) ---
func test_env_collision_tail_settles_without_bounce():
	if not ClassDB.class_exists("VRMSpringBoneSimulation"):
		test_completed = true
		return

	var skeleton := Skeleton3D.new()
	runner.root.add_child(skeleton)
	skeleton.add_bone("Root")
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
	spring.stiffness_scale = 1.0
	spring.gravity_scale = 10.0

	var box := StaticBody3D.new()
	box.collision_layer = 1
	runner.root.add_child(box)
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.0, 0.1, 1.0)
	var box_collision := CollisionShape3D.new()
	box_collision.shape = box_shape
	box_collision.position = Vector3(0, -0.45, 0)
	box.add_child(box_collision)

	await runner.process_frame

	var simulation := ClassDB.instantiate("VRMSpringBoneSimulation") as Node
	skeleton.add_child(simulation)
	simulation.setup([spring], [])
	simulation.set_environment_collision_enabled(true)
	simulation.active = true

	for i in range(100):
		simulation.step_simulation()
		await runner.process_frame

	var y_positions: Array[float] = []
	var jitter_count: int = 0
	var last_dir: float = 0.0
	for i in range(100):
		simulation.step_simulation()
		await runner.process_frame
		var tail: Vector3 = simulation.get_joint_current_tail(0, 0)
		if y_positions.size() > 0:
			var diff = tail.y - y_positions[-1]
			if abs(diff) > 1e-7:
				var current_dir = sign(diff)
				if last_dir != 0.0 and current_dir != last_dir:
					jitter_count += 1
				last_dir = current_dir
		y_positions.append(tail.y)

	var y_min: float = y_positions.min()
	var y_max: float = y_positions.max()
	assert_lt(y_max - y_min, 0.0001, "Tail should be stable")
	assert_lt(jitter_count, 5, "Tail is jittering!")

	runner.root.remove_child(skeleton)
	skeleton.queue_free()
	runner.root.remove_child(box)
	box.queue_free()
	test_completed = true


# --- TEST 3: Chaos Stress Test (Long Chain & Angle) ---
func test_env_collision_chaos_stress_test():
	if not ClassDB.class_exists("VRMSpringBoneSimulation"):
		test_completed = true
		return

	var skeleton := Skeleton3D.new()
	runner.root.add_child(skeleton)
	var bone_names = ["B0", "B1", "B2", "B3", "B4", "B5"]
	for i in range(bone_names.size()):
		skeleton.add_bone(bone_names[i])
		if i > 0:
			skeleton.set_bone_parent(i, i - 1)
			skeleton.set_bone_rest(i, Transform3D(Basis(), Vector3(0, -0.2, 0)))
	skeleton.rotation_degrees.x = 45

	var spring := SpringBoneRes.new()
	spring.joint_nodes = PackedStringArray(bone_names)
	spring.enable_environment_collision = true
	spring.environment_collision_mask = 1
	spring.stiffness_scale = 1.0
	spring.gravity_scale = 5.0

	var floor_obj := StaticBody3D.new()
	floor_obj.collision_layer = 1
	runner.root.add_child(floor_obj)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 0.1, 10)
	col.shape = shape
	col.position = Vector3(0, -0.3, 0)
	floor_obj.add_child(col)

	await runner.process_frame

	var simulation := ClassDB.instantiate("VRMSpringBoneSimulation") as Node
	skeleton.add_child(simulation)
	simulation.setup([spring], [])
	simulation.set_environment_collision_enabled(true)
	simulation.active = true

	for i in range(100):
		simulation.step_simulation()
		await runner.process_frame

	var positions: Array[Vector3] = []
	for i in range(50):
		simulation.step_simulation()
		await runner.process_frame
		positions.append(simulation.get_joint_current_tail(0, 4))

	var movement: float = 0.0
	for i in range(1, positions.size()):
		movement += (positions[i] - positions[i - 1]).length()
	assert_lt(movement, 8.0, "Chaos Test Failed: High movement detected")

	runner.root.remove_child(skeleton)
	skeleton.queue_free()
	runner.root.remove_child(floor_obj)
	floor_obj.queue_free()
	test_completed = true


# --- TEST 4: Moving Platform Response ---
func test_env_collision_moving_platform_jitter():
	if not ClassDB.class_exists("VRMSpringBoneSimulation"):
		test_completed = true
		return

	var skeleton := Skeleton3D.new()
	runner.root.add_child(skeleton)
	skeleton.add_bone("B0")
	skeleton.add_bone("B1")
	skeleton.set_bone_rest(1, Transform3D(Basis(), Vector3(0, -0.5, 0)))
	skeleton.set_bone_parent(1, 0)
	skeleton.add_bone("B2")
	skeleton.set_bone_rest(2, Transform3D(Basis(), Vector3(0, -0.2, 0)))
	skeleton.set_bone_parent(2, 1)

	var spring := SpringBoneRes.new()
	spring.joint_nodes = PackedStringArray(["B0", "B1", "B2"])
	spring.enable_environment_collision = true
	spring.environment_collision_mask = 1
	spring.stiffness_scale = 1.0
	spring.gravity_scale = 1.0

	var floor_obj := AnimatableBody3D.new()
	floor_obj.collision_layer = 1
	runner.root.add_child(floor_obj)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 0.1, 2)
	col.shape = shape
	col.position = Vector3(0, -0.6, 0)
	floor_obj.add_child(col)

	await runner.process_frame

	var simulation := ClassDB.instantiate("VRMSpringBoneSimulation") as Node
	skeleton.add_child(simulation)
	simulation.setup([spring], [])
	simulation.set_environment_collision_enabled(true)
	simulation.active = true

	for i in range(50):
		simulation.step_simulation()
		await runner.process_frame

	var max_v: float = 0.0
	var last_p = simulation.get_joint_current_tail(0, 0)
	for i in range(20):
		floor_obj.position.y += 0.01
		simulation.step_simulation()
		await runner.process_frame
		var p = simulation.get_joint_current_tail(0, 0)
		max_v = max(max_v, (p - last_p).length())
		last_p = p

	assert_lt(max_v, 0.05, "Moving Platform Failed: Excessive velocity gain")

	runner.root.remove_child(skeleton)
	skeleton.queue_free()
	runner.root.remove_child(floor_obj)
	floor_obj.queue_free()
	test_completed = true


# --- TEST 5: Energy Divergence (Explosion Check) ---
func test_env_collision_energy_divergence():
	if not ClassDB.class_exists("VRMSpringBoneSimulation"):
		test_completed = true
		return

	var skeleton := Skeleton3D.new()
	runner.root.add_child(skeleton)
	var bone_names = ["B0", "B1", "B2", "B3", "B4", "B5"]
	for i in range(bone_names.size()):
		skeleton.add_bone(bone_names[i])
		if i > 0:
			skeleton.set_bone_parent(i, i - 1)
			skeleton.set_bone_rest(i, Transform3D(Basis(), Vector3(0, -0.2, 0)))
	skeleton.rotation_degrees.x = 45

	var spring := SpringBoneRes.new()
	spring.joint_nodes = PackedStringArray(bone_names)
	spring.enable_environment_collision = true
	spring.environment_collision_mask = 1
	spring.stiffness_scale = 1.0
	spring.gravity_scale = 10.0

	var floor_obj := StaticBody3D.new()
	floor_obj.collision_layer = 1
	runner.root.add_child(floor_obj)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 0.1, 10)
	col.shape = shape
	col.position = Vector3(0, -0.5, 0)
	floor_obj.add_child(col)

	await runner.process_frame

	var simulation := ClassDB.instantiate("VRMSpringBoneSimulation") as Node
	skeleton.add_child(simulation)
	simulation.setup([spring], [])
	simulation.set_environment_collision_enabled(true)
	simulation.active = true

	var energy_log: Array[float] = []
	for i in range(200):
		simulation.step_simulation()
		await runner.process_frame
		var energy = 0.0
		for j in range(5):
			var v = simulation.get_joint_current_tail(0, j) - simulation.get_joint_prev_tail(0, j)
			energy += v.length_squared()
		energy_log.append(energy)

	var e_start = 0.0
	for i in range(50, 70):
		e_start += energy_log[i]
	e_start /= 20.0

	var e_end = 0.0
	for i in range(180, 200):
		e_end += energy_log[i]
	e_end /= 20.0

	assert_lt(e_end, e_start * 3.0, "Energy Divergence detected!")
	assert_lt(e_end, 0.15, "System failed to settle")

	runner.root.remove_child(skeleton)
	skeleton.queue_free()
	runner.root.remove_child(floor_obj)
	floor_obj.queue_free()
	test_completed = true
