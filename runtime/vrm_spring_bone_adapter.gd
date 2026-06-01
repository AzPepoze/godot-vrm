@tool
extends RefCounted

const VRMLogger = preload("../core/logger.gd")
const vrm_collider_class = preload("./vrm_collider.gd")

var simulation: SkeletonModifier3D = null
var skeleton: Skeleton3D = null
var has_simulation: bool = false

var gravity_multiplier: float = 1.0
var stiffness_multiplier: float = 1.0
var drag_multiplier: float = 1.0
var hit_radius_multiplier: float = 1.0
var gravity_rotation: Quaternion = Quaternion.IDENTITY
var add_force: Vector3 = Vector3.ZERO


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
	update_in_editor: bool
) -> void:
	if skeleton == null:
		return

	cleanup()

	_setup_cpp(spring_bones, collider_groups, disable_body_collisions, update_in_editor)


func _setup_cpp(
	spring_bones: Array,
	collider_groups: Array,
	disable_body_collisions: bool,
	update_in_editor: bool
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

		simulation.setup(spring_bones, collider_groups)
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
func update_parameters(
	p_gravity_multiplier: float,
	p_gravity_rotation: Quaternion,
	p_add_force: Vector3,
	p_wind_direction: Vector3 = Vector3.ZERO,
	p_wind_strength: float = 0.0,
	p_wind_turbulence: float = 0.2,
	p_wind_frequency: float = 1.0,
	p_env_coll_enabled: bool = false,
	p_env_coll_mask: int = 1,
	p_env_coll_bounce_damping: float = 0.8,
	p_stiffness_multiplier: float = 1.0,
	p_drag_multiplier: float = 1.0,
	p_hit_radius_multiplier: float = 1.0,
	p_body_collider_radius_multiplier: float = 1.0,
	p_simulate_in_local_space: bool = false,
	p_disable_body_collisions: bool = false
) -> void:
	gravity_multiplier = p_gravity_multiplier
	stiffness_multiplier = p_stiffness_multiplier
	drag_multiplier = p_drag_multiplier
	hit_radius_multiplier = p_hit_radius_multiplier
	gravity_rotation = p_gravity_rotation
	add_force = p_add_force

	if simulation:
		simulation.update_parameters(
			gravity_multiplier,
			gravity_rotation,
			add_force,
			stiffness_multiplier,
			drag_multiplier,
			hit_radius_multiplier,
			p_body_collider_radius_multiplier
		)
		simulation.set_enable_body_collisions(!p_disable_body_collisions)
		simulation.set_wind_direction(p_wind_direction)
		simulation.set_simulate_in_local_space(p_simulate_in_local_space)
		simulation.set_wind_strength(p_wind_strength)
		simulation.set_wind_turbulence(p_wind_turbulence)
		simulation.set_wind_frequency(p_wind_frequency)
		simulation.set_environment_collision_enabled(p_env_coll_enabled)
		simulation.set_environment_collision_bounce_damping(p_env_coll_bounce_damping)
		simulation.set_environment_collision_mask(p_env_coll_mask)


func set_active(active: bool) -> void:
	if simulation:
		simulation.active = active


func draw_gizmo(
	mesh: ImmediateMesh,
	skel_to_gizmo: Transform3D,
	color: Color,
	draw_spring_bones: bool,
	draw_body_collisions: bool
) -> void:
	if simulation:
		simulation.draw_gizmo(mesh, skel_to_gizmo, color, draw_spring_bones, draw_body_collisions)


func cleanup() -> void:
	if simulation != null:
		simulation.queue_free()
		simulation = null
