@tool
extends RefCounted

const VRMLogger = preload("../core/logger.gd")
const vrm_collider_class = preload("./vrm_collider.gd")
const vrm_spring_bone_logic_class = preload("res://vrm_spring_bone_logic_old.gd")

var simulator: SkeletonModifier3D = null
var skeleton: Skeleton3D = null
var has_simulator: bool = false

var use_gdscript: bool = false
var spring_bones_internal: Array = []
var center_bones: PackedInt32Array
var center_nodes: Array[Node3D]
var center_transforms: Array[Transform3D]
var center_transforms_inv: Array[Transform3D]
var springs_centers: PackedInt32Array

var gravity_multiplier: float = 1.0
var gravity_rotation: Quaternion = Quaternion.IDENTITY
var add_force: Vector3 = Vector3.ZERO


func _init(p_skeleton: Skeleton3D) -> void:
	skeleton = p_skeleton
	has_simulator = ClassDB.class_exists(&"VRMSpringBoneSimulator")
	if not has_simulator:
		VRMLogger.error(
			"vrm_spring_bone_adapter.gd",
			"VRMSpringBoneSimulator GDExtension not found! Falling back to GDScript."
		)
		use_gdscript = true


func setup_simulator(
	spring_bones: Array,
	collider_groups: Array,
	disable_colliders: bool,
	update_in_editor: bool,
	p_use_gdscript: bool = false
) -> void:
	use_gdscript = p_use_gdscript or not has_simulator
	if skeleton == null:
		return

	cleanup()

	if use_gdscript:
		_setup_gdscript(spring_bones, collider_groups, disable_colliders)
	else:
		_setup_cpp(spring_bones, collider_groups, disable_colliders, update_in_editor)


func _setup_cpp(
	spring_bones: Array, collider_groups: Array, disable_colliders: bool, update_in_editor: bool
) -> void:
	if skeleton.has_node("VRMSpringBoneSimulator"):
		skeleton.get_node("VRMSpringBoneSimulator").queue_free()
	simulator = ClassDB.instantiate("VRMSpringBoneSimulator")
	simulator.name = "VRMSpringBoneSimulator"
	skeleton.add_child.call_deferred(simulator, false, Node.INTERNAL_MODE_BACK)

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
			"setup_simulator (CPP): created simulator with %d spring bones, %d collider groups"
			% [spring_bones.size(), unique_collider_groups.size()]
		)
	)
	simulator.setup(spring_bones, unique_collider_groups)
	simulator.active = !disable_colliders
	if Engine.is_editor_hint():
		simulator.active = update_in_editor


