extends GLTFDocumentExtension

enum DebugMode {
	None = 0,
	Normal = 1,
	LitShadeRate = 2,
}

enum FirstPersonFlag {
	Auto,  # Create headlessModel
	Both,  # Default layer
	ThirdPersonOnly,
	FirstPersonOnly,
	FirstWithShadow,
	Layers,
	LayersWithShadow,
	Ignore,
}

const vrm_constants_class = preload("../../core/vrm_constants.gd")
const vrm_meta_class = preload("../../core/vrm_meta.gd")
const vrm_secondary = preload("../../runtime/vrm_secondary.gd")
const vrm_collider_group = preload("../../runtime/vrm_collider_group.gd")
const vrm_collider = preload("../../runtime/vrm_collider.gd")
const vrm_spring_bone = preload("../../runtime/vrm_spring_bone.gd")
const vrm_instance = preload("../../core/vrm_instance.gd")

const importer_mesh_attributes = preload("../common/importer_mesh_attributes.gd")

const vrm_utils = preload("../common/vrm_utils.gd")

# Module preloads
const vrm_material_module = preload("./vrm_material.gd")
const vrm_first_person_module = preload("./vrm_first_person.gd")
const vrm_secondary_setup_module = preload("./vrm_secondary_setup.gd")

var vrm_meta: Resource = null

const vrm_resource_factory = preload("../common/vrm_resource_factory.gd")


func _create_meta(
	_root_node: Node,
	_animplayer: AnimationPlayer,
	vrm_extension: Dictionary,
	gstate: GLTFState,
	skeleton: Skeleton3D,
	humanBones: BoneMap,
	human_bone_to_idx: Dictionary,
	pose_diffs: Array[Basis]
) -> Resource:
	return vrm_resource_factory.create_meta_v0(
		vrm_extension, gstate, skeleton, humanBones, human_bone_to_idx, pose_diffs
	)


const vrm_animation_service = preload("../common/vrm_animation_service.gd")
const VRMLogger = preload("../../core/logger.gd")


func _create_animation_player(
	animplayer: AnimationPlayer,
	vrm_extension: Dictionary,
	gstate: GLTFState,
	human_bone_to_idx: Dictionary,
	pose_diffs: Array[Basis]
) -> AnimationPlayer:
	return vrm_animation_service.setup_animation_player_v0(
		animplayer, vrm_extension, gstate, human_bone_to_idx, pose_diffs
	)


func _add_joints_recursive(
	new_joints_set: Dictionary, gltf_nodes: Array, bone: int, include_child_meshes: bool = false
) -> void:
	vrm_animation_service.add_joints_recursive(
		new_joints_set, gltf_nodes, bone, include_child_meshes
	)


func _add_joint_set_as_skin(obj: Dictionary, new_joints_set: Dictionary) -> void:
	vrm_animation_service.add_joint_set_as_skin(obj, new_joints_set)


func _add_vrm_nodes_to_skin(obj: Dictionary) -> bool:
	return vrm_animation_service.add_vrm_nodes_to_skin_v0(obj)


func _import_preflight(
	gstate: GLTFState, extensions: PackedStringArray = PackedStringArray(), psa2: Variant = null
) -> Error:
	if extensions.has("VRMC_vrm"):
		# VRM 1.0 file. Do not parse as a VRM 0.0.
		return ERR_INVALID_DATA
	# Godot 4.6 bug: get_additional_data uses [] internally, triggering
	# "Dictionary::operator[] used when there was no value for the given key".
	# Workaround: use GLTFState meta instead of additional_data for this sentinel.
	if gstate.has_meta(&"vrm_already_processed"):
		return ERR_SKIP
	gstate.set_meta(&"vrm_already_processed", true)
	VRMLogger.debug("vrm_extension.gd", "_import_preflight: processing VRM 0.0 file")
	# Set default additional_data values so get_additional_data()
	# doesn't trigger Godot 4.6 operator[] dict bug on missing keys.
	# These may be overridden later by the import dialog (import_vrm.gd).
	gstate.set_additional_data(
		&"vrm/head_hiding_method", vrm_constants_class.HeadHidingSetting.ThirdPersonOnly
	)
	gstate.set_additional_data(&"vrm/first_person_layers", 2)
	gstate.set_additional_data(&"vrm/third_person_layers", 4)
	gstate.set_additional_data(&"vrm/remove_end_bones", true)
	var gltf_json_parsed: Dictionary = gstate.json
	var gltf_nodes = gltf_json_parsed["nodes"]
	if not _add_vrm_nodes_to_skin(gltf_json_parsed):
		VRMLogger.error("vrm_extension.gd", "Failed to find required VRM keys in json")
		return ERR_INVALID_DATA
	return OK


