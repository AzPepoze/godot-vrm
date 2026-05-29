extends GLTFDocumentExtension

const vrm_constants_class = preload("../../core/vrm_constants.gd")
const vrm_meta_class = preload("../../core/vrm_meta.gd")
const vrm_secondary = preload("../../runtime/vrm_secondary.gd")
const vrm_top_level = preload("../../core/vrm_toplevel.gd")

const vrm_spring_bone = preload("../../runtime/vrm_spring_bone.gd")
const vrm_collider_group = preload("../../runtime/vrm_collider_group.gd")
const vrm_collider = preload("../../runtime/vrm_collider.gd")


func _get_skel_godot_node(gstate: GLTFState, nodes: Array, _skeletons: Array, skel_id: int) -> Node:
	# There's no working direct way to convert from skeleton_id to node_id.
	# Bugs:
	# GLTFNode.parent is -1 if skeleton bone.
	# skeleton_to_node is empty
	# get_scene_node(skeleton bone) works though might maybe return an attachment.
	# var skel_node_idx = nodes[gltfskel.roots[0]]
	# return gstate.get_scene_node(skel_node_idx) # as Skeleton
	if skel_id < 0:
		return null
	var skel_node_idx = -1
	for i in range(len(nodes)):
		if nodes[i].skeleton == skel_id:
			skel_node_idx = i
			break
	if skel_node_idx == -1:
		return null
	return gstate.get_scene_node(skel_node_idx)


func _import_preflight(
	_state: GLTFState, extensions: PackedStringArray = PackedStringArray()
) -> Error:
	if extensions.has("VRMC_springBone"):
		return OK
	return ERR_SKIP


func _import_post(gstate: GLTFState, node: Node) -> Error:
	var vrm_extension: Dictionary = gstate.json["extensions"]["VRMC_springBone"]
	var secondary_node: Node = node.get_node("secondary")
	if secondary_node == null:
		secondary_node = Node3D.new()
		secondary_node.name = "secondary"
		node.add_child(secondary_node, true)
		secondary_node.owner = node

	var nodes = gstate.get_nodes()
	var skeletons = gstate.get_skeletons()

	# Assume that all SpringBone are part of one skeleton for now.
	var skeleton_path: NodePath = secondary_node.get_path_to(
		secondary_node.get_parent().get_node("%GeneralSkeleton")
	)

	var collider_groups: Array[vrm_collider_group]
	for cgroup in vrm_extension.get("colliders", []):
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
			var pose_diffs = skeleton.get_meta("vrm_pose_diffs", [])
			if not pose_diffs.is_empty():
				pose_diff = pose_diffs[skeleton.find_bone(bone)]

		var collider: vrm_collider = vrm_collider.new()
		collider.node_path = node_path
		collider.bone = bone
		collider.resource_name = new_resource_name
		var shape = cgroup.get("shape", {})
		if shape.has("sphere"):
			var offset_obj = shape["sphere"].get("offset", [0.0, 0.0, 0.0])
			var offset_vec = Vector3(offset_obj[0], offset_obj[1], offset_obj[2])
			var local_pos: Vector3 = pose_diff * offset_vec
			collider.offset = local_pos
			collider.tail = local_pos
			collider.radius = shape["sphere"].get("radius", 0.0)
			collider.is_capsule = false
		elif shape.has("capsule"):
			var offset_obj = shape["capsule"].get("offset", [0.0, 0.0, 0.0])
			var offset_vec = Vector3(offset_obj[0], offset_obj[1], offset_obj[2])
			var local_pos: Vector3 = pose_diff * offset_vec
			collider.offset = local_pos
			var tail_obj = shape["capsule"].get("tail", [0.0, 0.0, 0.0])
			var tail_vec = Vector3(tail_obj[0], tail_obj[1], tail_obj[2])
			collider.tail = pose_diff * tail_vec
			collider.radius = shape["capsule"].get("radius", 0.0)
			collider.is_capsule = true
		collider_group.colliders.append(collider)
		collider_groups.append(collider_group)

	var spring_bones: Array[vrm_spring_bone]
	for sbone in vrm_extension.get("springs", []):
		var comment: String = sbone.get("name", "")
		var stiffness_force = float(sbone.get("stiffness", 1.0))
		var gravity_power = float(sbone.get("gravityPower", 0.0))
		var gravity_dir_json = sbone.get("gravityDir", [0.0, -1.0, 0.0])
		var gravity_dir = Vector3(gravity_dir_json[0], gravity_dir_json[1], gravity_dir_json[2])
		var drag_force = float(sbone.get("dragForce", 0.5))
		var hit_radius = float(sbone.get("hitRadius", 0.0))

		var spring_collider_groups: Array[vrm_collider_group]
		for cgroup_idx in sbone.get("colliders", []):
			spring_collider_groups.append(collider_groups[int(cgroup_idx)])

		var joint_chains: Array[PackedStringArray]
		var first_bone_node = -1
		for joint in sbone.get("joints", []):
			var bone_node = int(joint["node"])
			if first_bone_node == -1:
				first_bone_node = bone_node
			var gltfnode: GLTFNode = nodes[bone_node]
			var skeleton: Skeleton3D = _get_skel_godot_node(
				gstate, nodes, skeletons, gltfnode.skeleton
			)
			# VRM 1.0 joints are individual bones, not necessarily full chains.
			# But our spring bone logic expects chains.
			# For now we'll just treat each joint as a potential root.
			var chain = PackedStringArray(
				[skeleton.get_bone_name(skeleton.find_bone(gltfnode.resource_name))]
			)
			joint_chains.append(chain)

		var center_node: NodePath = NodePath()
		var center_bone: String = ""
		var center_node_idx = sbone.get("center", -1)
		if center_node_idx != -1:
			var center_gltfnode: GLTFNode = nodes[int(center_node_idx)]
			var bone_name: String = center_gltfnode.resource_name
			# Find a bone node to get its skeleton
			var gltfnode: GLTFNode = nodes[int(first_bone_node)]
			var skeleton: Skeleton3D = _get_skel_godot_node(
				gstate, nodes, skeletons, gltfnode.skeleton
			)
			if (
				center_gltfnode.skeleton == gltfnode.skeleton
				and skeleton.find_bone(bone_name) != -1
			):
				center_bone = bone_name
				center_node = NodePath()
			else:
				center_bone = ""
				center_node = secondary_node.get_path_to(
					gstate.get_scene_node(int(center_node_idx))
				)
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

			if not comment.is_empty():
				spring_bone.resource_name = comment.split("\n")[0]
			else:
				spring_bone.resource_name = chain[0]

			spring_bones.append(spring_bone)

	secondary_node.set_script(vrm_secondary)
	secondary_node.set("skeleton", skeleton_path)
	secondary_node.set("spring_bones", spring_bones)

	return OK
