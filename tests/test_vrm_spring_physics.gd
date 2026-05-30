extends "res://tests/test_base.gd"

const VRM_TOPLEVEL = preload("res://addons/vrm/core/vrm_toplevel.gd")
const VRM_SECONDARY = preload("res://addons/vrm/runtime/vrm_secondary.gd")
const VRM_LOADER = preload("res://addons/vrm/import_vrm.gd")


func test_vrm_spring_force_displacement():
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var vrm_ext := VRM_LOADER.new()

	# Load a real VRM 1.0 file to get a valid skeleton and spring setup
	var err = gltf.append_from_file("res://vrm_samples/AvatarSample_M.vrm", state)
	assert_eq(err, OK, "Should load VRM 1.0 sample")

	var scene_root = gltf.generate_scene(state)
	runner.root.add_child(scene_root)

	# Wait for _enter_tree and _ready
	await runner.wait_frame
	await runner.wait_frame

	var secondary = scene_root.get_node_or_null("secondary")
	assert_not_null(secondary, "Secondary node should exist")

	# Enable simulation in editor
	scene_root.update_in_editor = true
	await runner.wait_frame

	var skeleton: Skeleton3D = secondary.skel
	assert_not_null(skeleton, "Skeleton should be found")

	# Pick a hair bone to monitor (usually has spring physics)
	var bone_name = "Hair_1"  # Based on AvatarSample_M structure
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		# Fallback if name is different
		bone_idx = skeleton.find_bone("J_Sec_Hair1")

	assert_gt(bone_idx, -1, "Should find a spring bone")

	# Get baseline rotation
	var initial_rot = skeleton.get_bone_pose_rotation(bone_idx)

	# Apply a MASSIVE lateral force
	scene_root.springbone_add_force = Vector3(100, 0, 0)

	# Simulate a few frames
	for i in range(10):
		await runner.wait_frame

	var forced_rot = skeleton.get_bone_pose_rotation(bone_idx)

	# Compare
	var diff = initial_rot.inverse() * forced_rot
	var angle = abs(diff.get_angle())

	print("[PHYSICS TEST] Initial rot: ", initial_rot)
	print("[PHYSICS TEST] Forced rot: ", forced_rot)
	print("[PHYSICS TEST] Angle diff (rad): ", angle)

	assert_gt(angle, 0.01, "Bone should rotate significantly under heavy external force")

	# Clear force and check return
	scene_root.springbone_add_force = Vector3.ZERO
	for i in range(20):
		await runner.wait_frame

	var returned_rot = skeleton.get_bone_pose_rotation(bone_idx)
	var return_diff = initial_rot.inverse() * returned_rot
	var return_angle = abs(return_diff.get_angle())

	print("[PHYSICS TEST] Return angle diff (rad): ", return_angle)
	assert_lt(return_angle, angle, "Bone should start returning to rest pose when force is removed")

	scene_root.free()
