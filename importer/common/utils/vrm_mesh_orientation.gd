@tool
extends RefCounted

const ROTATE_180_BASIS = Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))
const ROTATE_180_TRANSFORM = Transform3D(ROTATE_180_BASIS, Vector3.ZERO)

const ImporterMeshAttributes = preload("../importer_mesh_attributes.gd")
const VRMGLTFLookups = preload("./vrm_gltf_lookups.gd")


static func adjust_mesh_zforward(mesh: ImporterMesh, blendshapes: Array):
	# MESH and SKIN data divide, to compensate for object position multiplying.
	var surf_count: int = mesh.get_surface_count()
	var surf_data_by_mesh = [].duplicate()
	for surf_idx in range(surf_count):
		var prim: int = mesh.get_surface_primitive_type(surf_idx)
		var fmt_compress_flags: int = mesh.get_surface_format(surf_idx)
		var arr: Array = mesh.get_surface_arrays(surf_idx)
		var name: String = mesh.get_surface_name(surf_idx)
		var bscount = mesh.get_blend_shape_count()
		var bsarr: Array[Array] = []
		for bsidx in range(bscount):
			bsarr.append(mesh.get_surface_blend_shape_arrays(surf_idx, bsidx))
		var lods: Dictionary = {}  # mesh.surface_get_lods(surf_idx) # get_lods(mesh, surf_idx)
		var mat: Material = mesh.get_surface_material(surf_idx)
		var vert_arr_len: int = len(arr[ArrayMesh.ARRAY_VERTEX])
		var vertarr: PackedVector3Array = arr[ArrayMesh.ARRAY_VERTEX]
		var invert_vector = Vector3(-1, 1, -1)
		for i in range(vert_arr_len):
			vertarr[i] = invert_vector * vertarr[i]
		if typeof(arr[ArrayMesh.ARRAY_NORMAL]) == TYPE_PACKED_VECTOR3_ARRAY:
			var normarr: PackedVector3Array = arr[ArrayMesh.ARRAY_NORMAL]
			for i in range(vert_arr_len):
				normarr[i] = invert_vector * normarr[i]
		if typeof(arr[ArrayMesh.ARRAY_TANGENT]) == TYPE_PACKED_FLOAT32_ARRAY:
			var tangarr: PackedFloat32Array = arr[ArrayMesh.ARRAY_TANGENT]
			for i in range(vert_arr_len):
				tangarr[i * 4] = -tangarr[i * 4]
				tangarr[i * 4 + 2] = -tangarr[i * 4 + 2]
		for bsidx in range(len(bsarr)):
			vertarr = bsarr[bsidx][ArrayMesh.ARRAY_VERTEX]
			for i in range(vert_arr_len):
				vertarr[i] = invert_vector * vertarr[i]
			if typeof(bsarr[bsidx][ArrayMesh.ARRAY_NORMAL]) == TYPE_PACKED_VECTOR3_ARRAY:
				var normarr: PackedVector3Array = bsarr[bsidx][ArrayMesh.ARRAY_NORMAL]
				for i in range(vert_arr_len):
					normarr[i] = invert_vector * normarr[i]
			if typeof(bsarr[bsidx][ArrayMesh.ARRAY_TANGENT]) == TYPE_PACKED_FLOAT32_ARRAY:
				var tangarr: PackedFloat32Array = bsarr[bsidx][ArrayMesh.ARRAY_TANGENT]
				for i in range(vert_arr_len):
					tangarr[i * 4] = -tangarr[i * 4]
					tangarr[i * 4 + 2] = -tangarr[i * 4 + 2]
			bsarr[bsidx].resize(ArrayMesh.ARRAY_MAX)

		surf_data_by_mesh.push_back(
			{
				"prim": prim,
				"arr": arr,
				"bsarr": bsarr,
				"lods": lods,
				"fmt_compress_flags": fmt_compress_flags,
				"name": name,
				"mat": mat
			}
		)
	if blendshapes.is_empty():
		for bsidx in mesh.get_blend_shape_count():
			blendshapes.append(mesh.get_blend_shape_name(bsidx))
	mesh.clear()
	for blend_name in blendshapes:
		mesh.add_blend_shape(blend_name)
	for surf_idx in range(surf_count):
		var prim: int = surf_data_by_mesh[surf_idx].get("prim")
		var arr: Array = surf_data_by_mesh[surf_idx].get("arr")
		var bsarr: Array[Array] = surf_data_by_mesh[surf_idx].get("bsarr")
		var lods: Dictionary = surf_data_by_mesh[surf_idx].get("lods")
		var fmt_compress_flags: int = surf_data_by_mesh[surf_idx].get("fmt_compress_flags")
		var name: String = surf_data_by_mesh[surf_idx].get("name")
		var mat: Material = surf_data_by_mesh[surf_idx].get("mat")
		mesh.add_surface(prim, arr, bsarr, lods, mat, name, fmt_compress_flags)


