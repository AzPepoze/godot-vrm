@tool
extends RefCounted

const VRMLogger = preload("../../core/logger.gd")
const vrm_animation_constants = preload("../common/animation/vrm_animation_constants.gd")


static func export_animations_v1(
    root_node: Node,
    skel: Skeleton3D,
    animplayer: AnimationPlayer,
    vrm_extension: Dictionary,
    gstate: GLTFState
):
    VRMLogger.debug("vrm_animation_export.gd", "export_animations_v1: exporting animations")
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
        if (
            exp.ends_with("Raw")
            and vrm_animation_constants.vrm_animation_to_look_at.has(exp.substr(0, len(exp) - 3))
        ):
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
                    VRMLogger.warning(
                        "vrm_animation_export.gd",
                        "Ignoring unsupported animation value track " + str(anim_path)
                    )
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
                        VRMLogger.warning(
                            "vrm_animation_export.gd",
                            "Unable to serialize color animation " + str(shader_prop)
                        )
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
        if vrm_animation_constants.vrm_animation_presets.has(exp):
            presets[exp] = expression
        elif "/" not in exp:
            custom[exp] = expression

    vrm_extension["expressions"] = {"preset": presets, "custom": custom}
    VRMLogger.info(
        "vrm_animation_export.gd",
        (
            "export_animations_v1: exported %d preset + %d custom expressions"
            % [presets.size(), custom.size()]
        )
    )


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
