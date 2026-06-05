@tool
extends RefCounted

const VRMLogger = preload("../../core/logger.gd")
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
    VRMLogger.debug(
        "vrm_animation.gd",
        "setup_animation_player_v0: %d blend shape groups" % blend_shape_groups.size()
    )
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

        if vrm_animation_constants.vrm0_to_vrm1_presets.has(shape["presetName"]):
            anim.resource_name = vrm_animation_constants.vrm0_to_vrm1_presets[shape["presetName"]]
            if shape["presetName"].begins_with("look"):
                animation_library.add_animation(
                    vrm_animation_constants.vrm0_to_vrm1_presets[shape["presetName"]] + "Raw", anim
                )
            if (
                firstperson.get("lookAtTypeName", "") != "Bone"
                or not shape["presetName"].begins_with("look")
            ):
                animation_library.add_animation(
                    vrm_animation_constants.vrm0_to_vrm1_presets[shape["presetName"]], anim
                )
        else:
            if shape["presetName"] == "unknown":
                anim.resource_name = shape["name"]
                animation_library.add_animation(shape["name"], anim)
            else:
                VRMLogger.warning("vrm_animation.gd", "Unrecognized preset name " + str(shape))

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
    if not animplayer.has_animation_library(&""):
        animplayer.add_animation_library("", animation_library)
    else:
        var existing_library: AnimationLibrary = animplayer.get_animation_library("")
        for anim_name in animation_library.get_animation_list():
            if existing_library.has_animation(anim_name):
                existing_library.remove_animation(anim_name)
            var anim: Animation = animation_library.get_animation(anim_name)
            existing_library.add_animation(anim_name, anim)
    VRMLogger.info(
        "vrm_animation.gd", "setup_animation_player_v0: animation library set up complete"
    )
    return animplayer
