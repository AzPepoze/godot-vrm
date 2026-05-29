@tool
extends EditorPlugin

var import_plugin: EditorSceneFormatImporter

const VRMC_node_constraint = preload("./importer/1.0/VRMC_node_constraint.gd")
var VRMC_node_constraint_inst := VRMC_node_constraint.new()

const VRMC_springBone = preload("./importer/1.0/VRMC_springBone.gd")
var VRMC_springBone_inst := VRMC_springBone.new()

const VRMC_materials_mtoon = preload("./importer/1.0/VRMC_materials_mtoon.gd")
var VRMC_materials_mtoon_inst := VRMC_materials_mtoon.new()

const VRMC_materials_hdr_emissiveMultiplier = preload(
	"./importer/1.0/VRMC_materials_hdr_emissiveMultiplier.gd"
)
var VRMC_materials_hdr_emissiveMultiplier_inst := VRMC_materials_hdr_emissiveMultiplier.new()

const VRMC_vrm = preload("./importer/1.0/VRMC_vrm.gd")
var VRMC_vrm_inst := VRMC_vrm.new()

const VRMC_vrm_animation = preload("./importer/1.0/VRMC_vrm_animation.gd")
var VRMC_vrm_animation_inst := VRMC_vrm_animation.new()

const vrm_options_post_import_plugin = preload(
	"./importer/common/vrm_options_post_import_plugin.gd"
)
var vrm_options_post_import_plugin_inst := vrm_options_post_import_plugin.new()

const vrm_meta_class = preload("./core/vrm_meta.gd")
const vrm_top_level = preload("./core/vrm_toplevel.gd")
const vrm_secondary = preload("./runtime/vrm_secondary.gd")

#const vrm_export_extension = preload("./importer/1.0/vrm_export_extension.gd")
#var vrm_export_extension_inst = vrm_export_extension.new()

const export_as_item: String = "VRM 1.0 Avatar..."
const export_as_id: int = 0x56524d31  # 'VRM1'

var file_export_lib: EditorFileDialog
var accept_dialog: AcceptDialog


func _enter_tree():
	add_scene_format_importer_plugin(import_plugin)
	add_scene_post_import_plugin(vrm_options_post_import_plugin_inst)
	add_tool_menu_item(export_as_item, _export_vrm_dialog)
	GLTFDocument.register_gltf_document_extension(VRMC_node_constraint_inst, true)
	GLTFDocument.register_gltf_document_extension(VRMC_springBone_inst, true)
	GLTFDocument.register_gltf_document_extension(VRMC_materials_mtoon_inst, true)
	GLTFDocument.register_gltf_document_extension(VRMC_materials_hdr_emissiveMultiplier_inst, true)
	GLTFDocument.register_gltf_document_extension(VRMC_vrm_inst, true)
	GLTFDocument.register_gltf_document_extension(VRMC_vrm_animation_inst, true)
	#GLTFDocument.register_gltf_document_extension(vrm_export_extension_inst)


func _exit_tree():
	remove_tool_menu_item(export_as_item)
	GLTFDocument.unregister_gltf_document_extension(VRMC_node_constraint_inst)
	GLTFDocument.unregister_gltf_document_extension(VRMC_springBone_inst)
	GLTFDocument.unregister_gltf_document_extension(VRMC_materials_mtoon_inst)
	GLTFDocument.unregister_gltf_document_extension(VRMC_materials_hdr_emissiveMultiplier_inst)
	GLTFDocument.unregister_gltf_document_extension(VRMC_vrm_inst)
	GLTFDocument.unregister_gltf_document_extension(VRMC_vrm_animation_inst)
	#GLTFDocument.unregister_gltf_document_extension(vrm_export_extension_inst)
	remove_scene_format_importer_plugin(import_plugin)
	remove_scene_post_import_plugin(vrm_options_post_import_plugin_inst)
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
	var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()
	if selected_nodes.is_empty():
		return
	var root_node = selected_nodes[0]
	var vrm_meta = root_node.get("vrm_meta")

	var failed_validate = VRMC_vrm.new()._validate_meta(vrm_meta)
	if not failed_validate.is_empty():
		if accept_dialog == null:
			accept_dialog = AcceptDialog.new()
			get_editor_interface().get_base_control().add_child(accept_dialog)
		accept_dialog.dialog_text = (
			"VRM Export requires filling out license dropdowns and basic data:\n"
			+ ",".join(failed_validate)
		)
		accept_dialog.popup_centered()
		return

	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var err = gltf.append_from_scene(root_node, state)
	if err == OK:
		err = gltf.write_to_filesystem(state, path)
		if err != OK:
			printerr("Failed to write VRM: " + str(err))
	else:
		printerr("Failed to append scene to GLTFState: " + str(err))
