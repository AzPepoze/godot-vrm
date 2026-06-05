extends "res://tests/test_base.gd"


func test_collision_props():
    var s = SpringBoneCollisionSphere3D.new()
    var props = []
    for p in s.get_property_list():
        props.append(p.name)
    assert_true(props.has("radius"), "Sphere should have radius")
    assert_true(props.has("bone_name"), "Sphere should have bone_name")
    assert_true(props.has("position_offset"), "Sphere should have position_offset")

    var c = SpringBoneCollisionCapsule3D.new()
    props.clear()
    for p in c.get_property_list():
        props.append(p.name)
    assert_true(props.has("radius"), "Capsule should have radius")
    assert_true(props.has("height"), "Capsule should have height")
    assert_true(props.has("bone_name"), "Capsule should have bone_name")
    assert_true(props.has("position_offset"), "Capsule should have position_offset")
    test_completed = true
