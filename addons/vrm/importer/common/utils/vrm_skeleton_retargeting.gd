@tool
extends RefCounted

const VRMTransformUtils = preload("./vrm_transform_utils.gd")
const VRMMeshOrientation = preload("./vrm_mesh_orientation.gd")


static func skeleton_rename(
	gstate: GLTFState, p_base_scene: Node, p_skeleton: Skeleton3D, p_bone_map: BoneMap
):
	var skellen: int = p_skeleton.get_bone_count()

	for i in range(skellen):
		var bn: StringName = p_bone_map.find_profile_bone_name(p_skeleton.get_bone_name(i))
		if bn != StringName():
			p_skeleton.set_bone_name(i, bn)

	var gnodes = gstate.nodes
	var root_bone_name = "Root"
	if p_skeleton.find_bone(root_bone_name) == -1:
		p_skeleton.add_bone(root_bone_name)
		var new_root_bone_id = p_skeleton.find_bone(root_bone_name)
		for root_bone_id in p_skeleton.get_parentless_bones():
			if root_bone_id != new_root_bone_id:
				p_skeleton.set_bone_parent(root_bone_id, new_root_bone_id)
	for gnode in gnodes:
		var bn: StringName = p_bone_map.find_profile_bone_name(gnode.resource_name)
		if bn != StringName():
			gnode.resource_name = bn

	var nodes: Array[Node] = p_base_scene.find_children("*", "ImporterMeshInstance3D")
	while not nodes.is_empty():
		var mi: ImporterMeshInstance3D = nodes.pop_back() as ImporterMeshInstance3D
		var skin: Skin = mi.skin
		if skin:
			var node = mi.get_node(mi.skeleton_path)
			if node and node is Skeleton3D and node == p_skeleton:
				skellen = skin.get_bind_count()
				for i in range(skellen):
					var bind_bone_name: StringName = skin.get_bind_name(i)
					if bind_bone_name.is_empty():
						if skin.get_bind_bone(i) != -1:
							break
					var bone_name_from_skel: StringName = p_bone_map.find_profile_bone_name(
						bind_bone_name
					)
					if not bone_name_from_skel.is_empty():
						skin.set_bind_name(i, bone_name_from_skel)

	nodes = p_base_scene.find_children("*")
	p_skeleton.name = "GeneralSkeleton"
	p_skeleton.set_unique_name_in_owner(true)
	while not nodes.is_empty():
		var nd = nodes.pop_back()
		if nd.has_method(&"_notify_skeleton_bones_renamed"):
			nd.call(&"_notify_skeleton_bones_renamed", p_base_scene, p_skeleton, p_bone_map)


static func skeleton_rotate(
	_p_base_scene: Node,
	src_skeleton: Skeleton3D,
	p_bone_map: BoneMap,
	old_skeleton_global_rest: Array[Transform3D]
) -> Array[Basis]:
	var is_renamed = true
	var profile = p_bone_map.profile
	var prof_skeleton = Skeleton3D.new()
	for i in range(profile.bone_size):
		prof_skeleton.add_bone(profile.get_bone_name(i))
		prof_skeleton.set_bone_rest(i, profile.get_reference_pose(i))
	for i in range(profile.bone_size):
		var parent = profile.find_bone(profile.get_bone_parent(i))
		if parent >= 0:
			prof_skeleton.set_bone_parent(i, parent)

	old_skeleton_global_rest.clear()
	for i in range(src_skeleton.get_bone_count()):
		old_skeleton_global_rest.push_back(src_skeleton.get_bone_global_rest(i))

	var diffs: Array[Basis]
	diffs.resize(src_skeleton.get_bone_count())

	var bones_to_process: PackedInt32Array = src_skeleton.get_parentless_bones()
	var bpidx = 0
	while bpidx < len(bones_to_process):
		var src_idx: int = bones_to_process[bpidx]
		bpidx += 1
		var src_children: PackedInt32Array = src_skeleton.get_bone_children(src_idx)
		for bone_idx in src_children:
			bones_to_process.push_back(bone_idx)

		var tgt_rot: Basis
		var src_bone_name: StringName = StringName(src_skeleton.get_bone_name(src_idx))
		if src_bone_name != StringName():
			var src_pg: Basis
			var src_parent_idx: int = src_skeleton.get_bone_parent(src_idx)
			if src_parent_idx >= 0:
				src_pg = src_skeleton.get_bone_global_rest(src_parent_idx).basis
			var prof_idx: int = profile.find_bone(src_bone_name)
			if prof_idx >= 0:
				tgt_rot = src_pg.inverse() * prof_skeleton.get_bone_global_rest(prof_idx).basis

		if src_skeleton.get_bone_parent(src_idx) >= 0:
			diffs[src_idx] = (
				tgt_rot.inverse()
				* diffs[src_skeleton.get_bone_parent(src_idx)]
				* src_skeleton.get_bone_rest(src_idx).basis
			)
		else:
			diffs[src_idx] = tgt_rot.inverse() * src_skeleton.get_bone_rest(src_idx).basis

		var diff: Basis
		if src_skeleton.get_bone_parent(src_idx) >= 0:
			diff = diffs[src_skeleton.get_bone_parent(src_idx)]

		src_skeleton.set_bone_rest(
			src_idx, Transform3D(tgt_rot, diff * src_skeleton.get_bone_rest(src_idx).origin)
		)

	prof_skeleton.queue_free()
	return diffs


static func perform_retarget(
	gstate: GLTFState, root_node: Node, skeleton: Skeleton3D, bone_map: BoneMap
) -> Array[Basis]:
	var global_transform_scale_local: Vector3 = VRMTransformUtils.apply_node_transforms(
		root_node, skeleton
	)
	skeleton_rename(gstate, root_node, skeleton, bone_map)
	var old_skeleton_global_rest: Array[Transform3D]
	var poses = skeleton_rotate(root_node, skeleton, bone_map, old_skeleton_global_rest)
	VRMMeshOrientation.apply_mesh_rotation(
		root_node, skeleton, old_skeleton_global_rest, global_transform_scale_local
	)
	var hips_bone_idx = skeleton.find_bone("Hips")
	if hips_bone_idx != -1:
		skeleton.motion_scale = abs(skeleton.get_bone_global_rest(hips_bone_idx).origin.y)
		if skeleton.motion_scale < 0.0001:
			skeleton.motion_scale = 1.0
	return poses


static func _recurse_bones(bones: Dictionary, skel: Skeleton3D, bone_idx: int):
	bones[skel.get_bone_name(bone_idx)] = bone_idx
	for child in skel.get_bone_children(bone_idx):
		_recurse_bones(bones, skel, child)
