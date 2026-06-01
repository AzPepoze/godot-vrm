extends "res://tests/test_base.gd"

const VRM_SPRING_BONE = preload("res://addons/vrm/runtime/vrm_spring_bone.gd")
const VRM_COLLIDER_GROUP = preload("res://addons/vrm/runtime/vrm_collider_group.gd")
const VRM_COLLIDER = preload("res://addons/vrm/runtime/vrm_collider.gd")


func _run_collision_case(skeleton_origin: Vector3) -> float:
	if not ClassDB.class_exists("VRMSpringBoneSimulation"):
		print("[SKIP] VRMSpringBoneSimulation not found")
		return 0.0

	var skel = Skeleton3D.new()
	skel.name = "Skeleton"
	skel.position = skeleton_origin
	skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	skel.add_bone("Root")
	skel.add_bone("Joint")
	skel.set_bone_parent(1, 0)
	skel.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0)))
	skel.reset_bone_poses()

	runner.root.add_child(skel)

	var simulation = ClassDB.instantiate("VRMSpringBoneSimulation")
	simulation.name = "VRMSpringBoneSimulation"
	skel.add_child(simulation)

	var collider = VRM_COLLIDER.new()
	collider.bone = "Root"
	collider.offset = Vector3(0.1, -0.15, 0)
	collider.radius = 0.2

	var group = VRM_COLLIDER_GROUP.new()
	group.colliders.append(collider)

	var sb = VRM_SPRING_BONE.new()
	sb.joint_nodes = ["Joint", ""]
	sb.collider_groups.append(group)
	sb.stiffness_scale = 1.0
	sb.hit_radius_scale = 1.0

	simulation.setup([sb], [group])
	simulation.active = true

	for i in range(10):
		simulation.step_simulation()
		await runner.process_frame

	var joint_rot = skel.get_bone_global_pose(1).basis.get_rotation_quaternion()
	var angle = joint_rot.get_angle()
	skel.queue_free()
	return angle


func test_vrm_spring_collision_interaction():
	var angle := await _run_collision_case(Vector3.ZERO)
	print("[COLLISION TEST] origin angle: ", angle)
	assert_gt(angle, 0.1, "Bone should rotate significantly due to collision")


func test_vrm_spring_collision_with_translated_skeleton():
	var angle := await _run_collision_case(Vector3(3.0, 1.0, -2.0))
	print("[COLLISION TEST] translated skeleton angle: ", angle)
	assert_gt(
		angle,
		0.1,
		"Bone collider collision should work when the skeleton is not at the world origin"
	)
	test_completed = true
