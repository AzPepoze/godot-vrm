@tool
@icon("res://addons/vrm/icons/vrm_instance.svg")
class_name VRMInstance
extends Node

const vrm_meta_class = preload("./vrm_meta.gd")

var spring_bone_controller: Node3D:
    set(value):
        spring_bone_controller = value
        _sync_all_arrays()


func _sync_all_arrays() -> void:
    if not spring_bone_controller:
        return
    spring_bones = _sync_from_controller(&"spring_bones", spring_bones)
    collider_groups = _sync_from_controller(&"collider_groups", collider_groups)
    collider_library = _sync_from_controller(&"collider_library", collider_library)


func _sync_from_controller(prop: StringName, parent_val: Array) -> Array:
    var child_val = spring_bone_controller.get(prop)
    if not (child_val is Array):
        return parent_val
    if parent_val.is_empty() and not child_val.is_empty():
        return child_val
    if not parent_val.is_empty() and child_val.is_empty():
        spring_bone_controller.set(prop, parent_val)
    elif parent_val != child_val:
        spring_bone_controller.set(prop, parent_val)
    return parent_val


func _sync_to_controller(prop: StringName, value: Array) -> Array:
    if not spring_bone_controller:
        return value
    var child_val = spring_bone_controller.get(prop)
    if child_val is Array and not child_val.is_empty() and value.is_empty():
        return child_val
    if spring_bone_controller.get(prop) != value:
        spring_bone_controller.set(prop, value)
    return value


@export var vrm_meta: Resource

@export_category("Spring bones")
@export var spring_bones: Array[VRMSpringBone] = []:
    set(value):
        spring_bones = _sync_to_controller(&"spring_bones", value)

@export var collider_groups: Array[VRMColliderGroup] = []:
    set(value):
        collider_groups = _sync_to_controller(&"collider_groups", value)

@export var collider_library: Array[VRMCollider] = []:
    set(value):
        collider_library = _sync_to_controller(&"collider_library", value)

@export_tool_button("Recreate Spring Bone Simulation", "Reload")
var recreate_spring_bone_simulation: Callable = recreate_simulation


func recreate_simulation() -> void:
    _sync_all_arrays()
    if spring_bone_controller:
        spring_bone_controller.call("_ready")
        notify_property_list_changed()


@export_category("VRM Settings")

@export var springbone_group_multipliers: Array[VRMSpringBoneGroupSetting] = []:
    set(value):
        for old_setting in springbone_group_multipliers:
            if old_setting and old_setting.changed.is_connected(_on_group_settings_changed):
                old_setting.changed.disconnect(_on_group_settings_changed)
        springbone_group_multipliers = value
        for new_setting in springbone_group_multipliers:
            if new_setting and not new_setting.changed.is_connected(_on_group_settings_changed):
                new_setting.changed.connect(_on_group_settings_changed)
        _on_group_settings_changed()

@export var settings: VRMSettings:
    set(value):
        if settings == value:
            return
        if settings != null and settings.settings_changed.is_connected(_on_settings_changed):
            settings.settings_changed.disconnect(_on_settings_changed)

        settings = value

        if settings != null:
            if not settings.settings_changed.is_connected(_on_settings_changed):
                settings.settings_changed.connect(_on_settings_changed)
        _on_settings_changed()

@export var default_springbone_center: Node3D:
    set(value):
        default_springbone_center = value
        if spring_bone_controller:
            spring_bone_controller.default_springbone_center = value


func _init() -> void:
    if settings == null:
        settings = VRMSettings.new()


func _on_settings_changed() -> void:
    if spring_bone_controller and spring_bone_controller.has_method("update_from_settings"):
        spring_bone_controller.update_from_settings(settings)


func _on_group_settings_changed() -> void:
    if spring_bone_controller and spring_bone_controller.has_method("_setup_spring_bone_adapter"):
        spring_bone_controller._setup_spring_bone_adapter()


func is_vrm_root() -> bool:
    return true
