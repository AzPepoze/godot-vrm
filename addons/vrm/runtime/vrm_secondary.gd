@tool
class_name VRMSecondary
extends Node3D

const VRMLogger = preload("../core/logger.gd")
const spring_bone_adapter_class = preload("./vrm_spring_bone_adapter.gd")
const SecondaryGizmo = preload("./vrm_secondary_gizmo.gd")

@export_category("Springbone Settings")
@export var update_secondary_fixed: bool = false:
	set(value):
		if update_secondary_fixed == value:
			return
		update_secondary_fixed = value
		if is_child_of_vrm:
			get_parent().update_secondary_fixed = value

@export var disable_colliders: bool = false:
	set(value):
		if disable_colliders == value:
			return
		disable_colliders = value
		if is_child_of_vrm:
			get_parent().disable_colliders = value
		if spring_bone_adapter:
			spring_bone_adapter.set_active(!value)
@export var override_springbone_center: bool = false:
	set(value):
		if override_springbone_center == value:
			return
		override_springbone_center = value
		if is_child_of_vrm:
			get_parent().override_springbone_center = value

@export var default_springbone_center: Node3D:
	set(value):
		if default_springbone_center == value:
			return
		default_springbone_center = value
		if is_child_of_vrm:
			get_parent().default_springbone_center = value

@export_group("Global Multipliers")
@export var springbone_stiffness_multiplier: float = 1.0:
	set(value):
		if springbone_stiffness_multiplier == value:
			return
		springbone_stiffness_multiplier = value
		if is_child_of_vrm:
			get_parent().springbone_stiffness_multiplier = value
		update_parameters()
@export var springbone_drag_multiplier: float = 1.0:
	set(value):
		if springbone_drag_multiplier == value:
			return
		springbone_drag_multiplier = value
		if is_child_of_vrm:
			get_parent().springbone_drag_multiplier = value
		update_parameters()
@export var springbone_gravity_multiplier: float = 1.0:
	set(value):
		if springbone_gravity_multiplier == value:
			return
		springbone_gravity_multiplier = value
		if is_child_of_vrm:
			get_parent().springbone_gravity_multiplier = value
		update_parameters()
@export var springbone_hit_radius_multiplier: float = 1.0:
	set(value):
		if springbone_hit_radius_multiplier == value:
			return
		springbone_hit_radius_multiplier = value
		if is_child_of_vrm:
			get_parent().springbone_hit_radius_multiplier = value
		update_parameters()
@export var constraint_weight_multiplier: float = 1.0:
	set(value):
		if constraint_weight_multiplier == value:
			return
		constraint_weight_multiplier = value
		if is_child_of_vrm:
			get_parent().constraint_weight_multiplier = value
		# Notify appliers if they exist
		_notify_constraint_appliers()

@export var springbone_gravity_rotation: Quaternion = Quaternion.IDENTITY:
	set(value):
		if springbone_gravity_rotation == value:
			return
		springbone_gravity_rotation = value
		if is_child_of_vrm:
			get_parent().springbone_gravity_rotation = value
		update_parameters()
@export var springbone_add_force: Vector3 = Vector3.ZERO:
	set(value):
		if springbone_add_force == value:
			return
		springbone_add_force = value
		if is_child_of_vrm:
			get_parent().springbone_add_force = value
		update_parameters()

@export_group("Wind Settings")
@export var wind_direction: Vector3 = Vector3.ZERO:
	set(value):
		if wind_direction == value:
			return
		wind_direction = value
		if is_child_of_vrm:
			get_parent().set("wind_direction", value)
		update_parameters()
@export var wind_strength: float = 0.0:
	set(value):
		if wind_strength == value:
			return
		wind_strength = value
		if is_child_of_vrm:
			get_parent().set("wind_strength", value)
		update_parameters()
@export var wind_turbulence: float = 0.2:
	set(value):
		if wind_turbulence == value:
			return
		wind_turbulence = value
		if is_child_of_vrm:
			get_parent().set("wind_turbulence", value)
		update_parameters()
@export var wind_frequency: float = 1.0:
	set(value):
		if wind_frequency == value:
			return
		wind_frequency = value
		if is_child_of_vrm:
			get_parent().set("wind_frequency", value)
		update_parameters()

@export_group("Environment Collision Settings")
@export var environment_collision_enabled: bool = false:
	set(value):
		if environment_collision_enabled == value:
			return
		environment_collision_enabled = value
		if is_child_of_vrm:
			get_parent().set("environment_collision_enabled", value)
		update_parameters()
@export var environment_collision_mask: int = 1:
	set(value):
		if environment_collision_mask == value:
			return
		environment_collision_mask = value
		if is_child_of_vrm:
			get_parent().set("environment_collision_mask", value)
		update_parameters()

@export_category("Run in Editor")
@export var update_in_editor: bool = false:
	set(value):
		if update_in_editor == value:
			return
		update_in_editor = value
		if is_child_of_vrm:
			get_parent().update_in_editor = value
		if spring_bone_adapter:
			spring_bone_adapter.set_active(value or not Engine.is_editor_hint())

@export var gizmo_spring_bone: bool = false:
	set(value):
		if gizmo_spring_bone == value:
			return
		gizmo_spring_bone = value
		if is_child_of_vrm:
			get_parent().gizmo_spring_bone = value
@export var gizmo_spring_bone_color: Color = Color.LIGHT_YELLOW:
	set(value):
		if gizmo_spring_bone_color == value:
			return
		gizmo_spring_bone_color = value
		if is_child_of_vrm:
			get_parent().gizmo_spring_bone_color = value
@export var gizmo_show_colliders: bool = false:
	set(value):
		if gizmo_show_colliders == value:
			return
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


