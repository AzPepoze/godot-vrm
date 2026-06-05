@tool
extends RefCounted

const VRMConstants = preload("../../core/vrm_constants.gd")
const ImporterMeshAttributes = preload("./importer_mesh_attributes.gd")
const VRMGLTFLookups = preload("./vrm_gltf_lookups.gd")


static func _generate_hide_bone_mesh(
    mesh: ImporterMesh, skin: Skin, bone_names_to_hide: Dictionary, blendshapes: Array
) -> ImporterMesh:
    var bind_indices_to_hide: Dictionary = {}
    for i in range(skin.get_bind_count()):
        var bind_name: StringName = skin.get_bind_name(i)
        if bind_name != &"":
            if bone_names_to_hide.has(bind_name):
                bind_indices_to_hide[i] = true
        else:
            if bone_names_to_hide.values().count(skin.get_bind_bone(i)) != 0:
                bind_indices_to_hide[i] = true

    var surf_count: int = mesh.get_surface_count()
    var surf_data_by_mesh = [].duplicate()
    var did_hide_any_surface_verts: bool = false
    for surf_idx in range(surf_count):
        var prim: int = mesh.get_surface_primitive_type(surf_idx)
        var fmt_compress_flags: int = mesh.get_surface_format(surf_idx)
        var arr: Array = mesh.get_surface_arrays(surf_idx).duplicate(true)
        var name: String = mesh.get_surface_name(surf_idx)
        var bscount = mesh.get_blend_shape_count()
        var bsarr: Array[Array] = []
        for bsidx in range(bscount):
            bsarr.append(mesh.get_surface_blend_shape_arrays(surf_idx, bsidx).duplicate(true))
        var mat: Material = mesh.get_surface_material(surf_idx)
        var vert_arr_len: int = len(arr[ArrayMesh.ARRAY_VERTEX])
        var hide_verts: PackedInt32Array
        hide_verts.resize(vert_arr_len)
        var did_hide_verts: bool = false
        if (
            typeof(arr[ArrayMesh.ARRAY_BONES]) == TYPE_PACKED_INT32_ARRAY
            and typeof(arr[ArrayMesh.ARRAY_WEIGHTS]) == TYPE_PACKED_FLOAT32_ARRAY
        ):
            var bonearr: PackedInt32Array = arr[ArrayMesh.ARRAY_BONES]
            var weightarr: PackedFloat32Array = arr[ArrayMesh.ARRAY_WEIGHTS]
            var bones_per_vert = len(bonearr) / vert_arr_len
            for i in range(vert_arr_len):
                for j in range(bones_per_vert):
                    if (
                        not is_zero_approx(weightarr[i * bones_per_vert + j])
                        and bind_indices_to_hide.has(bonearr[i * bones_per_vert + j])
                    ):
                        hide_verts[i] = 1
                        did_hide_verts = true
                        did_hide_any_surface_verts = true
                        break
        if did_hide_verts and prim == Mesh.PRIMITIVE_TRIANGLES:
            var indexarr: PackedInt32Array = arr[ArrayMesh.ARRAY_INDEX]
            var new_indexarr: PackedInt32Array = PackedInt32Array()
            var cnt: int = 0
            for i in range(0, len(indexarr) - 2, 3):
                if (
                    hide_verts[indexarr[i]] == 0
                    && hide_verts[indexarr[i + 1]] == 0
                    && hide_verts[indexarr[i + 2]] == 0
                ):
                    cnt += 3
            if cnt != 0:
                new_indexarr.resize(cnt)
                cnt = 0
                for i in range(0, len(indexarr) - 2, 3):
                    if (
                        hide_verts[indexarr[i]] == 0
                        && hide_verts[indexarr[i + 1]] == 0
                        && hide_verts[indexarr[i + 2]] == 0
                    ):
                        new_indexarr[cnt] = indexarr[i]
                        new_indexarr[cnt + 1] = indexarr[i + 1]
                        new_indexarr[cnt + 2] = indexarr[i + 2]
                        cnt += 3
                arr[ArrayMesh.ARRAY_INDEX] = new_indexarr
            else:
                continue

        surf_data_by_mesh.push_back(
            {
                "prim": prim,
                "arr": arr,
                "bsarr": bsarr,
                "fmt_compress_flags": fmt_compress_flags,
                "name": name,
                "mat": mat
            }
        )

    if len(surf_data_by_mesh) == 0:
        return null
    if not did_hide_any_surface_verts:
        return mesh

    var new_mesh: ImporterMesh = ImporterMesh.new()
    new_mesh.set_blend_shape_mode(mesh.get_blend_shape_mode())
    new_mesh.resource_name = mesh.resource_name + "_HeadHidden"
    if blendshapes.is_empty():
        for bsidx in mesh.get_blend_shape_count():
            blendshapes.append(mesh.get_blend_shape_name(bsidx))
    for blend_name in blendshapes:
        new_mesh.add_blend_shape(blend_name)
    for surf_idx in range(len(surf_data_by_mesh)):
        var s = surf_data_by_mesh[surf_idx]
        new_mesh.add_surface(s.prim, s.arr, s.bsarr, {}, s.mat, s.name, s.fmt_compress_flags)
    return new_mesh


