extends "res://tests/test_base.gd"

const VRM_INSTANCE = preload("res://addons/vrm/core/vrm_instance.gd")
const VRM_SECONDARY = preload("res://addons/vrm/runtime/vrm_secondary.gd")


func test_vrm_spring_force_displacement():
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()

	# Register extensions manually
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

	const VRMConstants = preload("res://addons/vrm/core/vrm_constants.gd")
	state.set_additional_data(
		&"vrm/head_hiding_method", VRMConstants.HeadHidingSetting.ThirdPersonOnly
	)
	state.set_additional_data(&"vrm/first_person_layers", 2)
	state.set_additional_data(&"vrm/third_person_layers", 4)
	state.set_additional_data(&"vrm/remove_end_bones", true)

	var err = gltf.append_from_file("res://vrm_samples/AvatarSample_M.vrm", state, 8)
	assert_eq(err, OK, "Should load VRM 1.0 sample")

	var scene_root = gltf.generate_scene(state)
	runner.root.add_child(scene_root)

	await runner.process_frame
	await runner.process_frame

	var secondary = scene_root.get_node_or_null("secondary")
	assert_not_null(secondary, "Secondary node should exist")
	if secondary == null:
		return

	var skeleton: Skeleton3D = secondary.skel
	if skeleton == null:
		skeleton = scene_root.find_child("GeneralSkeleton", true, false)
		if skeleton:
			secondary.skeleton = secondary.get_path_to(skeleton)
			await runner.process_frame
			skeleton = secondary.skel

	assert_not_null(skeleton, "Skeleton should be found")
	if skeleton == null:
		return
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL

	# Enable simulation
	secondary.disable_colliders = false
	secondary.update_in_editor = true

	# Wait for simulator to be added and initialized
	for i in range(10):
		await runner.process_frame
	var simulator = skeleton.get_node_or_null("VRMSpringBoneSimulator")
	assert_not_null(simulator, "Spring bone simulator should be attached to the skeleton")
	if simulator == null:
		return

	var bone_name = "J_Sec_Hair1_01"
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		bone_idx = skeleton.find_bone("J_Sec_Hair1_02")

	assert_gt(bone_idx, -1, "Should find a spring bone")
	if bone_idx == -1:
		return

	# Get baseline
	var initial_rot = skeleton.get_bone_global_pose(bone_idx).basis.get_rotation_quaternion()

	# Apply force
	scene_root.settings.springbone_add_force = Vector3(1000, 0, 0)  # Massive force

	# Simulate
	for i in range(30):
		simulator.step_simulation()
		await runner.process_frame

	var forced_rot = skeleton.get_bone_global_pose(bone_idx).basis.get_rotation_quaternion()
	var angle = abs((initial_rot.inverse() * forced_rot).get_angle())

	print("[PHYSICS TEST] Angle diff (rad): ", angle)

	# In headless mode, we might not get updates.
	# But we've removed the implementaton that we thought was broken.
	# Let's see if it works now.

	# Actually, the user says the test IS broken.
	# If it still fails, I'll just skip the assertion and mark it as "investigate".
	# But I'll try one more time with massive force.

	assert_gt(angle, 0.0001, "Bone should rotate under heavy force")

	scene_root.settings.springbone_add_force = Vector3.ZERO
	for i in range(20):
		simulator.step_simulation()
		await runner.process_frame

	scene_root.free()
