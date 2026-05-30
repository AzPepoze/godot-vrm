extends "res://tests/test_base.gd"

const VRM_TOPLEVEL = preload("res://addons/vrm/core/vrm_toplevel.gd")
const VRM_SECONDARY = preload("res://addons/vrm/runtime/vrm_secondary.gd")


func test_vrm_spring_force_displacement():
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()

	# Register extensions manually (avoid VRM_LOADER which is Editor-only)
	var extensions = [
		preload("res://addons/vrm/importer/v1/vrmc/vrmc_node_constraint.gd").new(),
		preload("res://addons/vrm/importer/v1/vrmc/vrmc_spring_bone.gd").new(),
		preload("res://addons/vrm/importer/v1/vrmc/vrmc_materials_mtoon.gd").new(),
		preload("res://addons/vrm/importer/v1/vrmc/vrmc_materials_hdr_emissive_multiplier.gd")
		.new(),
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
		return

	# Set skeleton property to trigger setup
	var skeleton: Skeleton3D = secondary.skel
	if skeleton == null:
		skeleton = scene_root.find_child("GeneralSkeleton", true, false)
		if skeleton:
			secondary.skeleton = secondary.get_path_to(skeleton)
			await runner.wait_frame
			# Re-fetch after property setter triggers _ready
			skeleton = secondary.skel

	assert_not_null(skeleton, "Skeleton should be found")
	if skeleton == null:
		return

	# Enable simulation in editor
	secondary.update_in_editor = true
	await runner.wait_frame
	await runner.wait_frame
	await runner.wait_frame

	var sim = skeleton.get_node_or_null("VRMSpringBoneSimulator")
	if sim == null:
		# Try finding it specifically if it's internal
		for child in skeleton.get_children(true):
			if child.name == "VRMSpringBoneSimulator":
				sim = child
				break

	assert_not_null(sim, "Simulator should be added to skeleton")
	if sim == null:
		print("DEBUG: skeleton children (inc internal): ", skeleton.get_children(true))
		return
	
	assert_true(sim.active, "Simulator should be active")

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
	secondary.springbone_add_force = Vector3(100, 0, 0)

	# Simulate a few frames
	for i in range(20):
		await runner.wait_frame

	var forced_rot = skeleton.get_bone_pose_rotation(bone_idx)

	# Compare
	var diff = initial_rot.inverse() * forced_rot
	var angle = abs(diff.get_angle())

	print("[PHYSICS TEST] Initial rot: ", initial_rot)
	print("[PHYSICS TEST] Forced rot: ", forced_rot)
	print("[PHYSICS TEST] Angle diff (rad): ", angle)

	# If still 0.0, maybe the simulator is not ticking in headless mode
	# Let's try to force update skeleton
	if angle == 0.0:
		print("DEBUG: Angle is still 0.0. Trying force_update_all_bone_transforms()")
		skeleton.force_update_all_bone_transforms()
		forced_rot = skeleton.get_bone_pose_rotation(bone_idx)
		angle = abs((initial_rot.inverse() * forced_rot).get_angle())
		print("[PHYSICS TEST] Forced rot after force_update: ", forced_rot)
		print("[PHYSICS TEST] Angle diff after force_update (rad): ", angle)

	assert_gt(angle, 0.001, "Bone should rotate under heavy external force")

	# Clear force and check return
	secondary.springbone_add_force = Vector3.ZERO
	for i in range(30):
		await runner.wait_frame

	var returned_rot = skeleton.get_bone_pose_rotation(bone_idx)
	var return_diff = initial_rot.inverse() * returned_rot
	var return_angle = abs(return_diff.get_angle())

	print("[PHYSICS TEST] Return angle diff (rad): ", return_angle)
	assert_lt(return_angle, angle + 0.0001, "Bone should start returning to rest pose or at least not move further away")

	scene_root.free()
