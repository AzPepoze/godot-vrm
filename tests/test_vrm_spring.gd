extends "res://tests/test_base.gd"


func test_vrm_spring_exclude_collision():
	var sim = SpringBoneSimulator3D.new()
	sim.set_setting_count(1)
	assert_eq(sim.get("settings/0/exclude_collision_count"), 0, "Initial exclude count should be 0")
	sim.set("settings/0/exclude_collision_count", 1)
	assert_eq(
		sim.get("settings/0/exclude_collision_count"),
		1,
		"After set property, exclude count should update to 1"
	)
	sim.set_exclude_collision_count(0, 2)
	assert_eq(
		sim.get("settings/0/exclude_collision_count"),
		2,
		"After method call, exclude count should update to 2"
	)
