@tool
extends RefCounted

const VRMLogger = preload("../../core/logger.gd")
const vrm_spring_bone_controller = preload("../../runtime/vrm_spring_bone_controller.gd")
const vrm_spring_bone_parser = preload("./vrm_spring_bone_parser.gd")


static func detect_group(bone_name: String, comment: String) -> String:
	return vrm_spring_bone_parser.detect_group(bone_name, comment)


static func parse_spring_bone_controller(
	spring_bone_controller: Node,
	vrm_extension: Dictionary,
	gstate: GLTFState,
	pose_diffs: Array[Basis],
	is_vrm_0: bool
) -> void:
	VRMLogger.debug(
		"vrm_spring_bone_service.gd",
		(
			"parse_spring_bone_controller: parsing spring_bone_controller animation (VRM %s)"
			% ("0.0" if is_vrm_0 else "1.0")
		)
	)

	var skeleton_path: NodePath = spring_bone_controller.get_path_to(
		spring_bone_controller.get_parent().get_node("%GeneralSkeleton")
	)

	# Parse Colliders
	var collider_groups = vrm_spring_bone_parser.parse_colliders_v0(
		vrm_extension["secondaryAnimation"]["colliderGroups"],
		gstate,
		pose_diffs,
		spring_bone_controller
	)

	# Parse Spring Bones
	var spring_bones = vrm_spring_bone_parser.parse_springs_v0(
		vrm_extension["secondaryAnimation"]["boneGroups"],
		gstate,
		collider_groups,
		spring_bone_controller
	)

	# Collect all colliders into a flat library
	var collider_library: Array[VRMCollider] = []
	for cg in collider_groups:
		collider_library.append_array(cg.colliders)

	spring_bone_controller.set_script(vrm_spring_bone_controller)
	spring_bone_controller.set("skeleton", skeleton_path)
	spring_bone_controller.set("spring_bones", Array(spring_bones))
	spring_bone_controller.set("collider_groups", Array(collider_groups))
	spring_bone_controller.set("collider_library", Array(collider_library))
