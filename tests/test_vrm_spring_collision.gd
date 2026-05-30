extends "res://tests/test_base.gd"

const VRM_SPRING_BONE = preload("res://addons/vrm/runtime/vrm_spring_bone.gd")
const VRM_COLLIDER_GROUP = preload("res://addons/vrm/runtime/vrm_collider_group.gd")
const VRM_COLLIDER = preload("res://addons/vrm/runtime/vrm_collider.gd")

func test_vrm_spring_collision_interaction():
	if not ClassDB.class_exists("VRMSpringBoneSimulator"):
		print("[SKIP] VRMSpringBoneSimulator not found")
		return

	# 1. Setup Skeleton
	var skel = Skeleton3D.new()
	skel.name = "Skeleton"
	skel.add_bone("Root")
	skel.add_bone("Joint")
	skel.set_bone_parent(1, 0)
	# Joint must have a non-zero rest offset so the simulator can guess a tail direction
	skel.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0)))
	skel.reset_bone_poses()
	
	runner.root.add_child(skel)

	# 2. Setup Simulator
	var simulator = ClassDB.instantiate("VRMSpringBoneSimulator")
	simulator.name = "VRMSpringBoneSimulator"
	skel.add_child(simulator)

	# 3. Setup Collider
	var collider = VRM_COLLIDER.new()
	collider.bone = "Root"
	# Offset slightly on X so it pushes the bone sideways instead of straight down
	collider.offset = Vector3(0.1, -0.15, 0)
	collider.radius = 0.2
	
	var group = VRM_COLLIDER_GROUP.new()
	group.colliders.append(collider)

	# 4. Setup Spring Bone
	var sb = VRM_SPRING_BONE.new()
	sb.joint_nodes = ["Joint", ""] # Chain starting at Joint, with empty end node
	sb.collider_groups.append(group)
	sb.stiffness_scale = 1.0
	sb.hit_radius_scale = 1.0
	
	# 5. Initialize Simulator
	simulator.setup([sb], [group])
	simulator.active = true

	# Wait for simulation to run
	# Collider is at (0, -0.1, 0) with radius 0.2.
	# Joint origin is (0, 0, 0). Default end bone pos is (0, -0.07, 0).
	# They definitely overlap.
	
	for i in range(20):
		await runner.process_frame

	var joint_rot = skel.get_bone_global_pose(1).basis.get_rotation_quaternion()
	var angle = joint_rot.get_angle()
	print("[COLLISION TEST] Joint global rotation: ", joint_rot, " Angle: ", angle)
	
	assert_gt(angle, 0.1, "Bone should rotate significantly due to collision")

	skel.queue_free()
