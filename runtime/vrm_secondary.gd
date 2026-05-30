@tool
class_name VRMSecondary
extends Node3D

const VRMLogger = preload("../core/logger.gd")
const spring_bone_adapter_class = preload("./vrm_spring_bone_adapter.gd")
const SecondaryGizmo = preload("./vrm_secondary_gizmo.gd")

@export_category("Springbone Settings")
@export var update_secondary_fixed: bool = false:
	set(value):
		update_secondary_fixed = value
		if is_child_of_vrm:
			get_parent().update_secondary_fixed = value
@export var disable_colliders: bool = false:
	set(value):
		disable_colliders = value
		if is_child_of_vrm:
			get_parent().disable_colliders = value
		if spring_bone_adapter:
			spring_bone_adapter.set_active(!value)
@export var override_springbone_center: bool = false:
	set(value):
		override_springbone_center = value
		if is_child_of_vrm:
			get_parent().override_springbone_center = value

@export var default_springbone_center: Node3D:
	set(value):
		default_springbone_center = value
		if is_child_of_vrm:
			get_parent().default_springbone_center = value

@export var springbone_gravity_multiplier: float = 1.0:
	set(value):
		springbone_gravity_multiplier = value
		if is_child_of_vrm:
			get_parent().springbone_gravity_multiplier = value
		update_parameters()
@export var springbone_gravity_rotation: Quaternion = Quaternion.IDENTITY:
	set(value):
		springbone_gravity_rotation = value
		if is_child_of_vrm:
			get_parent().springbone_gravity_rotation = value
		update_parameters()
@export var springbone_add_force: Vector3 = Vector3.ZERO:
	set(value):
		springbone_add_force = value
		if is_child_of_vrm:
			get_parent().springbone_add_force = value
		update_parameters()

@export_category("Run in Editor")
@export var update_in_editor: bool = false:
	set(value):
		update_in_editor = value
		if is_child_of_vrm:
			get_parent().update_in_editor = value
		if spring_bone_adapter:
			spring_bone_adapter.set_active(value or not Engine.is_editor_hint())

@export var gizmo_spring_bone: bool = false:
	set(value):
		gizmo_spring_bone = value
		if is_child_of_vrm:
			get_parent().gizmo_spring_bone = value
@export var gizmo_spring_bone_color: Color = Color.LIGHT_YELLOW:
	set(value):
		gizmo_spring_bone_color = value
		if is_child_of_vrm:
			get_parent().gizmo_spring_bone_color = value
@export var gizmo_show_colliders: bool = false:
	set(value):
		gizmo_show_colliders = value
		if is_child_of_vrm:
			get_parent().gizmo_show_colliders = value

@export_category("Spring bones")
@export_node_path("Skeleton3D") var skeleton: NodePath:
	set(value):
		skeleton = value
		if is_inside_tree():
			_ready()

@export var spring_bones: Array[VRMSpringBone]:
	set(value):
		spring_bones = value
		if is_child_of_vrm:
			get_parent().set("spring_bones", value)
		if is_inside_tree():
			_ready()

var skel: Skeleton3D
var is_child_of_vrm: bool = false
var _parent_ref: Node = null
var spring_bone_adapter: RefCounted = null
var _gizmo: MeshInstance3D = null

@export var collider_groups: Array[VRMColliderGroup]:
	set(value):
		collider_groups = value
		if is_child_of_vrm:
			get_parent().set("collider_groups", value)
		if skel != null:
			_setup_spring_bone_adapter()
@export var collider_library: Array[VRMCollider]:
	set(value):
		collider_library = value
		if is_child_of_vrm:
			get_parent().set("collider_library", value)


func _enter_tree() -> void:
	_parent_ref = get_parent()
	if _parent_ref != null and "spring_bones" in _parent_ref:
		is_child_of_vrm = true
		# Push data to parent (set during import before is_child_of_vrm was true)
		_parent_ref.set("collider_groups", collider_groups)
		_parent_ref.set("collider_library", collider_library)
		_parent_ref.set("spring_bones", spring_bones)


func _ready() -> void:
	_parent_ref = get_parent()

	if skeleton.is_empty():
		var parent = get_parent()
		if parent is Skeleton3D:
			skel = parent
		else:
			skel = parent.get_node_or_null("%GeneralSkeleton")
		if skel:
			skeleton = get_path_to(skel)
	else:
		skel = get_node_or_null(skeleton)

	if skel == null:
		VRMLogger.warning("vrm_secondary.gd", "_ready: no skeleton found, skipping setup")
		return

	# Sort spring bones by group so the inspector shows them organized
	spring_bones.sort_custom(func(a, b): return a.group < b.group)

	_setup_spring_bone_adapter()
	_setup_gizmo()
	VRMLogger.debug(
		"vrm_secondary.gd", "_ready: setup complete for %d spring bones" % spring_bones.size()
	)


func _setup_spring_bone_adapter() -> void:
	if spring_bone_adapter == null:
		spring_bone_adapter = spring_bone_adapter_class.new(skel)

	spring_bone_adapter.setup_simulator(
		spring_bones, collider_groups, disable_colliders, update_in_editor
	)
	spring_bone_adapter.update_parameters(
		springbone_gravity_multiplier, springbone_gravity_rotation, springbone_add_force
	)


func _setup_gizmo() -> void:
	if _gizmo == null:
		_gizmo = SecondaryGizmo.new(self )
		add_child(_gizmo, false, Node.INTERNAL_MODE_BACK)


func update_parameters() -> void:
	if spring_bone_adapter != null:
		spring_bone_adapter.update_parameters(
			springbone_gravity_multiplier, springbone_gravity_rotation, springbone_add_force
		)


func _process(_delta: float):
	if _gizmo != null:
		if Engine.is_editor_hint():
			_gizmo.draw_in_editor()
		else:
			_gizmo.draw_in_game()
	if is_child_of_vrm and _parent_ref != null:
		# Sync from toplevel if changed in editor
		if _parent_ref.springbone_gravity_multiplier != springbone_gravity_multiplier:
			springbone_gravity_multiplier = _parent_ref.springbone_gravity_multiplier
			update_parameters()
		if _parent_ref.springbone_gravity_rotation != springbone_gravity_rotation:
			springbone_gravity_rotation = _parent_ref.springbone_gravity_rotation
			update_parameters()
		if _parent_ref.springbone_add_force != springbone_add_force:
			springbone_add_force = _parent_ref.springbone_add_force
			update_parameters()
		if _parent_ref.disable_colliders != disable_colliders:
			disable_colliders = _parent_ref.disable_colliders
			if spring_bone_adapter:
				spring_bone_adapter.set_active(!disable_colliders)
		if _parent_ref.update_in_editor != update_in_editor:
			update_in_editor = _parent_ref.update_in_editor
			if spring_bone_adapter:
				spring_bone_adapter.set_active(update_in_editor or not Engine.is_editor_hint())
		if _parent_ref.collider_groups != collider_groups:
			collider_groups = _parent_ref.collider_groups
		if _parent_ref.collider_library != collider_library:
			collider_library = _parent_ref.collider_library
