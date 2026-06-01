extends "res://tests/test_base.gd"


func test_springbone_joints():
	var skel = Skeleton3D.new()
	skel.name = "Skeleton3D"
	skel.add_bone("Root")
	skel.add_bone("Joint1")
	skel.set_bone_parent(1, 0)
	skel.add_bone("Joint2")
	skel.set_bone_parent(2, 1)
	skel.add_bone("End")
	skel.set_bone_parent(3, 2)

	var sim = SpringBoneSimulator3D.new()
	skel.add_child(sim)

	sim.set_setting_count(1)
	sim.set_root_bone_name(0, "Root")
	sim.set_end_bone_name(0, "End")

	runner.root.add_child(skel)

	assert_eq(sim.get_joint_count(0), 4, "Immediate joint count should be 4")

	sim.reset()

	assert_eq(sim.get_joint_count(0), 4, "Post-reset joint count should be 4")

	await runner.process_frame

	assert_eq(sim.get_joint_count(0), 4, "After process_frame joint count should be 4")
	assert_eq(sim.get_joint_bone_name(0, 0), "Root", "Joint 0 is Root")
	assert_eq(sim.get_joint_bone_name(0, 1), "Joint1", "Joint 1 is Joint1")
	assert_eq(sim.get_joint_bone_name(0, 2), "Joint2", "Joint 2 is Joint2")
	assert_eq(sim.get_joint_bone_name(0, 3), "End", "Joint 3 is End")

	skel.queue_free()
	test_completed = true
