@tool
extends RefCounted

const vrm_constants_class = preload("../../core/vrm_constants.gd")
const vrm_utils = preload("./vrm_utils.gd")

const vrm0_to_vrm1_presets: Dictionary = {
	"joy": "happy",
	"angry": "angry",
	"sorrow": "sad",
	"fun": "relaxed",
	"a": "aa",
	"i": "ih",
	"u": "ou",
	"e": "ee",
	"o": "oh",
	"blink": "blink",
	"blink_l": "blinkLeft",
	"blink_r": "blinkRight",
	"lookup": "lookUp",
	"lookdown": "lookDown",
	"lookleft": "lookLeft",
	"lookright": "lookRight",
	"neutral": "neutral",
}

const vrm_animation_to_look_at: Dictionary = {
	"lookUp": "rangeMapVerticalUp",
	"lookDown": "rangeMapVerticalDown",
	"lookLeft": "rangeMapHorizontalOuter",
	"lookRight": "rangeMapHorizontalInner",
}


static func _get_skel_godot_node(
	gstate: GLTFState, nodes: Array, skeletons: Array, skel_id: int
) -> Node:
	if skel_id < 0 or skel_id >= skeletons.size():
		return null
	var gltfskel: GLTFSkeleton = skeletons[skel_id]
	if gltfskel.roots.is_empty():
		return null
	var skel_node_idx = gltfskel.roots[0]
	return gstate.get_scene_node(skel_node_idx)


