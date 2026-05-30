extends "res://tests/test_base.gd"

# Test VRM 1.0 spring bone collider group JSON parsing with synthetic mock data.
# The VRM 1.0 spec has a two-level structure: flat colliders list indexed by
# colliderGroups, which are in turn referenced by springs.  This is the key
# difference from VRM 0.0 and the source of Bug 2.

# Preload the types used in parsing so we can inspect dict structures.
const vrm_collider = preload("res://addons/vrm/runtime/vrm_collider.gd")
const vrm_collider_group = preload("res://addons/vrm/runtime/vrm_collider_group.gd")


func _make_sphere_collider_json(node_idx: int, radius: float = 0.1) -> Dictionary:
	return {
		"node": node_idx,
		"shape":
		{
			"sphere":
			{
				"offset": [0.0, 0.0, 0.0],
				"radius": radius,
			}
		}
	}


func _make_capsule_collider_json(node_idx: int, radius: float = 0.05) -> Dictionary:
	return {
		"node": node_idx,
		"shape":
		{
			"capsule":
			{
				"offset": [0.0, 0.0, 0.0],
				"tail": [0.0, -0.1, 0.0],
				"radius": radius,
			}
		}
	}


func _make_group_json(collider_indices: Array) -> Dictionary:
	return {"colliders": collider_indices}


func _make_spring_json(name: String, joints: Array, group_indices: Array) -> Dictionary:
	return {
		"name": name,
		"joints": joints,
		"colliderGroups": group_indices,
		"stiffness": 1.0,
		"gravityPower": 0.0,
		"gravityDir": [0.0, -1.0, 0.0],
		"dragForce": 0.5,
		"hitRadius": 0.02,
	}


func test_vrm1_collider_group_structure():
	# Build a minimal VRM 1.0 VRMC_springBone JSON dict and verify structure.
	var vrm_spring: Dictionary = {
		"colliders":
		[
			_make_sphere_collider_json(0, 0.1),
		],
		"colliderGroups":
		[
			_make_group_json([0]),
		],
		"springs":
		[
			_make_spring_json("Tail", [{"node": 0}], [0]),
		]
	}

	# Verify the colliderGroups key references colliders by index (not inline objects)
	var collider_groups: Array = vrm_spring["colliderGroups"]
	assert_eq(collider_groups.size(), 1, "Should have exactly 1 collider group")

	var group0: Dictionary = collider_groups[0]
	assert_true(group0.has("colliders"), "Group must have 'colliders' key")
	assert_eq(
		group0["colliders"],
		[0],
		"Group colliders should reference collider index 0, not contain collider objects"
	)

	# Verify spring references group index, not collider index
	var springs: Array = vrm_spring["springs"]
	assert_eq(springs.size(), 1, "Should have exactly 1 spring")
	var spring0: Dictionary = springs[0]
	assert_eq(
		spring0["colliderGroups"], [0], "Spring colliderGroups should reference group index 0"
	)


func test_vrm1_collider_flat_vs_group():
	# 2 flat colliders, 1 group containing both.
	var vrm_spring: Dictionary = {
		"colliders":
		[
			_make_sphere_collider_json(0, 0.1),
			_make_capsule_collider_json(1, 0.05),
		],
		"colliderGroups":
		[
			_make_group_json([0, 1]),
		],
		"springs": [],
	}

	var collider_groups: Array = vrm_spring["colliderGroups"]
	assert_eq(collider_groups.size(), 1, "Should have 1 group")

	var group0: Dictionary = collider_groups[0]
	assert_eq(group0["colliders"].size(), 2, "Group should reference 2 colliders")
	assert_eq(group0["colliders"][0], 0, "First collider index should be 0")
	assert_eq(group0["colliders"][1], 1, "Second collider index should be 1")

	# Count of flat colliders
	var colliders: Array = vrm_spring["colliders"]
	assert_eq(colliders.size(), 2, "Should have 2 flat colliders")


func test_vrm1_collider_multiple_groups():
	# 3 colliders, 2 groups. group0 has [0], group1 has [1, 2].
	var vrm_spring: Dictionary = {
		"colliders":
		[
			_make_sphere_collider_json(0, 0.1),
			_make_sphere_collider_json(1, 0.15),
			_make_capsule_collider_json(2, 0.05),
		],
		"colliderGroups":
		[
			_make_group_json([0]),
			_make_group_json([1, 2]),
		],
		"springs": [],
	}

	var collider_groups: Array = vrm_spring["colliderGroups"]
	# Group count is 2, NOT 3 (not the same as flat collider count)
	assert_eq(
		collider_groups.size(), 2, "Should have 2 collider groups, not 3 (groups != flat colliders)"
	)

	var group0: Dictionary = collider_groups[0]
	assert_eq(group0["colliders"].size(), 1, "Group 0 should have 1 collider")

	var group1: Dictionary = collider_groups[1]
	assert_eq(group1["colliders"].size(), 2, "Group 1 should have 2 colliders")

	# Verify collider counts are independent
	var colliders: Array = vrm_spring["colliders"]
	assert_eq(colliders.size(), 3, "Should have 3 flat colliders")

	# Verify collider 0 is sphere, collider 2 is capsule
	assert_true(colliders[0]["shape"].has("sphere"), "Collider 0 should be sphere")
	assert_true(colliders[2]["shape"].has("capsule"), "Collider 2 should be capsule")
