extends GLTFDocumentExtension

const vrm_constants_class = preload("../../core/vrm_constants.gd")
const vrm_meta_class = preload("../../core/vrm_meta.gd")
const vrm_secondary = preload("../../runtime/vrm_secondary.gd")
const vrm_collider_group = preload("../../runtime/vrm_collider_group.gd")
const vrm_collider = preload("../../runtime/vrm_collider.gd")
const vrm_spring_bone = preload("../../runtime/vrm_spring_bone.gd")
const vrm_top_level = preload("../../core/vrm_toplevel.gd")

const importer_mesh_attributes = preload("../common/importer_mesh_attributes.gd")

const vrm_utils = preload("../common/vrm_utils.gd")

var vrm_meta: Resource = null

enum DebugMode {
	None = 0,
	Normal = 1,
	LitShadeRate = 2,
}

enum FirstPersonFlag {
	Auto,  # Create headlessModel
	Both,  # Default layer
	ThirdPersonOnly,
	FirstPersonOnly,
	FirstWithShadow,
	Layers,
	LayersWithShadow,
	Ignore,
}


func _process_khr_material(orig_mat: StandardMaterial3D, gltf_mat_props: Dictionary) -> Material:
	if gltf_mat_props.has("extensions") and gltf_mat_props["extensions"].has("KHR_materials_unlit"):
		orig_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# TODO: validate that this is sufficient.
	return orig_mat


const vrm_material_processor = preload("../common/vrm_material_processor.gd")


func _vrm_get_texture_info(
	gstate: GLTFState, vrm_mat_props: Dictionary, unity_tex_name: String
) -> Dictionary:
	return vrm_material_processor.get_texture_info_v0(gstate, vrm_mat_props, unity_tex_name)


func _vrm_get_float(vrm_mat_props: Dictionary, key: String, def: float) -> float:
	return vrm_mat_props["floatProperties"].get(key, def)


func _process_vrm_material(
	orig_mat: Material, gstate: GLTFState, vrm_mat_props: Dictionary
) -> Material:
	return vrm_material_processor.process_vrm_material_v0(orig_mat, gstate, vrm_mat_props)


func _update_materials(vrm_extension: Dictionary, gstate: GLTFState) -> void:
	var images = gstate.get_images()
	#print(images)
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
			# print("Material " + str(i) + ": " + str(oldmat.resource_name) + " already is shader.")
			continue
		var vrm_mat_props: Dictionary = vrm_extension["materialProperties"][i]
		var newmat: Material = _process_vrm_material(oldmat, gstate, vrm_mat_props)
		spatial_to_shader_mat[oldmat] = newmat
		spatial_to_shader_mat[newmat] = newmat
		# print("Replacing shader " + str(oldmat) + "/" + str(oldmat.resource_name) + " with " + str(newmat) + "/" + str(newmat.resource_name))

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
				new_mat.render_priority = target_render_priority
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


func _first_person_head_hiding(
	vrm_extension: Dictionary, gstate: GLTFState, human_bone_to_idx: Dictionary
) -> void:
	var nodes = gstate.get_nodes()
	var head_bone_idx: int = human_bone_to_idx["head"]
	var head_relative_bones: Dictionary = {}
	var skeletons: Array[GLTFSkeleton] = gstate.get_skeletons()
	if head_bone_idx != -1:
		var head_node: GLTFNode = nodes[head_bone_idx]
		var skeleton: Skeleton3D = gstate.get_scene_node(skeletons[head_node.skeleton].roots[0])
		vrm_utils._recurse_bones(head_relative_bones, skeleton, skeleton.find_bone("Head"))

	var mesh_annotations_by_node: Dictionary = {}
	for meshannotation in vrm_extension["firstPerson"].get("meshAnnotations", []):
		mesh_annotations_by_node[int(meshannotation["mesh"])] = meshannotation.get(
			"firstPersonFlag", "Auto"
		)

	var node_to_head_hidden_node: Dictionary = {}
	vrm_utils.perform_head_hiding(
		gstate, mesh_annotations_by_node, head_relative_bones, node_to_head_hidden_node
	)


const vrm_resource_factory = preload("../common/vrm_resource_factory.gd")


func _create_meta(
	_root_node: Node,
	_animplayer: AnimationPlayer,
	vrm_extension: Dictionary,
	gstate: GLTFState,
	skeleton: Skeleton3D,
	humanBones: BoneMap,
	human_bone_to_idx: Dictionary,
	pose_diffs: Array[Basis]
) -> Resource:
	return vrm_resource_factory.create_meta_v0(
		vrm_extension, gstate, skeleton, humanBones, human_bone_to_idx, pose_diffs
	)


const vrm_animation_service = preload("../common/vrm_animation_service.gd")


func _create_animation_player(
	animplayer: AnimationPlayer,
	vrm_extension: Dictionary,
	gstate: GLTFState,
	human_bone_to_idx: Dictionary,
	pose_diffs: Array[Basis]
) -> AnimationPlayer:
	return vrm_animation_service.setup_animation_player_v0(
		animplayer, vrm_extension, gstate, human_bone_to_idx, pose_diffs
	)


const vrm_secondary_service = preload("../common/vrm_secondary_service.gd")


