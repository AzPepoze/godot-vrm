@tool
class_name VRMInstance
extends Node

const vrm_meta_class = preload("./vrm_meta.gd")

# Reference to the secondary node if it exists.
var secondary_node: Node3D

@export var vrm_meta: Resource

@export_category("Spring bones")
@export var spring_bones: Array[VRMSpringBone]
@export var collider_groups: Array[VRMColliderGroup]
@export var collider_library: Array[VRMCollider]

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