static func perform_head_hiding(
    gstate: GLTFState,
    mesh_annotations_by_node: Dictionary,
    head_relative_bones: Dictionary,
    node_to_head_hidden_node: Dictionary
):
    var meshes = gstate.get_meshes()
    var nodes = gstate.get_nodes()
    var head_hiding_method_prop = gstate.get_additional_data(&"vrm/head_hiding_method")
    var head_hiding_method = (
        head_hiding_method_prop
        if typeof(head_hiding_method_prop) == TYPE_INT
        else VRMConstants.HeadHidingSetting.ThirdPersonOnly
    )
    if head_hiding_method == VRMConstants.HeadHidingSetting.IgnoreHeadHiding:
        return

    var layer_mask_first = (
        gstate.get_additional_data(&"vrm/first_person_layers")
        if typeof(gstate.get_additional_data(&"vrm/first_person_layers")) == TYPE_INT
        else 2
    )
    var layer_mask_third = (
        gstate.get_additional_data(&"vrm/third_person_layers")
        if typeof(gstate.get_additional_data(&"vrm/third_person_layers")) == TYPE_INT
        else 4
    )

    for node_idx in range(len(nodes)):
        var node_node: Node = gstate.get_scene_node(node_idx)
        if node_node is ImporterMeshInstance3D:
            var node := node_node as ImporterMeshInstance3D
            var flag: String = mesh_annotations_by_node.get(node_idx, "auto")
            var mesh: ImporterMesh = node.mesh
            var head_hidden_mesh: ImporterMesh = mesh
            if (
                flag == "auto"
                and head_hiding_method != VRMConstants.HeadHidingSetting.ThirdPersonOnly
            ):
                if node.skin == null:
                    var parent_node = node.get_parent()
                    if (
                        parent_node is BoneAttachment3D
                        and head_relative_bones.has(parent_node.bone_name)
                    ):
                        flag = "thirdPersonOnly"
                else:
                    var blend_shape_names: Dictionary = VRMGLTFLookups._extract_blendshape_names(
                        gstate.json
                    )
                    head_hidden_mesh = _generate_hide_bone_mesh(
                        mesh, node.skin, head_relative_bones, blend_shape_names.get(node_idx, [])
                    )
                    if head_hidden_mesh == null:
                        flag = "thirdPersonOnly"
                    elif head_hidden_mesh == mesh:
                        flag = "both"

            var layer_mask: int = layer_mask_first | layer_mask_third
            if flag == "thirdPersonOnly":
                layer_mask = layer_mask_third
                if head_hiding_method == VRMConstants.HeadHidingSetting.FirstPersonOnly:
                    node.mesh = null
                    continue
            elif flag == "firstPersonOnly":
                layer_mask = layer_mask_first
                if head_hiding_method == VRMConstants.HeadHidingSetting.ThirdPersonOnly:
                    node.mesh = null
                    continue

            node.script = ImporterMeshAttributes
            if flag == "auto" and head_hidden_mesh != mesh:
                if (
                    head_hiding_method
                    in [
                        VRMConstants.HeadHidingSetting.BothLayers,
                        VRMConstants.HeadHidingSetting.BothLayersWithShadow,
                        VRMConstants.HeadHidingSetting.FirstPersonOnlyWithShadow
                    ]
                ):
                    var head_hidden_node = ImporterMeshInstance3D.new()
                    head_hidden_node.name = node.name + " (Headless)"
                    head_hidden_node.skin = node.skin
                    head_hidden_node.mesh = head_hidden_mesh
                    head_hidden_node.skeleton_path = node.skeleton_path
                    head_hidden_node.script = ImporterMeshAttributes
                    node.add_sibling(head_hidden_node)
                    head_hidden_node.owner = node.owner
                    var gltf_mesh: GLTFMesh = GLTFMesh.new()
                    gltf_mesh.mesh = head_hidden_mesh
                    meshes.append(gltf_mesh)
                    node_to_head_hidden_node[node] = head_hidden_node
                    layer_mask = layer_mask_third
                elif head_hiding_method == VRMConstants.HeadHidingSetting.FirstPersonOnly:
                    for m in meshes:
                        if m.mesh == mesh:
                            m.mesh = head_hidden_mesh
                    node.mesh = head_hidden_mesh
    gstate.meshes = meshes
