extends GLTFDocumentExtension

const VRMLogger = preload("../../../core/logger.gd")


func _import_preflight(state: GLTFState, extensions = PackedStringArray()) -> Error:
    if extensions.has("VRMC_materials_mtoon"):
        return OK
    return ERR_SKIP


func _prepare_gltf_texture(
    gltf_samplers: Array[GLTFTextureSampler],
    gltf_textures: Array[GLTFTexture],
    texdic: Dictionary,
    tex: Texture2D
) -> int:
    var gltf_sampler: GLTFTextureSampler = GLTFTextureSampler.new()
    # FIXME: We do not currently have a way to set texture wrap / repeat settings for each shader, so we use defaults for now
    var sampler_idx: int = len(gltf_samplers)
    gltf_samplers.push_back(gltf_sampler)

    var gltf_tex: GLTFTexture = GLTFTexture.new()
    # Ok so this is is yucky and gross. There is no way to intercept between creation of Standard Materials
    # and craetion of the images array, and also no way to alter the cached images array.
    # So, all GLTFTexture objects point to 0. Then, we fill these in post, since some images may reference
    # textures which were added internally, and we can't know their index until later.
    gltf_tex.src_image = 0
    #gltf_tex.src_image = len(gltf_images)
    #gltf_images.push_back(tex)
    gltf_tex.sampler = sampler_idx
    var texture_idx: int = len(gltf_textures)
    gltf_textures.push_back(gltf_tex)
    texdic[texture_idx] = tex
    return texture_idx


func _prepare_material_for_export(
    gltf_samp: Array[GLTFTextureSampler],
    gltf_tex: Array[GLTFTexture],
    texdic: Dictionary,
    standard_textures: Dictionary,
    mtoon_material: ShaderMaterial
) -> StandardMaterial3D:
    var shader_name = mtoon_material.shader.resource_path.get_file().get_basename()
    var has_cutout = shader_name.find("_cutout") > 0
    var has_trans = shader_name.find("_trans") > 0
    var has_zwrite = shader_name.find("_zwrite") > 0
    var has_cull_off = shader_name.find("_cull_off") > 0
    var has_outline = false
    if mtoon_material.next_pass != null and mtoon_material.next_pass.shader != null:
        var outline_shader = mtoon_material.next_pass.shader.resource_path.get_file().get_basename()
        has_outline = outline_shader.find("mtoon_outline") > 0

    var standard_mat: StandardMaterial3D = StandardMaterial3D.new()
    var col: Variant = mtoon_material.get_shader_parameter("_Color")
    if typeof(col) == TYPE_VECTOR4:
        col = Color(col.x, col.y, col.z, col.w)
    if typeof(col) == TYPE_PLANE:
        col = Color(col.x, col.y, col.z, col.d)
    standard_mat.albedo_color = col
    standard_mat.albedo_texture = mtoon_material.get_shader_parameter("_MainTex")
    standard_textures[standard_mat.albedo_texture] = true
    col = mtoon_material.get_shader_parameter("_EmissionColor")
    if typeof(col) == TYPE_VECTOR4:
        col = Color(col.x, col.y, col.z, col.w)
    if typeof(col) == TYPE_PLANE:
        col = Color(col.x, col.y, col.z, col.d)
    if typeof(col) == TYPE_COLOR:
        col.a = 1.0
        standard_mat.emission_enabled = (
            mtoon_material.get_shader_parameter("_EmissionMap") != null
            or !col.is_equal_approx(Color.BLACK)
        )
        standard_mat.emission_texture = mtoon_material.get_shader_parameter("_EmissionMap")
        standard_mat.emission_energy_multiplier = mtoon_material.get_shader_parameter(
            "_EmissionMultiplier"
        )
        standard_textures[standard_mat.emission_texture] = true
        standard_mat.emission = col
    standard_mat.normal_texture = mtoon_material.get_shader_parameter("_BumpMap")
    standard_textures[standard_mat.normal_texture] = true
    standard_mat.normal_enabled = mtoon_material.get_shader_parameter("_BumpMap") != null
    standard_mat.normal_scale = mtoon_material.get_shader_parameter("_BumpScale")
    if has_trans:
        standard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    elif has_cutout:
        standard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        standard_mat.alpha_scissor_threshold = mtoon_material.get_shader_parameter("_Cutoff")
    else:
        standard_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

    var tex_repeat: Variant = mtoon_material.get_shader_parameter("_MainTex_ST")
    if typeof(tex_repeat) == TYPE_PLANE:
        standard_mat.uv1_scale = Vector3(tex_repeat.x, tex_repeat.y, 0)
        standard_mat.uv1_offset = Vector3(tex_repeat.z, tex_repeat.d, 0)
    elif typeof(tex_repeat) == TYPE_VECTOR4:
        standard_mat.uv1_scale = Vector3(tex_repeat.x, tex_repeat.y, 0)
        standard_mat.uv1_offset = Vector3(tex_repeat.z, tex_repeat.w, 0)

    var additional_textures = {}
    if mtoon_material.get_shader_parameter("_ShadeTexture") != null:
        additional_textures["shadeMultiplyTexture"] = _prepare_gltf_texture(
            gltf_samp, gltf_tex, texdic, mtoon_material.get_shader_parameter("_ShadeTexture")
        )
    if mtoon_material.get_shader_parameter("_ShadingGradeTexture") != null:
        additional_textures["shadingShiftTexture"] = _prepare_gltf_texture(
            gltf_samp, gltf_tex, texdic, mtoon_material.get_shader_parameter("_ShadingGradeTexture")
        )
    if mtoon_material.get_shader_parameter("_RimTexture") != null:
        additional_textures["rimMultiplyTexture"] = _prepare_gltf_texture(
            gltf_samp, gltf_tex, texdic, mtoon_material.get_shader_parameter("_RimTexture")
        )
    if mtoon_material.get_shader_parameter("_SphereAdd") != null:
        additional_textures["matcapTexture"] = _prepare_gltf_texture(
            gltf_samp, gltf_tex, texdic, mtoon_material.get_shader_parameter("_SphereAdd")
        )
    if mtoon_material.get_shader_parameter("_UvAnimMaskTexture") != null:
        additional_textures["uvAnimationMaskTexture"] = _prepare_gltf_texture(
            gltf_samp, gltf_tex, texdic, mtoon_material.get_shader_parameter("_UvAnimMaskTexture")
        )
    if mtoon_material.get_shader_parameter("_OutlineWidthTexture") != null:
        additional_textures["outlineWidthMultiplyTexture"] = _prepare_gltf_texture(
            gltf_samp, gltf_tex, texdic, mtoon_material.get_shader_parameter("_OutlineWidthTexture")
        )

    standard_mat.set_meta("mtoon_material", mtoon_material)
    standard_mat.set_meta("additional_textures", additional_textures)
    standard_mat.set_meta("has_zwrite", has_zwrite)
    standard_mat.set_meta("has_cull_off", has_cull_off)
    return standard_mat


