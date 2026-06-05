@tool
extends RefCounted

const VRMLogger = preload("../../core/logger.gd")
const vrm_constants_class = preload("../../core/vrm_constants.gd")
const vrm_material_processor = preload("../common/vrm_material_processor.gd")


static func process_khr_material(
    orig_mat: StandardMaterial3D, gltf_mat_props: Dictionary
) -> Material:
    if gltf_mat_props.has("extensions") and gltf_mat_props["extensions"].has("KHR_materials_unlit"):
        orig_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        # TODO: validate that this is sufficient.
    return orig_mat


static func vrm_get_texture_info(
    gstate: GLTFState, vrm_mat_props: Dictionary, unity_tex_name: String
) -> Dictionary:
    return vrm_material_processor.get_texture_info_v0(gstate, vrm_mat_props, unity_tex_name)


static func vrm_get_float(vrm_mat_props: Dictionary, key: String, def: float) -> float:
    return vrm_mat_props["floatProperties"].get(key, def)


static func process_vrm_material(
    orig_mat: Material, gstate: GLTFState, vrm_mat_props: Dictionary
) -> Material:
    return vrm_material_processor.process_vrm_material_v0(orig_mat, gstate, vrm_mat_props)


static func update_materials(vrm_extension: Dictionary, gstate: GLTFState) -> void:
    var images = gstate.get_images()
    VRMLogger.debug(
        "vrm_material.gd",
        (
            "update_materials: processing %d images for %d materials"
            % [images.size(), gstate.get_materials().size()]
        )
    )
    var materials: Array = gstate.get_materials()
    var spatial_to_shader_mat: Dictionary = {}

    # Render priority setup
    var render_queue_to_priority: Array = []
    var negative_render_queue_to_priority: Array = []
    var uniq_render_queues: Dictionary = {}
    for i in range(materials.size()):
        var vrm_mat_props: Dictionary = vrm_extension["materialProperties"][i]
        var render_queue = int(vrm_mat_props.get("renderQueue", 2000))
        if not uniq_render_queues.has(render_queue):
            uniq_render_queues[render_queue] = true
            if render_queue >= 2000:
                render_queue_to_priority.append(render_queue)
            else:
                negative_render_queue_to_priority.append(-render_queue)
    render_queue_to_priority.sort()
    negative_render_queue_to_priority.sort()

    for i in range(materials.size()):
        var oldmat: Material = materials[i]
        if oldmat is ShaderMaterial:
            # Indicates that the user asked to keep existing materials. Avoid changing them.
            VRMLogger.debug(
                "vrm_material.gd",
                "Material %d: %s already is shader, skipping" % [i, oldmat.resource_name]
            )
            continue
        var vrm_mat_props: Dictionary = vrm_extension["materialProperties"][i]
        var newmat: Material = process_vrm_material(oldmat, gstate, vrm_mat_props)
        spatial_to_shader_mat[oldmat] = newmat
        spatial_to_shader_mat[newmat] = newmat
        VRMLogger.debug(
            "vrm_material.gd",
            (
                "Replacing shader %s/%s with %s/%s"
                % [oldmat, oldmat.resource_name, newmat, newmat.resource_name]
            )
        )

        # Render priority
        var render_queue = int(vrm_mat_props.get("renderQueue", 2000))
        var delta_render_queue = render_queue - 2000
        var target_render_priority = 0
        if delta_render_queue >= 0:
            target_render_priority = render_queue_to_priority.find(render_queue)
            if target_render_priority > 100:
                target_render_priority = 100
        else:
            target_render_priority = -negative_render_queue_to_priority.find(-render_queue)
            if target_render_priority < -100:
                target_render_priority = -100
        # render_priority only makes sense for transparent materials.
        if newmat.get_class() == "StandardMaterial3D":
            if int(newmat.transparency) > 0:
                newmat.render_priority = target_render_priority
        else:
            var blend_mode = int(vrm_mat_props["floatProperties"].get("_BlendMode", 0))
            if (
                blend_mode == int(vrm_constants_class.RenderMode.Transparent)
                or blend_mode == int(vrm_constants_class.RenderMode.TransparentWithZWrite)
            ):
                newmat.render_priority = target_render_priority
        materials[i] = newmat
        var oldpath = oldmat.resource_path
        if oldpath.is_empty():
            continue
        newmat.take_over_path(oldpath)
        ResourceSaver.save(newmat, oldpath)
    gstate.set_materials(materials)

    var meshes = gstate.get_meshes()
    for i in range(meshes.size()):
        var gltfmesh: GLTFMesh = meshes[i]
        var mesh = gltfmesh.mesh
        mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
        for surf_idx in range(mesh.get_surface_count()):
            var surfmat = mesh.get_surface_material(surf_idx)
            if spatial_to_shader_mat.has(surfmat):
                mesh.set_surface_material(surf_idx, spatial_to_shader_mat[surfmat])
            else:
                # It is possible that the material was not in the materials array.
                # This happens with some glTF files.
                # In this case, we just keep the material as is.
                pass
