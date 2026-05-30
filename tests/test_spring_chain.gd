extends "res://tests/test_base.gd"

const vrm_spring_bone_parser = preload("res://addons/vrm/importer/common/vrm_spring_bone_parser.gd")


func test_spring_bone_resource():
	var sb := VRMSpringBone.new()
	assert_not_null(sb, "VRMSpringBone should be creatable")
	assert_true(sb.joint_nodes is PackedStringArray, "joint_nodes should be PackedStringArray")
	assert_eq(sb.stiffness_scale, 1.0, "Default stiffness_scale should be 1.0")
	assert_eq(sb.drag_force_scale, 1.0, "Default drag_force_scale should be 1.0")
	assert_eq(sb.hit_radius_scale, 1.0, "Default hit_radius_scale should be 1.0")
	assert_eq(sb.gravity_scale, 1.0, "Default gravity_scale should be 1.0")
	assert_eq(sb.gravity_dir_default, Vector3(0, -1, 0), "Default gravity_dir should be (0,-1,0)")


func test_spring_bone_joint_nodes():
	var sb := VRMSpringBone.new()
	sb.joint_nodes = PackedStringArray(["Hips", "Spine", "Chest", ""])
	assert_eq(sb.joint_nodes.size(), 4, "joint_nodes should have 4 entries")
	assert_eq(sb.joint_nodes[0], "Hips", "First joint should be Hips")


func test_collider_resource():
	var c := VRMCollider.new()
	assert_not_null(c, "VRMCollider should be creatable")
	assert_eq(c.radius, 0.0, "Default radius should be 0.0")
	assert_eq(c.offset, Vector3.ZERO, "Default offset should be zero")
	assert_eq(c.is_capsule, false, "Default is_capsule should be false")
	assert_eq(c.gizmo_color, Color.MAGENTA, "Default gizmo_color should be MAGENTA")


func test_collider_group_resource():
	var cg := VRMColliderGroup.new()
	assert_not_null(cg, "VRMColliderGroup should be creatable")
	assert_true(cg.colliders.is_empty(), "New collider group should have empty colliders")

	var c := VRMCollider.new()
	cg.colliders.append(c)
	assert_eq(cg.colliders.size(), 1, "Collider group should have 1 collider after append")


func test_spring_bone_service_chain_building():
	# Create a simple skeleton with a bone chain
	var skel := Skeleton3D.new()
	skel.add_bone("Root")
	skel.add_bone("Child")
	skel.set_bone_parent(1, 0)
	skel.add_bone("Grandchild")
	skel.set_bone_parent(2, 1)

	var chains: Array[PackedStringArray] = []
	vrm_spring_bone_parser.create_joints_recursive(chains, skel, 0, -1)

	assert_true(chains.size() > 0, "Should create at least one chain")
	# Root -> Child -> Grandchild chain, terminated by ""
	assert_eq(chains[0].size(), 4, "Chain should have 4 entries (Root, Child, Grandchild, '')")
	assert_eq(chains[0][0], "Root", "First entry should be Root")
	assert_eq(chains[0][1], "Child", "Second entry should be Child")
	assert_eq(chains[0][2], "Grandchild", "Third entry should be Grandchild")
	assert_eq(chains[0][3], "", "Last entry should be empty terminator")
