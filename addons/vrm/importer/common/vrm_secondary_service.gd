@tool
extends RefCounted

const VRMLogger = preload("../../core/logger.gd")
const vrm_secondary = preload("../../runtime/vrm_secondary.gd")
const vrm_spring_bone = preload("../../runtime/vrm_spring_bone.gd")
const vrm_collider_group = preload("../../runtime/vrm_collider_group.gd")
const vrm_collider = preload("../../runtime/vrm_collider.gd")


# Detect a human-readable group label from a bone name or VRM comment.
# Comment takes highest priority, then bone name prefix parsing.
# Examples:
#   bone="J_Sec_Hair3_01" comment=""         → "Hair3"
#   bone="J_Sec_L_SkirtSide2_01" comment=""  → "SkirtSide2"
#   bone="J_Sec_L_Bust2" comment=""          → "Bust2"
#   bone="J_Sec_Hair3_01" comment="Pigtail"  → "Pigtail"
static func detect_group(bone_name: String, comment: String) -> String:
	# Comment takes priority
	if not comment.is_empty():
		return comment.split("\n")[0].strip_edges()

	var name = bone_name

	# Strip common VRM bone prefixes
	for prefix in ["J_Sec_", "J_", "S_J_"]:
		if name.begins_with(prefix):
			name = name.trim_prefix(prefix)
			break

	# Strip side prefixes (L_ / R_)
	if name.begins_with("L_") or name.begins_with("R_"):
		name = name.substr(2)

	# Remove trailing _end marker
	if name.ends_with("_end"):
		name = name.trim_suffix("_end")

	# Remove trailing _ followed by digits (bone chain index like _01)
	var underscore_idx = name.rfind("_")
	if underscore_idx != -1:
		var suffix = name.substr(underscore_idx + 1)
		if suffix.is_valid_int():
			name = name.substr(0, underscore_idx)

	# If the result is empty or purely numeric (e.g. "01"), return "Other"
	if name.is_empty() or name.is_valid_int():
		return "Other"
	return name


static func _get_skel_godot_node(
	gstate: GLTFState, nodes: Array, skeletons: Array, skel_id: int
) -> Node:
	if skel_id < 0 or skel_id >= skeletons.size():
		return null
	var gltfskel: GLTFSkeleton = skeletons[skel_id]
	if gltfskel.roots.is_empty():
		return null
	var skel_node_idx = gltfskel.roots[0]
	return gstate.get_scene_node(skel_node_idx)


