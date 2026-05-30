@tool
class_name VRMTopLevel
extends Node

const vrm_meta_class = preload("./vrm_meta.gd")

# Reference to the secondary node if it exists.
var secondary_node: Node3D

@export var vrm_meta: Resource

@export_category("Spring bones")
@export var spring_bones: Array[VRMSpringBone]
@export var collider_groups: Array[VRMColliderGroup]
@export var collider_library: Array[VRMCollider]

@export_category("Springbone Settings")
@export var update_secondary_fixed: bool = false:
	set(value):
		if update_secondary_fixed == value:
			return
		update_secondary_fixed = value
		if secondary_node:
			secondary_node.update_secondary_fixed = value

@export var use_gdscript_spring_bones: bool = false:
	set(value):
		if use_gdscript_spring_bones == value:
			return
		use_gdscript_spring_bones = value
		if secondary_node:
			secondary_node.use_gdscript_spring_bones = value

@export var disable_colliders: bool = false:
	set(value):
		if disable_colliders == value:
			return
		disable_colliders = value
		if secondary_node:
			secondary_node.disable_colliders = value
@export var override_springbone_center: bool = false:
	set(value):
		if override_springbone_center == value:
			return
		override_springbone_center = value
		if secondary_node:
			secondary_node.override_springbone_center = value
@export var default_springbone_center: Node3D:
	set(value):
		if default_springbone_center == value:
			return
		default_springbone_center = value
		if secondary_node:
			secondary_node.default_springbone_center = value
@export var springbone_gravity_multiplier: float = 1.0:
	set(value):
		if springbone_gravity_multiplier == value:
			return
		springbone_gravity_multiplier = value
		if secondary_node:
			secondary_node.springbone_gravity_multiplier = value
@export var springbone_gravity_rotation: Quaternion = Quaternion.IDENTITY:
	set(value):
		if springbone_gravity_rotation == value:
			return
		springbone_gravity_rotation = value
		if secondary_node:
			secondary_node.springbone_gravity_rotation = value
@export var springbone_add_force: Vector3 = Vector3.ZERO:
	set(value):
		if springbone_add_force == value:
			return
		springbone_add_force = value
		if secondary_node:
			secondary_node.springbone_add_force = value

@export_category("Run in Editor")
@export var update_in_editor: bool = false:
	set(value):
		if update_in_editor == value:
			return
		update_in_editor = value
		if secondary_node:
			secondary_node.update_in_editor = value
@export var gizmo_spring_bone: bool = false:
	set(value):
		if gizmo_spring_bone == value:
			return
		gizmo_spring_bone = value
		if secondary_node:
			secondary_node.gizmo_spring_bone = value
@export var gizmo_spring_bone_color: Color = Color.LIGHT_YELLOW:
	set(value):
		if gizmo_spring_bone_color == value:
			return
		gizmo_spring_bone_color = value
		if secondary_node:
			secondary_node.gizmo_spring_bone_color = value
@export var gizmo_show_colliders: bool = false:
	set(value):
		if gizmo_show_colliders == value:
			return
		gizmo_show_colliders = value
		if secondary_node:
			secondary_node.gizmo_show_colliders = value


func is_vrm_root() -> bool:
	return true