static func setup_animation_player_v0(
	animplayer: AnimationPlayer,
	vrm_extension: Dictionary,
	gstate: GLTFState,
	human_bone_to_idx: Dictionary,
	pose_diffs: Array[Basis]
) -> AnimationPlayer:
	# Remove all glTF animation players for safety.
	for i in range(gstate.get_animation_players_count(0)):
		var node: AnimationPlayer = gstate.get_animation_player(i)
		node.get_parent().remove_child(node)

	var animation_library: AnimationLibrary = AnimationLibrary.new()

	var meshes = gstate.get_meshes()
	var nodes = gstate.get_nodes()
	var blend_shape_groups = vrm_extension["blendShapeMaster"]["blendShapeGroups"]
	var mesh_idx_to_meshinstance: Dictionary = (
		vrm_utils.generate_mesh_index_to_meshinstance_mapping(gstate)
	)
	var material_name_to_mesh_and_surface_idx: Dictionary = {}
	for i in range(meshes.size()):
		var gltfmesh: GLTFMesh = meshes[i]
		for j in range(gltfmesh.mesh.get_surface_count()):
			material_name_to_mesh_and_surface_idx[gltfmesh.mesh.get_surface_material(j).resource_name] = [
				i, j
			]

	var firstperson = vrm_extension["firstPerson"]

	var reset_anim = Animation.new()
	reset_anim.resource_name = "RESET"

	for shape in blend_shape_groups:
		var anim = Animation.new()
		for matbind in shape["materialValues"]:
			var mat_name = matbind["materialName"]
			if not material_name_to_mesh_and_surface_idx.has(mat_name):
				continue
			var mesh_and_surface_idx = material_name_to_mesh_and_surface_idx[mat_name]
			var node: ImporterMeshInstance3D = mesh_idx_to_meshinstance[mesh_and_surface_idx[0]]
			var surface_idx = mesh_and_surface_idx[1]

			var mat: Material = node.mesh.get_surface_material(surface_idx)
			var paramprop = "shader_parameter/" + matbind["propertyName"]
			var origvalue = null
			var tv = matbind["targetValue"]
			var newvalue = tv[0]

			if mat is ShaderMaterial:
				var smat: ShaderMaterial = mat
				var param = smat.get_shader_parameter(matbind["propertyName"])
				if param is Color:
					origvalue = param
					if len(tv) >= 4:
						newvalue = Color(tv[0], tv[1], tv[2], tv[3])
					else:
						newvalue = origvalue
				elif (
					matbind["propertyName"] == "_MainTex"
					or matbind["propertyName"] == "_MainTex_ST"
				):
					origvalue = param
					if len(tv) >= 4:
						newvalue = (
							Vector4(tv[2], tv[3], tv[0], tv[1])
							if matbind["propertyName"] == "_MainTex"
							else Vector4(tv[0], tv[1], tv[2], tv[3])
						)
					else:
						newvalue = origvalue
				elif param is float:
					origvalue = param
					newvalue = tv[0]

			if origvalue != null:
				var animtrack: int = anim.add_track(Animation.TYPE_VALUE)
				anim.track_set_path(
					animtrack,
					(
						str(animplayer.get_parent().get_path_to(node))
						+ ":mesh:surface_"
						+ str(surface_idx)
						+ "/material:"
						+ paramprop
					)
				)
				anim.track_set_interpolation_type(
					animtrack,
					(
						Animation.INTERPOLATION_NEAREST
						if bool(shape["isBinary"])
						else Animation.INTERPOLATION_LINEAR
					)
				)
				anim.track_insert_key(animtrack, 0.0, newvalue)
				animtrack = reset_anim.add_track(Animation.TYPE_VALUE)
				reset_anim.track_set_path(
					animtrack,
					(
						str(animplayer.get_parent().get_path_to(node))
						+ ":mesh:surface_"
						+ str(surface_idx)
						+ "/material:"
						+ paramprop
					)
				)
				reset_anim.track_set_interpolation_type(
					animtrack,
					(
						Animation.INTERPOLATION_NEAREST
						if bool(shape["isBinary"])
						else Animation.INTERPOLATION_LINEAR
					)
				)
				reset_anim.track_insert_key(animtrack, 0.0, origvalue)
		for bind in shape["binds"]:
			var node: ImporterMeshInstance3D = mesh_idx_to_meshinstance[int(bind["mesh"])]
			var nodeMesh: ImporterMesh = node.mesh

			if (
				nodeMesh == null
				|| bind["index"] < 0
				|| bind["index"] >= nodeMesh.get_blend_shape_count()
			):
				continue
			var animtrack: int = anim.add_track(Animation.TYPE_BLEND_SHAPE)
			anim.track_set_path(
				animtrack,
				(
					str(animplayer.get_parent().get_path_to(node))
					+ ":"
					+ str(nodeMesh.get_blend_shape_name(int(bind["index"])))
				)
			)
			var interpolation: int = Animation.INTERPOLATION_LINEAR
			if shape.has("isBinary") and bool(shape["isBinary"]):
				interpolation = Animation.INTERPOLATION_NEAREST
			anim.track_set_interpolation_type(animtrack, interpolation)
			anim.track_insert_key(animtrack, 0.0, 0.99999 * float(bind["weight"]) / 100.0)
			animtrack = reset_anim.add_track(Animation.TYPE_BLEND_SHAPE)
			reset_anim.track_set_path(
				animtrack,
				(
					str(animplayer.get_parent().get_path_to(node))
					+ ":"
					+ str(nodeMesh.get_blend_shape_name(int(bind["index"])))
				)
			)
			reset_anim.track_insert_key(animtrack, 0.0, float(0.0))

		if vrm0_to_vrm1_presets.has(shape["presetName"]):
			anim.resource_name = vrm0_to_vrm1_presets[shape["presetName"]]
			if shape["presetName"].begins_with("look"):
				animation_library.add_animation(
					vrm0_to_vrm1_presets[shape["presetName"]] + "Raw", anim
				)
			if (
				firstperson.get("lookAtTypeName", "") != "Bone"
				or not shape["presetName"].begins_with("look")
			):
				animation_library.add_animation(vrm0_to_vrm1_presets[shape["presetName"]], anim)
		else:
			if shape["presetName"] == "unknown":
				anim.resource_name = shape["name"]
				animation_library.add_animation(shape["name"], anim)
			else:
				push_warning("Unrecognized preset name " + str(shape))

	var skeletons: Array[GLTFSkeleton] = gstate.get_skeletons()
	var eye_bone_horizontal: Quaternion = Quaternion.from_euler(Vector3(PI / 2, 0, 0))
	if firstperson.get("lookAtTypeName", "") == "Bone":
		var horizout = firstperson["lookAtHorizontalOuter"]
		var horizin = firstperson["lookAtHorizontalInner"]
		var vertup = firstperson["lookAtVerticalUp"]
		var vertdown = firstperson["lookAtVerticalDown"]
		var lefteye: int = human_bone_to_idx.get("leftEye", -1)
		var righteye: int = human_bone_to_idx.get("rightEye", -1)
		var leftEyePath: String = ""
		var rightEyePath: String = ""
		if lefteye > 0:
			var leftEyeNode: GLTFNode = nodes[lefteye]
			var skeleton: Skeleton3D = _get_skel_godot_node(
				gstate, nodes, skeletons, leftEyeNode.skeleton
			)
			var skeletonPath: NodePath = animplayer.get_parent().get_path_to(skeleton)
			leftEyePath = (
				str(skeletonPath) + ":" + nodes[human_bone_to_idx["leftEye"]].resource_name
			)
		if righteye > 0:
			var rightEyeNode: GLTFNode = nodes[righteye]
			var skeleton: Skeleton3D = _get_skel_godot_node(
				gstate, nodes, skeletons, rightEyeNode.skeleton
			)
			var skeletonPath: NodePath = animplayer.get_parent().get_path_to(skeleton)
			rightEyePath = (
				str(skeletonPath) + ":" + nodes[human_bone_to_idx["rightEye"]].resource_name
			)

		if lefteye > 0 and righteye > 0:
			var animtrack: int = reset_anim.add_track(Animation.TYPE_ROTATION_3D)
			reset_anim.track_set_path(animtrack, leftEyePath)
			reset_anim.rotation_track_insert_key(animtrack, 0.0, eye_bone_horizontal)
			animtrack = reset_anim.add_track(Animation.TYPE_ROTATION_3D)
			reset_anim.track_set_path(animtrack, rightEyePath)
			reset_anim.rotation_track_insert_key(animtrack, 0.0, eye_bone_horizontal)

		# LookLeft
		var anim_ll = Animation.new()
		animation_library.add_animation("lookLeft", anim_ll)
		if lefteye > 0 and righteye > 0:
			var at = anim_ll.add_track(Animation.TYPE_ROTATION_3D)
			anim_ll.track_set_path(at, leftEyePath)
			anim_ll.track_set_interpolation_type(at, Animation.INTERPOLATION_LINEAR)
			anim_ll.rotation_track_insert_key(
				at,
				horizout["xRange"] / 90.0,
				(
					eye_bone_horizontal
					* (
						(Basis(Vector3(0, 0, 1), -horizout["yRange"] * PI / 180.0))
						. get_rotation_quaternion()
					)
				)
			)
			at = anim_ll.add_track(Animation.TYPE_ROTATION_3D)
			anim_ll.track_set_path(at, rightEyePath)
			anim_ll.track_set_interpolation_type(at, Animation.INTERPOLATION_LINEAR)
			anim_ll.rotation_track_insert_key(
				at,
				horizin["xRange"] / 90.0,
				(
					eye_bone_horizontal
					* (
						(Basis(Vector3(0, 0, 1), -horizin["yRange"] * PI / 180.0))
						. get_rotation_quaternion()
					)
				)
			)

		# LookRight
		var anim_lr = Animation.new()
		animation_library.add_animation("lookRight", anim_lr)
		if lefteye > 0 and righteye > 0:
			var at = anim_lr.add_track(Animation.TYPE_ROTATION_3D)
			anim_lr.track_set_path(at, leftEyePath)
			anim_lr.track_set_interpolation_type(at, Animation.INTERPOLATION_LINEAR)
			anim_lr.rotation_track_insert_key(
				at,
				horizin["xRange"] / 90.0,
				(
					eye_bone_horizontal
					* (
						(Basis(Vector3(0, 0, 1), horizin["yRange"] * PI / 180.0))
						. get_rotation_quaternion()
					)
				)
			)
			at = anim_lr.add_track(Animation.TYPE_ROTATION_3D)
			anim_lr.track_set_path(at, rightEyePath)
			anim_lr.track_set_interpolation_type(at, Animation.INTERPOLATION_LINEAR)
			anim_lr.rotation_track_insert_key(
				at,
				horizout["xRange"] / 90.0,
				(
					eye_bone_horizontal
					* (
						(Basis(Vector3(0, 0, 1), horizout["yRange"] * PI / 180.0))
						. get_rotation_quaternion()
					)
				)
			)

		# LookUp
		var anim_lu = Animation.new()
		animation_library.add_animation("lookUp", anim_lu)
		if lefteye > 0 and righteye > 0:
			var at = anim_lu.add_track(Animation.TYPE_ROTATION_3D)
			anim_lu.track_set_path(at, leftEyePath)
			anim_lu.track_set_interpolation_type(at, Animation.INTERPOLATION_LINEAR)
			anim_lu.rotation_track_insert_key(
				at,
				vertup["xRange"] / 90.0,
				(
					eye_bone_horizontal
					* (
						(Basis(Vector3(1, 0, 0), -vertup["yRange"] * PI / 180.0))
						. get_rotation_quaternion()
					)
				)
			)
			at = anim_lu.add_track(Animation.TYPE_ROTATION_3D)
			anim_lu.track_set_path(at, rightEyePath)
			anim_lu.track_set_interpolation_type(at, Animation.INTERPOLATION_LINEAR)
			anim_lu.rotation_track_insert_key(
				at,
				vertup["xRange"] / 90.0,
				(
					eye_bone_horizontal
					* (
						(Basis(Vector3(1, 0, 0), -vertup["yRange"] * PI / 180.0))
						. get_rotation_quaternion()
					)
				)
			)

		# LookDown
		var anim_ld = Animation.new()
		animation_library.add_animation("lookDown", anim_ld)
		if lefteye > 0 and righteye > 0:
			var at = anim_ld.add_track(Animation.TYPE_ROTATION_3D)
			anim_ld.track_set_path(at, leftEyePath)
			anim_ld.track_set_interpolation_type(at, Animation.INTERPOLATION_LINEAR)
			anim_ld.rotation_track_insert_key(
				at,
				vertdown["xRange"] / 90.0,
				(
					eye_bone_horizontal
					* (
						(Basis(Vector3(1, 0, 0), vertdown["yRange"] * PI / 180.0))
						. get_rotation_quaternion()
					)
				)
			)
			at = anim_ld.add_track(Animation.TYPE_ROTATION_3D)
			anim_ld.track_set_path(at, rightEyePath)
			anim_ld.track_set_interpolation_type(at, Animation.INTERPOLATION_LINEAR)
			anim_ld.rotation_track_insert_key(
				at,
				vertdown["xRange"] / 90.0,
				(
					eye_bone_horizontal
					* (
						(Basis(Vector3(1, 0, 0), vertdown["yRange"] * PI / 180.0))
						. get_rotation_quaternion()
					)
				)
			)

	animation_library.add_animation("RESET", reset_anim)
	animplayer.add_animation_library("", animation_library)
	return animplayer


