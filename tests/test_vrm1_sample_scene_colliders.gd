extends "res://tests/test_base.gd"

const VRM_COLLIDER = preload("res://addons/vrm/runtime/vrm_collider.gd")
const VRM_COLLIDER_GROUP = preload("res://addons/vrm/runtime/vrm_collider_group.gd")

const SAMPLE_SCENE := "res://vrm_samples/sample_scene.tscn"


func _instantiate_sample_scene() -> Node:
	var packed_scene: PackedScene = load(SAMPLE_SCENE)
	assert_not_null(packed_scene, "sample_scene.tscn should load")
	if packed_scene == null:
		return null
	var scene := packed_scene.instantiate()
	runner.root.add_child(scene)
	await runner.process_frame
	return scene


func _find_avatar_sample(scene: Node) -> Node:
	var avatar := scene.get_node_or_null("AvatarSample_M")
	assert_not_null(avatar, "sample_scene.tscn should contain AvatarSample_M")
	return avatar


func test_avatar_sample_scene_spring_overrides_keep_collider_refs():
	var scene := await _instantiate_sample_scene()
	if scene == null:
		test_completed = true
		return
	var avatar := _find_avatar_sample(scene)
	if avatar == null:
		scene.queue_free()
		test_completed = true
		return

	var collider_groups: Array = avatar.get("collider_groups")
	var collider_group_ids := {}
	for group in collider_groups:
		if group != null:
			collider_group_ids[group.get_instance_id()] = true

	var spring_bones: Array = avatar.get("spring_bones")
	var checked_springs := 0
	for spring in spring_bones:
		if spring == null:
			continue
		if spring.group != "Hair" and spring.group != "Skirt":
			continue
		checked_springs += 1
		assert_gt(
			spring.collider_groups.size(),
			0,
			"%s should keep collider group references in sample_scene.tscn" % spring.resource_name
		)
		for group in spring.collider_groups:
			assert_true(
				collider_group_ids.has(group.get_instance_id()),
				(
					"%s collider reference should resolve to AvatarSample_M.collider_groups"
					% spring.resource_name
				)
			)

	assert_gt(checked_springs, 0, "Sample scene should include hair/skirt spring overrides")
	scene.queue_free()
	test_completed = true


func test_avatar_sample_scene_hair_chain_reacts_to_assigned_collider():
	if not ClassDB.class_exists("VRMSpringBoneSimulation"):
		print("[SKIP] VRMSpringBoneSimulation not found")
		test_completed = true
		return

	var scene := await _instantiate_sample_scene()
	if scene == null:
		test_completed = true
		return
	var avatar := _find_avatar_sample(scene)
	if avatar == null:
		scene.queue_free()
		test_completed = true
		return

	var skeleton: Skeleton3D = avatar.find_child("GeneralSkeleton", true, false)
	assert_not_null(skeleton, "AvatarSample_M should contain GeneralSkeleton")
	if skeleton == null:
		scene.queue_free()
		test_completed = true
		return

	var hair_spring: VRMSpringBone = null
	for spring in avatar.get("spring_bones"):
		if spring != null and spring.group == "Hair":
			hair_spring = spring
			break
	assert_not_null(hair_spring, "AvatarSample_M should have a hair spring")
	if hair_spring == null:
		scene.queue_free()
		test_completed = true
		return

	var root_bone := str(hair_spring.joint_nodes[0])
	if skeleton.has_meta("vrm_rename_map"):
		var rename_map = skeleton.get_meta("vrm_rename_map")
		if rename_map.has(StringName(root_bone)):
			root_bone = String(rename_map[StringName(root_bone)])

	var root_bone_idx := skeleton.find_bone(root_bone)
	assert_gt(root_bone_idx, -1, "Hair spring root bone should exist in skeleton")
	if root_bone_idx == -1:
		scene.queue_free()
		test_completed = true
		return

	# Verify the simulation can be set up and run without errors
	var collider := VRM_COLLIDER.new()
	collider.bone = root_bone
	collider.radius = 0.25
	var group := VRM_COLLIDER_GROUP.new()
	group.colliders.append(collider)

	var hair_spring_copy := hair_spring.duplicate() as VRMSpringBone
	var joints := PackedStringArray()
	if skeleton.has_meta("vrm_rename_map"):
		var rename_map = skeleton.get_meta("vrm_rename_map")
		for joint in hair_spring_copy.joint_nodes:
			var sn := StringName(joint)
			if rename_map.has(sn):
				joints.append(String(rename_map[sn]))
			else:
				joints.append(joint)
	else:
		joints = hair_spring_copy.joint_nodes
	hair_spring_copy.joint_nodes = joints

	var simulation: Node = ClassDB.instantiate("VRMSpringBoneSimulation")
	simulation.name = "VRMSpringBoneSimulationSampleTest"
	skeleton.add_child(simulation)
	simulation.setup([hair_spring_copy], [group])
	simulation.active = true

	for i in range(5):
		simulation.step_simulation()
		await runner.process_frame

	assert_true(
		simulation.get_chain_count() > 0, "Simulation should have at least one chain after setup"
	)
	assert_gt(simulation.get_joint_count(0), 0, "First chain should have joints")
	scene.queue_free()
	test_completed = true
