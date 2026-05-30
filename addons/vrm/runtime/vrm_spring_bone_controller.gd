@tool
class_name VRMSpringBoneController
extends Node3D

const VRMLogger = preload("../core/logger.gd")
const spring_bone_adapter_class = preload("./vrm_spring_bone_adapter.gd")
const SpringBoneGizmo = preload("./vrm_spring_bone_controller_gizmo.gd")

@export_category("Springbone Settings")
@export var update_spring_bone_controller_in_physics: bool:
	get:
		if _settings == null:
			_settings = VRMSettings.new()
		return _settings.update_spring_bone_controller_in_physics
	set(value):
		if _settings == null:
			_settings = VRMSettings.new()
		_settings.update_spring_bone_controller_in_physics = value

@export var disable_colliders: bool:
	get:
		if _settings == null:
			_settings = VRMSettings.new()
		return _settings.disable_colliders
	set(value):
		if _settings == null:
			_settings = VRMSettings.new()
		_settings.disable_colliders = value
		if spring_bone_adapter:
			spring_bone_adapter.set_active(!value)

@export var override_springbone_center: bool:
	get:
		if _settings == null:
			_settings = VRMSettings.new()
		return _settings.override_springbone_center
	set(value):
		if _settings == null:
			_settings = VRMSettings.new()
		_settings.override_springbone_center = value

@export var default_springbone_center: Node3D

@export_category("Run in Editor")
@export var update_in_editor: bool:
	get:
		if _settings == null:
			_settings = VRMSettings.new()
		return _settings.update_in_editor
	set(value):
		if _settings == null:
			_settings = VRMSettings.new()
		_settings.update_in_editor = value
		if spring_bone_adapter:
			spring_bone_adapter.set_active(value or not Engine.is_editor_hint())

@export var gizmo_spring_bone: bool:
	get:
		if _settings == null:
			_settings = VRMSettings.new()
		return _settings.gizmo_spring_bone
	set(value):
		if _settings == null:
			_settings = VRMSettings.new()
		_settings.gizmo_spring_bone = value

@export var gizmo_spring_bone_color: Color:
	get:
		if _settings == null:
			_settings = VRMSettings.new()
		return _settings.gizmo_spring_bone_color
	set(value):
		if _settings == null:
			_settings = VRMSettings.new()
		_settings.gizmo_spring_bone_color = value

@export var gizmo_show_colliders: bool:
	get:
		if _settings == null:
			_settings = VRMSettings.new()
		return _settings.gizmo_show_colliders
	set(value):
		if _settings == null:
			_settings = VRMSettings.new()
		_settings.gizmo_show_colliders = value

@export var gizmo_show_wind: bool:
	get:
		if _settings == null:
			_settings = VRMSettings.new()
		return _settings.gizmo_show_wind
	set(value):
		if _settings == null:
			_settings = VRMSettings.new()
		_settings.gizmo_show_wind = value

@export var gizmo_wind_color: Color:
	get:
		if _settings == null:
			_settings = VRMSettings.new()
		return _settings.gizmo_wind_color
	set(value):
		if _settings == null:
			_settings = VRMSettings.new()
		_settings.gizmo_wind_color = value

@export_category("Spring bones")
@export_node_path("Skeleton3D") var skeleton: NodePath:
	set(value):
		skeleton = value
		if is_inside_tree():
			_ready()

@export var spring_bones: Array[VRMSpringBone]:
	set(value):
		spring_bones = value
		if is_inside_tree():
			_ready()

@export var collider_groups: Array[VRMColliderGroup]:
	set(value):
		collider_groups = value
		if skel != null:
			_setup_spring_bone_adapter()

@export var collider_library: Array[VRMCollider]

var skel: Skeleton3D
var is_child_of_vrm: bool = false
var _parent_ref: Node = null
var spring_bone_adapter: RefCounted = null
var _gizmo: MeshInstance3D = null
var _settings: VRMSettings = null


func _enter_tree() -> void:
	_parent_ref = get_parent()
	if _parent_ref != null and _parent_ref.has_method("is_vrm_root"):
		is_child_of_vrm = true
		_parent_ref.set("spring_bone_controller", self)
		# Pull settings resource
		var parent_settings = _parent_ref.get("settings")
		if parent_settings is VRMSettings:
			update_from_settings(parent_settings)


func _ready() -> void:
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
		VRMLogger.warning(
			"vrm_spring_bone_controller.gd", "_ready: no skeleton found, skipping setup"
		)
		return

	spring_bones.sort_custom(func(a, b): return a.group < b.group)

	_setup_spring_bone_adapter()
	_setup_gizmo()
	VRMLogger.debug(
		"vrm_spring_bone_controller.gd",
		"_ready: setup complete for %d spring bones" % spring_bones.size()
	)


