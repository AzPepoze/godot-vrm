@tool
extends RefCounted


static func generate_mesh_index_to_meshinstance_mapping(gstate: GLTFState) -> Dictionary:
    var nodes = gstate.get_nodes()
    var mesh_idx_to_meshinstance: Dictionary = {}
    for i in range(nodes.size()):
        var gltfnode: GLTFNode = nodes[i]
        var mesh_idx: int = gltfnode.mesh
        if mesh_idx != -1:
            var scenenode: ImporterMeshInstance3D = gstate.get_scene_node(i)
            mesh_idx_to_meshinstance[mesh_idx] = scenenode
    return mesh_idx_to_meshinstance


static func _extract_blendshape_names(gltf_json: Dictionary) -> Dictionary:
    var blend_shape_names: Dictionary = {}
    for node_json in gltf_json["nodes"]:
        if node_json.has("mesh"):
            var prims = gltf_json["meshes"][node_json["mesh"]]["primitives"]
            if prims[0].has("extras") and prims[0]["extras"].has("targetNames"):
                blend_shape_names[int(node_json["mesh"])] = prims[0]["extras"]["targetNames"]
    return blend_shape_names