static func rotate_scene_180_inner(p_node: Node3D, mesh_set: Dictionary, skin_set: Dictionary):
	if p_node is Skeleton3D:
		for bone_idx in range(p_node.get_bone_count()):
			var rest: Transform3D = (
				ROTATE_180_TRANSFORM * p_node.get_bone_rest(bone_idx) * ROTATE_180_TRANSFORM
			)
			p_node.set_bone_rest(bone_idx, rest)
			p_node.set_bone_pose_rotation(
				bone_idx,
				(
					Quaternion(ROTATE_180_BASIS)
					* p_node.get_bone_pose_rotation(bone_idx)
					* Quaternion(ROTATE_180_BASIS)
				)
			)
			p_node.set_bone_pose_scale(bone_idx, Vector3.ONE)
			p_node.set_bone_pose_position(bone_idx, rest.origin)
	p_node.transform = ROTATE_180_TRANSFORM * p_node.transform * ROTATE_180_TRANSFORM
	if p_node is ImporterMeshInstance3D:
		mesh_set[p_node.mesh] = true
		if p_node.skin != null:
			skin_set[p_node.skin] = true
	for child in p_node.get_children():
		if child is Node3D:
			rotate_scene_180_inner(child, mesh_set, skin_set)


static func rotate_scene_180(p_scene: Node3D, blend_shape_names: Dictionary, gstate: GLTFState):
	var mesh_set: Dictionary = {}
	var skin_set: Dictionary = {}
	rotate_scene_180_inner(p_scene, mesh_set, skin_set)

	var mesh_idx_to_meshinstance: Dictionary = (
		VRMGLTFLookups.generate_mesh_index_to_meshinstance_mapping(gstate)
	)

	for mesh_index in mesh_idx_to_meshinstance.keys():
		var mesh_node = mesh_idx_to_meshinstance[mesh_index]
		var mesh = mesh_node.mesh
		if mesh_index in blend_shape_names.keys():
			adjust_mesh_zforward(mesh, blend_shape_names[mesh_index])
		else:
			adjust_mesh_zforward(mesh, [])

	for skin in skin_set:
		for b in range(skin.get_bind_count()):
			skin.set_bind_pose(
				b, ROTATE_180_TRANSFORM * skin.get_bind_pose(b) * ROTATE_180_TRANSFORM
			)


static func apply_mesh_rotation(
	p_base_scene: Node,
	src_skeleton: Skeleton3D,
	old_skeleton_global_rest: Array[Transform3D],
	global_transform_scale_local: Vector3
):
	var nodes: Array[Node] = p_base_scene.find_children("*", "ImporterMeshInstance3D")
	var mutated_skins: Dictionary
	while not nodes.is_empty():
		var this_node = nodes.pop_back()
		if this_node is ImporterMeshInstance3D:
			var mi = this_node
			var skin: Skin = mi.skin
			var node = mi.get_node_or_null(mi.skeleton_path)
			if skin and node and node is Skeleton3D and node == src_skeleton:
				if mutated_skins.has(skin):
					continue
				mutated_skins[skin] = true
				var skellen = skin.get_bind_count()
				for i in range(skellen):
					var bn: StringName = skin.get_bind_name(i)
					if bn == &"":
						bn = node.get_bone_name(skin.get_bind_bone(i))
					var bone_idx: int = src_skeleton.find_bone(bn)
					if bone_idx >= 0:
						var adjust_transform: Transform3D = (
							src_skeleton.get_bone_global_rest(bone_idx).affine_inverse()
							* old_skeleton_global_rest[bone_idx]
						)
						adjust_transform = adjust_transform.scaled(global_transform_scale_local)
						skin.set_bind_pose(i, adjust_transform * skin.get_bind_pose(i))

	nodes = src_skeleton.get_children()
	while not nodes.is_empty():
		var attachment: BoneAttachment3D = nodes.pop_back() as BoneAttachment3D
		if attachment == null:
			continue
		var bone_idx: int = attachment.bone_idx
		if bone_idx == -1:
			bone_idx = src_skeleton.find_bone(attachment.bone_name)
		var adjust_transform: Transform3D = (
			src_skeleton.get_bone_global_rest(bone_idx).affine_inverse()
			* old_skeleton_global_rest[bone_idx]
		)
		adjust_transform = adjust_transform.scaled(global_transform_scale_local)

		var child_nodes: Array[Node] = attachment.get_children()
		while not child_nodes.is_empty():
			var child: Node3D = child_nodes.pop_back() as Node3D
			if child == null:
				continue
			child.transform = adjust_transform * child.transform

	for i in range(src_skeleton.get_bone_count()):
		var fixed_rest: Transform3D = src_skeleton.get_bone_rest(i)
		src_skeleton.set_bone_pose_position(i, fixed_rest.origin)
		src_skeleton.set_bone_pose_rotation(i, fixed_rest.basis.get_rotation_quaternion())
		src_skeleton.set_bone_pose_scale(i, fixed_rest.basis.get_scale())
