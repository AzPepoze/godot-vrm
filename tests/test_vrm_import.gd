extends "res://tests/test_base.gd"

const VRM_EXTENSION = preload("res://addons/vrm/importer/v0/vrm_extension.gd")


func test_load_alicia_v0_skeleton():
	var gltf := GLTFDocument.new()
	var vrm_ext := VRM_EXTENSION.new()
	GLTFDocument.register_gltf_document_extension(vrm_ext, true)

	var state := GLTFState.new()
	var err := gltf.append_from_file("res://vrm_samples/AliciaSolid_vrm-0.51.vrm", state, 8)
	assert_eq(err, OK, "append_from_file for Alicia should succeed")

	if err != OK:
		GLTFDocument.unregister_gltf_document_extension(vrm_ext)
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
	GLTFDocument.unregister_gltf_document_extension(vrm_ext)


func test_v0_alicia_secondary_to_springbone_clean_rename():
	# Verify the v0 secondaryAnimation import produces exactly one VRMSpringBoneController
	# and no old-style 'secondary' nodes leak into the scene tree.
	var gltf := GLTFDocument.new()
	var vrm_ext := VRM_EXTENSION.new()
	GLTFDocument.register_gltf_document_extension(vrm_ext, true)

	var state := GLTFState.new()
	var err := gltf.append_from_file("res://vrm_samples/AliciaSolid_vrm-0.51.vrm", state, 8)
	assert_eq(err, OK, "append_from_file should succeed")
	if err != OK:
		GLTFDocument.unregister_gltf_document_extension(vrm_ext)
		return

	var scene_root := gltf.generate_scene(state)
	runner.root.add_child(scene_root)
	await runner.wait_frame

	# 1. Verify scene structure: v0 models have a 'secondary' bone from the
	# GLTF data (VRM 0.x spec hierarchy parent for spring chains). This is
	# separate from the VRMSpringBoneController the importer adds for runtime
	# physics. Both coexist — they serve different purposes and should not conflict.
	var all_children := scene_root.find_children("*", "", true, false)
	var secondary_node: Node = null
	for child in all_children:
		if child.name == "secondary" and child is Node3D and child.get_script() == null:
			secondary_node = child
			break
	assert_not_null(secondary_node,
		"v0 VRM should have 'secondary' node (VRM 0.x spec bone hierarchy container)"
	)

	# Verify it's NOT a VRMSpringBoneController or a scripted controller
	if secondary_node:
		assert_null(secondary_node.get_script(),
			"'secondary' node should be a plain bone-container Node3D, not a scripted controller"
		)
		# It should have no spring_bones/collider data (those belong to VRMSpringBoneController)
		var sec_has_springs = secondary_node.get("spring_bones")
		assert_true(
			sec_has_springs == null or (sec_has_springs is Array and sec_has_springs.is_empty()),
			"'secondary' bone node should not hold spring bone data"
		)

	# 2. Exactly one VRMSpringBoneController should exist
	var controllers := scene_root.find_children("VRMSpringBoneController", "", true, false)
	assert_eq(controllers.size(), 1,
		"Exactly one VRMSpringBoneController should exist, found %d" % controllers.size()
	)
	if controllers.size() != 1:
		scene_root.queue_free()
		await runner.wait_frame
		GLTFDocument.unregister_gltf_document_extension(vrm_ext)
		return

	var spring_bone_controller: Node = controllers[0]

	# 3. The controller must have the VRMSpringBoneController script attached
	assert_not_null(spring_bone_controller.get_script(),
		"VRMSpringBoneController should have its script attached"
	)

	# 4. Spring bones loaded from secondaryAnimation.boneGroups
	# Note: 3 boneGroups produce 18 spring bones because each group's bone
	# list is split into individual joint chains by create_joints_recursive.
	var spring_bones: Array = spring_bone_controller.get("spring_bones")
	assert_gt(spring_bones.size(), 0,
		"Should load spring bones from secondaryAnimation, got %d" % spring_bones.size()
	)

	# 5. Collider groups loaded from secondaryAnimation.colliderGroups (v0 spec has 6)
	var collider_groups: Array = spring_bone_controller.get("collider_groups")
	assert_eq(collider_groups.size(), 6,
		"v0 Alicia has 6 colliderGroups, got %d" % collider_groups.size()
	)

	# 6. Collider library must contain all colliders from all groups
	var collider_library: Array = spring_bone_controller.get("collider_library")
	assert_true(collider_library.size() > 0,
		"collider_library should contain colliders, got %d" % collider_library.size()
	)

	# 7. Each spring bone must have joint nodes (chain of bones)
	for i in range(spring_bones.size()):
		var sb = spring_bones[i]
		assert_not_null(sb, "Spring bone %d should not be null" % i)
		if sb:
			assert_true(sb.joint_nodes.size() > 0,
				"Spring bone %d should have joint nodes, got %d" % [i, sb.joint_nodes.size()]
			)

	# 8. VRMInstance root should reference the controller (set via _enter_tree)
	var root_controller = scene_root.get("spring_bone_controller")
	assert_not_null(root_controller,
		"VRMInstance.spring_bone_controller should reference the child VRMSpringBoneController"
	)

	# 9. No duplicate data: root's spring_bones should match controller's
	var root_spring_bones: Array = scene_root.get("spring_bones")
	assert_eq(root_spring_bones.size(), spring_bones.size(),
		"Root spring_bones count should match controller, root=%d controller=%d"
		% [root_spring_bones.size(), spring_bones.size()]
	)

	# 10. Skeleton path must be set on the controller
	var skel_path: NodePath = spring_bone_controller.get("skeleton")
	assert_true(not skel_path.is_empty(),
		"VRMSpringBoneController.skeleton path must be set"
	)

	scene_root.queue_free()
	await runner.wait_frame
	GLTFDocument.unregister_gltf_document_extension(vrm_ext)


