extends "res://tests/test_base.gd"

const VRM_TOPLEVEL = preload("res://addons/vrm/core/vrm_toplevel.gd")
const VRM_SECONDARY = preload("res://addons/vrm/runtime/vrm_secondary.gd")
const VRM_LOADER = preload("res://addons/vrm/import_vrm.gd")


func test_vrm_spring_force_displacement():
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()

	# Register extensions manually (avoid VRM_LOADER which is Editor-only)
	var extensions = [
		preload("res://addons/vrm/importer/v1/vrmc/vrmc_node_constraint.gd").new(),
		preload("res://addons/vrm/importer/v1/vrmc/vrmc_spring_bone.gd").new(),
		preload("res://addons/vrm/importer/v1/vrmc/vrmc_materials_mtoon.gd").new(),
		(
			preload("res://addons/vrm/importer/v1/vrmc/vrmc_materials_hdr_emissive_multiplier.gd")
			. new()
		),
		preload("res://addons/vrm/importer/v1/vrmc/vrmc_vrm.gd").new(),
		preload("res://addons/vrm/importer/v1/vrmc/vrmc_vrm_animation.gd").new(),
	]
	for ext in extensions:
		GLTFDocument.register_gltf_document_extension(ext, true)

	# Pre-seed state to avoid Dictionary::operator[] bug in 4.6
	const VRMConstants = preload("res://addons/vrm/core/vrm_constants.gd")
	state.set_additional_data(
		&"vrm/head_hiding_method", VRMConstants.HeadHidingSetting.ThirdPersonOnly
	)
	state.set_additional_data(&"vrm/first_person_layers", 2)
	state.set_additional_data(&"vrm/third_person_layers", 4)
	state.set_additional_data(&"vrm/remove_end_bones", true)

	# Load a real VRM 1.0 file to get a valid skeleton and spring setup
	var err = gltf.append_from_file("res://vrm_samples/AvatarSample_M.vrm", state, 8)
	assert_eq(err, OK, "Should load VRM 1.0 sample")

	var scene_root = gltf.generate_scene(state)
	runner.root.add_child(scene_root)

	# Wait for _enter_tree and _ready
	await runner.wait_frame
	await runner.wait_frame

	var secondary = scene_root.get_node_or_null("secondary")
	assert_not_null(secondary, "Secondary node should exist")
	if secondary == null:
		print("DEBUG: secondary node not found in scene_root. children: ", scene_root.get_children())
		return

	# Enable simulation in editor
	secondary.update_in_editor = true
	await runner.wait_frame
	await runner.wait_frame

	var skeleton: Skeleton3D = secondary.skel
	if skeleton == null:
		skeleton = scene_root.find_child("GeneralSkeleton", true, false)
		if skeleton:
			secondary.skel = skeleton

	assert_not_null(skeleton, "Skeleton should be found")
	if skeleton == null:
		return

	# Pick a hair bone to monitor (usually has spring physics)
	var bone_name = "J_Sec_Hair1_01"  # Based on AvatarSample_M structure
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		# Fallback if name is different
		bone_idx = skeleton.find_bone("J_Sec_Hair1_02")

	assert_gt(bone_idx, -1, "Should find a spring bone")
	if bone_idx == -1:
		return

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
