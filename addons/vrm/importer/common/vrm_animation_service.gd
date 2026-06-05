@tool
extends RefCounted

# Preload all the new modules
const vrm_animation_constants = preload("./animation/vrm_animation_constants.gd")
const vrm_animation_v0 = preload("../v0/vrm_animation.gd")
const vrm_animation_v1 = preload("../v1/vrm_animation_import.gd")
const vrm_animation_export = preload("../v1/vrm_animation_export.gd")

# Re-export constants
const vrm0_to_vrm1_presets: Dictionary = vrm_animation_constants.vrm0_to_vrm1_presets
const vrm_animation_to_look_at: Dictionary = vrm_animation_constants.vrm_animation_to_look_at
const vrm_animation_presets: Dictionary = vrm_animation_constants.vrm_animation_presets


# Re-export VRM0 functions
static func _get_skel_godot_node(
    gstate: GLTFState, nodes: Array, skeletons: Array, skel_id: int
) -> Node:
    return vrm_animation_v0._get_skel_godot_node(gstate, nodes, skeletons, skel_id)


static func setup_animation_player_v0(
    animplayer: AnimationPlayer,
    vrm_extension: Dictionary,
    gstate: GLTFState,
    human_bone_to_idx: Dictionary,
    pose_diffs: Array[Basis]
) -> AnimationPlayer:
    return vrm_animation_v0.setup_animation_player_v0(
        animplayer, vrm_extension, gstate, human_bone_to_idx, pose_diffs
    )


# Re-export VRM1 functions
static func setup_animation_player_v1(
    animplayer: AnimationPlayer,
    vrm_extension: Dictionary,
    gstate: GLTFState,
    human_bone_to_idx: Dictionary,
    pose_diffs: Array[Basis]
) -> AnimationPlayer:
    return vrm_animation_v1.setup_animation_player_v1(
        animplayer, vrm_extension, gstate, human_bone_to_idx, pose_diffs
    )


static func create_animation_v1(
    default_values: Dictionary,
    default_blend_shapes: Dictionary,
    anim_name: String,
    expression: Dictionary,
    animplayer: AnimationPlayer,
    gstate: GLTFState,
    material_idx_to_mesh_and_surface_idx: Dictionary,
    mesh_idx_to_meshinstance: Dictionary,
    node_to_head_hidden_node: Dictionary,
    look_at: Dictionary
) -> Animation:
    return vrm_animation_v1.create_animation_v1(
        default_values,
        default_blend_shapes,
        anim_name,
        expression,
        animplayer,
        gstate,
        material_idx_to_mesh_and_surface_idx,
        mesh_idx_to_meshinstance,
        node_to_head_hidden_node,
        look_at
    )


# Re-export functions
static func export_animations_v1(
    root_node: Node,
    skel: Skeleton3D,
    animplayer: AnimationPlayer,
    vrm_extension: Dictionary,
    gstate: GLTFState
):
    return vrm_animation_export.export_animations_v1(
        root_node, skel, animplayer, vrm_extension, gstate
    )


static func add_joints_recursive(
    new_joints_set: Dictionary, gltf_nodes: Array, bone: int, include_child_meshes: bool = false
) -> void:
    return vrm_animation_export.add_joints_recursive(
        new_joints_set, gltf_nodes, bone, include_child_meshes
    )


static func add_joint_set_as_skin(obj: Dictionary, new_joints_set: Dictionary) -> void:
    return vrm_animation_export.add_joint_set_as_skin(obj, new_joints_set)


static func add_vrm_nodes_to_skin_v0(obj: Dictionary) -> bool:
    return vrm_animation_export.add_vrm_nodes_to_skin_v0(obj)


static func add_vrm_nodes_to_skin_v1(obj: Dictionary) -> bool:
    return vrm_animation_export.add_vrm_nodes_to_skin_v1(obj)