func _create_joints_recursive(
	joint_chains: Array[PackedStringArray],
	skeleton: Skeleton3D,
	bone_idx: int,
	level: int,
	current_chain: int
):
	vrm_secondary_service.create_joints_recursive(
		joint_chains, skeleton, bone_idx, level, current_chain
	)


func _parse_secondary_node(
	secondary_node: Node,
	vrm_extension: Dictionary,
	gstate: GLTFState,
	pose_diffs: Array[Basis],
	is_vrm_0: bool
) -> void:
	vrm_secondary_service.parse_secondary_node(
		secondary_node, vrm_extension, gstate, pose_diffs, is_vrm_0
	)


func _add_joints_recursive(
	new_joints_set: Dictionary, gltf_nodes: Array, bone: int, include_child_meshes: bool = false
) -> void:
	vrm_animation_service.add_joints_recursive(
		new_joints_set, gltf_nodes, bone, include_child_meshes
	)


func _add_joint_set_as_skin(obj: Dictionary, new_joints_set: Dictionary) -> void:
	vrm_animation_service.add_joint_set_as_skin(obj, new_joints_set)


func _add_vrm_nodes_to_skin(obj: Dictionary) -> bool:
	return vrm_animation_service.add_vrm_nodes_to_skin_v0(obj)


func _import_preflight(
	gstate: GLTFState, extensions: PackedStringArray = PackedStringArray(), psa2: Variant = null
) -> Error:
	if extensions.has("VRMC_vrm"):
		# VRM 1.0 file. Do not parse as a VRM 0.0.
		return ERR_INVALID_DATA
	if typeof(gstate.get_additional_data(&"vrm/already_processed")) != TYPE_NIL:
		return ERR_SKIP
	gstate.set_additional_data(&"vrm/already_processed", true)
	var gltf_json_parsed: Dictionary = gstate.json
	var gltf_nodes = gltf_json_parsed["nodes"]
	if not _add_vrm_nodes_to_skin(gltf_json_parsed):
		push_error("Failed to find required VRM keys in json")
		return ERR_INVALID_DATA
	return OK


func _import_post_parse(state: GLTFState) -> Error:
	var nodes := state.get_nodes()
	for n in nodes:
		if n.name == "Root":
			pass
	return OK


func _import_post(gstate: GLTFState, node: Node) -> Error:
	var gltf: GLTFDocument = GLTFDocument.new()
	var root_node: Node = node

	var vrm_extension: Dictionary = gstate.json["extensions"]["VRM"]

	var human_bone_to_idx: Dictionary = {}
	for human_bone in vrm_extension["humanoid"]["humanBones"]:
		human_bone_to_idx[human_bone["bone"]] = int(human_bone["node"])

	var skeletons = gstate.get_skeletons()
	var hipsNode: GLTFNode = gstate.nodes[human_bone_to_idx["hips"]]
	var skeleton: Skeleton3D = vrm_animation_service._get_skel_godot_node(
		gstate, gstate.nodes, skeletons, hipsNode.skeleton
	)
	var gltfnodes: Array = gstate.nodes

	var humanBones: BoneMap = BoneMap.new()
	humanBones.profile = SkeletonProfileHumanoid.new()

	var vrm0_to_human_bone = vrm_constants_class.get_vrm_to_human_bone(true)

	for vrm_bone_name in human_bone_to_idx:
		if vrm0_to_human_bone.has(vrm_bone_name):
			humanBones.set_skeleton_bone_name(
				vrm0_to_human_bone[vrm_bone_name],
				gltfnodes[human_bone_to_idx[vrm_bone_name]].resource_name
			)

	var pose_diffs: Array[Basis] = vrm_utils.perform_retarget(
		gstate, root_node, skeleton, humanBones
	)

	skeleton.set_meta("vrm_pose_diffs", pose_diffs)

	_update_materials(vrm_extension, gstate)
	_first_person_head_hiding(vrm_extension, gstate, human_bone_to_idx)

	var animplayer: AnimationPlayer
	if root_node.has_node("AnimationPlayer"):
		animplayer = root_node.get_node("AnimationPlayer")
	else:
		animplayer = AnimationPlayer.new()
		animplayer.name = "AnimationPlayer"
		root_node.add_child(animplayer, true)
		animplayer.owner = root_node

	_create_animation_player(animplayer, vrm_extension, gstate, human_bone_to_idx, pose_diffs)

	root_node.set_script(vrm_top_level)

	if (
		vrm_extension.has("secondaryAnimation")
		and (
			vrm_extension["secondaryAnimation"].get("colliderGroups", []).size() > 0
			or vrm_extension["secondaryAnimation"].get("boneGroups", []).size() > 0
		)
	):
		var secondary_node: Node = root_node.get_node("secondary")
		if secondary_node == null:
			secondary_node = Node3D.new()
			secondary_node.name = "secondary"
			root_node.add_child(secondary_node, true)
			secondary_node.owner = root_node

		_parse_secondary_node(secondary_node, vrm_extension, gstate, pose_diffs, true)

	var vrm_meta: Resource = _create_meta(
		root_node,
		animplayer,
		vrm_extension,
		gstate,
		skeleton,
		humanBones,
		human_bone_to_idx,
		pose_diffs
	)
	root_node.set("vrm_meta", vrm_meta)

	return OK
