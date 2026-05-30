extends GLTFDocumentExtension

const vrm_constants_class = preload("../../../core/vrm_constants.gd")
const vrm_meta_class = preload("../../../core/vrm_meta.gd")
const vrm_secondary = preload("../../../runtime/vrm_secondary.gd")
const vrm_top_level = preload("../../../core/vrm_toplevel.gd")

const vrm_spring_bone = preload("../../../runtime/vrm_spring_bone.gd")
const vrm_collider_group = preload("../../../runtime/vrm_collider_group.gd")
const vrm_collider = preload("../../../runtime/vrm_collider.gd")
const vrm_secondary_service = preload("../../common/vrm_secondary_service.gd")
const VRMLogger = preload("../../../core/logger.gd")


func _get_skel_godot_node(gstate: GLTFState, _nodes: Array, skeletons: Array, skel_id: int) -> Node:
	if skel_id < 0 or skel_id >= skeletons.size():
		return null
	var gltfskel: GLTFSkeleton = skeletons[skel_id]
	if gltfskel.roots.is_empty():
		return null
	var skel_node_idx = gltfskel.roots[0]
	return gstate.get_scene_node(skel_node_idx)


func _import_preflight(
	_state: GLTFState, extensions: PackedStringArray = PackedStringArray()
) -> Error:
	if extensions.has("VRMC_springBone"):
		return OK
	return ERR_SKIP


