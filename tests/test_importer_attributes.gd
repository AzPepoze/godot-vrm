extends "res://tests/test_base.gd"

const ImporterMeshAttributes = preload(
	"res://addons/vrm/importer/common/importer_mesh_attributes.gd"
)


func test_attributes_class_exists():
	assert_not_null(ImporterMeshAttributes, "ImporterMeshAttributes should be loadable")


func test_attributes_default_layers():
	var attrs = ImporterMeshAttributes.new()
	assert_eq(attrs.layers, 1, "Default layers should be 1 so meshes render on the default layer")


func test_attributes_default_shadow():
	var attrs = ImporterMeshAttributes.new()
	assert_eq(
		attrs.shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Default shadow should be ON"
	)


func test_attributes_orig_layers_fallback():
	var attrs = ImporterMeshAttributes.new()
	assert_eq(attrs.orig_layers, 1, "orig_layers should fallback to 1")


func test_attributes_orig_shadow_fallback():
	var attrs = ImporterMeshAttributes.new()
	assert_eq(
		attrs.orig_shadow,
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		"orig_shadow should fallback to ON"
	)


func test_attributes_first_person_flag_default():
	var attrs = ImporterMeshAttributes.new()
	assert_eq(attrs.first_person_flag, "", "first_person_flag should default to empty string")


func test_attributes_signal_connected():
	var attrs = ImporterMeshAttributes.new()
	assert_true(
		attrs.replacing_by.is_connected(attrs._on_replacing_by),
		"_on_replacing_by should be connected to replacing_by signal"
	)
	test_completed = true
