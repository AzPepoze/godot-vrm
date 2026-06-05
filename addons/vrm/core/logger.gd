@tool
extends RefCounted
## Centralized logging utility for the VRM addon.
##
## Usage:
##   VRMLogger.info("vrm_extension.gd", "Starting import of %s" % path)
##   VRMLogger.debug("vrm_material.gd", "Material %d: processing mtoon" % i)
##
## Log level is controlled via ProjectSettings:
##   vrm/logger/log_level  — 0=DEBUG, 1=INFO, 2=WARNING, 3=ERROR, 4=NONE

const SETTING_LOG_LEVEL := &"vrm/logger/log_level"

enum Level {
    DEBUG = 0,
    INFO = 1,
    WARNING = 2,
    ERROR = 3,
    NONE = 4,
}

static var _cached_level: int = -1
static var error_happened: bool = false


static func _get_log_level() -> int:
    if _cached_level != -1:
        return _cached_level
    if ProjectSettings.has_setting(SETTING_LOG_LEVEL):
        _cached_level = ProjectSettings.get_setting(SETTING_LOG_LEVEL)
    else:
        _cached_level = Level.INFO
    return _cached_level


static func _should_log(level: int) -> bool:
    return level >= _get_log_level()


static func _format(level_name: String, tag: String, message: String) -> String:
    return "[VRM][%s][%s] %s" % [level_name, tag, message]


static func debug(tag: String, message: String) -> void:
    if not _should_log(Level.DEBUG):
        return
    print_rich("[color=dim gray]%s[/color]" % _format("DEBUG", tag, message))


static func info(tag: String, message: String) -> void:
    if not _should_log(Level.INFO):
        return
    print_rich(_format("INFO", tag, message))


static func warning(tag: String, message: String) -> void:
    error_happened = true
    if not _should_log(Level.WARNING):
        return
    push_warning(_format("WARN", tag, message))


static func error(tag: String, message: String) -> void:
    error_happened = true
    if not _should_log(Level.ERROR):
        return
    push_error(_format("ERROR", tag, message))


## Call this in _enter_tree or similar to register the project setting.
static func register_settings() -> void:
    if not ProjectSettings.has_setting(SETTING_LOG_LEVEL):
        ProjectSettings.set_setting(SETTING_LOG_LEVEL, Level.WARNING)
        var info := {
            "name": SETTING_LOG_LEVEL,
            "type": TYPE_INT,
            "hint": PROPERTY_HINT_ENUM,
            "hint_string": "Debug,Info,Warning,Error,None",
        }
        ProjectSettings.add_property_info(info)
        ProjectSettings.set_initial_value(SETTING_LOG_LEVEL, Level.WARNING)
        # Flush cached level so next access re-reads
        _cached_level = -1


## Force re-read of the project setting (call after changing it at runtime).
static func refresh_level() -> void:
    _cached_level = -1