func _import_post(gstate: GLTFState, node: Node) -> Error:
	var vrm_extension: Dictionary = gstate.json["extensions"]["VRMC_springBone"]
	var secondary_node: Node = node.get_node_or_null("secondary")
	if secondary_node == null:
		secondary_node = Node3D.new()
		secondary_node.name = "secondary"
		node.add_child(secondary_node, true)
		secondary_node.owner = node

	var nodes = gstate.get_nodes()
	var skeletons = gstate.get_skeletons()

	# Parse flat colliders list (VRM 1.0 spec: each entry is one collider shape)
	var colliders: Array[vrm_collider] = []
	for collider_json in vrm_extension.get("colliders", []):
		var gltfnode: GLTFNode = nodes[int(collider_json["node"])]
		var collider: vrm_collider = vrm_collider.new()
		var node_path: NodePath
		var bone: String = ""
		var new_resource_name: String = ""
		var pose_diff: Basis = Basis()
		if gltfnode.skeleton == -1:
			var found_node: Node = gstate.get_scene_node(int(collider_json["node"]))
			node_path = secondary_node.get_path_to(found_node)
			new_resource_name = found_node.name
		else:
			var skeleton: Skeleton3D = _get_skel_godot_node(
				gstate, nodes, skeletons, gltfnode.skeleton
			)
			bone = nodes[int(collider_json["node"])].resource_name
			new_resource_name = bone
			if skeleton != null:
				var pose_diffs = skeleton.get_meta("vrm_pose_diffs", [])
				if not pose_diffs.is_empty():
					pose_diff = pose_diffs[skeleton.find_bone(bone)]

		collider.node_path = node_path
		collider.bone = bone
		collider.resource_name = new_resource_name
		var shape = collider_json.get("shape", {})
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
		colliders.append(collider)

	# Parse colliderGroups referencing colliders by index (VRM 1.0 spec)
	var collider_groups: Array[vrm_collider_group] = []
	for cgroup_json in vrm_extension.get("colliderGroups", []):
		var collider_group: vrm_collider_group = vrm_collider_group.new()
		for collider_idx in cgroup_json.get("colliders", []):
			collider_group.colliders.append(colliders[int(collider_idx)])
		collider_groups.append(collider_group)

	var spring_bones: Array[vrm_spring_bone]
	var skeleton_path: NodePath = NodePath()
	for sbone in vrm_extension.get("springs", []):
		var comment: String = sbone.get("name", "")
		var spring_bone: vrm_spring_bone = vrm_spring_bone.new()
		spring_bone.comment = comment

		var spring_collider_groups: Array[vrm_collider_group]
		for cgroup_idx in sbone.get("colliders", []):
			spring_collider_groups.append(collider_groups[int(cgroup_idx)])
		spring_bone.collider_groups = spring_collider_groups

		var first_bone_node = -1
		for joint_json in sbone.get("joints", []):
			var bone_node = int(joint_json["node"])
			if first_bone_node == -1:
				first_bone_node = bone_node
			var gltfnode: GLTFNode = nodes[bone_node]
			var bone_name: String = gltfnode.resource_name
			var skeleton: Skeleton3D = _get_skel_godot_node(
				gstate, nodes, skeletons, gltfnode.skeleton
			)
			if skeleton == null:
				continue
			if skeleton_path.is_empty():
				skeleton_path = secondary_node.get_path_to(skeleton)

			if skeleton.find_bone(bone_name) == -1:
				VRMLogger.error(
					"vrmc_spring_bone.gd", "Failed to find bone %s in skeleton" % bone_name
				)
				continue

			spring_bone.joint_nodes.append(bone_name)
			spring_bone.stiffness_force.append(float(joint_json.get("stiffness", 1.0)))
			spring_bone.gravity_power.append(float(joint_json.get("gravityPower", 0.0)))
			var gdir_json = joint_json.get("gravityDir", [0.0, -1.0, 0.0])
			spring_bone.gravity_dir.append(Vector3(gdir_json[0], gdir_json[1], gdir_json[2]))
			spring_bone.drag_force.append(float(joint_json.get("dragForce", 0.5)))
			spring_bone.hit_radius.append(float(joint_json.get("hitRadius", 0.0)))

		if spring_bone.joint_nodes.is_empty():
			continue

		# VRM 1.0 spec allows different parameters per joint.
		# We use the first joint's values as the base scale and normalize the arrays if they are uniform.
		if not spring_bone.stiffness_force.is_empty():
			spring_bone.stiffness_scale = spring_bone.stiffness_force[0]
			if (
				spring_bone.stiffness_force.count(spring_bone.stiffness_scale)
				== spring_bone.stiffness_force.size()
			):
				spring_bone.stiffness_force.clear()
			elif spring_bone.stiffness_scale > 0.0:
				for i in range(spring_bone.stiffness_force.size()):
					spring_bone.stiffness_force[i] /= spring_bone.stiffness_scale
			else:
				spring_bone.stiffness_scale = 1.0

		if not spring_bone.gravity_power.is_empty():
			spring_bone.gravity_scale = spring_bone.gravity_power[0]
			if (
				spring_bone.gravity_power.count(spring_bone.gravity_scale)
				== spring_bone.gravity_power.size()
			):
				spring_bone.gravity_power.clear()
			elif spring_bone.gravity_scale > 0.0:
				for i in range(spring_bone.gravity_power.size()):
					spring_bone.gravity_power[i] /= spring_bone.gravity_scale
			else:
				spring_bone.gravity_scale = 1.0

		if not spring_bone.drag_force.is_empty():
			spring_bone.drag_force_scale = spring_bone.drag_force[0]
			if (
				spring_bone.drag_force.count(spring_bone.drag_force_scale)
				== spring_bone.drag_force.size()
			):
				spring_bone.drag_force.clear()
			elif spring_bone.drag_force_scale > 0.0:
				for i in range(spring_bone.drag_force.size()):
					spring_bone.drag_force[i] /= spring_bone.drag_force_scale
			else:
				spring_bone.drag_force_scale = 1.0

		if not spring_bone.hit_radius.is_empty():
			spring_bone.hit_radius_scale = spring_bone.hit_radius[0]
			if (
				spring_bone.hit_radius.count(spring_bone.hit_radius_scale)
				== spring_bone.hit_radius.size()
			):
				spring_bone.hit_radius.clear()
			elif spring_bone.hit_radius_scale > 0.0:
				for i in range(spring_bone.hit_radius.size()):
					spring_bone.hit_radius[i] /= spring_bone.hit_radius_scale
			else:
				spring_bone.hit_radius_scale = 1.0

		if not spring_bone.gravity_dir.is_empty():
			spring_bone.gravity_dir_default = spring_bone.gravity_dir[0]
			if (
				spring_bone.gravity_dir.count(spring_bone.gravity_dir_default)
				== spring_bone.gravity_dir.size()
			):
				spring_bone.gravity_dir.clear()

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
				skeleton != null
				and center_gltfnode.skeleton == gltfnode.skeleton
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

		spring_bone.center_bone = center_bone
		spring_bone.center_node = center_node

		# Use a descriptive name combining group and first bone for readability
		if not comment.is_empty():
			spring_bone.resource_name = (
				"%s · %s" % [comment.split("\n")[0], spring_bone.joint_nodes[0]]
			)
		else:
			spring_bone.resource_name = spring_bone.joint_nodes[0]

		spring_bone.group = vrm_secondary_service.detect_group(spring_bone.joint_nodes[0], comment)
		spring_bones.append(spring_bone)

	# Sort by group so same-group bones appear together in the inspector
	spring_bones.sort_custom(func(a, b): return a.group < b.group)

	secondary_node.set_script(vrm_secondary)
	secondary_node.set("skeleton", skeleton_path)
	secondary_node.set("spring_bones", spring_bones)
	secondary_node.set("use_gdscript_spring_bones", gstate.get_additional_data(&"vrm/use_gdscript"))
	# Use untyped Array to avoid type-mismatch between preload-const and class_name
	secondary_node.set("collider_groups", Array(collider_groups))
	secondary_node.set("collider_library", Array(colliders))

	return OK
