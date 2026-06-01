extends "res://tests/test_base.gd"


func test_classes_exist():
	assert_true(ClassDB.class_exists("SpringBoneSimulator3D"), "SpringBoneSimulator3D should exist")
	assert_true(
		ClassDB.class_exists("SpringBoneCollisionSphere3D"),
		"SpringBoneCollisionSphere3D should exist"
	)
	assert_true(
		ClassDB.class_exists("SpringBoneCollisionCapsule3D"),
		"SpringBoneCollisionCapsule3D should exist"
	)
	test_completed = true
