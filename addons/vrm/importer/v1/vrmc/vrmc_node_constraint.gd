@tool
extends GLTFDocumentExtension

const vrm_constraint = preload("../../../node_constraint/vrm_constraint.gd")
const vrm_constraint_applier = preload("../../../node_constraint/vrm_constraint_applier.gd")


func _import_preflight(
    _state: GLTFState, extensions: PackedStringArray = PackedStringArray()
) -> Error:
    if extensions.has("VRMC_node_constraint"):
        return OK
    return ERR_SKIP


func _import_post_parse_node(
    _state: GLTFState, gltf_node: GLTFNode, node_extensions: Dictionary
) -> Error:
    if node_extensions.has("VRMC_node_constraint"):
        var constraint_ext: Dictionary = node_extensions["VRMC_node_constraint"]
        var constraint: vrm_constraint = vrm_constraint.from_dictionary(constraint_ext)
        gltf_node.set_additional_data(&"vrm_constraint", constraint)
    return OK


func _import_post(gstate: GLTFState, root_node: Node) -> Error:
    var nodes = gstate.get_nodes()
    for i in range(nodes.size()):
        var gltf_node: GLTFNode = nodes[i]
        var constraint: vrm_constraint = gltf_node.get_additional_data(&"vrm_constraint")
        if constraint:
            var applier = vrm_constraint_applier.new()
            applier.name = "VRM_ConstraintApplier_" + str(i)
            var node = gstate.get_scene_node(i)
            node.add_child(applier, true)
            applier.owner = root_node
            applier.constraints.append(constraint)
    return OK


func _export_preflight(_state: GLTFState, root_node: Node) -> Error:
    var appliers: Array[Node] = root_node.find_children("*", "VRMConstraintApplier", true, false)
    if not appliers.is_empty():
        return OK
    return ERR_SKIP


func _export_post_parse_node(
    state: GLTFState, _root_node: Node, gltf_node: GLTFNode, node_extensions: Dictionary
) -> Error:
    var node: Node = state.get_scene_node(gltf_node.index)
    var applier: Node = null
    for child in node.get_children():
        if child is vrm_constraint_applier:
            applier = child
            break
    if applier and applier is vrm_constraint_applier:
        node_extensions["VRMC_node_constraint"] = applier.constraints[0].to_dictionary()
        state.add_used_extension("VRMC_node_constraint", false)
    return OK
