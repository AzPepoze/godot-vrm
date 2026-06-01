extends "res://tests/test_base.gd"

# Test VRM 1.0 meta parsing via vrm_resource_factory.create_meta_v1.
# Uses synthetic dictionaries to verify correctness and graceful defaults.

const vrm_resource_factory = preload("res://addons/vrm/importer/common/vrm_resource_factory.gd")


func _make_bone_map() -> BoneMap:
	var bm := BoneMap.new()
	bm.profile = SkeletonProfileHumanoid.new()
	return bm


func _fresh_state() -> GLTFState:
	return GLTFState.new()


func _make_base_vrm_extension() -> Dictionary:
	return {
		"specVersion": "1.0",
		"meta":
		{
			"name": "TestAvatar",
			"version": "1.0",
			"authors": ["Author1"],
			"contactInformation": "test@example.com",
			"references": ["https://example.com"],
		}
	}


func test_create_meta_v1_title():
	var vrm_ext := _make_base_vrm_extension()
	var meta = vrm_resource_factory.create_meta_v1(vrm_ext, _fresh_state(), _make_bone_map())
	assert_not_null(meta, "Meta resource should not be null")
	assert_eq(meta.title, "TestAvatar", "Title should match input")
	test_completed = true


func test_create_meta_v1_authors():
	var vrm_ext := _make_base_vrm_extension()
	var meta = vrm_resource_factory.create_meta_v1(vrm_ext, _fresh_state(), _make_bone_map())
	assert_eq(meta.authors.size(), 1, "Should have 1 author")
	assert_eq(meta.authors[0], "Author1", "Author name should match input")
	test_completed = true


func test_create_meta_v1_spec_version():
	var vrm_ext := _make_base_vrm_extension()
	var meta = vrm_resource_factory.create_meta_v1(vrm_ext, _fresh_state(), _make_bone_map())
	assert_eq(meta.spec_version, "1.0", "Spec version should be 1.0")
	test_completed = true


func test_create_meta_v1_avatar_permission_map():
	var state := _fresh_state()
	var bm := _make_bone_map()

	# onlyAuthor → OnlyAuthor
	var vrm_ext := _make_base_vrm_extension()
	vrm_ext["meta"]["avatarPermission"] = "onlyAuthor"
	var meta = vrm_resource_factory.create_meta_v1(vrm_ext, state, bm)
	assert_eq(meta.allowed_user_name, "OnlyAuthor", "onlyAuthor should map to OnlyAuthor")

	# everyone → Everyone
	vrm_ext["meta"]["avatarPermission"] = "everyone"
	meta = vrm_resource_factory.create_meta_v1(vrm_ext, state, bm)
	assert_eq(meta.allowed_user_name, "Everyone", "everyone should map to Everyone")

	# unknown → empty
	vrm_ext["meta"]["avatarPermission"] = "unknownValue"
	meta = vrm_resource_factory.create_meta_v1(vrm_ext, state, bm)
	assert_eq(meta.allowed_user_name, "", "Unknown value should map to empty string")
	test_completed = true


func test_create_meta_v1_commercial_usage_map():
	var state := _fresh_state()
	var bm := _make_bone_map()

	var vrm_ext := _make_base_vrm_extension()
	vrm_ext["meta"]["commercialUsage"] = "personalNonProfit"
	var meta = vrm_resource_factory.create_meta_v1(vrm_ext, state, bm)
	assert_eq(
		meta.commercial_usage_type, "PersonalNonProfit", "personalNonProfit should map correctly"
	)

	vrm_ext["meta"]["commercialUsage"] = "corporation"
	meta = vrm_resource_factory.create_meta_v1(vrm_ext, state, bm)
	assert_eq(
		meta.commercial_usage_type, "AllowCorporation", "corporation should map to AllowCorporation"
	)
	test_completed = true


func test_create_meta_v1_violent_usage():
	var state := _fresh_state()
	var bm := _make_bone_map()

	var vrm_ext := _make_base_vrm_extension()
	vrm_ext["meta"]["allowExcessivelyViolentUsage"] = true
	var meta = vrm_resource_factory.create_meta_v1(vrm_ext, state, bm)
	assert_eq(meta.violent_usage, "Allow", "true should map to Allow")

	vrm_ext["meta"]["allowExcessivelyViolentUsage"] = false
	meta = vrm_resource_factory.create_meta_v1(vrm_ext, state, bm)
	assert_eq(meta.violent_usage, "Disallow", "false should map to Disallow")
	test_completed = true


func test_create_meta_v1_sexual_usage():
	var state := _fresh_state()
	var bm := _make_bone_map()

	var vrm_ext := _make_base_vrm_extension()
	vrm_ext["meta"]["allowExcessivelySexualUsage"] = true
	var meta = vrm_resource_factory.create_meta_v1(vrm_ext, state, bm)
	assert_eq(meta.sexual_usage, "Allow", "true should map to Allow")

	vrm_ext["meta"]["allowExcessivelySexualUsage"] = false
	meta = vrm_resource_factory.create_meta_v1(vrm_ext, state, bm)
	assert_eq(meta.sexual_usage, "Disallow", "false should map to Disallow")
	test_completed = true


func test_create_meta_v1_missing_meta_key():
	# Pass vrm_extension with no "meta" key at all
	var vrm_ext: Dictionary = {"specVersion": "1.0"}
	var meta = vrm_resource_factory.create_meta_v1(vrm_ext, _fresh_state(), _make_bone_map())
	assert_not_null(meta, "Meta resource should still be created")
	assert_eq(meta.title, "", "Title should default to empty string when meta key missing")
	test_completed = true


func test_create_meta_v1_humanoid_bone_mapping():
	var vrm_ext := _make_base_vrm_extension()
	var bm := _make_bone_map()
	var meta = vrm_resource_factory.create_meta_v1(vrm_ext, _fresh_state(), bm)
	assert_not_null(meta.humanoid_bone_mapping, "humanoid_bone_mapping (BoneMap) should be set")
	test_completed = true