func _setup_gdscript(spring_bones: Array, _collider_groups: Array, disable_colliders: bool) -> void:
	VRMLogger.info(
		"vrm_spring_bone_adapter.gd",
		"setup_simulator (GDScript): setting up %d spring bones" % spring_bones.size()
	)

	spring_bones_internal.clear()
	center_bones.clear()
	center_nodes.clear()
	center_transforms.clear()
	center_transforms_inv.clear()
	springs_centers.clear()

	var center_to_index: Dictionary = {}

	for sb in spring_bones:
		if sb == null:
			continue
		var center_key: Variant = sb.center_bone
		if sb.center_bone == "":
			center_key = sb.center_node

		if not center_to_index.has(center_key):
			center_to_index[center_key] = len(center_bones)
			if sb.center_bone != "":
				center_bones.push_back(skeleton.find_bone(sb.center_bone))
			else:
				center_bones.push_back(-1)
			if sb.center_node == NodePath():
				center_nodes.push_back(null)
			else:
				center_nodes.push_back(
					(
						skeleton.get_node_or_null(sb.center_node)
						if sb.center_node != NodePath()
						else null
					)
				)
			center_transforms.push_back(Transform3D.IDENTITY)
			center_transforms_inv.push_back(Transform3D.IDENTITY)

	_update_centers()
	if skeleton.has_node("VRMSpringBoneSimulator"):
		skeleton.get_node("VRMSpringBoneSimulator").queue_free()

	# Load the script
	var vrm_spring_bone_old_script = load("res://vrm_spring_bone_old.gd")
	if vrm_spring_bone_old_script == null:
		VRMLogger.error("vrm_spring_bone_adapter.gd", "Failed to load res://vrm_spring_bone_old.gd")
		return

	# Use the script to create the runtime state
	for sb in spring_bones:
		if sb == null:
			continue
		var center_key: Variant = sb.center_bone
		if sb.center_bone == "":
			center_key = sb.center_node
		var center_idx: int = center_to_index[center_key]

		var tmp_colliders: Array = []
		for cg in sb.collider_groups:
			if cg == null:
				continue
			for c in cg.colliders:
				if c == null:
					continue
				var c_runtime = c.create_runtime(null, skeleton)
				tmp_colliders.append(c_runtime)

		# Inner classes can be instantiated via script.ClassName.new()
		if not ("SpringBoneRuntimeState" in vrm_spring_bone_old_script):
			VRMLogger.error(
				"vrm_spring_bone_adapter.gd",
				"SpringBoneRuntimeState not found in vrm_spring_bone_old.gd"
			)
			continue

		var runtime_state = vrm_spring_bone_old_script.SpringBoneRuntimeState.new(sb, skeleton)
		runtime_state.ready(skeleton, tmp_colliders, center_transforms_inv[center_idx])
		runtime_state.disable_colliders = disable_colliders
		runtime_state.gravity_multiplier = gravity_multiplier
		runtime_state.gravity_rotation = gravity_rotation
		runtime_state.add_force = add_force

		spring_bones_internal.append(runtime_state)
		springs_centers.append(center_idx)


func _update_centers():
	if skeleton.has_node("VRMSpringBoneSimulator"):
		skeleton.get_node("VRMSpringBoneSimulator").queue_free()
	if skeleton == null:
		return
	var skel_transform = skeleton.global_transform
	var skel_transform_inv = skel_transform.affine_inverse()

	for i in range(len(center_nodes)):
		if center_bones[i] == -1 and center_nodes[i] == null:
			center_transforms[i] = skel_transform
			center_transforms_inv[i] = skel_transform_inv
		elif center_bones[i] == -1 and center_nodes[i] != null:
			center_transforms[i] = (
				center_nodes[i].global_transform.affine_inverse() * skel_transform
			)
			center_transforms_inv[i] = skel_transform_inv * center_nodes[i].global_transform
		else:
			center_transforms[i] = skeleton.get_bone_global_pose(center_bones[i])
			center_transforms_inv[i] = center_transforms[i].affine_inverse()


func update(delta: float) -> void:
	if not use_gdscript:
		return

	_update_centers()
	if skeleton.has_node("VRMSpringBoneSimulator"):
		skeleton.get_node("VRMSpringBoneSimulator").queue_free()

	for i in range(len(spring_bones_internal)):
		var center_idx = springs_centers[i]
		spring_bones_internal[i].update(
			delta, center_transforms[center_idx], center_transforms_inv[center_idx]
		)


func update_parameters(
	p_gravity_multiplier: float, p_gravity_rotation: Quaternion, p_add_force: Vector3
) -> void:
	gravity_multiplier = p_gravity_multiplier
	gravity_rotation = p_gravity_rotation
	add_force = p_add_force

	if not use_gdscript and simulator:
		simulator.update_parameters(gravity_multiplier, gravity_rotation, add_force)
	elif use_gdscript:
		for sb in spring_bones_internal:
			sb.gravity_multiplier = gravity_multiplier
			sb.gravity_rotation = gravity_rotation
			sb.add_force = add_force


func set_active(active: bool) -> void:
	if not use_gdscript and simulator:
		simulator.active = active
	elif use_gdscript:
		for sb in spring_bones_internal:
			sb.disable_colliders = !active


func cleanup() -> void:
	if simulator != null:
		simulator.queue_free()
		simulator = null
	spring_bones_internal.clear()
