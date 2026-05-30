extends GLTFDocumentExtension

const vrm_secondary = preload("../../../runtime/vrm_secondary.gd")
const vrm_spring_bone_parser = preload("../../common/vrm_spring_bone_parser.gd")
const vrm_collider_group = preload("../../../runtime/vrm_collider_group.gd")
const VRMLogger = preload("../../../core/logger.gd")


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

	# Parse Colliders (v1 flat list)
	var colliders = vrm_spring_bone_parser.parse_colliders_v1(
		vrm_extension.get("colliders", []), gstate, secondary_node
	)

	# Parse Collider Groups referencing colliders by index
	var collider_groups: Array[VRMColliderGroup] = []
	for cgroup_json in vrm_extension.get("colliderGroups", []):
		var collider_group: vrm_collider_group = vrm_collider_group.new()
		for collider_idx in cgroup_json.get("colliders", []):
			collider_group.colliders.append(colliders[int(collider_idx)])
		collider_groups.append(collider_group)

	# Parse Spring Bones
	var spring_bones = vrm_spring_bone_parser.parse_springs_v1(
		vrm_extension.get("springs", []), gstate, collider_groups, secondary_node
	)

	# Determine skeleton path from first spring bone
	var skeleton_path: NodePath = NodePath()
	if not spring_bones.is_empty():
		var first_bone_name = spring_bones[0].joint_nodes[0]
		var skeleton = node.get_node_or_null("%GeneralSkeleton")
		if skeleton:
			skeleton_path = secondary_node.get_path_to(skeleton)

	secondary_node.set_script(vrm_secondary)
	secondary_node.set("skeleton", skeleton_path)
	secondary_node.set("spring_bones", Array(spring_bones))
	secondary_node.set("collider_groups", Array(collider_groups))
	secondary_node.set("collider_library", Array(colliders))

	return OK
