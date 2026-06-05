@tool
extends RefCounted

enum BoneRenameMode {
	NONE = 0,
	HUMANBONES = 1,
	SYMMETRIZE_VROID = 2,
}

const humanoid_strategy = preload("./vrm_bone_renamer_humanoid.gd")
const symmetrize_strategy = preload("./vrm_bone_renamer_symmetrize.gd")

static func rename_skeleton_bones(
	gstate: GLTFState,
	p_base_scene: Node,
	p_skeleton: Skeleton3D,
	p_bone_map: BoneMap,
	mode: int
) -> void:
	if mode == BoneRenameMode.HUMANBONES:
		humanoid_strategy.rename_bones(gstate, p_base_scene, p_skeleton, p_bone_map)
	elif mode == BoneRenameMode.SYMMETRIZE_VROID:
		symmetrize_strategy.rename_bones(gstate, p_base_scene, p_skeleton, p_bone_map)

	# Ensure a single Root bone exists at the top level of the skeleton
	var root_bone_name = "Root"
	if p_skeleton.find_bone(root_bone_name) == -1:
		p_skeleton.add_bone(root_bone_name)
		var new_root_bone_id = p_skeleton.find_bone(root_bone_name)
		for root_bone_id in p_skeleton.get_parentless_bones():
			if root_bone_id != new_root_bone_id:
				p_skeleton.set_bone_parent(root_bone_id, new_root_bone_id)

	p_skeleton.name = "GeneralSkeleton"
	p_skeleton.set_unique_name_in_owner(true)

	# Notify descendant nodes about bone name changes (e.g. springbone, secondary, etc.)
	var nodes = p_base_scene.find_children("*")
	while not nodes.is_empty():
		var nd = nodes.pop_back()
		if nd.has_method(&"_notify_skeleton_bones_renamed"):
			nd.call(&"_notify_skeleton_bones_renamed", p_base_scene, p_skeleton, p_bone_map)
