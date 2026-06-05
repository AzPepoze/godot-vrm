extends "res://tests/test_base.gd"


func test_spring_bone_simulation_exists():
    assert_true(ClassDB.class_exists("SpringBoneSimulator3D"), "SpringBoneSimulator3D should exist")
    assert_true(
        ClassDB.class_exists("VRMSpringBoneSimulation"), "VRMSpringBoneSimulation should exist"
    )
    test_completed = true
