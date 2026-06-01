extends "res://tests/test_base.gd"

const VRMSpringBoneParser = preload("res://addons/vrm/importer/common/vrm_spring_bone_parser.gd")

# --- Comment priority ---


func test_comment_takes_priority():
	var result = VRMSpringBoneParser.detect_group("J_Sec_Hair3_01", "Pigtail")
	assert_eq(result, "Pigtail", "Comment should take priority over bone name")
	test_completed = true


func test_comment_with_newline():
	var result = VRMSpringBoneParser.detect_group("J_Sec_Hair3_01", "Hair\nsome extra text")
	assert_eq(result, "Hair", "Only first line of comment should be used")
	test_completed = true


func test_empty_comment_falls_back_to_bone():
	var result = VRMSpringBoneParser.detect_group("J_Sec_Skirt_01", "")
	assert_eq(result, "Skirt", "Empty comment should fall back to bone name parsing")
	test_completed = true

# --- VRM prefix stripping ---
	test_completed = true


func test_j_sec_prefix():
	var result = VRMSpringBoneParser.detect_group("J_Sec_Hair3_01", "")
	assert_eq(result, "Hair3", "J_Sec_ prefix should be stripped")
	test_completed = true


func test_j_prefix():
	var result = VRMSpringBoneParser.detect_group("J_Sec_Hair_01", "")
	assert_eq(result, "Hair", "J_ prefix should be stripped")
	test_completed = true


func test_s_j_prefix():
	var result = VRMSpringBoneParser.detect_group("S_J_Hair_01", "")
	assert_eq(result, "Hair", "S_J_ prefix should be stripped")
	test_completed = true

# --- Side prefix stripping ---
	test_completed = true


func test_left_side_prefix():
	var result = VRMSpringBoneParser.detect_group("J_Sec_L_SkirtSide2_01", "")
	assert_eq(result, "SkirtSide2", "L_ side prefix should be stripped")
	test_completed = true


func test_right_side_prefix():
	var result = VRMSpringBoneParser.detect_group("J_Sec_R_SkirtSide2_01", "")
	assert_eq(result, "SkirtSide2", "R_ side prefix should be stripped")
	test_completed = true

# --- Trailing chain index stripping ---
	test_completed = true


func test_trailing_chain_index():
	var result = VRMSpringBoneParser.detect_group("J_Sec_Hair3_01", "")
	assert_eq(result, "Hair3", "Trailing _01 chain index should be stripped")
	test_completed = true


func test_higher_chain_index():
	var result = VRMSpringBoneParser.detect_group("J_Sec_Hair3_10", "")
	assert_eq(result, "Hair3", "Trailing _10 chain index should be stripped")
	test_completed = true

# --- _end marker ---
	test_completed = true


func test_end_marker():
	var result = VRMSpringBoneParser.detect_group("J_Sec_Hair3_01_end", "")
	assert_eq(result, "Hair3", "Trailing _end marker should be stripped")
	test_completed = true

# --- Real-world bone names from AvatarSample_M ---
	test_completed = true


func test_avatar_hair3():
	var result = VRMSpringBoneParser.detect_group("J_Sec_Hair3_01", "")
	assert_eq(result, "Hair3", "AvatarSample_M hair3 bone")
	test_completed = true


func test_avatar_hair5():
	var result = VRMSpringBoneParser.detect_group("J_Sec_Hair5_06", "")
	assert_eq(result, "Hair5", "AvatarSample_M hair5 bone")
	test_completed = true


func test_avatar_skirt_left():
	var result = VRMSpringBoneParser.detect_group("J_Sec_L_SkirtSide2_01", "")
	assert_eq(result, "SkirtSide2", "AvatarSample_M left skirt bone")
	test_completed = true


func test_avatar_skirt_right():
	var result = VRMSpringBoneParser.detect_group("J_Sec_R_SkirtSide2_03", "")
	assert_eq(result, "SkirtSide2", "AvatarSample_M right skirt bone")
	test_completed = true


func test_avatar_bust_left():
	var result = VRMSpringBoneParser.detect_group("J_Sec_L_Bust2", "")
	assert_eq(result, "Bust2", "AvatarSample_M left bust bone (no trailing index)")
	test_completed = true


func test_avatar_bust_right():
	var result = VRMSpringBoneParser.detect_group("J_Sec_R_Bust2", "")
	assert_eq(result, "Bust2", "AvatarSample_M right bust bone (no trailing index)")
	test_completed = true

# --- Edge cases ---
	test_completed = true


func test_empty_bone_name():
	var result = VRMSpringBoneParser.detect_group("", "")
	assert_eq(result, "Other", "Empty bone name should return 'Other'")
	test_completed = true


func test_unexpected_prefix():
	var result = VRMSpringBoneParser.detect_group("CustomBone_01", "")
	assert_eq(
		result, "CustomBone", "Bone without known prefix should still strip trailing chain index"
	)
	test_completed = true


func test_trailing_number_after_prefix():
	var result = VRMSpringBoneParser.detect_group("J_Sec_01", "")
	assert_eq(
		result,
		"Other",
		"Bone name that becomes purely numeric after stripping should return 'Other'"
	)
	test_completed = true


func test_trailing_number_no_prefix():
	var result = VRMSpringBoneParser.detect_group("_01", "")
	assert_eq(result, "Other", "Bone name that becomes purely numeric should return 'Other'")
	test_completed = true
