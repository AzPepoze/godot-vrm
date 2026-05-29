extends "res://tests/test_base.gd"


func test_springbone_api_methods():
	var methods = ClassDB.class_get_method_list("SpringBoneSimulator3D")
	var names = []
	for m in methods:
		names.append(m["name"])
	assert_true(names.has("set_setting_count"), "API should contain set_setting_count")
	assert_true(names.has("get_setting_count"), "API should contain get_setting_count")
	assert_true(names.has("set_root_bone_name"), "API should contain set_root_bone_name")
	assert_true(names.has("set_end_bone_name"), "API should contain set_end_bone_name")
