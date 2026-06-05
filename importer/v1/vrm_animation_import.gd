@tool
extends RefCounted

const vrm_utils = preload("../common/vrm_utils.gd")
const vrm_animation_constants = preload("../common/animation/vrm_animation_constants.gd")


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

        var head_bone_name: String = nodes[head_bone_idx].resource_name
        var head_attach: BoneAttachment3D = null
        for child in skel.find_children("*", "BoneAttachment3D"):
            var child_attach: BoneAttachment3D = child as BoneAttachment3D
            if child_attach.bone_name == head_bone_name:
                head_attach = child_attach
                break
        if head_attach == null:
            head_attach = BoneAttachment3D.new()
            head_attach.name = "Head"
            skel.add_child(head_attach)
            head_attach.owner = skel.owner
            head_attach.bone_name = head_bone_name
            var head_bone_offset: Node3D = Node3D.new()
            head_bone_offset.name = "LookOffset"
            head_attach.add_child(head_bone_offset)
            head_bone_offset.unique_name_in_owner = true
            head_bone_offset.owner = skel.owner
            var look_offset = Vector3(0, 0, 0)
            if lookAt.has("offsetFromHeadBone"):
                var gltf_look_offset = lookAt["offsetFromHeadBone"]
                var head_bone_idx_in_skel = skel.find_bone(head_bone_name)
                if head_bone_idx_in_skel >= 0 and head_bone_idx_in_skel < pose_diffs.size():
                    look_offset = (
                        pose_diffs[head_bone_idx_in_skel]
                        * Vector3(gltf_look_offset[0], gltf_look_offset[1], gltf_look_offset[2])
                    )
                else:
                    look_offset = Vector3(
                        gltf_look_offset[0], gltf_look_offset[1], gltf_look_offset[2]
                    )
            elif lefteye >= 0 and righteye >= 0:
                look_offset = skel.get_bone_rest(lefteye).origin.lerp(
                    skel.get_bone_rest(righteye).origin, 0.5
                )
            head_bone_offset.position = look_offset

        vrm_utils._recurse_bones(head_relative_bones, skel, skel.find_bone(head_bone_name))

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
        if (
            lookAt.get("type", "") != "bone"
            or not vrm_animation_constants.vrm_animation_to_look_at.has(expression_name)
        ):
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
        if vrm_animation_constants.vrm_animation_to_look_at.has(expression_name):
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
        if vrm_animation_constants.vrm_animation_to_look_at.has(expression_name):
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
        reset_anim.track_insert_key(animtrack, 0.0, default_blend_shapes[anim_path])
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
    if not animplayer.has_animation_library(&""):
        animplayer.add_animation_library("", animation_library)
    else:
        var existing_library: AnimationLibrary = animplayer.get_animation_library("")
        for anim_name in animation_library.get_animation_list():
            if existing_library.has_animation(anim_name):
                existing_library.remove_animation(anim_name)
            var anim: Animation = animation_library.get_animation(anim_name)
            existing_library.add_animation(anim_name, anim)
    return animplayer


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
    if vrm_animation_constants.vrm_animation_to_look_at.has(anim_name):
        extra_weight = (
            look_at
            . get(vrm_animation_constants.vrm_animation_to_look_at[anim_name], {})
            . get("outputScale", 1.0)
        )
        input_key = (
            look_at.get(vrm_animation_constants.vrm_animation_to_look_at[anim_name], {}).get(
                "inputMaxValue", 90.0
            )
            / 180.0
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