func _export_preflight(state: GLTFState, root: Node) -> Error:
    var materials: Dictionary = {}
    var meshes = root.find_children("*", "ImporterMeshInstance3D")
    var texdic: Dictionary = {}
    var standard_textures: Dictionary = {}
    var gltf_samp: Array[GLTFTextureSampler] = state.texture_samplers
    var gltf_tex: Array[GLTFTexture] = state.textures
    var uses_mtoon: bool = false
    for meshx in meshes:
        var mesh: ImporterMeshInstance3D = meshx
        for m in range(mesh.mesh.get_surface_count()):
            var mat: Material = mesh.mesh.get_surface_material(m)
            if mat is ShaderMaterial:
                if mat.shader != null and mat.shader.resource_path.get_file().begins_with("mtoon"):
                    uses_mtoon = true
                    if not materials.has(mat):
                        materials[mat] = _prepare_material_for_export(
                            gltf_samp, gltf_tex, texdic, standard_textures, mat
                        )
                    mesh.mesh.set_surface_material(m, materials[mat])
    meshes = root.find_children("*", "MeshInstance3D")
    for meshx in meshes:
        var mesh: MeshInstance3D = meshx
        if mesh.mesh == null:
            continue
        for m in range(mesh.mesh.get_surface_count()):
            var mat: Material = mesh.get_surface_override_material(m)
            if mat == null:
                mat = mesh.mesh.surface_get_material(m)
            if mat is ShaderMaterial:
                if mat.shader != null and mat.shader.resource_path.get_file().begins_with("mtoon"):
                    uses_mtoon = true
                    if not materials.has(mat):
                        materials[mat] = _prepare_material_for_export(
                            gltf_samp, gltf_tex, texdic, standard_textures, mat
                        )
                    mesh.set_surface_override_material(m, materials[mat])

    if uses_mtoon:
        state.add_used_extension("VRMC_materials_mtoon", false)

    state.texture_samplers = gltf_samp
    state.textures = gltf_tex
    var unique_images_to_add: Dictionary = {}
    for tex in texdic.values():
        if not standard_textures.has(tex):
            unique_images_to_add[tex] = true
    var gltf_images: Array[Texture2D] = state.images
    for tex in unique_images_to_add:
        gltf_images.push_back(tex)
    state.images = gltf_images  # Any textures not used by a StandardMaterial3D are our responsibility.
    state.set_meta("texture_dictionary", texdic)
    state.set_meta("shader_to_standard_material", materials)
    return OK


