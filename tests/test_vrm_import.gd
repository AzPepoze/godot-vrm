extends "res://tests/test_base.gd"

const VRM_EXTENSION = preload("res://addons/vrm/importer/v0/vrm_extension.gd")


func test_load_alicia_v0_skeleton():
	var gltf := GLTFDocument.new()
	var vrm_ext := VRM_EXTENSION.new()
	gltf.register_gltf_document_extension(vrm_ext, true)

	var state := GLTFState.new()
	var err := gltf.append_from_file("res://vrm_samples/AliciaSolid_vrm-0.51.vrm", state, 8)
	assert_eq(err, OK, "append_from_file for Alicia should succeed")

	if err != OK:
		gltf.unregister_gltf_document_extension(vrm_ext)
		return

	var scene_root := gltf.generate_scene(state)
	runner.root.add_child(scene_root)
	await runner.wait_frame

	# Check skeleton exists with expected bones
	var skeleton := _find_skeleton(scene_root)
	assert_not_null(skeleton, "Skeleton should exist")
	if skeleton:
		assert_true(skeleton.find_bone("Hips") >= 0, "Hips bone should exist")
		assert_true(skeleton.find_bone("Head") >= 0, "Head bone should exist")
		assert_true(
			skeleton.get_bone_count() > 10,
			"Should have many bones, got %d" % skeleton.get_bone_count()
		)

	# Check meshes
	var mesh_instances := scene_root.find_children("*", "MeshInstance3D")
	assert_true(mesh_instances.size() > 0, "Should have at least one MeshInstance3D")

	# Check VRM meta
	var vrm_meta = scene_root.get("vrm_meta")
	assert_not_null(vrm_meta, "vrm_meta should be set on root")
	if vrm_meta:
		assert_true(vrm_meta.title.length() > 0, "VRM should have a title")
		assert_true(vrm_meta.authors.size() > 0, "VRM should have authors")

	# Check animation player
	var anim_player := scene_root.get_node_or_null("AnimationPlayer")
	assert_not_null(anim_player, "AnimationPlayer should exist")
	if anim_player:
		var anim_list: PackedStringArray = anim_player.get_animation_list()
		assert_true(anim_list.size() > 0, "Should have at least one animation")

	scene_root.queue_free()
	await runner.wait_frame
	gltf.unregister_gltf_document_extension(vrm_ext)


func test_load_alicia_spring_bones():
	var gltf := GLTFDocument.new()
	var vrm_ext := VRM_EXTENSION.new()
	gltf.register_gltf_document_extension(vrm_ext, true)

	var state := GLTFState.new()
	var err := gltf.append_from_file("res://vrm_samples/AliciaSolid_vrm-0.51.vrm", state, 8)
	assert_eq(err, OK, "append_from_file should succeed")
	if err != OK:
		gltf.unregister_gltf_document_extension(vrm_ext)
		return

	var scene_root := gltf.generate_scene(state)
	runner.root.add_child(scene_root)
	await runner.wait_frame

	# Check secondary spring bone node
	var secondary := scene_root.get_node_or_null("secondary")
	assert_not_null(secondary, "secondary node should exist for spring bones")
	if secondary:
		var spring_bones: Array = secondary.spring_bones
		assert_true(
			spring_bones.size() > 0, "Should have spring bones, got %d" % spring_bones.size()
		)

		if spring_bones.size() > 0:
			var sb = spring_bones[0]
			assert_not_null(sb, "First spring bone should not be null")
			if sb:
				# Check joint chain has bones
				assert_true(sb.joint_nodes.size() > 0, "Spring bone should have joint nodes")
				# Check parameters have reasonable defaults
				assert_true(sb.stiffness_scale >= 0.0, "Stiffness should be >= 0")
				assert_true(sb.gravity_scale >= -10.0, "Gravity scale should be in range")

	scene_root.queue_free()
	await runner.wait_frame
	gltf.unregister_gltf_document_extension(vrm_ext)


func test_load_godette_small_file():
	var gltf := GLTFDocument.new()
	var vrm_ext := VRM_EXTENSION.new()
	gltf.register_gltf_document_extension(vrm_ext, true)

	var state := GLTFState.new()
	var err := gltf.append_from_file("res://vrm_samples/Godette_vrm_v4.vrm", state, 8)
	assert_eq(err, OK, "append_from_file for Godette should succeed")
	if err != OK:
		gltf.unregister_gltf_document_extension(vrm_ext)
		return

	var scene_root := gltf.generate_scene(state)
	runner.root.add_child(scene_root)
	await runner.wait_frame

	var skeleton := _find_skeleton(scene_root)
	assert_not_null(skeleton, "Skeleton should exist")

	scene_root.queue_free()
	await runner.wait_frame
	gltf.unregister_gltf_document_extension(vrm_ext)


func _find_skeleton(root: Node) -> Skeleton3D:
	var children := root.find_children("*", "Skeleton3D", true, false)
	if children.size() > 0:
		return children[0]
	return null
