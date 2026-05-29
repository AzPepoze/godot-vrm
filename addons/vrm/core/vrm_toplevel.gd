@tool
extends Node

const vrm_meta_class = preload("./vrm_meta.gd")
const spring_bone_class = preload("../runtime/vrm_spring_bone.gd")
const collider_class = preload("../runtime/vrm_collider.gd")
const collider_group_class = preload("../runtime/vrm_collider_group.gd")

@export var vrm_meta: Resource
@export var spring_bones: Array[spring_bone_class]
@export var collider_groups: Array[collider_group_class]
@export var collider_library: Array[collider_class]

# Reference to the secondary node if it exists.
var secondary_node: Node3D

@export var update_secondary_fixed: bool = false
@export var disable_colliders: bool = false
@export var override_springbone_center: bool = false
@export var default_springbone_center: Node3D
@export var springbone_gravity_multiplier: float = 1.0
@export var springbone_gravity_rotation: Quaternion = Quaternion.IDENTITY
@export var springbone_add_force: Vector3 = Vector3.ZERO
@export var update_in_editor: bool = false
@export var gizmo_spring_bone: bool = false
@export var gizmo_spring_bone_color: Color = Color.LIGHT_YELLOW
