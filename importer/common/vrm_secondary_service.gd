@tool
extends RefCounted

const VRMLogger = preload("../../core/logger.gd")
const vrm_secondary = preload("../../runtime/vrm_secondary.gd")
const vrm_spring_bone_parser = preload("./vrm_spring_bone_parser.gd")


static func detect_group(bone_name: String, comment: String) -> String:
	return vrm_spring_bone_parser.detect_group(bone_name, comment)


static func parse_secondary_node(
	secondary_node: Node,
	vrm_extension: Dictionary,
	gstate: GLTFState,
	pose_diffs: Array[Basis],
	is_vrm_0: bool
) -> void:
	VRMLogger.debug(
		"vrm_secondary_service.gd",
		(
			"parse_secondary_node: parsing secondary animation (VRM %s)"
			% ("0.0" if is_vrm_0 else "1.0")
		)
	)

	var skeleton_path: NodePath = secondary_node.get_path_to(
		secondary_node.get_parent().get_node("%GeneralSkeleton")
	)

	# Parse Colliders
	var collider_groups = vrm_spring_bone_parser.parse_colliders_v0(
		vrm_extension["secondaryAnimation"]["colliderGroups"], gstate, pose_diffs, secondary_node
	)

	# Parse Spring Bones
	var spring_bones = vrm_spring_bone_parser.parse_springs_v0(
		vrm_extension["secondaryAnimation"]["boneGroups"], gstate, collider_groups, secondary_node
	)

	# Collect all colliders into a flat library
	var collider_library: Array[VRMCollider] = []
	for cg in collider_groups:
		collider_library.append_array(cg.colliders)

	secondary_node.set_script(vrm_secondary)
	secondary_node.set("skeleton", skeleton_path)
	secondary_node.set("spring_bones", Array(spring_bones))
	secondary_node.set("collider_groups", Array(collider_groups))
	secondary_node.set("collider_library", Array(collider_library))