func _import_post_parse(state: GLTFState) -> Error:
	VRMLogger.debug("vrm_extension.gd", "_import_post_parse: %d nodes" % state.get_nodes().size())
	var nodes := state.get_nodes()
	for n in nodes:
		# GLTFNode has original_name (not 'name'). This was a leftover debug loop.
		if n.original_name == "Root":
			VRMLogger.debug(
				"vrm_extension.gd", "Found Root node: %s (skin=%d)" % [n.original_name, n.skin]
			)
	return OK


func _import_post(gstate: GLTFState, node: Node) -> Error:
	VRMLogger.info("vrm_extension.gd", "_import_post: starting VRM 0.0 import")
	var gltf: GLTFDocument = GLTFDocument.new()
	var root_node: Node = node

	var vrm_extension: Dictionary = gstate.json["extensions"]["VRM"]

	var human_bone_to_idx: Dictionary = {}
	for human_bone in vrm_extension["humanoid"]["humanBones"]:
		human_bone_to_idx[human_bone["bone"]] = int(human_bone["node"])
	VRMLogger.debug("vrm_extension.gd", "Mapped %d human bones" % human_bone_to_idx.size())

	var skeletons = gstate.get_skeletons()
	var hipsNode: GLTFNode = gstate.nodes[human_bone_to_idx["hips"]]
	var skeleton: Skeleton3D = vrm_animation_service._get_skel_godot_node(
		gstate, gstate.nodes, skeletons, hipsNode.skeleton
	)
	var gltfnodes: Array = gstate.nodes

	var humanBones: BoneMap = BoneMap.new()
	humanBones.profile = SkeletonProfileHumanoid.new()

	var vrm0_to_human_bone = vrm_constants_class.get_vrm_to_human_bone(true)

	for vrm_bone_name in human_bone_to_idx:
		if vrm0_to_human_bone.has(vrm_bone_name):
			humanBones.set_skeleton_bone_name(
				vrm0_to_human_bone[vrm_bone_name],
				gltfnodes[human_bone_to_idx[vrm_bone_name]].resource_name
			)
	VRMLogger.debug(
		"vrm_extension.gd", "BoneMap configured with %d bones" % human_bone_to_idx.size()
	)

	var pose_diffs: Array[Basis] = vrm_utils.perform_retarget(
		gstate, root_node, skeleton, humanBones
	)
	VRMLogger.debug(
		"vrm_extension.gd", "Retarget complete for %d bones" % skeleton.get_bone_count()
	)

	skeleton.set_meta("vrm_pose_diffs", pose_diffs)

	VRMLogger.debug("vrm_extension.gd", "Updating materials...")
	vrm_material_module.update_materials(vrm_extension, gstate)
	VRMLogger.debug("vrm_extension.gd", "Head hiding...")
	vrm_first_person_module.first_person_head_hiding(vrm_extension, gstate, human_bone_to_idx)

	var animplayer: AnimationPlayer
	if root_node.has_node("AnimationPlayer"):
		animplayer = root_node.get_node("AnimationPlayer")
	else:
		animplayer = AnimationPlayer.new()
		animplayer.name = "AnimationPlayer"
		root_node.add_child(animplayer, true)
		animplayer.owner = root_node

	_create_animation_player(animplayer, vrm_extension, gstate, human_bone_to_idx, pose_diffs)

	root_node.set_script(vrm_instance)

	if (
		vrm_extension.has("secondaryAnimation")
		and (
			vrm_extension["secondaryAnimation"].get("colliderGroups", []).size() > 0
			or vrm_extension["secondaryAnimation"].get("boneGroups", []).size() > 0
		)
	):
		VRMLogger.debug(
			"vrm_extension.gd", "Setting up secondary animation (spring bones/colliders)"
		)
		var secondary_node: Node = root_node.get_node_or_null("secondary")
		if secondary_node == null:
			secondary_node = Node3D.new()
			secondary_node.name = "secondary"
			root_node.add_child(secondary_node, true)

		vrm_secondary_setup_module.parse_secondary_node(
			secondary_node, vrm_extension, gstate, pose_diffs, true
		)
	else:
		VRMLogger.debug("vrm_extension.gd", "No secondary animation to set up")

	VRMLogger.debug("vrm_extension.gd", "Creating VRM meta resource...")
	var vrm_meta: Resource = _create_meta(
		root_node,
		animplayer,
		vrm_extension,
		gstate,
		skeleton,
		humanBones,
		human_bone_to_idx,
		pose_diffs
	)
	root_node.set("vrm_meta", vrm_meta)

	if gstate.get_additional_data(&"vrm/remove_end_bones"):
		vrm_utils.remove_end_bone_nodes(root_node, skeleton)

	VRMLogger.info("vrm_extension.gd", "_import_post: VRM 0.0 import complete OK")
	return OK
