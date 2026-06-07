@tool
extends EditorPlugin

const VRMLogger = preload("./core/logger.gd")

var import_plugin: EditorSceneFormatImporter

# GLTF extension classes to register
const gltf_extension_classes = [
    preload("./importer/v1/vrmc/vrmc_node_constraint.gd"),
    preload("./importer/v1/vrmc/vrmc_spring_bone.gd"),
    preload("./importer/v1/vrmc/vrmc_materials_mtoon.gd"),
    preload("./importer/v1/vrmc/vrmc_materials_hdr_emissive_multiplier.gd"),
    preload("./importer/v1/vrmc/vrmc_vrm.gd"),
    preload("./importer/v1/vrmc/vrmc_vrm_animation.gd"),
]

# Extension instances
var gltf_extension_instances: Array[GLTFDocumentExtension] = []

# Post-import plugin
const vrm_options_post_import_plugin_class = preload(
    "./importer/common/vrm_options_post_import_plugin.gd"
)
var post_import_plugin_instance: EditorScenePostImportPlugin = null

const vrm_meta_class = preload("./core/vrm_meta.gd")
const vrm_instance = preload("./core/vrm_instance.gd")
const vrm_spring_bone_controller = preload("./runtime/vrm_spring_bone_controller.gd")

const export_as_item: String = "VRM 1.0 Avatar..."
const export_as_id: int = 0x56524d31  # 'VRM1'

var file_export_lib: EditorFileDialog
var accept_dialog: AcceptDialog


func register_import_settings() -> void:
    var import_settings := {
        "vrm/import/head_hiding_method": {
            "type": TYPE_INT,
            "hint": PROPERTY_HINT_ENUM,
            "hint_string": "ThirdPersonOnly,FirstPersonOnly,FirstWithShadow,Layers,LayersWithShadow,IgnoreHeadHiding",
            "default": 0,
        },
        "vrm/import/bone_rename": {
            "type": TYPE_INT,
            "hint": PROPERTY_HINT_ENUM,
            "hint_string": "None,Humanoid,Symmetrize VRoid Bone Names on X-Axis",
            "default": 1,
        },
        "vrm/import/skeleton_name": {
            "type": TYPE_STRING,
            "hint": PROPERTY_HINT_NONE,
            "default": "Skeleton3D",
        },
        "vrm/import/remove_end_bones": {
            "type": TYPE_BOOL,
            "hint": PROPERTY_HINT_NONE,
            "default": true,
        },
        "vrm/import/v1_rotate_180": {
            "type": TYPE_BOOL,
            "hint": PROPERTY_HINT_NONE,
            "default": true,
        },
    }
    for setting_name in import_settings:
        if not ProjectSettings.has_setting(setting_name):
            var s = import_settings[setting_name]
            ProjectSettings.set_setting(setting_name, s["default"])
            var info := {
                "name": setting_name,
                "type": s["type"],
                "hint": s["hint"],
            }
            if s.get("hint_string", "") != "":
                info["hint_string"] = s["hint_string"]
            ProjectSettings.add_property_info(info)
            ProjectSettings.set_initial_value(setting_name, s["default"])


func _enter_tree():
    VRMLogger.register_settings()
    register_import_settings()
    # Instantiate and register GLTF extensions
    for extension_class in gltf_extension_classes:
        var instance = extension_class.new()
        gltf_extension_instances.append(instance)
        GLTFDocument.register_gltf_document_extension(instance, true)

    # Register post-import plugin
    post_import_plugin_instance = vrm_options_post_import_plugin_class.new()
    add_scene_post_import_plugin(post_import_plugin_instance)

    # Register importer and menu item
    add_scene_format_importer_plugin(import_plugin)
    add_tool_menu_item(export_as_item, _export_vrm_dialog)


func _exit_tree():
    remove_tool_menu_item(export_as_item)

    # Unregister GLTF extensions
    for instance in gltf_extension_instances:
        GLTFDocument.unregister_gltf_document_extension(instance)
    gltf_extension_instances.clear()

    # Unregister post-import plugin
    if post_import_plugin_instance:
        remove_scene_post_import_plugin(post_import_plugin_instance)
        post_import_plugin_instance = null

    # Unregister importer
    remove_scene_format_importer_plugin(import_plugin)
    import_plugin = null


func _init():
    import_plugin = preload("./import_vrm.gd").new()


func _export_vrm_dialog():
    var selection = get_editor_interface().get_selection().get_selected_nodes()
    if selection.size() != 1:
        if accept_dialog == null:
            accept_dialog = AcceptDialog.new()
            get_editor_interface().get_base_control().add_child(accept_dialog)
        accept_dialog.dialog_text = "Please select exactly one node to export."
        accept_dialog.popup_centered()
        return

    if file_export_lib == null:
        file_export_lib = EditorFileDialog.new()
        file_export_lib.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
        file_export_lib.add_filter("*.vrm", "VRM 1.0 Avatar")
        file_export_lib.connect("file_selected", _export_vrm)
        get_editor_interface().get_base_control().add_child(file_export_lib)

    var root = selection[0]
    var filename = root.get_scene_file_path().get_file().get_basename()
    if filename.is_empty():
        filename = root.get_name()
    file_export_lib.current_file = filename + ".vrm"
    file_export_lib.popup_centered_ratio()


func _export_vrm(path: String):
    VRMLogger.info("plugin.gd", "_export_vrm: starting export to %s" % path)
    var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()
    if selected_nodes.is_empty():
        return
    var root_node = selected_nodes[0]
    var vrm_meta = root_node.get("vrm_meta")

    var vrmc_vrm_instance = preload("./importer/v1/vrmc/vrmc_vrm.gd").new()
    var failed_validate = vrmc_vrm_instance._validate_meta(vrm_meta)
    if not failed_validate.is_empty():
        if accept_dialog == null:
            accept_dialog = AcceptDialog.new()
            get_editor_interface().get_base_control().add_child(accept_dialog)
        accept_dialog.dialog_text = (
            "VRM Export requires filling out license dropdowns and basic data:\n"
            + ",".join(failed_validate)
        )
        accept_dialog.popup_centered()
        VRMLogger.warning("plugin.gd", "_export_vrm: validation failed")
        return

    var gltf: GLTFDocument = GLTFDocument.new()
    var state: GLTFState = GLTFState.new()
    var err = gltf.append_from_scene(root_node, state)
    if err == OK:
        err = gltf.write_to_filesystem(state, path)
        if err != OK:
            VRMLogger.error("plugin.gd", "Failed to write VRM: " + str(err))
        else:
            VRMLogger.info("plugin.gd", "_export_vrm: export to %s completed successfully" % path)
    else:
        VRMLogger.error("plugin.gd", "Failed to append scene to GLTFState: " + str(err))