const vrm_animation_presets: Dictionary = {
	"happy": true,
	"angry": true,
	"sad": true,
	"relaxed": true,
	"surprised": true,
	"aa": true,
	"ih": true,
	"ou": true,
	"ee": true,
	"oh": true,
	"blink": true,
	"blinkLeft": true,
	"blinkRight": true,
	"lookUp": true,
	"lookDown": true,
	"lookLeft": true,
	"lookRight": true,
	"neutral": true,
}


static func setup_animation_player_v1(
	animplayer: AnimationPlayer,
	vrm_extension: Dictionary,
	gstate: GLTFState,
	human_bone_to_idx: Dictionary,
	pose_diffs: Array[Basis]
) -> AnimationPlayer:
	# Remove all glTF animation players for safety.
	for i in range(gstate.get_animation_players_count(0)):
		var node: AnimationPlayer = gstate.get_animation_player(i)
		node.get_parent().remove_child(node)

	var animation_library: AnimationLibrary = AnimationLibrary.new()

	var materials = gstate.get_materials()
	var nodes = gstate.get_nodes()

	var firstperson = vrm_extension.get("firstPerson", {})
	var lookAt = vrm_extension.get("lookAt", {})

	var skeletons: Array = gstate.get_skeletons()
	var head_relative_bones: Dictionary = {}
	var node_to_head_hidden_node: Dictionary = {}

	var lefteye: int = human_bone_to_idx.get("leftEye", -1)
	var righteye: int = human_bone_to_idx.get("rightEye", -1)

	var head_bone_idx = human_bone_to_idx.get("head", -1)
	if head_bone_idx >= 0:
		var headNode: GLTFNode = nodes[head_bone_idx]
		var skel: Skeleton3D = _get_skel_godot_node(gstate, nodes, skeletons, headNode.skeleton)

		var head_attach: BoneAttachment3D = null
		for child in skel.find_children("*", "BoneAttachment3D"):
			var child_attach: BoneAttachment3D = child as BoneAttachment3D
			if child_attach.bone_name == "Head":
				head_attach = child_attach
				break
		if head_attach == null:
			head_attach = BoneAttachment3D.new()
			head_attach.name = "Head"
			skel.add_child(head_attach)
			head_attach.owner = skel.owner
			head_attach.bone_name = "Head"
			var head_bone_offset: Node3D = Node3D.new()
			head_bone_offset.name = "LookOffset"
			head_attach.add_child(head_bone_offset)
			head_bone_offset.unique_name_in_owner = true
			head_bone_offset.owner = skel.owner
			var look_offset = Vector3(0, 0, 0)
			if lookAt.has("offsetFromHeadBone"):
				var gltf_look_offset = lookAt["offsetFromHeadBone"]
				look_offset = (
					pose_diffs[skel.find_bone("Head")]
					* Vector3(gltf_look_offset[0], gltf_look_offset[1], gltf_look_offset[2])
				)
			elif lefteye >= 0 and righteye >= 0:
				look_offset = skel.get_bone_rest(lefteye).origin.lerp(
					skel.get_bone_rest(righteye).origin, 0.5
				)
			head_bone_offset.position = look_offset

		vrm_utils._recurse_bones(head_relative_bones, skel, skel.find_bone("Head"))

	var mesh_annotations_by_node = {}
	for meshannotation in firstperson.get("meshAnnotations", []):
		mesh_annotations_by_node[int(meshannotation["node"])] = meshannotation.get("type", "auto")

	vrm_utils.perform_head_hiding(
		gstate, mesh_annotations_by_node, head_relative_bones, node_to_head_hidden_node
	)

	var meshes = gstate.get_meshes()
	var expressions = vrm_extension.get("expressions", {})
	var mesh_idx_to_meshinstance: Dictionary = {}
	var material_idx_to_mesh_and_surface_idx: Dictionary = {}
	var material_to_idx: Dictionary = {}
	for i in range(materials.size()):
		material_to_idx[materials[i]] = i
	for i in range(meshes.size()):
		var gltfmesh: GLTFMesh = meshes[i]
		for j in range(gltfmesh.mesh.get_surface_count()):
			material_idx_to_mesh_and_surface_idx[material_to_idx[gltfmesh.mesh.get_surface_material(j)]] = [
				i, j
			]

	for i in range(nodes.size()):
		var gltfnode: GLTFNode = nodes[i]
		var mesh_idx: int = gltfnode.mesh
		if mesh_idx != -1:
			var scenenode: ImporterMeshInstance3D = gstate.get_scene_node(i)
			mesh_idx_to_meshinstance[mesh_idx] = scenenode

	var default_values: Dictionary = {}
	var default_blend_shapes: Dictionary = {}

	var all_presets = expressions.get("preset", {})
	for expression_name in all_presets:
		var expression = all_presets[expression_name]
		if lookAt.get("type", "") != "bone" or not vrm_animation_to_look_at.has(expression_name):
			var anim: Animation = create_animation_v1(
				default_values,
				default_blend_shapes,
				expression_name,
				expression,
				animplayer,
				gstate,
				material_idx_to_mesh_and_surface_idx,
				mesh_idx_to_meshinstance,
				node_to_head_hidden_node,
				lookAt
			)
			animation_library.add_animation(expression_name, anim)
		if vrm_animation_to_look_at.has(expression_name):
			var anim_raw: Animation = create_animation_v1(
				default_values,
				default_blend_shapes,
				expression_name + "Raw",
				expression,
				animplayer,
				gstate,
				material_idx_to_mesh_and_surface_idx,
				mesh_idx_to_meshinstance,
				node_to_head_hidden_node,
				{}
			)
			animation_library.add_animation(expression_name + "Raw", anim_raw)

	var custom_presets = expressions.get("custom", {})
	for expression_name in custom_presets:
		if all_presets.has(expression_name):
			continue
		if vrm_animation_to_look_at.has(expression_name):
			continue
		var expression = custom_presets[expression_name]
		var anim: Animation = create_animation_v1(
			default_values,
			default_blend_shapes,
			expression_name,
			expression,
			animplayer,
			gstate,
			material_idx_to_mesh_and_surface_idx,
			mesh_idx_to_meshinstance,
			node_to_head_hidden_node,
			lookAt
		)
		animation_library.add_animation(expression_name, anim)

	var eye_bone_horizontal: Quaternion = Quaternion.from_euler(Vector3(PI / 2, 0, 0))
	var leftEyePath: String = ""
	var rightEyePath: String = ""
	if lookAt.get("type", "") == "bone" and lefteye >= 0 and righteye >= 0:
		var leftEyeNode: GLTFNode = nodes[lefteye]
		var rightEyeNode: GLTFNode = nodes[righteye]
		var skeleton: Skeleton3D = _get_skel_godot_node(
			gstate, nodes, skeletons, leftEyeNode.skeleton
		)
		var skeletonPath: NodePath = animplayer.get_parent().get_path_to(skeleton)
		leftEyePath = (str(skeletonPath) + ":" + nodes[human_bone_to_idx["leftEye"]].resource_name)
		rightEyePath = (
			str(skeletonPath) + ":" + nodes[human_bone_to_idx["rightEye"]].resource_name
		)

	if (
		lookAt.get("type", "") == "bone"
		and not leftEyePath.is_empty()
		and not rightEyePath.is_empty()
	):
		var horizout = lookAt.get("rangeMapHorizontalOuter", {})
		var horizin = lookAt.get("rangeMapHorizontalInner", {})
		var vertdown = lookAt.get("rangeMapVerticalDown", {})
		var vertup = lookAt.get("rangeMapVerticalUp", {})

		var look_anims = {
			"lookLeft": [horizout, horizin],
			"lookRight": [horizout, horizin],
			"lookUp": [vertup, vertup],
			"lookDown": [vertdown, vertdown]
		}

		for anim_name in look_anims:
			var anim = Animation.new()
			animation_library.add_animation(anim_name, anim)
			var range_l = look_anims[anim_name][0]
			var range_r = look_anims[anim_name][1]

			var at = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(at, leftEyePath)
			anim.track_set_interpolation_type(at, Animation.INTERPOLATION_LINEAR)
			var input_val = range_l.get("inputMaxValue", 90) / 180.0
			var scale = range_l.get("outputScale", 1.0)

			if anim_name == "lookLeft":
				anim.rotation_track_insert_key(
					at,
					input_val,
					(
						eye_bone_horizontal
						* (
							(Basis(Vector3(0, 0, 1), -scale * input_val * PI / 180.0))
							. get_rotation_quaternion()
						)
					)
				)
			elif anim_name == "lookRight":
				anim.rotation_track_insert_key(
					at,
					input_val,
					(
						eye_bone_horizontal
						* (
							(Basis(Vector3(0, 0, 1), scale * input_val * PI / 180.0))
							. get_rotation_quaternion()
						)
					)
				)
			elif anim_name == "lookUp":
				anim.rotation_track_insert_key(
					at,
					input_val,
					(
						eye_bone_horizontal
						* (
							(Basis(Vector3(1, 0, 0), -scale * input_val * PI / 180.0))
							. get_rotation_quaternion()
						)
					)
				)
			elif anim_name == "lookDown":
				anim.rotation_track_insert_key(
					at,
					input_val,
					(
						eye_bone_horizontal
						* (
							(Basis(Vector3(1, 0, 0), scale * input_val * PI / 180.0))
							. get_rotation_quaternion()
						)
					)
				)

			at = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(at, rightEyePath)
			anim.track_set_interpolation_type(at, Animation.INTERPOLATION_LINEAR)
			input_val = range_r.get("inputMaxValue", 90) / 180.0
			scale = range_r.get("outputScale", 1.0)
			if anim_name == "lookLeft":
				anim.rotation_track_insert_key(
					at,
					input_val,
					(
						eye_bone_horizontal
						* (
							(Basis(Vector3(0, 0, 1), -scale * input_val * PI / 180.0))
							. get_rotation_quaternion()
						)
					)
				)
			elif anim_name == "lookRight":
				anim.rotation_track_insert_key(
					at,
					input_val,
					(
						eye_bone_horizontal
						* (
							(Basis(Vector3(0, 0, 1), scale * input_val * PI / 180.0))
							. get_rotation_quaternion()
						)
					)
				)
			elif anim_name == "lookUp":
				anim.rotation_track_insert_key(
					at,
					input_val,
					(
						eye_bone_horizontal
						* (
							(Basis(Vector3(1, 0, 0), -scale * input_val * PI / 180.0))
							. get_rotation_quaternion()
						)
					)
				)
			elif anim_name == "lookDown":
				anim.rotation_track_insert_key(
					at,
					input_val,
					(
						eye_bone_horizontal
						* (
							(Basis(Vector3(1, 0, 0), scale * input_val * PI / 180.0))
							. get_rotation_quaternion()
						)
					)
				)

	var reset_anim: Animation = Animation.new()
	reset_anim.resource_name = "RESET"
	for anim_path in default_values:
		var animtrack: int = reset_anim.add_track(Animation.TYPE_VALUE)
		reset_anim.track_set_path(animtrack, anim_path)
		reset_anim.track_insert_key(animtrack, 0.0, default_values[anim_path])
	for anim_path in default_blend_shapes:
		var animtrack: int = reset_anim.add_track(Animation.TYPE_BLEND_SHAPE)
		reset_anim.track_set_path(animtrack, anim_path)
		reset_anim.blend_shape_track_insert_key(animtrack, 0.0, default_blend_shapes[anim_path])

	if (
		lookAt.get("type", "") == "bone"
		and not leftEyePath.is_empty()
		and not rightEyePath.is_empty()
	):
		var animtrack = reset_anim.add_track(Animation.TYPE_ROTATION_3D)
		reset_anim.track_set_path(animtrack, leftEyePath)
		reset_anim.rotation_track_insert_key(animtrack, 0.0, eye_bone_horizontal)
		animtrack = reset_anim.add_track(Animation.TYPE_ROTATION_3D)
		reset_anim.track_set_path(animtrack, rightEyePath)
		reset_anim.rotation_track_insert_key(animtrack, 0.0, eye_bone_horizontal)

	animation_library.add_animation(&"RESET", reset_anim)
	animplayer.add_animation_library("", animation_library)
	return animplayer