static func create_joints_recursive(
	joint_chains: Array[PackedStringArray],
	skeleton: Skeleton3D,
	bone_idx: int,
	level: int,
	current_chain: int
):
	if current_chain == -1:
		current_chain = len(joint_chains)
		joint_chains.push_back(PackedStringArray())
	if current_chain != -1:
		joint_chains[current_chain].push_back(skeleton.get_bone_name(bone_idx))
	var bone_children = skeleton.get_bone_children(bone_idx)
	if bone_children.is_empty():
		if current_chain != -1:
			joint_chains[current_chain].push_back("")
	else:
		for i in range(len(bone_children)):
			var child_bone: int = bone_children[i]
			if i == 0:
				create_joints_recursive(
					joint_chains, skeleton, child_bone, level + 1, current_chain
				)
			else:
				create_joints_recursive(joint_chains, skeleton, child_bone, 0, -1)


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
	var nodes = gstate.get_nodes()
	var skeletons = gstate.get_skeletons()

	var skeleton_path: NodePath = secondary_node.get_path_to(
		secondary_node.get_parent().get_node("%GeneralSkeleton")
	)

	var offset_flip: Vector3 = Vector3(-1, 1, 1) if is_vrm_0 else Vector3(1, 1, 1)

	var collider_groups: Array[vrm_collider_group]
	for cgroup in vrm_extension["secondaryAnimation"]["colliderGroups"]:
		var gltfnode: GLTFNode = nodes[int(cgroup["node"])]
		var collider_group: vrm_collider_group = vrm_collider_group.new()
		var node_path: NodePath
		var bone: String = ""
		var new_resource_name: String = ""
		var pose_diff: Basis = Basis()
		if gltfnode.skeleton == -1:
			var found_node: Node = gstate.get_scene_node(int(cgroup["node"]))
			node_path = secondary_node.get_path_to(found_node)
			bone = ""
			new_resource_name = found_node.name
		else:
			var skeleton: Skeleton3D = _get_skel_godot_node(
				gstate, nodes, skeletons, gltfnode.skeleton
			)
			bone = nodes[int(cgroup["node"])].resource_name
			new_resource_name = bone
			pose_diff = pose_diffs[skeleton.find_bone(bone)]

		for collider_info in cgroup["colliders"]:
			var collider: vrm_collider = vrm_collider.new()
			collider.node_path = node_path
			collider.bone = bone
			collider.resource_name = new_resource_name
			var offset_obj = collider_info.get("offset", {"x": 0.0, "y": 0.0, "z": 0.0})
			var offset_vec = (
				offset_flip * Vector3(offset_obj["x"], offset_obj["y"], offset_obj["z"])
			)
			var local_pos: Vector3 = pose_diff * offset_vec
			var radius: float = collider_info.get("radius", 0.0)
			collider.is_capsule = false
			collider.offset = local_pos
			collider.tail = local_pos
			collider.radius = radius
			collider_group.colliders.append(collider)
		collider_groups.append(collider_group)

	var spring_bones: Array[vrm_spring_bone]
	for sbone in vrm_extension["secondaryAnimation"]["boneGroups"]:
		if sbone.get("bones", []).size() == 0:
			continue
		var first_bone_node: int = sbone["bones"][0]
		var gltfnode: GLTFNode = nodes[int(first_bone_node)]
		var skeleton: Skeleton3D = _get_skel_godot_node(gstate, nodes, skeletons, gltfnode.skeleton)

		var comment: String = sbone.get("comment", "")
		var stiffness_force = float(sbone.get("stiffiness", 1.0))
		var gravity_power = float(sbone.get("gravityPower", 0.0))
		var gravity_dir_json = sbone.get("gravityDir", {"x": 0.0, "y": -1.0, "z": 0.0})
		var gravity_dir = Vector3(
			gravity_dir_json["x"], gravity_dir_json["y"], gravity_dir_json["z"]
		)
		var drag_force = float(sbone.get("dragForce", 0.4))
		var hit_radius = float(sbone.get("hitRadius", 0.02))

		var spring_collider_groups: Array[vrm_collider_group]
		for cgroup_idx in sbone.get("colliderGroups", []):
			spring_collider_groups.append(collider_groups[int(cgroup_idx)])

		var joint_chains: Array[PackedStringArray]
		for bone_node in sbone["bones"]:
			create_joints_recursive(
				joint_chains,
				skeleton,
				skeleton.find_bone(nodes[int(bone_node)].resource_name),
				1,
				-1
			)

		var center_node: NodePath = NodePath()
		var center_bone: String = ""
		var center_node_idx = sbone.get("center", -1)
		if center_node_idx != -1:
			var center_gltfnode: GLTFNode = nodes[int(center_node_idx)]
			var bone_name: String = center_gltfnode.resource_name
			if (
				center_gltfnode.skeleton == gltfnode.skeleton
				and skeleton.find_bone(bone_name) != -1
			):
				center_bone = bone_name
				center_node = NodePath()
			else:
				center_bone = ""
				center_node = (secondary_node.get_path_to(
					gstate.get_scene_node(int(center_node_idx))
				))
				if center_node == NodePath():
					center_node = secondary_node.get_path_to(secondary_node)

		for chain in joint_chains:
			var spring_bone: vrm_spring_bone = vrm_spring_bone.new()
			spring_bone.comment = comment
			spring_bone.center_bone = center_bone
			spring_bone.center_node = center_node
			spring_bone.collider_groups = spring_collider_groups
			for bone_name in chain:
				spring_bone.joint_nodes.push_back(bone_name)
			spring_bone.stiffness_scale = stiffness_force
			spring_bone.gravity_scale = gravity_power
			spring_bone.gravity_dir_default = gravity_dir
			spring_bone.drag_force_scale = drag_force
			spring_bone.hit_radius_scale = hit_radius

			# Use a descriptive name combining group and first bone for readability
			if not comment.is_empty():
				spring_bone.resource_name = "%s · %s" % [comment.split("\n")[0], chain[0]]
			else:
				spring_bone.resource_name = chain[0]

			spring_bone.group = detect_group(chain[0], comment)
			spring_bones.append(spring_bone)

	# Sort by group so same-group bones appear together in the inspector
	spring_bones.sort_custom(func(a, b): return a.group < b.group)

	# Collect all colliders into a flat library for the inspector
	var collider_library: Array[vrm_collider] = []
	for cg in collider_groups:
		collider_library.append_array(cg.colliders)

	VRMLogger.debug(
		"vrm_secondary_service.gd",
		(
			"parse_secondary_node: parsed %d collider groups, %d spring bones"
			% [collider_groups.size(), spring_bones.size()]
		)
	)
	secondary_node.set_script(vrm_secondary)
	secondary_node.set("skeleton", skeleton_path)
	secondary_node.set("spring_bones", spring_bones)
	# Use untyped Array to avoid type-mismatch between preload-const and class_name
	secondary_node.set("collider_groups", Array(collider_groups))
	secondary_node.set("collider_library", Array(collider_library))
	secondary_node.set("use_gdscript_spring_bones", gstate.get_additional_data(&"vrm/use_gdscript"))
