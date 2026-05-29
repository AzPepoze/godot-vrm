@tool
extends GLTFDocumentExtension

const bone_node_constraint = preload("../../../node_constraint/bone_node_constraint.gd")
const bone_node_constraint_applier = preload(
	"../../../node_constraint/bone_node_constraint_applier.gd"
)


func _import_preflight(_state: GLTFState, extensions: PackedStringArray) -> Error:
	if extensions.has("VRMC_node_constraint"):
		return OK
	return ERR_SKIP


func _parse_node_extensions(
	gltf_state: GLTFState, gltf_node: GLTFNode, node_extensions: Dictionary
) -> Error:
	if not node_extensions.has("VRMC_node_constraint"):
		return OK
	var constraint_ext: Dictionary = node_extensions["VRMC_node_constraint"]
	var constraint: bone_node_constraint = bone_node_constraint.from_dictionary(constraint_ext)

	var node_index = -1
	var nodes = gltf_state.get_nodes()
	for i in range(nodes.size()):
		if nodes[i] == gltf_node:
			node_index = i
			break
	var scene_node = gltf_state.get_scene_node(node_index)
	if scene_node:
		var applier = bone_node_constraint_applier.new()
		applier.name = "VRMC_node_constraint"
		applier.constraint = constraint
		scene_node.add_child(applier)
		applier.owner = gltf_state.get_scene_node(0)

	return OK


func _export_preflight(_state: GLTFState, root: Node) -> Error:
	var appliers = root.find_children("*", "VRMNodeConstraintApplier", true, false)
	if appliers.is_empty():
		return ERR_SKIP
	return OK


func _export_node_extensions(
	state: GLTFState, _gltf_node: GLTFNode, node: Node, node_extensions: Dictionary
) -> Error:
	var applier = node.get_node_or_null("VRMC_node_constraint")
	if applier and applier is bone_node_constraint_applier:
		node_extensions["VRMC_node_constraint"] = applier.constraint.to_dictionary()
		state.add_used_extension("VRMC_node_constraint", false)
	return OK
