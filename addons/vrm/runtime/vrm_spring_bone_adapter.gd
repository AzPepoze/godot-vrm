@tool
extends RefCounted

const VRMLogger = preload("../core/logger.gd")
const vrm_collider_class = preload("./vrm_collider.gd")

var simulation: SkeletonModifier3D = null
var skeleton: Skeleton3D = null
var has_simulation: bool = false

var _settings: VRMSettings = null


func _init(p_skeleton: Skeleton3D) -> void:
	skeleton = p_skeleton
	has_simulation = ClassDB.class_exists(&"VRMSpringBoneSimulation")
	if not has_simulation:
		VRMLogger.error(
			"vrm_spring_bone_adapter.gd", "VRMSpringBoneSimulation GDExtension not found!"
		)


func setup_simulation(
	spring_bones: Array,
	collider_groups: Array,
	disable_body_collisions: bool,
	update_in_editor: bool,
	group_multipliers: Array = []
) -> void:
	if skeleton == null:
		return

	cleanup()

	_setup_cpp(
		spring_bones, collider_groups, disable_body_collisions, update_in_editor, group_multipliers
	)


func _setup_cpp(
	spring_bones: Array,
	collider_groups: Array,
	_disable_body_collisions: bool,
	update_in_editor: bool,
	group_multipliers: Array = []
) -> void:
	if not has_simulation:
		return

	if skeleton.has_node("VRMSpringBoneSimulation"):
		skeleton.get_node("VRMSpringBoneSimulation").queue_free()
	simulation = ClassDB.instantiate("VRMSpringBoneSimulation")
	simulation.name = "VRMSpringBoneSimulation"

	var setup_func = func():
		if not is_instance_valid(simulation) or not is_instance_valid(skeleton):
			return
		if simulation.get_parent() == null:
			skeleton.add_child(simulation)

		var rename_map: Dictionary = {}
		if skeleton.has_meta("vrm_rename_map"):
			rename_map = skeleton.get_meta("vrm_rename_map")

		var modified_spring_bones: Array = []
		for sb in spring_bones:
			if sb == null:
				continue
			var sb_copy: VRMSpringBone = sb.duplicate()

			# 1. Update joint_nodes
			var joints: PackedStringArray = sb_copy.joint_nodes
			var updated_joints := PackedStringArray()
			for joint in joints:
				var sn := StringName(joint)
				if rename_map.has(sn):
					updated_joints.append(String(rename_map[sn]))
				else:
					updated_joints.append(joint)
			sb_copy.joint_nodes = updated_joints

			# 2. Update center_bone
			var cb: String = sb_copy.center_bone
			var cb_sn := StringName(cb)
			if cb != "" and rename_map.has(cb_sn):
				sb_copy.center_bone = String(rename_map[cb_sn])

			# Apply group multipliers
			var multiplier = 1.0
			for gm in group_multipliers:
				if gm != null and gm.group_name == sb.group:
					multiplier = gm.hit_radius_multiplier
					break
			if multiplier != 1.0:
				# PackedFloat64Array is passed by value, but modifying the property directly works
				# However, since it is a copy, we can just replace the array
				var new_hit_radius = PackedFloat64Array()
				for r in sb_copy.hit_radius:
					new_hit_radius.append(r * multiplier)
				sb_copy.hit_radius = new_hit_radius
				# also scale hit_radius_scale
				sb_copy.hit_radius_scale *= multiplier
			
			modified_spring_bones.append(sb_copy)

		var modified_collider_groups: Array = []
		for cg in collider_groups:
			if cg == null:
				continue
			var cg_copy: VRMColliderGroup = cg.duplicate()
			var colliders_copy: Array[VRMCollider] = []
			for col in cg_copy.colliders:
				if col == null:
					continue
				var col_copy: VRMCollider = col.duplicate()
				var b := col_copy.bone
				var b_sn := StringName(b)
				if b != "" and rename_map.has(b_sn):
					col_copy.bone = String(rename_map[b_sn])
				colliders_copy.append(col_copy)
			cg_copy.colliders = colliders_copy
			modified_collider_groups.append(cg_copy)

		simulation.setup(modified_spring_bones, modified_collider_groups)
		if _settings:
			update_parameters(_settings)
		else:
			simulation.active = true
			if Engine.is_editor_hint():
				simulation.active = update_in_editor

	if skeleton.is_inside_tree():
		setup_func.call_deferred()
	else:
		setup_func.call()

	VRMLogger.debug(
		"vrm_spring_bone_adapter.gd",
		(
			"setup_simulation (CPP): created simulation with %d spring bones, %d collider groups"
			% [spring_bones.size(), collider_groups.size()]
		)
	)


# gdlint: ignore=function-arguments-number
func update_parameters(p_settings: VRMSettings) -> void:
	_settings = p_settings

	if simulation and _settings:
		simulation.set_gizmo_display_mode(_settings.gizmo_display_mode)
		simulation.update_parameters(
			_settings.springbone_gravity_multiplier,
			_settings.springbone_gravity_rotation,
			_settings.springbone_add_force,
			_settings.springbone_stiffness_multiplier,
			_settings.springbone_drag_multiplier,
			(
				_settings.springbone_hit_radius_multiplier
				if not _settings.disable_spring_bone_collisions
				else 0.0
			),
			_settings.body_collision_radius_multiplier
		)
		simulation.set_enable_body_collisions(!_settings.disable_body_collisions)
		simulation.set_wind_direction(_settings.wind_direction)
		simulation.set_simulate_in_local_space(_settings.springbone_simulate_in_local_space)
		simulation.set_wind_strength(_settings.wind_strength)
		simulation.set_wind_turbulence(_settings.wind_turbulence)
		simulation.set_wind_frequency(_settings.wind_frequency)
		simulation.set_environment_collision_enabled(_settings.environment_collision_enabled)
		simulation.set_environment_collision_bounce_damping(
			_settings.environment_collision_bounce_damping
		)
		simulation.set_environment_collision_mask(_settings.environment_collision_mask)
		simulation.set_debug_collision(_settings.environment_collision_debug)

		simulation.set_active(true)
		if Engine.is_editor_hint():
			simulation.set_active(_settings.update_in_editor)


func set_gizmo_display_mode(mode: int) -> void:
	if simulation:
		simulation.set_gizmo_display_mode(mode)


func draw_gizmo(
	mesh: ImmediateMesh,
	skel_to_gizmo: Transform3D,
	color: Color,
	draw_spring_bones: bool,
	draw_body_collisions: bool,
	gizmo_display_mode: int = 0
) -> void:
	if simulation:
		simulation.draw_gizmo(mesh, skel_to_gizmo, color, draw_spring_bones, draw_body_collisions)


func cleanup() -> void:
	if simulation != null:
		simulation.queue_free()
		simulation = null