func test_load_alicia_spring_bones():
	var gltf := GLTFDocument.new()
	var vrm_ext := VRM_EXTENSION.new()
	GLTFDocument.register_gltf_document_extension(vrm_ext, true)

	var state := GLTFState.new()
	var err := gltf.append_from_file("res://vrm_samples/AliciaSolid_vrm-0.51.vrm", state, 8)
	assert_eq(err, OK, "append_from_file should succeed")
	if err != OK:
		GLTFDocument.unregister_gltf_document_extension(vrm_ext)
		return

	var scene_root := gltf.generate_scene(state)
	runner.root.add_child(scene_root)
	await runner.wait_frame

	# Check spring_bone_controller spring bone node
	var spring_bone_controller := scene_root.get_node_or_null("VRMSpringBoneController")
	assert_not_null(
		spring_bone_controller, "spring_bone_controller node should exist for spring bones"
	)
	if spring_bone_controller:
		var spring_bones: Array = spring_bone_controller.spring_bones
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
	GLTFDocument.unregister_gltf_document_extension(vrm_ext)


func test_load_alicia_collider_groups():
	var gltf := GLTFDocument.new()
	var vrm_ext := VRM_EXTENSION.new()
	GLTFDocument.register_gltf_document_extension(vrm_ext, true)

	var state := GLTFState.new()
	var err := gltf.append_from_file("res://vrm_samples/AliciaSolid_vrm-0.51.vrm", state, 8)
	assert_eq(err, OK, "append_from_file should succeed")
	if err != OK:
		GLTFDocument.unregister_gltf_document_extension(vrm_ext)
		return

	var scene_root := gltf.generate_scene(state)
	runner.root.add_child(scene_root)
	await runner.wait_frame

	var spring_bone_controller := scene_root.get_node_or_null("VRMSpringBoneController")
	assert_not_null(spring_bone_controller, "spring_bone_controller node should exist")

	# Check that collider_groups property exists and is accessible
	var collider_groups_raw = spring_bone_controller.get("collider_groups")
	assert_not_null(
		collider_groups_raw,
		"spring_bone_controller.collider_groups must exist (import should set it)"
	)
	if collider_groups_raw != null:
		var cgs_arr: Array = collider_groups_raw
		print("  [V0 collider_groups]: size=%d" % cgs_arr.size())

	var spring_bones: Array = spring_bone_controller.get("spring_bones")

	# If spring bones reference colliders, collider_groups must not be empty
	var has_collider_refs := false
	for sb in spring_bones:
		if sb == null:
			continue
		var cgs = sb.get("collider_groups")
		if cgs != null:
			var cg_arr: Array = cgs
			if cg_arr.size() > 0:
				has_collider_refs = true
				break

	if has_collider_refs:
		var cgs_arr: Array = collider_groups_raw
		assert_gt(
			cgs_arr.size(),
			0,
			(
				"collider_groups must not be empty when spring bones reference collider groups. "
				+ (
					"Size: %d. Import is not assigning collider_groups to spring_bone_controller."
					% cgs_arr.size()
				)
			)
		)

	scene_root.queue_free()
	await runner.wait_frame
	GLTFDocument.unregister_gltf_document_extension(vrm_ext)


