@tool
extends RefCounted

const VRMLogger = preload("../core/logger.gd")
const vrm_collider_class = preload("./vrm_collider.gd")

var simulator: SkeletonModifier3D = null
var skeleton: Skeleton3D = null
var has_simulator: bool = false

var gravity_multiplier: float = 1.0
var gravity_rotation: Quaternion = Quaternion.IDENTITY
var add_force: Vector3 = Vector3.ZERO


func _init(p_skeleton: Skeleton3D) -> void:
	skeleton = p_skeleton
	has_simulator = ClassDB.class_exists(&"VRMSpringBoneSimulator")
	if not has_simulator:
		VRMLogger.error(
			"vrm_spring_bone_adapter.gd", "VRMSpringBoneSimulator GDExtension not found!"
		)


func setup_simulator(
	spring_bones: Array,
	collider_groups: Array,
	disable_colliders: bool,
	update_in_editor: bool
) -> void:
	if skeleton == null:
		return

	cleanup()

	_setup_cpp(spring_bones, collider_groups, disable_colliders, update_in_editor)


func _setup_cpp(
	spring_bones: Array, collider_groups: Array, disable_colliders: bool, update_in_editor: bool
) -> void:
	if not has_simulator:
		return

	if skeleton.has_node("VRMSpringBoneSimulator"):
		skeleton.get_node("VRMSpringBoneSimulator").queue_free()
	simulator = ClassDB.instantiate("VRMSpringBoneSimulator")
	simulator.name = "VRMSpringBoneSimulator"
	skeleton.add_child(simulator)

	VRMLogger.debug(
		"vrm_spring_bone_adapter.gd",
		(
			"setup_simulator (CPP): created simulator with %d spring bones, %d collider groups"
			% [spring_bones.size(), collider_groups.size()]
		)
	)

	simulator.setup(spring_bones, collider_groups)
	simulator.active = !disable_colliders
	if Engine.is_editor_hint():
		simulator.active = update_in_editor


func update_parameters(
	p_gravity_multiplier: float, p_gravity_rotation: Quaternion, p_add_force: Vector3,
	p_wind_direction: Vector3 = Vector3.ZERO, p_wind_strength: float = 0.0,
	p_wind_turbulence: float = 0.2, p_wind_frequency: float = 1.0,
	p_env_coll_enabled: bool = false, p_env_coll_mask: int = 1
) -> void:
	gravity_multiplier = p_gravity_multiplier
	gravity_rotation = p_gravity_rotation
	add_force = p_add_force

	if simulator:
		simulator.update_parameters(gravity_multiplier, gravity_rotation, add_force)
		simulator.set_wind_direction(p_wind_direction)
		simulator.set_wind_strength(p_wind_strength)
		simulator.set_wind_turbulence(p_wind_turbulence)
		simulator.set_wind_frequency(p_wind_frequency)
		simulator.set_environment_collision_enabled(p_env_coll_enabled)
		simulator.set_environment_collision_mask(p_env_coll_mask)


func set_active(active: bool) -> void:
	if simulator:
		simulator.active = active


func draw_gizmo(
	mesh: ImmediateMesh,
	skel_to_gizmo: Transform3D,
	color: Color,
	draw_spring_bones: bool,
	draw_colliders: bool
) -> void:
	if simulator:
		simulator.draw_gizmo(mesh, skel_to_gizmo, color, draw_spring_bones, draw_colliders)


func cleanup() -> void:
	if simulator != null:
		simulator.queue_free()
		simulator = null
