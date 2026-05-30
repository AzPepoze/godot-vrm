extends "res://tests/test_base.gd"

# Test VRM animation constants for correctness and completeness.
# These constants control the mapping of VRM 0.0 preset names to VRM 1.0,
# look-at animation routing, and the set of recognized expression presets.

const vrm_animation_constants = preload(
	"res://addons/vrm/importer/common/animation/vrm_animation_constants.gd"
)


func test_vrm0_to_vrm1_preset_keys():
	var presets: Dictionary = vrm_animation_constants.vrm0_to_vrm1_presets
	# Spot-check known mappings
	assert_eq(presets["joy"], "happy", "'joy' should map to 'happy'")
	assert_eq(presets["a"], "aa", "'a' should map to 'aa'")
	assert_eq(presets["blink_l"], "blinkLeft", "'blink_l' should map to 'blinkLeft'")
	assert_eq(presets["blink_r"], "blinkRight", "'blink_r' should map to 'blinkRight'")
	assert_eq(presets["lookup"], "lookUp", "'lookup' should map to 'lookUp'")
	assert_eq(presets["lookdown"], "lookDown", "'lookdown' should map to 'lookDown'")
	assert_eq(presets["lookleft"], "lookLeft", "'lookleft' should map to 'lookLeft'")
	assert_eq(presets["lookright"], "lookRight", "'lookright' should map to 'lookRight'")
	assert_eq(presets["neutral"], "neutral", "'neutral' should map to 'neutral'")


func test_vrm_animation_to_look_at_keys():
	var look_at: Dictionary = vrm_animation_constants.vrm_animation_to_look_at
	# All four look directions must be present with non-empty values
	assert_true(look_at.has("lookUp"), "lookUp key must exist")
	assert_true(look_at.has("lookDown"), "lookDown key must exist")
	assert_true(look_at.has("lookLeft"), "lookLeft key must exist")
	assert_true(look_at.has("lookRight"), "lookRight key must exist")

	assert_false(str(look_at["lookUp"]).is_empty(), "lookUp value must be non-empty")
	assert_false(str(look_at["lookDown"]).is_empty(), "lookDown value must be non-empty")
	assert_false(str(look_at["lookLeft"]).is_empty(), "lookLeft value must be non-empty")
	assert_false(str(look_at["lookRight"]).is_empty(), "lookRight value must be non-empty")


func test_vrm_animation_presets_completeness():
	var presets: Dictionary = vrm_animation_constants.vrm_animation_presets

	# All 18 expected preset names (VRM 1.0 spec)
	var expected: Array[String] = [
		"happy",
		"angry",
		"sad",
		"relaxed",
		"surprised",
		"aa",
		"ih",
		"ou",
		"ee",
		"oh",
		"blink",
		"blinkLeft",
		"blinkRight",
		"lookUp",
		"lookDown",
		"lookLeft",
		"lookRight",
		"neutral",
	]

	assert_eq(
		presets.size(), 18, "Preset dict should have exactly 18 entries, got %d" % presets.size()
	)

	for preset_name in expected:
		assert_true(presets.has(preset_name), "Missing preset: %s" % preset_name)
		assert_true(presets[preset_name], "Preset '%s' should map to true" % preset_name)

	# No unexpected keys
	for key in presets.keys():
		assert_true(key in expected, "Unexpected preset key: %s" % key)


func test_look_at_presets_subset_of_all_presets():
	var look_at: Dictionary = vrm_animation_constants.vrm_animation_to_look_at
	var presets: Dictionary = vrm_animation_constants.vrm_animation_presets

	# Every key in vrm_animation_to_look_at must also be a key in vrm_animation_presets
	for key in look_at.keys():
		assert_true(presets.has(key), "look_at key '%s' must exist in vrm_animation_presets" % key)