func update_from_settings(settings: VRMSettings) -> void:
	if _settings != null and _settings.settings_changed.is_connected(update_parameters):
		_settings.settings_changed.disconnect(update_parameters)

	_settings = settings

	if _settings != null:
		if not _settings.settings_changed.is_connected(update_parameters):
			_settings.settings_changed.connect(update_parameters)
		update_parameters()
		_notify_constraint_appliers()


func _setup_spring_bone_adapter() -> void:
	if spring_bone_adapter == null:
		spring_bone_adapter = spring_bone_adapter_class.new(skel)
	else:
		spring_bone_adapter.skeleton = skel

	spring_bone_adapter.setup_simulation(
		spring_bones, collider_groups, disable_colliders, update_in_editor
	)
	update_parameters()


func _setup_gizmo() -> void:
	if _gizmo == null:
		_gizmo = SpringBoneGizmo.new(self)
		add_child(_gizmo, false, Node.INTERNAL_MODE_BACK)


func update_parameters() -> void:
	if spring_bone_adapter != null and _settings != null:
		spring_bone_adapter.update_parameters(
			_settings.springbone_gravity_multiplier,
			_settings.springbone_gravity_rotation,
			_settings.springbone_add_force,
			_settings.wind_direction,
			_settings.wind_strength,
			_settings.wind_turbulence,
			_settings.wind_frequency,
			_settings.environment_collision_enabled,
			_settings.environment_collision_mask,
			_settings.springbone_stiffness_multiplier,
			_settings.springbone_drag_multiplier,
			_settings.springbone_hit_radius_multiplier
		)
		spring_bone_adapter.set_active(!_settings.disable_colliders)
		if Engine.is_editor_hint():
			spring_bone_adapter.set_active(_settings.update_in_editor)


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

		if gizmo_show_wind and _settings != null:
			_draw_wind_arrow(_gizmo.mesh, _settings.wind_direction, gizmo_wind_color, skel_to_gizmo)

	if is_child_of_vrm and _parent_ref != null:
		var val_default_springbone_center = _parent_ref.get("default_springbone_center")
		if val_default_springbone_center != null:
			default_springbone_center = val_default_springbone_center


func _draw_wind_arrow(
	mesh: ImmediateMesh, direction: Vector3, color: Color, skel_to_gizmo: Transform3D
) -> void:
	if direction.length() < 0.001:
		return

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_set_color(color)

	# Gizmo is in skeleton space because of the skel_to_gizmo transform
	# Find Head bone for positioning
	var head_idx = skel.find_bone("Head")
	var start_pos_skel = Vector3(0, 1.5, 0)  # Fallback
	if head_idx != -1:
		start_pos_skel = skel.get_bone_global_pose(head_idx).origin

	# The direction is already transformed to skeleton-local space by VRMWind
	# But the gizmo line should show where it points in skeleton space
	var end_pos_skel = start_pos_skel + direction.normalized() * 0.5

	# Transform points from skeleton local space to gizmo local space
	# This ensures the arrow correctly represents the world direction
	var start_pos = skel_to_gizmo * start_pos_skel
	var end_pos = skel_to_gizmo * end_pos_skel

	# Draw Main Line
	mesh.surface_add_vertex(start_pos)
	mesh.surface_add_vertex(end_pos)

	# Draw Arrow Head
	var dir = (end_pos - start_pos).normalized()
	var ortho = dir.cross(Vector3.UP).normalized()
	if ortho.length() < 0.01:
		ortho = dir.cross(Vector3.RIGHT).normalized()

	var arrow_side_1 = end_pos - dir * 0.1 + ortho * 0.05
	var arrow_side_2 = end_pos - dir * 0.1 - ortho * 0.05

	mesh.surface_add_vertex(end_pos)
	mesh.surface_add_vertex(arrow_side_1)
	mesh.surface_add_vertex(end_pos)
	mesh.surface_add_vertex(arrow_side_2)

	mesh.surface_end()


func _notify_constraint_appliers() -> void:
	if not is_inside_tree() or _settings == null:
		return
	var root = _parent_ref if is_child_of_vrm else get_parent()
	if root:
		var appliers = root.find_children("*", "VRMConstraintApplier", true, false)
		for applier in appliers:
			if applier.has_method("set_global_weight_multiplier"):
				applier.set_global_weight_multiplier(_settings.constraint_weight_multiplier)
