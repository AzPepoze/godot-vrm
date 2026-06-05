extends GLTFDocumentExtension

const VRMLogger = preload("../../../core/logger.gd")
const vrm_constants_class = preload("../../../core/vrm_constants.gd")
const vrm_bone_renamer_humanoid = preload("../../../importer/common/vrm_bone_renamer_humanoid.gd")
const vrm_meta_class = preload("../../../core/vrm_meta.gd")
const vrm_instance = preload("../../../core/vrm_instance.gd")
const vrm_utils = preload("../../../importer/common/vrm_utils.gd")

const importer_mesh_attributes = preload("../../../importer/common/importer_mesh_attributes.gd")

var vrm_meta: Resource = null


func _get_skel_godot_node(gstate: GLTFState, nodes: Array, skeletons: Array, skel_id: int) -> Node:
    if skel_id < 0 or skel_id >= skeletons.size():
        return null
    var gltfskel: GLTFSkeleton = skeletons[skel_id]
    if gltfskel.roots.is_empty():
        return null
    var skel_node_idx = gltfskel.roots[0]
    return gstate.get_scene_node(skel_node_idx)


const vrm_resource_factory = preload("../../../importer/common/vrm_resource_factory.gd")


func _create_meta(
    _root_node: Node,
    _animplayer: AnimationPlayer,
    vrm_extension: Dictionary,
    gstate: GLTFState,
    _skeleton: Skeleton3D,
    humanBones: BoneMap,
    _human_bone_to_idx: Dictionary,
    _pose_diffs: Array[Basis]
) -> Resource:
    return vrm_resource_factory.create_meta_v1(vrm_extension, gstate, humanBones)


static func _validate_meta(vrm_meta: Resource) -> PackedStringArray:
    if vrm_meta == null:
        return PackedStringArray(["vrm_meta"])
    var missing: PackedStringArray = []
    for prop in [
        "allowed_user_name",
        "violent_usage",
        "sexual_usage",
        "commercial_usage_type",
        "political_religious_usage",
        "antisocial_hate_usage",
        "credit_notation",
        "allow_redistribution",
        "modification",
        "title"
    ]:
        var val: Variant = vrm_meta.get(prop)
        if typeof(val) != TYPE_STRING or val.strip_edges() == "":
            missing.append(prop)
    if vrm_meta.get("authors").is_empty():
        missing.append("authors")
    return missing


func _export_meta(vrm_meta: Resource, vrm_extension: Dictionary, _gstate: GLTFState):
    vrm_resource_factory.export_meta_v1(vrm_meta, vrm_extension)


const vrm_animation_service = preload("../../../importer/common/vrm_animation_service.gd")


func _create_animation_player(
    animplayer: AnimationPlayer,
    vrm_extension: Dictionary,
    gstate: GLTFState,
    human_bone_to_idx: Dictionary,
    pose_diffs: Array[Basis]
) -> AnimationPlayer:
    return vrm_animation_service.setup_animation_player_v1(
        animplayer, vrm_extension, gstate, human_bone_to_idx, pose_diffs
    )


func _export_animations(
    root_node: Node,
    skel: Skeleton3D,
    animplayer: AnimationPlayer,
    vrm_extension: Dictionary,
    gstate: GLTFState
):
    vrm_animation_service.export_animations_v1(root_node, skel, animplayer, vrm_extension, gstate)


func _add_joints_recursive(
    new_joints_set: Dictionary, gltf_nodes: Array, bone: int, include_child_meshes: bool = false
) -> void:
    vrm_animation_service.add_joints_recursive(
        new_joints_set, gltf_nodes, bone, include_child_meshes
    )


func _add_joint_set_as_skin(obj: Dictionary, new_joints_set: Dictionary) -> void:
    vrm_animation_service.add_joint_set_as_skin(obj, new_joints_set)


func _add_vrm_nodes_to_skin(obj: Dictionary) -> bool:
    return vrm_animation_service.add_vrm_nodes_to_skin_v1(obj)


func remove_null_owner(node: Node):
    if node.owner == null:
        var parent = node.get_parent()
        if parent:
            parent.remove_child(node)
        node.queue_free()
        return
    for child in node.get_children():
        remove_null_owner(child)