func _to_gltf_color(c: Variant):
    if typeof(c) == TYPE_VECTOR4:
        return [c.x, c.y, c.z]
    if typeof(c) == TYPE_PLANE:
        return [c.x, c.y, c.z]
    if typeof(c) == TYPE_NIL:
        return [0, 0, 0]
    return [c.r, c.g, c.b]


func _cm_to_m(m: float) -> float:
    return m / 100.0


const vrm_material_processor = preload("../../common/vrm_material_processor.gd")


func _process_vrm_material(
    orig_mat: Material,
    gltf_images: Array[Texture2D],
    gltf_tex: Array[GLTFTexture],
    mat_props: Dictionary,
    vrm_mat_props: Dictionary
) -> Material:
    if vrm_mat_props.get("specVersion", "") != "1.0":
        VRMLogger.warning(
            "vrmc_materials_mtoon.gd",
            "Unsupported VRM MToon specVersion " + str(vrm_mat_props.get("specVersion", ""))
        )
    return vrm_material_processor.process_vrm_material_v1(
        orig_mat, gltf_images, gltf_tex, mat_props, vrm_mat_props
    )


# Called when the node enters the scene tree for the first time.
func _import_post(gstate: GLTFState, _root: Node) -> Error:
    # Guard: skip if there are no MToon materials to process.
    var materials: Array[Material] = gstate.get_materials()
    var has_mtoon := false
    for i in range(materials.size()):
        var json_material = gstate.json["materials"][i]
        var extensions: Dictionary = json_material.get("extensions", {})
        if extensions.has("VRMC_materials_mtoon"):
            has_mtoon = true
            break
    if not has_mtoon:
        VRMLogger.debug(
            "vrmc_materials_mtoon.gd", "_import_post: no MToon materials found, skipping"
        )
        return OK

    VRMLogger.info(
        "vrmc_materials_mtoon.gd", "_import_post: processing %d materials" % materials.size()
    )
    var images: Array[Texture2D] = gstate.get_images()
    var gltf_textures: Array[GLTFTexture] = gstate.get_textures()
    VRMLogger.debug("vrmc_materials_mtoon.gd", "_import_post: %d images available" % images.size())
    var materials_json: Array[Dictionary] = []
    var materials_vrm_json: Array[Dictionary] = []
    var spatial_to_shader_mat: Dictionary = {}

    for i in range(materials.size()):
        var material: Material = materials[i]
        var json_material = gstate.json["materials"][i]
        materials_json.push_back(json_material)
        var extensions: Dictionary = json_material.get("extensions", {})
        materials_vrm_json.push_back(extensions.get("VRMC_materials_mtoon", {}))

    # Material conversions
    for i in range(materials.size()):
        var oldmat: Material = materials[i]
        if oldmat is ShaderMaterial:
            # Indicates that the user asked to keep existing materials. Avoid changing them.
            VRMLogger.debug(
                "vrmc_materials_mtoon.gd",
                "Material %d (%s) is ShaderMaterial, skipping" % [i, oldmat.resource_name]
            )
            continue
        var newmat: Material = oldmat
        var mat_props: Dictionary = materials_json[i]
        var vrm_mat_props: Dictionary = materials_vrm_json[i]
        if not vrm_mat_props.has("specVersion"):
            spatial_to_shader_mat[newmat] = newmat
            continue
        newmat = _process_vrm_material(newmat, images, gltf_textures, mat_props, vrm_mat_props)
        spatial_to_shader_mat[oldmat] = newmat
        spatial_to_shader_mat[newmat] = newmat
        VRMLogger.debug(
            "vrmc_materials_mtoon.gd",
            "Material %d: %s -> %s" % [i, oldmat.resource_name, newmat.resource_name]
        )
        materials[i] = newmat
        var oldpath = oldmat.resource_path
        if oldpath.is_empty():
            continue
        newmat.take_over_path(oldpath)
        ResourceSaver.save(newmat, oldpath)
    gstate.set_materials(materials)
    VRMLogger.debug(
        "vrmc_materials_mtoon.gd", "_import_post: %d materials processed" % materials.size()
    )

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
                # Not an error: the surface material may have been set by a previous
                # extension (e.g. VRM 0.0 importer) or is not part of MToon processing.
                VRMLogger.debug(
                    "vrmc_materials_mtoon.gd",
                    (
                        "Mesh %d material %d name %s has no mtoon replacement (already processed?)"
                        % [i, surf_idx, surfmat.resource_name]
                    )
                )

    # FIXME: due to head duplication, do we now have some meshes which are not in gltf state?
    return OK
