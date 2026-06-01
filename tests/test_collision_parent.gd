extends "res://tests/test_base.gd"


func test_collision_parents():
	assert_eq(ClassDB.get_parent_class("SpringBoneCollisionSphere3D"), "SpringBoneCollision3D")
	assert_eq(ClassDB.get_parent_class("SpringBoneCollisionCapsule3D"), "SpringBoneCollision3D")
	test_completed = true