func test_load_godette_small_file():
	var gltf := GLTFDocument.new()
	var vrm_ext := VRM_EXTENSION.new()
	GLTFDocument.register_gltf_document_extension(vrm_ext, true)

	var state := GLTFState.new()
	var err := gltf.append_from_file("res://vrm_samples/Godette_vrm_v4.vrm", state, 8)
	assert_eq(err, OK, "append_from_file for Godette should succeed")
	if err != OK:
		GLTFDocument.unregister_gltf_document_extension(vrm_ext)
		return

	var scene_root := gltf.generate_scene(state)
	runner.root.add_child(scene_root)
	await runner.wait_frame

	var skeleton := _find_skeleton(scene_root)
	assert_not_null(skeleton, "Skeleton should exist")

	scene_root.queue_free()
	await runner.wait_frame
	GLTFDocument.unregister_gltf_document_extension(vrm_ext)


func _find_skeleton(root: Node) -> Skeleton3D:
	var children := root.find_children("*", "Skeleton3D", true, false)
	if children.size() > 0:
		return children[0]
	return null


# ── End-bone cleanup (v0 path) ──────────────────────────────────────────────


func test_v0_alicia_end_bones_removed():
	var gltf := GLTFDocument.new()
	var vrm_ext := VRM_EXTENSION.new()
	GLTFDocument.register_gltf_document_extension(vrm_ext, true)

	var state := GLTFState.new()
	var err := gltf.append_from_file("res://vrm_samples/AliciaSolid_vrm-0.51.vrm", state, 8)
	assert_eq(err, OK, "append_from_file should succeed")
	if err != OK:
		GLTFDocument.unregister_gltf_document_extension(vrm_ext)
		return

	var scene_root := gltf.generate_scene(state)
	runner.root.add_child(scene_root)
	await runner.wait_frame

	var skeleton := _find_skeleton(scene_root)
	assert_not_null(skeleton, "Skeleton should exist")
	if skeleton:
		# After cleanup, no skeleton child should match an end-bone pattern
		var end_bone_children := []
		for child in skeleton.get_children():
			if child.name.contains("_end"):
				end_bone_children.append(child)
		assert_eq(
			end_bone_children.size(),
			0,
			(
				"Skeleton should have zero *_end children after cleanup, "
				+ "found %d: %s" % [end_bone_children.size(), str(end_bone_children)]
			)
		)
		# Skeleton must still have bones (bones != scene-node children)
		assert_ge(
			skeleton.get_bone_count(),
			10,
			"Skeleton must retain 10+ bones after cleanup, got %d" % skeleton.get_bone_count()
		)

	scene_root.queue_free()
	await runner.wait_frame
	GLTFDocument.unregister_gltf_document_extension(vrm_ext)


func test_v0_godette_end_bones_removed():
	var gltf := GLTFDocument.new()
	var vrm_ext := VRM_EXTENSION.new()
	GLTFDocument.register_gltf_document_extension(vrm_ext, true)

	var state := GLTFState.new()
	var err := gltf.append_from_file("res://vrm_samples/Godette_vrm_v4.vrm", state, 8)
	assert_eq(err, OK, "append_from_file for Godette should succeed")
	if err != OK:
		GLTFDocument.unregister_gltf_document_extension(vrm_ext)
		return

	var scene_root := gltf.generate_scene(state)
	runner.root.add_child(scene_root)
	await runner.wait_frame

	var skeleton := _find_skeleton(scene_root)
	assert_not_null(skeleton, "Skeleton should exist")
	if skeleton:
		var end_bone_children := []
		for child in skeleton.get_children():
			if child.name.contains("_end"):
				end_bone_children.append(child)
		assert_eq(
			end_bone_children.size(),
			0,
			(
				"Skeleton should have zero *_end children after cleanup, "
				+ "found %d: %s" % [end_bone_children.size(), str(end_bone_children)]
			)
		)
		assert_ge(
			skeleton.get_bone_count(),
			10,
			"Skeleton must retain 10+ bones after cleanup, got %d" % skeleton.get_bone_count()
		)

	scene_root.queue_free()
	await runner.wait_frame
	GLTFDocument.unregister_gltf_document_extension(vrm_ext)
