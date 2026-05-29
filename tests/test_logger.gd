extends "res://tests/test_base.gd"

const VRMLogger = preload("res://addons/vrm/core/logger.gd")


func test_logger_class_exists():
	assert_not_null(VRMLogger, "VRMLogger should be loadable")
	# Verify static functions exist by calling them without error
	VRMLogger.refresh_level()
	assert_true(true, "refresh_level should not crash")
	# register_settings should work
	VRMLogger.register_settings()
	assert_true(
		ProjectSettings.has_setting(&"vrm/logger/log_level"),
		"register_settings should create the project setting"
	)


func test_logger_level_constants():
	assert_eq(VRMLogger.Level.DEBUG, 0, "DEBUG should be 0")
	assert_eq(VRMLogger.Level.INFO, 1, "INFO should be 1")
	assert_eq(VRMLogger.Level.WARNING, 2, "WARNING should be 2")
	assert_eq(VRMLogger.Level.ERROR, 3, "ERROR should be 3")
	assert_eq(VRMLogger.Level.NONE, 4, "NONE should be 4")


func test_logger_register_settings():
	VRMLogger.register_settings()
	assert_true(
		ProjectSettings.has_setting(&"vrm/logger/log_level"),
		"ProjectSettings should have vrm/logger/log_level after register"
	)
	var val = ProjectSettings.get_setting(&"vrm/logger/log_level")
	assert_true(val >= 0 and val <= 4, "Log level should be in range 0-4, got " + str(val))


func test_logger_refresh_level():
	VRMLogger.register_settings()
	VRMLogger.refresh_level()
	# Should not crash
	assert_true(true, "refresh_level should not crash")
