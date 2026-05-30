@tool
class_name VRMInstance
extends Node

const vrm_meta_class = preload("./vrm_meta.gd")

# Reference to the secondary node if it exists.
# Reference to the secondary node if it exists.
var secondary_node: Node3D:
	set(value):
		secondary_node = value
		if secondary_node:
			if not _temp_spring_bones.is_empty():
				secondary_node.set("spring_bones", _temp_spring_bones)
				_temp_spring_bones.clear()
			if not _temp_collider_groups.is_empty():
				secondary_node.set("collider_groups", _temp_collider_groups)
				_temp_collider_groups.clear()
			if not _temp_collider_library.is_empty():
				secondary_node.set("collider_library", _temp_collider_library)
				_temp_collider_library.clear()

@export var vrm_meta: Resource

# Temporary properties storage when secondary_node is not yet assigned
var _temp_spring_bones: Array[VRMSpringBone] = []
var _temp_collider_groups: Array[VRMColliderGroup] = []
var _temp_collider_library: Array[VRMCollider] = []


func _get_property_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"name": "Spring bones", "type": TYPE_NIL, "usage": PROPERTY_USAGE_CATEGORY})
	list.append(
		{
			"name": "spring_bones",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_TYPE_STRING,
			"hint_string": "%d/%d:VRMSpringBone" % [TYPE_OBJECT, TYPE_OBJECT],
			"usage": PROPERTY_USAGE_DEFAULT
		}
	)
	list.append(
		{
			"name": "collider_groups",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_TYPE_STRING,
			"hint_string": "%d/%d:VRMColliderGroup" % [TYPE_OBJECT, TYPE_OBJECT],
			"usage": PROPERTY_USAGE_DEFAULT
		}
	)
	list.append(
		{
			"name": "collider_library",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_TYPE_STRING,
			"hint_string": "%d/%d:VRMCollider" % [TYPE_OBJECT, TYPE_OBJECT],
			"usage": PROPERTY_USAGE_DEFAULT
		}
	)
	return list


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"spring_bones":
			if secondary_node:
				secondary_node.set("spring_bones", value)
			else:
				_temp_spring_bones = value
			return true
		&"collider_groups":
			if secondary_node:
				secondary_node.set("collider_groups", value)
			else:
				_temp_collider_groups = value
			return true
		&"collider_library":
			if secondary_node:
				secondary_node.set("collider_library", value)
			else:
				_temp_collider_library = value
			return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"spring_bones":
			return secondary_node.get("spring_bones") if secondary_node else _temp_spring_bones
		&"collider_groups":
			return (
				secondary_node.get("collider_groups") if secondary_node else _temp_collider_groups
			)
		&"collider_library":
			return (
				secondary_node.get("collider_library") if secondary_node else _temp_collider_library
			)
	return null


@export_category("VRM Settings")
@export var settings: VRMSettings:
	set(value):
		if settings == value:
			return
		if settings != null and settings.settings_changed.is_connected(_on_settings_changed):
			settings.settings_changed.disconnect(_on_settings_changed)

		# Ensure settings are unique per instance to prevent cross-contamination
		settings = value.duplicate() if value != null else VRMSettings.new()

		settings.settings_changed.connect(_on_settings_changed)
		_on_settings_changed()

@export_category("Springbone Runtime")
@export var update_secondary_fixed: bool = false:
	set(value):
		update_secondary_fixed = value
		if secondary_node:
			secondary_node.update_secondary_fixed = value

@export var disable_colliders: bool = false:
	set(value):
		disable_colliders = value
		if secondary_node:
			secondary_node.disable_colliders = value

@export var override_springbone_center: bool = false:
	set(value):
		override_springbone_center = value
		if secondary_node:
			secondary_node.override_springbone_center = value

@export var default_springbone_center: Node3D:
	set(value):
		default_springbone_center = value
		if secondary_node:
			secondary_node.default_springbone_center = value

@export_category("Run in Editor")
@export var update_in_editor: bool = false:
	set(value):
		update_in_editor = value
		if secondary_node:
			secondary_node.update_in_editor = value

@export var gizmo_spring_bone: bool = false:
	set(value):
		gizmo_spring_bone = value
		if secondary_node:
			secondary_node.gizmo_spring_bone = value

@export var gizmo_spring_bone_color: Color = Color.LIGHT_YELLOW:
	set(value):
		gizmo_spring_bone_color = value
		if secondary_node:
			secondary_node.gizmo_spring_bone_color = value

@export var gizmo_show_colliders: bool = false:
	set(value):
		gizmo_show_colliders = value
		if secondary_node:
			secondary_node.gizmo_show_colliders = value

@export var gizmo_show_wind: bool = false:
	set(value):
		gizmo_show_wind = value
		if secondary_node:
			secondary_node.gizmo_show_wind = value

@export var gizmo_wind_color: Color = Color.CYAN:
	set(value):
		gizmo_wind_color = value
		if secondary_node:
			secondary_node.gizmo_wind_color = value


func _init() -> void:
	if settings == null:
		settings = VRMSettings.new()
	else:
		# Ensure settings are unique per instance to prevent cross-contamination
		settings = settings.duplicate()


func _on_settings_changed() -> void:
	if secondary_node and secondary_node.has_method("update_from_settings"):
		secondary_node.update_from_settings(settings)


func is_vrm_root() -> bool:
	return true