# Pull a property from parent with fallback for properties that may not exist on older VRM roots.
func _pull_parent(prop: StringName, fallback: Variant = null) -> Variant:
	var val = _parent_ref.get(prop)
	return val if val != null else fallback


# Sync a single property from parent. Returns true if the value changed.
func _sync_prop(prop: StringName) -> bool:
	var parent_val = _parent_ref.get(prop)
	if parent_val == null:
		return false
	if get(prop) != parent_val:
		set(prop, parent_val)
		return true
	return false


func _enter_tree() -> void:
	_parent_ref = get_parent()
	if _parent_ref != null and _parent_ref.has_method("is_vrm_root"):
		is_child_of_vrm = true
		_parent_ref.set("secondary_node", self)
		# Push data to parent
		for prop in ["collider_groups", "collider_library", "spring_bones"]:
			_parent_ref.set(prop, get(prop))
		# Pull initial settings from parent
		springbone_stiffness_multiplier = _pull_parent("springbone_stiffness_multiplier", 1.0)
		springbone_drag_multiplier = _pull_parent("springbone_drag_multiplier", 1.0)
		springbone_gravity_multiplier = _pull_parent("springbone_gravity_multiplier", 1.0)
		springbone_hit_radius_multiplier = _pull_parent("springbone_hit_radius_multiplier", 1.0)
		constraint_weight_multiplier = _pull_parent("constraint_weight_multiplier", 1.0)
		springbone_gravity_rotation = _parent_ref.get("springbone_gravity_rotation")
		springbone_add_force = _parent_ref.get("springbone_add_force")
		wind_direction = _pull_parent("wind_direction", Vector3.ZERO)
		wind_strength = _pull_parent("wind_strength", 0.0)
		wind_turbulence = _pull_parent("wind_turbulence", 0.2)
		wind_frequency = _pull_parent("wind_frequency", 1.0)
		environment_collision_enabled = _pull_parent("environment_collision_enabled", false)
		environment_collision_mask = _pull_parent("environment_collision_mask", 1)
		update_parameters()
		gizmo_spring_bone = _parent_ref.get("gizmo_spring_bone")
		gizmo_spring_bone_color = _parent_ref.get("gizmo_spring_bone_color")
		gizmo_show_colliders = _parent_ref.get("gizmo_show_colliders")


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
	else:
		spring_bone_adapter.skeleton = skel

	spring_bone_adapter.setup_simulator(
		spring_bones, collider_groups, disable_colliders, update_in_editor
	)
	spring_bone_adapter.update_parameters(
		springbone_gravity_multiplier, springbone_gravity_rotation, springbone_add_force,
		wind_direction, wind_strength, wind_turbulence, wind_frequency,
		environment_collision_enabled, environment_collision_mask,
		springbone_stiffness_multiplier, springbone_drag_multiplier, springbone_hit_radius_multiplier
	)


func _setup_gizmo() -> void:
	if _gizmo == null:
		_gizmo = SecondaryGizmo.new(self )
		add_child(_gizmo, false, Node.INTERNAL_MODE_BACK)


func update_parameters() -> void:
	if spring_bone_adapter != null:
		spring_bone_adapter.update_parameters(
			springbone_gravity_multiplier, springbone_gravity_rotation, springbone_add_force,
			wind_direction, wind_strength, wind_turbulence, wind_frequency,
			environment_collision_enabled, environment_collision_mask,
			springbone_stiffness_multiplier, springbone_drag_multiplier, springbone_hit_radius_multiplier
		)


func _process(_delta: float):
	if _gizmo != null and spring_bone_adapter != null:
		var skel_to_gizmo: Transform3D = (
			_gizmo.global_transform.affine_inverse() * skel.global_transform
		)
		spring_bone_adapter.draw_gizmo(
			_gizmo.mesh,
			skel_to_gizmo,
			gizmo_spring_bone_color,
			gizmo_spring_bone,
			gizmo_show_colliders
		)

	if is_child_of_vrm and _parent_ref != null:
		_sync_from_parent()


func _sync_from_parent() -> void:
	# Sync physics parameters (trigger update_parameters on change)
	var needs_update := false
	for prop in [
		"springbone_stiffness_multiplier", "springbone_drag_multiplier",
		"springbone_gravity_multiplier", "springbone_hit_radius_multiplier",
		"constraint_weight_multiplier",
		"springbone_gravity_rotation", "springbone_add_force",
		"wind_direction", "wind_strength", "wind_turbulence", "wind_frequency",
		"environment_collision_enabled", "environment_collision_mask",
	]:
		needs_update = _sync_prop(prop) or needs_update
	if needs_update:
		update_parameters()
		_notify_constraint_appliers()

	# Sync non-physics flags
	for prop in [
		"update_secondary_fixed", "override_springbone_center", "default_springbone_center",
		"gizmo_spring_bone", "gizmo_spring_bone_color", "gizmo_show_colliders",
		"collider_groups", "collider_library",
	]:
		_sync_prop(prop)

	# These have side effects beyond simple assignment
	if _sync_prop("disable_colliders") and spring_bone_adapter:
		spring_bone_adapter.set_active(!disable_colliders)
	if _sync_prop("update_in_editor") and spring_bone_adapter:
		spring_bone_adapter.set_active(update_in_editor or not Engine.is_editor_hint())


func _notify_constraint_appliers() -> void:
	if not is_inside_tree():
		return
	# Search for appliers in the same model
	var root = _parent_ref if is_child_of_vrm else get_parent()
	if root:
		var appliers = root.find_children("*", "BoneNodeConstraintApplier", true, false)
		for applier in appliers:
			if applier.has_method("set_global_weight_multiplier"):
				applier.set_global_weight_multiplier(constraint_weight_multiplier)