static func export_animations_v1(
	root_node: Node,
	skel: Skeleton3D,
	animplayer: AnimationPlayer,
	vrm_extension: Dictionary,
	gstate: GLTFState
):
	if (
		animplayer.has_animation("lookLeft")
		and animplayer.has_animation("lookUp")
		and animplayer.has_animation("lookDown")
	):
		var look_left_anim: Animation = animplayer.get_animation("lookLeft")
		var look_up_anim: Animation = animplayer.get_animation("lookUp")
		var look_down_anim: Animation = animplayer.get_animation("lookDown")
		var look_at = {
			"rangeMapHorizontalInner": {},
			"rangeMapHorizontalOuter": {},
			"rangeMapVerticalDown": {},
			"rangeMapVerticalUp": {}
		}
		if look_left_anim.track_get_type(0) == Animation.TYPE_ROTATION_3D:
			look_at["type"] = "bone"
		else:
			look_at["type"] = "expression"
		if look_at["type"] == "bone":
			for i in range(look_left_anim.get_track_count()):
				var key: String
				if look_left_anim.track_get_path(i).get_subname(0) == "leftEye":
					key = "rangeMapHorizontalOuter"
				elif look_left_anim.track_get_path(i).get_subname(0) == "rightEye":
					key = "rangeMapHorizontalInner"
				else:
					continue
				var look_length = look_left_anim.track_get_key_time(i, 0)
				var quat: Quaternion = look_left_anim.track_get_key_value(i, 0)
				var angle_from_quat: float = quat.get_angle() * sign(quat.get_axis().y)
				look_at[key] = {
					"inputMaxValue": look_length * 180.0,
					"outputScale": abs(angle_from_quat * 180.0 / PI)
				}
			for i in range(look_up_anim.get_track_count()):
				if look_up_anim.track_get_path(i).get_subname(0) != "leftEye":
					continue
				var look_length = look_up_anim.track_get_key_time(i, 0)
				var quat: Quaternion = look_up_anim.track_get_key_value(i, 0)
				var angle_from_quat: float = quat.get_angle() * sign(quat.get_axis().y)
				look_at["rangeMapVerticalUp"] = {
					"inputMaxValue": look_length * 180.0,
					"outputScale": abs(angle_from_quat * 180.0 / PI)
				}
			for i in range(look_down_anim.get_track_count()):
				if look_down_anim.track_get_path(i).get_subname(0) != "leftEye":
					continue
				var look_length = look_down_anim.track_get_key_time(i, 0)
				var quat: Quaternion = look_down_anim.track_get_key_value(i, 0)
				var angle_from_quat: float = quat.get_angle() * sign(quat.get_axis().y)
				look_at["rangeMapVerticalDown"] = {
					"inputMaxValue": look_length * 180.0,
					"outputScale": abs(angle_from_quat * 180.0 / PI)
				}
		else:
			var look_length = look_left_anim.track_get_key_time(0, 0)
			look_at["rangeMapHorizontalOuter"] = {
				"inputMaxValue": look_length * 180.0, "outputScale": 1.0
			}
			look_at["rangeMapHorizontalInner"] = {
				"inputMaxValue": look_length * 180.0, "outputScale": 1.0
			}
			look_length = look_up_anim.track_get_key_time(0, 0)
			look_at["rangeMapVerticalUp"] = {
				"inputMaxValue": look_length * 180.0, "outputScale": 1.0
			}
			look_length = look_down_anim.track_get_key_time(0, 0)
			look_at["rangeMapVerticalDown"] = {
				"inputMaxValue": look_length * 180.0, "outputScale": 1.0
			}
		vrm_extension["lookAt"] = look_at

	var presets: Dictionary = {}
	var custom: Dictionary = {}
	var mat_lookup: Dictionary = {}
	var gltf_materials: Array[Material] = gstate.materials
	var shader_to_standard_material = gstate.get_meta("shader_to_standard_material")
	if typeof(shader_to_standard_material) == TYPE_DICTIONARY:
		for i in range(len(gltf_materials)):
			if shader_to_standard_material.has(gltf_materials[i]):
				mat_lookup[shader_to_standard_material[gltf_materials[i]]] = i
			mat_lookup[gltf_materials[i]] = i
	var mesh_bs_lookup: Dictionary = {}
	var gltf_meshes: Array[GLTFMesh] = gstate.meshes
	for i in range(len(gltf_meshes)):
		var mesh: ImporterMesh = gltf_meshes[i].mesh
		var blend_shape_to_idx: Dictionary = {}
		for bsi in range(mesh.get_blend_shape_count()):
			blend_shape_to_idx[mesh.get_blend_shape_name(bsi)] = bsi
		mesh_bs_lookup[gltf_meshes[i].mesh] = blend_shape_to_idx
	var mesh_instances = animplayer.get_parent().find_children("*", "MeshInstance3D")
	for meshinst in mesh_instances:
		var mesh: Mesh = meshinst.mesh
		var blend_shape_to_idx: Dictionary = {}
		if mesh is ArrayMesh:
			for bsi in range(mesh.get_blend_shape_count()):
				blend_shape_to_idx[mesh.get_blend_shape_name(bsi)] = bsi
		mesh_bs_lookup[mesh] = blend_shape_to_idx
	mesh_instances = animplayer.get_parent().find_children("*", "ImporterMeshInstance3D")
	for meshinst in mesh_instances:
		var mesh: ImporterMesh = meshinst.mesh
		var blend_shape_to_idx: Dictionary = {}
		for bsi in range(mesh.get_blend_shape_count()):
			blend_shape_to_idx[mesh.get_blend_shape_name(bsi)] = bsi
		mesh_bs_lookup[mesh] = blend_shape_to_idx

	for exp in animplayer.get_animation_list():
		if exp == "RESET":
			continue
		if exp.ends_with("Raw") and vrm_animation_to_look_at.has(exp.substr(0, len(exp) - 3)):
			exp = exp.substr(0, len(exp) - 3)
		var expression: Dictionary = {}
		var texture_transform_binds = {}
		var morph_target_binds = []
		var material_color_binds = []
		var anim: Animation = animplayer.get_animation(exp)
		if anim.get_track_count() == 0:
			continue
		for i in range(anim.get_track_count()):
			var anim_path = anim.track_get_path(i)
			var meshinst: Node = animplayer.get_parent().get_node(
				NodePath(str(anim_path.get_concatenated_names()))
			)
			var val = anim.track_get_key_value(i, 0)
			if anim.track_get_type(i) == Animation.TYPE_BLEND_SHAPE:
				if val == 0.0:
					continue
				var gltf_blendshape_idx = mesh_bs_lookup[meshinst.mesh][anim_path.get_subname(0)]
				morph_target_binds.push_back(
					{
						"node": gstate.get_node_index(meshinst),
						"index": gltf_blendshape_idx,
						"weight": val
					}
				)
			elif anim.track_get_type(i) == Animation.TYPE_VALUE:
				if (
					anim_path.get_subname_count() < 3
					or anim_path.get_subname(0) != "mesh"
					or not anim_path.get_subname(1).begins_with("surface_")
					or not anim_path.get_subname(1).ends_with("/material")
				):
					push_warning("Ignoring unsupported animation value track " + str(anim_path))
					continue
				var material_idx = int(anim_path.get_subname(1).split("/")[0].split("_")[1])
				var gltf_material_idx: int
				if meshinst is ImporterMeshInstance3D:
					gltf_material_idx = mat_lookup[meshinst.mesh.get_surface_material(material_idx)]
				if meshinst is MeshInstance3D:
					if meshinst.get_surface_override_material(material_idx) == null:
						gltf_material_idx = mat_lookup[meshinst.mesh.surface_get_material(
							material_idx
						)]
					else:
						gltf_material_idx = mat_lookup[meshinst.get_surface_override_material(
							material_idx
						)]
				if typeof(val) == TYPE_COLOR:
					var property_mapping = {
						"shader_parameter/_Color": "color",
						"shader_parameter/_EmissionColor": "emissionColor",
						"shader_parameter/_ShadeColor": "shadeColor",
						"shader_parameter/_SphereColor": "matcapColor",
						"shader_parameter/_RimColor": "rimColor",
						"shader_parameter/_OutlineColor": "outlineColor",
						"albedo_color": "color",
						"emission": "emissionColor",
					}
					var shader_prop = anim_path.get_subname(2)
					if not property_mapping.has(shader_prop):
						push_warning("Unable to serialize color animation " + str(shader_prop))
						continue
					var material_bind = {
						"material": gltf_material_idx,
						"type": property_mapping[shader_prop],
						"targetValue": [val.r, val.g, val.b, val.a]
					}
					material_color_binds.push_back(material_bind)
				elif typeof(val) == TYPE_VECTOR4:
					var shader_prop = anim_path.get_subname(2)
					assert(shader_prop == "shader_parameter/_MainTex_ST")
					texture_transform_binds[gltf_material_idx] = {
						"material": gltf_material_idx,
						"scale": [val.x, val.y],
						"offset": [val.z, val.w]
					}
				elif typeof(val) == TYPE_VECTOR3:
					var shader_prop = anim_path.get_subname(2)
					if not texture_transform_binds.has(gltf_material_idx):
						texture_transform_binds[gltf_material_idx] = {}
					var tex_bind = texture_transform_binds[gltf_material_idx]
					tex_bind["material"] = gltf_material_idx
					if shader_prop == "uv1_offset":
						tex_bind["offset"] = [val.z, val.w]
					elif shader_prop == "uv1_scale":
						tex_bind["scale"] = [val.x, val.y]
		if (
			morph_target_binds.is_empty()
			and material_color_binds.is_empty()
			and texture_transform_binds.is_empty()
		):
			continue
		if not morph_target_binds.is_empty():
			expression["morphTargetBinds"] = morph_target_binds
		if not material_color_binds.is_empty():
			expression["materialColorBinds"] = material_color_binds
		if not texture_transform_binds.is_empty():
			expression["textureTransformBinds"] = texture_transform_binds.values()
		expression["isBinary"] = anim.get_meta(
			"vrm_is_binary", anim.track_get_interpolation_type(0) == Animation.INTERPOLATION_NEAREST
		)
		if anim.has_meta("vrm_override_blink"):
			expression["overrideBlink"] = anim.get_meta("vrm_override_blink")
		if anim.has_meta("vrm_override_look_at"):
			expression["overrideLookAt"] = anim.get_meta("vrm_override_look_at")
		if anim.has_meta("vrm_override_mouth"):
			expression["overrideMouth"] = anim.get_meta("vrm_override_mouth")
		if vrm_animation_presets.has(exp):
			presets[exp] = expression
		elif "/" not in exp:
			custom[exp] = expression

	vrm_extension["expressions"] = {"preset": presets, "custom": custom}


