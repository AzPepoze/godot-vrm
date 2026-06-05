extends "res://tests/test_base.gd"


func test_spring_methods():
    var skel = Skeleton3D.new()
    skel.add_bone("BoneA")
    skel.add_bone("BoneB")
    skel.set_bone_parent(1, 0)
    skel.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)))

    var sim = SpringBoneSimulator3D.new()
    skel.add_child(sim)
    runner.root.add_child(skel)

    # Case 1: Root=BoneA, End=BoneB, extend=false
    sim.set_setting_count(1)
    sim.set_root_bone_name(0, "BoneA")
    sim.set_end_bone_name(0, "BoneB")
    sim.set_extend_end_bone(0, false)
    sim.reset()
    await runner.process_frame

    assert_eq(sim.get_joint_count(0), 2, "Case 1: Joint count should be 2")
    assert_eq(sim.get_joint_bone_name(0, 0), "BoneA", "Case 1: Joint 0 should be BoneA")
    assert_eq(sim.get_joint_bone_name(0, 1), "BoneB", "Case 1: Joint 1 should be BoneB")

    # Case 2: Root=BoneA, End=BoneB, extend=true
    sim.set_extend_end_bone(0, true)
    sim.set_end_bone_length(0, 0.2)
    sim.reset()
    await runner.process_frame

    # assert_eq(sim.get_joint_count(0), 3, "Case 2: Joint count should be 3")
    # assert_eq(sim.get_joint_bone_name(0, 0), "BoneA", "Case 2: Joint 0 should be BoneA")
    # assert_eq(sim.get_joint_bone_name(0, 1), "BoneB", "Case 2: Joint 1 should be BoneB")
    # assert_eq(sim.get_joint_bone_name(0, 2), "", "Case 2: Joint 2 should be virtual extension")

    # Case 3: Root=BoneA, End=BoneA, extend=true
    sim.set_end_bone_name(0, "BoneA")
    sim.set_extend_end_bone(0, true)
    sim.set_end_bone_length(0, 0.5)
    sim.reset()
    await runner.process_frame

    # assert_eq(sim.get_joint_count(0), 2, "Case 3: Joint count should be 2")
    # assert_eq(sim.get_joint_bone_name(0, 0), "BoneA", "Case 3: Joint 0 should be BoneA")
    # assert_eq(sim.get_joint_bone_name(0, 1), "", "Case 3: Joint 1 should be virtual extension")

    skel.queue_free()
    test_completed = true
