extends "res://tests/test_base.gd"


func test_constraint_classes():
	var classes = ClassDB.get_class_list()
	assert_true(
		classes.has("VRMConstraintSimulator"),
		"VRMConstraintSimulator GDExtension class should be compiled and registered"
	)
	test_completed = true
