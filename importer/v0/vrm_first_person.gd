@tool
extends RefCounted

const vrm_utils = preload("../common/vrm_utils.gd")


static func first_person_head_hiding(
    vrm_extension: Dictionary, gstate: GLTFState, human_bone_to_idx: Dictionary
) -> void:
    var nodes = gstate.get_nodes()
    var head_bone_idx: int = human_bone_to_idx["head"]
    var head_relative_bones: Dictionary = {}
    var skeletons: Array[GLTFSkeleton] = gstate.get_skeletons()
    if head_bone_idx != -1:
        var head_node: GLTFNode = nodes[head_bone_idx]
        var skeleton: Skeleton3D = gstate.get_scene_node(skeletons[head_node.skeleton].roots[0])
        vrm_utils._recurse_bones(
            head_relative_bones, skeleton, skeleton.find_bone(nodes[head_bone_idx].resource_name)
        )

    var mesh_annotations_by_node: Dictionary = {}
    for meshannotation in vrm_extension["firstPerson"].get("meshAnnotations", []):
        mesh_annotations_by_node[int(meshannotation["mesh"])] = meshannotation.get(
            "firstPersonFlag", "Auto"
        )

    var node_to_head_hidden_node: Dictionary = {}
    vrm_utils.perform_head_hiding(
        gstate, mesh_annotations_by_node, head_relative_bones, node_to_head_hidden_node
    )
