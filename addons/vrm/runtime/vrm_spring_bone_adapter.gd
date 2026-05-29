@tool
extends RefCounted

const VRMLogger = preload("../core/logger.gd")
const VRMSpringBoneSimulatorClass = preload("./vrm_spring_bone.gd")
const VRMColliderGroupClass = preload("./vrm_collider_group.gd")

var simulator: SkeletonModifier3D = null
var skeleton: Skeleton3D = null
var has_simulator: bool = false


func _init(p_skeleton: Skeleton3D) -> void:
	skeleton = p_skeleton
	has_simulator = ClassDB.class_exists(&"VRMSpringBoneSimulator")
	if not has_simulator:
		VRMLogger.error(
			"vrm_spring_bone_adapter.gd",
			"VRMSpringBoneSimulator GDExtension not found! Spring bones will not work."
		)


func setup_simulator(
	spring_bones: Array, collider_groups: Array, disable_colliders: bool, update_in_editor: bool
) -> void:
	if not has_simulator or skeleton == null:
		return

	if simulator != null:
		simulator.queue_free()
		simulator = null

	simulator = ClassDB.instantiate("VRMSpringBoneSimulator")
	simulator.name = "VRMSpringBoneSimulator"
	skeleton.add_child(simulator, false, Node.INTERNAL_MODE_BACK)

	var unique_collider_groups: Array = []
	for sb in spring_bones:
		if sb == null:
			continue
		for cg in sb.collider_groups:
			if cg != null and cg not in unique_collider_groups:
				unique_collider_groups.append(cg)

	VRMLogger.info(
		"vrm_spring_bone_adapter.gd",
		(
			"setup_simulator: created simulator with %d spring bones, %d collider groups"
			% [spring_bones.size(), unique_collider_groups.size()]
		)
	)
	simulator.setup(spring_bones, unique_collider_groups)
	simulator.active = !disable_colliders
	if Engine.is_editor_hint():
		simulator.active = update_in_editor


func update_parameters(
	gravity_multiplier: float, gravity_rotation: Quaternion, add_force: Vector3
) -> void:
	if has_simulator and simulator:
		simulator.update_parameters(gravity_multiplier, gravity_rotation, add_force)


func set_active(active: bool) -> void:
	if has_simulator and simulator:
		simulator.active = active


func cleanup() -> void:
	if simulator != null:
		simulator.queue_free()
		simulator = null