static func add_joints_recursive(
	new_joints_set: Dictionary, gltf_nodes: Array, bone: int, include_child_meshes: bool = false
) -> void:
	if bone < 0:
		return
	var gltf_node: Dictionary = gltf_nodes[bone]
	if not include_child_meshes and gltf_node.get("mesh", -1) != -1:
		return
	new_joints_set[bone] = true
	for child_node in gltf_node.get("children", []):
		if not new_joints_set.has(child_node):
			add_joints_recursive(new_joints_set, gltf_nodes, int(child_node))


static func add_joint_set_as_skin(obj: Dictionary, new_joints_set: Dictionary) -> void:
	var new_joints = []
	for node in new_joints_set:
		new_joints.push_back(node)
	new_joints.sort()
	var new_skin: Dictionary = {"joints": new_joints}
	if not obj.has("skins"):
		obj["skins"] = []
	obj["skins"].push_back(new_skin)


static func add_vrm_nodes_to_skin_v0(obj: Dictionary) -> bool:
	var vrm_extension: Dictionary = obj.get("extensions", {}).get("VRM", {})
	if not vrm_extension.has("humanoid"):
		return false
	var new_joints_set = {}
	var secondaryAnimation = vrm_extension.get("secondaryAnimation", {})
	for bone_group in secondaryAnimation.get("boneGroups", []):
		for bone in bone_group["bones"]:
			add_joints_recursive(new_joints_set, obj["nodes"], int(bone), true)
	for collider_group in secondaryAnimation.get("colliderGroups", []):
		if int(collider_group["node"]) >= 0:
			new_joints_set[int(collider_group["node"])] = true
	var firstPerson = vrm_extension.get("firstPerson", {})
	if firstPerson.get("firstPersonBone", -1) >= 0:
		new_joints_set[int(firstPerson["firstPersonBone"])] = true
	for human_bone in vrm_extension["humanoid"]["humanBones"]:
		add_joints_recursive(new_joints_set, obj["nodes"], int(human_bone["node"]), false)
	add_joint_set_as_skin(obj, new_joints_set)
	return true


