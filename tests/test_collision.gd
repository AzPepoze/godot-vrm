extends "res://tests/test_base.gd"


func test_collision_setup():
    var skel = Skeleton3D.new()
    skel.add_bone("Root")
    skel.add_bone("Tip")
    skel.set_bone_parent(1, 0)
    skel.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, -1.0, 0)))
    skel.reset_bone_poses()

    var sim = SpringBoneSimulator3D.new()
    sim.active = true
    skel.add_child(sim)

    var col = SpringBoneCollisionSphere3D.new()
    col.name = "Collider"
    col.bone_name = "Tip"
    col.radius = 0.5
    col.position_offset = Vector3(0, 0, 0)
    sim.add_child(col)

    sim.set_setting_count(1)
    sim.set_root_bone_name(0, "Root")
    sim.set_end_bone_name(0, "Tip")
    sim.set_extend_end_bone(0, true)
    sim.set_end_bone_length(0, 0.2)
    sim.set_radius(0, 0.1)

    sim.set("settings/0/enable_all_child_collisions", true)

    runner.root.add_child(skel)
    sim.reset()

    await runner.process_frame

    var pose_origin = skel.get_bone_global_pose(1).origin
    assert_eq(pose_origin, Vector3(0, -1.0, 0), "Bone pose should be at rest pose initially")

    skel.queue_free()
    test_completed = true
