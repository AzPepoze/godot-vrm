@tool
extends EditorSceneFormatImporter

const VRMLogger = preload("./core/logger.gd")
const gltf_document_extension_class = preload("./importer/v0/vrm_extension.gd")
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
    var state: GLTFState = GLTFState.new()
    state.set_additional_data(
        &"vrm/head_hiding_method",
        options.get(&"vrm/head_hiding_method", 0) as vrm_constants.HeadHidingSetting
    )
    state.set_additional_data(
        &"vrm/first_person_layers",
        options.get(&"vrm/only_if_head_hiding_uses_layers/first_person_layers", 2) as int
    )
    state.set_additional_data(
        &"vrm/third_person_layers",
        options.get(&"vrm/only_if_head_hiding_uses_layers/third_person_layers", 4) as int
    )
    state.set_additional_data(
        &"vrm/remove_end_bones", options.get(&"vrm/remove_end_bones", true) as bool
    )
    state.set_meta(&"vrm_bone_rename", options.get(&"vrm/bone_rename", 0) as int)
    state.set_additional_data(
        &"vrm/skeleton_name", options.get(&"vrm/skeleton_name", "Skeleton3D") as String
    )
    # HANDLE_BINARY_EMBED_AS_BASISU crashes on some files in 4.0 and 4.1
    state.handle_binary_image = GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED  # GLTFState.HANDLE_BINARY_EXTRACT_TEXTURES
    VRMLogger.info("import_vrm.gd", "_import_scene: importing %s" % path)
    var err = gltf.append_from_file(path, state, 8)
    if err != OK:
        VRMLogger.error(
            "import_vrm.gd",
            "_import_scene: append_from_file failed with error %d for %s" % [err, path]
        )
        gltf.unregister_gltf_document_extension(vrm_extension)
        return null

    var generated_scene = gltf.generate_scene(state)
    VRMLogger.info("import_vrm.gd", "_import_scene: scene generated successfully for %s" % path)

    if SAVE_DEBUG_GLTFSTATE_RES and path != "":
        if !ResourceLoader.exists(path + ".res"):
            state.take_over_path(path + ".res")
            ResourceSaver.save(state, path + ".res")
    gltf.unregister_gltf_document_extension(vrm_extension)
    return generated_scene
