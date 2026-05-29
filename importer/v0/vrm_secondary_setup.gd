@tool
extends RefCounted

const vrm_secondary_service = preload("../common/vrm_secondary_service.gd")


static func create_joints_recursive(
	joint_chains: Array[PackedStringArray],
	skeleton: Skeleton3D,
	bone_idx: int,
	level: int,
	current_chain: int
):
	vrm_secondary_service.create_joints_recursive(
		joint_chains, skeleton, bone_idx, level, current_chain
	)


static func parse_secondary_node(
	secondary_node: Node,
	vrm_extension: Dictionary,
	gstate: GLTFState,
	pose_diffs: Array[Basis],
	is_vrm_0: bool
) -> void:
	vrm_secondary_service.parse_secondary_node(
		secondary_node, vrm_extension, gstate, pose_diffs, is_vrm_0
	)