func _export_preflight(state: GLTFState, root: Node) -> Error:
    VRMLogger.info("vrmc_vrm.gd", "_export_preflight: starting VRM 1.0 export")
    var vrm_meta_node = root.get("vrm_meta")
    if vrm_meta_node == null:
        VRMLogger.debug("vrmc_vrm.gd", "_export_preflight: no vrm_meta found, skipping")
        return ERR_SKIP

    # Duplicate root so we can modify it.
    var new_root = root.duplicate()
    remove_null_owner(new_root)

    var vrm_extension: Dictionary = {}
    vrm_extension["specVersion"] = "1.0"
    _export_meta(vrm_meta_node, vrm_extension, state)

    # TODO: humanoid, lookAt, expressions, secondaryAnimation, etc.
    # This is a very barebones export.

    # Store the extension data to be injected in _export_post
    state.set_additional_data(&"vrmc_vrm_dict", vrm_extension)
    state.add_used_extension("VRMC_vrm", false)

    VRMLogger.info("vrmc_vrm.gd", "_export_preflight: VRM 1.0 export prepared OK")
    return OK


func _export_post(state: GLTFState) -> Error:
    print("--- _export_post called in vrmc_vrm.gd ---")
    var vrm_extension = state.get_additional_data(&"vrmc_vrm_dict")
    print("vrm_extension is: ", vrm_extension)
    if vrm_extension == null:
        return ERR_SKIP

    if state.json.get("extensions") == null:
        state.json["extensions"] = {}
    state.json["extensions"]["VRMC_vrm"] = vrm_extension

    VRMLogger.info("vrmc_vrm.gd", "_export_post: injected VRMC_vrm extension into JSON")
    return OK


func _import_preflight(
    _state: GLTFState, extensions: PackedStringArray = PackedStringArray(), _psa2: Variant = null
) -> Error:
    if not extensions.has("VRMC_vrm"):
        return ERR_SKIP
    _state.set_additional_data(&"vrm/remove_end_bones", true)
    _state.set_additional_data(&"vrm/skeleton_name", "Skeleton3D")
    return OK


func _import_post_parse(state: GLTFState) -> Error:
    var gltf_json_parsed: Dictionary = state.json
    if not _add_vrm_nodes_to_skin(gltf_json_parsed):
        VRMLogger.error("vrmc_vrm.gd", "Failed to find required VRM keys in json")
        return ERR_INVALID_DATA

    return OK


func _import_post(gstate: GLTFState, node: Node) -> Error:
    VRMLogger.info("vrmc_vrm.gd", "_import_post: starting VRM 1.0 import")
    var root_node: Node = node

    var vrm_extension: Dictionary = gstate.json["extensions"]["VRMC_vrm"]

    var humanBones_json: Dictionary = vrm_extension["humanoid"]["humanBones"]
    var human_bone_to_idx: Dictionary = {}
    for human_bone_name in humanBones_json:
        human_bone_to_idx[human_bone_name] = int(humanBones_json[human_bone_name]["node"])
    VRMLogger.debug("vrmc_vrm.gd", "_import_post: mapped %d human bones" % human_bone_to_idx.size())

    var skeletons = gstate.get_skeletons()
    var hipsNode: GLTFNode = gstate.nodes[human_bone_to_idx["hips"]]
    var skeleton: Skeleton3D = _get_skel_godot_node(
        gstate, gstate.nodes, skeletons, hipsNode.skeleton
    )
    var gltfnodes: Array = gstate.nodes

    var humanBones: BoneMap = vrm_bone_renamer_humanoid.create_humanoid_bone_map(
        gstate, human_bone_to_idx, false
    )

    var skeleton_name_val = gstate.get_additional_data(&"vrm/skeleton_name")
    var skeleton_name: String = "Skeleton3D"
    if skeleton_name_val is String and not skeleton_name_val.is_empty():
        skeleton_name = skeleton_name_val

    var do_retarget = true

    var pose_diffs: Array[Basis]
    if do_retarget:
        VRMLogger.debug(
            "vrmc_vrm.gd",
            "_import_post: performing retarget for %d bones" % skeleton.get_bone_count()
        )
        pose_diffs = vrm_utils.perform_retarget(
            gstate, root_node, skeleton, humanBones, skeleton_name
        )
        VRMLogger.debug("vrmc_vrm.gd", "_import_post: retarget complete")
    else:
        # resize is busted for TypedArray and crashes Godot
        for i in range(skeleton.get_bone_count()):
            pose_diffs.append(Basis.IDENTITY)

    skeleton.set_meta("vrm_pose_diffs", pose_diffs)

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

    vrm_utils.clear_all_bone_attachments(skeleton)

    VRMLogger.info("vrmc_vrm.gd", "_import_post: VRM 1.0 import complete OK")
    return OK
