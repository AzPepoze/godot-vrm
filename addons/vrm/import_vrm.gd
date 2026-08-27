@tool
extends EditorSceneFormatImporter

const VRMLogger = preload("./core/logger.gd")
const gltf_document_extension_class = preload("./importer/v0/vrm_extension.gd")
const vrmc_extension_classes = [
    preload("./importer/v1/vrmc/vrmc_node_constraint.gd"),
    preload("./importer/v1/vrmc/vrmc_spring_bone.gd"),
    preload("./importer/v1/vrmc/vrmc_materials_mtoon.gd"),
    preload("./importer/v1/vrmc/vrmc_materials_hdr_emissive_multiplier.gd"),
    preload("./importer/v1/vrmc/vrmc_vrm.gd"),
    preload("./importer/v1/vrmc/vrmc_vrm_animation.gd"),
]
const vrm_constants = preload("./core/vrm_constants.gd")

const SAVE_DEBUG_GLTFSTATE_RES: bool = false


func _get_importer_name() -> String:
    return "VRM"


func _get_extensions() -> PackedStringArray:
    return PackedStringArray(["vrm"])


func _import_scene(path: String, flags: int, options: Dictionary) -> Object:
    var gltf: GLTFDocument = GLTFDocument.new()
    var vrm_extension: GLTFDocumentExtension = gltf_document_extension_class.new()
    gltf.register_gltf_document_extension(vrm_extension, true)
    var vrmc_extensions: Array[GLTFDocumentExtension] = []
    for extension_class in vrmc_extension_classes:
        var extension: GLTFDocumentExtension = extension_class.new()
        vrmc_extensions.append(extension)
        gltf.register_gltf_document_extension(extension, true)
    var state: GLTFState = GLTFState.new()

    var override_global: bool = options.get(&"vrm/override_global_defaults", false) as bool

    var head_hiding: int = options.get(&"vrm/head_hiding_method", 0) as int
    var bone_rename: int = options.get(&"vrm/bone_rename", 1) as int
    var skeleton_name: String = options.get(&"vrm/skeleton_name", "Skeleton3D") as String
    var remove_end: bool = options.get(&"vrm/remove_end_bones", true) as bool
    var v1_rotate_180: bool = options.get(&"vrm/v1_rotate_180", true) as bool

    if not override_global:
        head_hiding = ProjectSettings.get_setting("vrm/import/head_hiding_method", head_hiding)
        bone_rename = ProjectSettings.get_setting("vrm/import/bone_rename", bone_rename)
        skeleton_name = ProjectSettings.get_setting("vrm/import/skeleton_name", skeleton_name)
        remove_end = ProjectSettings.get_setting("vrm/import/remove_end_bones", remove_end)
        v1_rotate_180 = ProjectSettings.get_setting("vrm/import/v1_rotate_180", v1_rotate_180)

    state.set_additional_data(
        &"vrm/head_hiding_method", head_hiding as vrm_constants.HeadHidingSetting
    )
    state.set_meta(&"vrm_head_hiding_method", true)
    state.set_additional_data(
        &"vrm/first_person_layers",
        options.get(&"vrm/only_if_head_hiding_uses_layers/first_person_layers", 2) as int
    )
    state.set_meta(&"vrm_first_person_layers", true)
    state.set_additional_data(
        &"vrm/third_person_layers",
        options.get(&"vrm/only_if_head_hiding_uses_layers/third_person_layers", 4) as int
    )
    state.set_meta(&"vrm_third_person_layers", true)
    state.set_additional_data(&"vrm/remove_end_bones", remove_end)
    state.set_meta(&"vrm_remove_end_bones", true)
    state.set_additional_data(&"vrm/v1_rotate_180", v1_rotate_180)
    state.set_meta(&"vrm_v1_rotate_180", true)
    state.set_meta(&"vrm_bone_rename", bone_rename)
    state.set_meta(&"vrm_skeleton_name", skeleton_name)
    # HANDLE_BINARY_EMBED_AS_BASISU crashes on some files in 4.0 and 4.1
    state.handle_binary_image = GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED # GLTFState.HANDLE_BINARY_EXTRACT_TEXTURES
    VRMLogger.info("import_vrm.gd", "_import_scene: importing %s" % path)
    var err = gltf.append_from_file(path, state, 8)
    if err != OK:
        VRMLogger.error(
            "import_vrm.gd",
            "_import_scene: append_from_file failed with error %d for %s" % [err, path]
        )
        gltf.unregister_gltf_document_extension(vrm_extension)
        for extension in vrmc_extensions:
            gltf.unregister_gltf_document_extension(extension)
        return null

    # Godot 4.7+ may skip lifecycle callbacks for extensions registered on this
    # local GLTFDocument. Earlier releases invoke them themselves, so running
    # them manually there would apply VRM post-import work twice.
    var spring_bone_extension = vrmc_extensions[1]
    var mtoon_extension = vrmc_extensions[2]
    var vrm_v1_extension = vrmc_extensions[4]
    var used_extensions: PackedStringArray = PackedStringArray(state.json.get("extensionsUsed", []))

    if mtoon_extension.has_method(&"_import_post"):
        mtoon_extension._import_post(state, null)

    var engine_version := Engine.get_version_info()
    var needs_local_lifecycle_workaround: bool = (
        engine_version.major == 4 and engine_version.minor >= 7
    )

    var import_vrm_v1 := false
    if needs_local_lifecycle_workaround and vrm_v1_extension.has_method(&"_import_preflight"):
        import_vrm_v1 = vrm_v1_extension._import_preflight(state, used_extensions) == OK
    if import_vrm_v1 and vrm_v1_extension.has_method(&"_import_post_parse"):
        vrm_v1_extension._import_post_parse(state)

    var import_spring_bones := false
    if needs_local_lifecycle_workaround and spring_bone_extension.has_method(&"_import_preflight"):
        import_spring_bones = spring_bone_extension._import_preflight(state, used_extensions) == OK

    var import_vrm_v0 := false
    if needs_local_lifecycle_workaround and vrm_extension.has_method(&"_import_preflight"):
        import_vrm_v0 = vrm_extension._import_preflight(state, used_extensions) == OK
    if import_vrm_v0 and vrm_extension.has_method(&"_import_post_parse"):
        vrm_extension._import_post_parse(state)

    var generated_scene = gltf.generate_scene(state)
    VRMLogger.info("import_vrm.gd", "_import_scene: scene generated successfully for %s" % path)

    if import_vrm_v1 and vrm_v1_extension.has_method(&"_import_post"):
        vrm_v1_extension._import_post(state, generated_scene)
    if import_spring_bones and spring_bone_extension.has_method(&"_import_post"):
        spring_bone_extension._import_post(state, generated_scene)
    if import_vrm_v0 and vrm_extension.has_method(&"_import_post"):
        vrm_extension._import_post(state, generated_scene)

    if SAVE_DEBUG_GLTFSTATE_RES and path != "":
        if !ResourceLoader.exists(path + ".res"):
            state.take_over_path(path + ".res")
            ResourceSaver.save(state, path + ".res")
    gltf.unregister_gltf_document_extension(vrm_extension)
    for extension in vrmc_extensions:
        gltf.unregister_gltf_document_extension(extension)
    return generated_scene
