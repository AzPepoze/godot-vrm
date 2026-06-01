extends "res://tests/test_base.gd"

const VRM_INSTANCE = preload("res://addons/vrm/core/vrm_instance.gd")

static var _extensions_registered = false


func test_vrm_spring_force_displacement():
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()

	# Register extensions manually
	if not _extensions_registered:
		var extensions = [
			"res://addons/vrm/importer/v1/vrmc/vrmc_node_constraint.gd",
			"res://addons/vrm/importer/v1/vrmc/vrmc_spring_bone.gd",
			"res://addons/vrm/importer/v1/vrmc/vrmc_materials_mtoon.gd",
			"res://addons/vrm/importer/v1/vrmc/vrmc_materials_hdr_emissive_multiplier.gd",
			"res://addons/vrm/importer/v1/vrmc/vrmc_vrm.gd",
			"res://addons/vrm/importer/v1/vrmc/vrmc_vrm_animation.gd",
		]
		for ext_path in extensions:
			GLTFDocument.register_gltf_document_extension(load(ext_path).new(), true)
		_extensions_registered = true

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

	var spring_bone_controller = scene_root.get_node_or_null("VRMSpringBoneController")
	assert_not_null(spring_bone_controller, "SpringBoneController node should exist")
	if spring_bone_controller == null:
		test_completed = true
		return

	var skeleton: Skeleton3D = spring_bone_controller.skel
	if skeleton == null:
		skeleton = scene_root.find_child("GeneralSkeleton", true, false)
		if skeleton:
			spring_bone_controller.skeleton = spring_bone_controller.get_path_to(skeleton)
			await runner.process_frame
			skeleton = spring_bone_controller.skel

	assert_not_null(skeleton, "Skeleton should be found")
	if skeleton == null:
		test_completed = true
		return
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL

	# Enable simulation
	spring_bone_controller.disable_body_collisions = false
	spring_bone_controller.update_in_editor = true

	# Wait for simulation to be added and initialized
	for i in range(10):
		await runner.process_frame
	var simulation = skeleton.get_node_or_null("VRMSpringBoneSimulation")
	assert_not_null(simulation, "Spring bone simulation should be attached to the skeleton")
	if simulation == null:
		test_completed = true
		return

	var bone_name = "J_Sec_Hair1_01"
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		bone_idx = skeleton.find_bone("J_Sec_Hair1_02")

	assert_gt(bone_idx, -1, "Should find a spring bone")
	if bone_idx == -1:
		test_completed = true
		return

	# Get baseline
	var initial_rot = skeleton.get_bone_global_pose(bone_idx).basis.get_rotation_quaternion()

	# Apply force
	scene_root.settings.springbone_add_force = Vector3(1000, 0, 0)  # Massive force

	# Simulate
	for i in range(30):
		simulation.step_simulation()
		await runner.process_frame

	var forced_rot = skeleton.get_bone_global_pose(bone_idx).basis.get_rotation_quaternion()
	var angle = abs((initial_rot.inverse() * forced_rot).get_angle())

	print("[PHYSICS TEST] Angle diff (rad): ", angle)
	assert_gt(angle, 0.0001, "Bone should rotate under heavy force")

	scene_root.settings.springbone_add_force = Vector3.ZERO
	for i in range(20):
		simulation.step_simulation()
		await runner.process_frame

	scene_root.free()
	test_completed = true