static func add_vrm_nodes_to_skin_v1(obj: Dictionary) -> bool:
	var vrm_extension: Dictionary = obj.get("extensions", {}).get("VRMC_vrm", {})
	if not vrm_extension.has("humanoid"):
		return false
	var new_joints_set = {}
	var human_bones: Dictionary = vrm_extension["humanoid"]["humanBones"]
	for human_bone in human_bones:
		add_joints_recursive(
			new_joints_set, obj["nodes"], int(human_bones[human_bone]["node"]), false
		)
	add_joint_set_as_skin(obj, new_joints_set)
	return true


static func create_animation_v1(
	default_values: Dictionary,
	default_blend_shapes: Dictionary,
	anim_name: String,
	expression: Dictionary,
	animplayer: AnimationPlayer,
	gstate: GLTFState,
	material_idx_to_mesh_and_surface_idx: Dictionary,
	mesh_idx_to_meshinstance: Dictionary,
	node_to_head_hidden_node: Dictionary,
	look_at: Dictionary
) -> Animation:
	var anim = Animation.new()
	anim.resource_name = anim_name

	var extra_weight: float = 1.0
	var input_key: float = 0.0
	if vrm_animation_to_look_at.has(anim_name):
		extra_weight = look_at.get(vrm_animation_to_look_at[anim_name], {}).get("outputScale", 1.0)
		input_key = (
			look_at.get(vrm_animation_to_look_at[anim_name], {}).get("inputMaxValue", 90.0) / 180.0
		)

	var interpolation_type = (
		Animation.INTERPOLATION_NEAREST
		if bool(expression.get("isBinary", false))
		else Animation.INTERPOLATION_LINEAR
	)
	anim.set_meta("vrm_is_binary", expression.get("isBinary", false))
	anim.set_meta("vrm_override_blink", expression.get("overrideBlink", false))
	anim.set_meta("vrm_override_look_at", expression.get("overrideLookAt", false))
	anim.set_meta("vrm_override_mouth", expression.get("overrideMouth", false))

	for textransformbind in expression.get("textureTransformBinds", []):
		var mat_idx = int(textransformbind["material"])
		if not material_idx_to_mesh_and_surface_idx.has(mat_idx):
			continue
		var mesh_and_surface_idx = material_idx_to_mesh_and_surface_idx[mat_idx]
		var node: ImporterMeshInstance3D = mesh_idx_to_meshinstance[mesh_and_surface_idx[0]]
		var surface_idx = mesh_and_surface_idx[1]
		var mat: Material = node.mesh.get_surface_material(surface_idx)
		var scale = textransformbind["scale"]
		var offset = textransformbind["offset"]

		var props = []
		if mat is ShaderMaterial:
			var param = mat.get_shader_parameter("_MainTex_ST")
			if param is Vector4:
				var newval = Vector4(scale[0], scale[1], offset[0], offset[1])
				props.append(["shader_parameter/_MainTex_ST", param, newval])
				if mat.next_pass != null:
					props.append(["next_pass:shader_parameter/_MainTex_ST", param, newval])
		elif mat is BaseMaterial3D:
			props.append(["uv1_offset", mat.uv1_offset, Vector3(offset[0], offset[1], 0)])
			props.append(["uv1_scale", mat.uv1_scale, Vector3(scale[0], scale[1], 0)])

		for p in props:
			var animtrack: int = anim.add_track(Animation.TYPE_VALUE)
			var anim_path = (
				str(animplayer.get_parent().get_path_to(node))
				+ ":mesh:surface_"
				+ str(surface_idx)
				+ "/material:"
				+ p[0]
			)
			anim.track_set_path(animtrack, anim_path)
			anim.track_set_interpolation_type(animtrack, interpolation_type)
			anim.track_insert_key(animtrack, input_key, p[1].lerp(p[2], extra_weight))
			default_values[anim_path] = p[1]

	for matbind in expression.get("materialColorBinds", []):
		var mat_idx = int(matbind["material"])
		if not material_idx_to_mesh_and_surface_idx.has(mat_idx):
			continue
		var mesh_and_surface_idx = material_idx_to_mesh_and_surface_idx[mat_idx]
		var node: ImporterMeshInstance3D = mesh_idx_to_meshinstance[mesh_and_surface_idx[0]]
		var surface_idx = mesh_and_surface_idx[1]
		var mat: Material = node.get_surface_material(surface_idx)
		var tv: Array = matbind["targetValue"]
		var newvalue: Color = Color(tv[0], tv[1], tv[2], tv[3])
		if matbind["type"] != "color" and matbind["type"] != "outlineColor":
			newvalue.a = 1.0

		var property_path = ""
		var origvalue: Color

		if mat is ShaderMaterial:
			var property_mapping = {
				"color": "_Color",
				"emissionColor": "_EmissionColor",
				"shadeColor": "_ShadeColor",
				"matcapColor": "_SphereColor",
				"rimColor": "_RimColor",
				"outlineColor": "_OutlineColor",
			}
			var param_name = property_mapping.get(matbind["type"], matbind["type"])
			var param = mat.get_shader_parameter(param_name)
			if param is Color:
				origvalue = param
				property_path = "shader_parameter/" + param_name
				if matbind["type"] == "outlineColor":
					property_path = "next_pass:" + property_path
		elif mat is BaseMaterial3D:
			if matbind["type"] == "color":
				property_path = "albedo_color"
				origvalue = mat.albedo_color
			elif matbind["type"] == "emissionColor":
				property_path = "emission"
				origvalue = mat.emission

		if not property_path.is_empty():
			var animtrack: int = anim.add_track(Animation.TYPE_VALUE)
			var anim_path = (
				str(animplayer.get_parent().get_path_to(node))
				+ ":mesh:surface_"
				+ str(surface_idx)
				+ "/material:"
				+ property_path
			)
			anim.track_set_path(animtrack, anim_path)
			anim.track_set_interpolation_type(animtrack, interpolation_type)
			anim.track_insert_key(animtrack, input_key, origvalue.lerp(newvalue, extra_weight))
			default_values[anim_path] = origvalue

	for bind in expression.get("morphTargetBinds", []):
		var node_maybe = gstate.get_scene_node(int(bind["node"]))
		if not node_maybe is ImporterMeshInstance3D:
			continue
		var node = node_maybe as ImporterMeshInstance3D
		var nodeMesh = node.mesh
		if (
			nodeMesh == null
			or bind["index"] < 0
			or bind["index"] >= nodeMesh.get_blend_shape_count()
		):
			continue

		var bs_name = str(nodeMesh.get_blend_shape_name(int(bind["index"])))
		var target_nodes = [node]
		var cur = node_to_head_hidden_node.get(node)
		while cur != null:
			target_nodes.append(cur)
			cur = node_to_head_hidden_node.get(cur)

		for target in target_nodes:
			var animtrack: int = anim.add_track(Animation.TYPE_BLEND_SHAPE)
			var anim_path = str(animplayer.get_parent().get_path_to(target)) + ":" + bs_name
			anim.track_set_path(animtrack, anim_path)
			anim.track_set_interpolation_type(animtrack, interpolation_type)
			anim.blend_shape_track_insert_key(animtrack, input_key, 0.99999 * float(bind["weight"]))
			default_blend_shapes[anim_path] = 0.0

	return anim
