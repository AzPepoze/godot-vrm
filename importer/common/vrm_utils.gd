@tool
extends RefCounted

# Preload all the new modularized utilities
const VRMMeshOrientation = preload("./vrm_mesh_orientation.gd")
const VRMSkeletonRetargeting = preload("./vrm_skeleton_retargeting.gd")
const VRMHeadHiding = preload("./vrm_head_hiding.gd")
const VRMGLTFLookups = preload("./vrm_gltf_lookups.gd")
const VRMTransformUtils = preload("./vrm_transform_utils.gd")
const VRMSkeletonCleanup = preload("./vrm_skeleton_cleanup.gd")
const VRMConstants = preload("../../core/vrm_constants.gd")

# Re-export constants from VRMMeshOrientation
const ROTATE_180_BASIS = VRMMeshOrientation.ROTATE_180_BASIS
const ROTATE_180_TRANSFORM = VRMMeshOrientation.ROTATE_180_TRANSFORM


# Re-export functions from VRMMeshOrientation
static func adjust_mesh_zforward(mesh: ImporterMesh, blendshapes: Array):
    return VRMMeshOrientation.adjust_mesh_zforward(mesh, blendshapes)


static func rotate_scene_180_inner(p_node: Node3D, mesh_set: Dictionary, skin_set: Dictionary):
    return VRMMeshOrientation.rotate_scene_180_inner(p_node, mesh_set, skin_set)


static func rotate_scene_180(p_scene: Node3D, blend_shape_names: Dictionary, gstate: GLTFState):
    return VRMMeshOrientation.rotate_scene_180(p_scene, blend_shape_names, gstate)


static func apply_mesh_rotation(
    p_base_scene: Node,
    src_skeleton: Skeleton3D,
    old_skeleton_global_rest: Array[Transform3D],
    global_transform_scale_local: Vector3
):
    return VRMMeshOrientation.apply_mesh_rotation(
        p_base_scene, src_skeleton, old_skeleton_global_rest, global_transform_scale_local
    )


# Re-export functions from VRMSkeletonRetargeting
static func skeleton_rename(
    gstate: GLTFState, p_base_scene: Node, p_skeleton: Skeleton3D, p_bone_map: BoneMap
):
    return VRMSkeletonRetargeting.skeleton_rename(gstate, p_base_scene, p_skeleton, p_bone_map)


static func skeleton_rotate(
    _p_base_scene: Node,
    src_skeleton: Skeleton3D,
    p_bone_map: BoneMap,
    old_skeleton_global_rest: Array[Transform3D]
) -> Array[Basis]:
    return VRMSkeletonRetargeting.skeleton_rotate(
        _p_base_scene, src_skeleton, p_bone_map, old_skeleton_global_rest
    )


static func perform_retarget(
    gstate: GLTFState,
    root_node: Node,
    skeleton: Skeleton3D,
    bone_map: BoneMap,
    skeleton_name: String = "Skeleton3D",
    
) -> Array[Basis]:
    return VRMSkeletonRetargeting.perform_retarget(
        gstate, root_node, skeleton, bone_map, skeleton_name
    )


static func _recurse_bones(bones: Dictionary, skel: Skeleton3D, bone_idx: int):
    return VRMSkeletonRetargeting._recurse_bones(bones, skel, bone_idx)


# Re-export functions from VRMHeadHiding
static func perform_head_hiding(
    gstate: GLTFState,
    mesh_annotations_by_node: Dictionary,
    head_relative_bones: Dictionary,
    node_to_head_hidden_node: Dictionary
):
    return VRMHeadHiding.perform_head_hiding(
        gstate, mesh_annotations_by_node, head_relative_bones, node_to_head_hidden_node
    )


static func _generate_hide_bone_mesh(
    mesh: ImporterMesh, skin: Skin, bone_names_to_hide: Dictionary, blendshapes: Array
) -> ImporterMesh:
    return VRMHeadHiding._generate_hide_bone_mesh(mesh, skin, bone_names_to_hide, blendshapes)


# Re-export functions from VRMGLTFLookups
static func generate_mesh_index_to_meshinstance_mapping(gstate: GLTFState) -> Dictionary:
    return VRMGLTFLookups.generate_mesh_index_to_meshinstance_mapping(gstate)


static func _extract_blendshape_names(gltf_json: Dictionary) -> Dictionary:
    return VRMGLTFLookups._extract_blendshape_names(gltf_json)


# Re-export functions from VRMTransformUtils
static func apply_node_transforms(p_node: Node, p_skeleton: Skeleton3D) -> Vector3:
    return VRMTransformUtils.apply_node_transforms(p_node, p_skeleton)


# Re-export functions from VRMSkeletonCleanup
static func remove_end_bone_nodes(root_node: Node, skeleton: Skeleton3D) -> int:
    return VRMSkeletonCleanup.remove_end_bone_nodes(root_node, skeleton)


static func clear_all_bone_attachments(skeleton: Skeleton3D) -> void:
    VRMSkeletonCleanup.clear_all_bone_attachments(skeleton)


static func apply_default_import_settings(gstate: GLTFState) -> void:
    # Set default additional_data values so get_additional_data()
    # doesn't trigger Godot 4.6 operator[] dict bug on missing keys.
    # These may be overridden later by the import dialog (import_vrm.gd).
    
    var additional_data_defaults = {
        &"vrm_head_hiding_method": [&"vrm/head_hiding_method", VRMConstants.HeadHidingSetting.ThirdPersonOnly],
        &"vrm_first_person_layers": [&"vrm/first_person_layers", 2],
        &"vrm_third_person_layers": [&"vrm/third_person_layers", 4],
        &"vrm_remove_end_bones": [&"vrm/remove_end_bones", true],
        &"vrm_v1_rotate_180": [&"vrm/v1_rotate_180", true],
    }
    
    for meta_key in additional_data_defaults:
        if not gstate.has_meta(meta_key):
            gstate.set_additional_data(additional_data_defaults[meta_key][0], additional_data_defaults[meta_key][1])
            
    if not gstate.has_meta(&"vrm_skeleton_name"):
        gstate.set_meta(&"vrm_skeleton_name", "Skeleton3D")

