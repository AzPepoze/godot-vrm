@tool
extends RefCounted

const VRMLogger = preload("../../core/logger.gd")

const mtoon_shader_base_path: String = "res://addons/mtoon/mtoon"


static func _m_to_cm(cm: float) -> float:
    return cm * 100.0


static func _assign_property(
    new_mat: ShaderMaterial, property_name: String, property_value: Variant
) -> void:
    new_mat.set_shader_parameter(property_name, property_value)
    if new_mat.next_pass != null:
        new_mat.next_pass.set_shader_parameter(property_name, property_value)


static func _assign_texture(
    new_mat: ShaderMaterial,
    gltf_images: Array[Texture2D],
    gltf_tex: Array[GLTFTexture],
    texture_name: String,
    texture_info: Dictionary
) -> void:
    var tex: Texture2D = null
    if texture_info.has("index"):
        tex = gltf_images[gltf_tex[texture_info["index"]].src_image]
    _assign_property(new_mat, texture_name, tex)


static func _assign_color(
    new_mat: ShaderMaterial, has_alpha: bool, property_name: String, color_array: Array
) -> void:
    var col: Color
    if has_alpha:
        col = Color(color_array[0], color_array[1], color_array[2], color_array[3])
    else:
        col = Color(color_array[0], color_array[1], color_array[2])
    _assign_property(new_mat, property_name, col)


static func process_vrm_material_v1(
    orig_mat: Material,
    gltf_images: Array[Texture2D],
    gltf_tex: Array[GLTFTexture],
    mat_props: Dictionary,
    vrm_mat_props: Dictionary
) -> Material:
    VRMLogger.debug(
        "vrm_material_processor.gd",
        "process_vrm_material_v1: processing material %s" % orig_mat.resource_name
    )
    var blend_extension: String = ""
    var alpha_mode: String = mat_props.get("alphaMode", "OPAQUE")
    if alpha_mode == "MASK":
        blend_extension = "_cutout"
    if alpha_mode == "BLEND":
        blend_extension = "_trans"
        if vrm_mat_props.get("transparentWithZWrite", false) == true:
            blend_extension += "_zwrite"

    var outline_width_mode: String = vrm_mat_props.get("outlineWidthMode", "none")
    var godot_outline_shader_name: String = ""
    if outline_width_mode != "none":
        godot_outline_shader_name = mtoon_shader_base_path + "_outline" + blend_extension

    var godot_shader_name = mtoon_shader_base_path + blend_extension
    if mat_props.get("doubleSided", false) == true:
        godot_shader_name += "_cull_off"

    var godot_shader: Shader = ResourceLoader.load(godot_shader_name + ".gdshader")
    var new_mat: ShaderMaterial = ShaderMaterial.new()
    new_mat.resource_name = orig_mat.resource_name
    new_mat.shader = godot_shader

    var outline_mat: ShaderMaterial = null
    if !godot_outline_shader_name.is_empty():
        var godot_shader_outline: Shader = ResourceLoader.load(
            godot_outline_shader_name + ".gdshader"
        )
        if godot_shader_outline != null:
            outline_mat = ShaderMaterial.new()
            outline_mat.resource_name = orig_mat.resource_name + "(Outline)"
            outline_mat.shader = godot_shader_outline
            new_mat.next_pass = outline_mat

    var base_color_texture = mat_props.get("pbrMetallicRoughness", {}).get("baseColorTexture", {})
    var khr_texture_transform = base_color_texture.get("extensions", {}).get(
        "KHR_texture_transform", {}
    )
    var offset = khr_texture_transform.get("offset", [0.0, 0.0])
    var scale = khr_texture_transform.get("scale", [1.0, 1.0])
    var texture_repeat = Vector4(scale[0], scale[1], offset[0], offset[1])

    _assign_texture(new_mat, gltf_images, gltf_tex, "_MainTex", base_color_texture)
    _assign_texture(
        new_mat,
        gltf_images,
        gltf_tex,
        "_ShadeTexture",
        vrm_mat_props.get("shadeMultiplyTexture", {})
    )
    _assign_texture(
        new_mat,
        gltf_images,
        gltf_tex,
        "_ShadingGradeTexture",
        vrm_mat_props.get("shadingShiftTexture", {})
    )
    _assign_texture(new_mat, gltf_images, gltf_tex, "_BumpMap", mat_props.get("normalTexture", {}))
    _assign_texture(
        new_mat, gltf_images, gltf_tex, "_EmissionMap", mat_props.get("emissiveTexture", {})
    )

    var emission_mult = 1.0
    var extensions: Dictionary = mat_props.get("extensions", {})
    var vrmc_emissive: Dictionary = extensions.get("VRMC_materials_hdr_emissiveMultiplier", {})
    var khr_emissive: Dictionary = extensions.get("KHR_materials_emissive_strength", {})
    if khr_emissive.has("emissiveStrength"):
        emission_mult = khr_emissive["emissiveStrength"]
    elif vrmc_emissive.has("emissiveMultiplier"):
        emission_mult = vrmc_emissive["emissiveMultiplier"]
    new_mat.set_shader_parameter("_EmissionMultiplier", emission_mult)

    _assign_texture(
        new_mat, gltf_images, gltf_tex, "_RimTexture", vrm_mat_props.get("rimMultiplyTexture", {})
    )
    _assign_texture(
        new_mat, gltf_images, gltf_tex, "_SphereAdd", vrm_mat_props.get("matcapTexture", {})
    )
    _assign_texture(
        new_mat,
        gltf_images,
        gltf_tex,
        "_UvAnimMaskTexture",
        vrm_mat_props.get("uvAnimationMaskTexture", {})
    )
    _assign_texture(
        new_mat,
        gltf_images,
        gltf_tex,
        "_OutlineWidthTexture",
        vrm_mat_props.get("outlineWidthMultiplyTexture", {})
    )

    _assign_color(
        new_mat,
        true,
        "_Color",
        mat_props.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1])
    )
    _assign_color(new_mat, false, "_ShadeColor", vrm_mat_props.get("shadeColorFactor", [0, 0, 0]))
    _assign_color(
        new_mat, false, "_RimColor", vrm_mat_props.get("parametricRimColorFactor", [0, 0, 0])
    )
    _assign_color(new_mat, false, "_MatcapColor", vrm_mat_props.get("matcapFactor", [1, 1, 1]))
    _assign_color(
        new_mat, false, "_OutlineColor", vrm_mat_props.get("outlineColorFactor", [0, 0, 0, 1])
    )
    _assign_color(new_mat, false, "_EmissionColor", mat_props.get("emissiveFactor", [0, 0, 0]))

    _assign_property(new_mat, "_MainTex_ST", texture_repeat)

    var outline_width_idx: float = 0
    var outline_width: float = vrm_mat_props.get("outlineWidthFactor", 0.0)
    if outline_width_mode == "worldCoordinates":
        outline_width_idx = 1
        outline_width = _m_to_cm(outline_width)
    elif outline_width_mode == "screenCoordinates":
        outline_width_idx = 2

    _assign_property(new_mat, "_OutlineWidthMode", outline_width_idx)
    _assign_property(new_mat, "_OutlineWidth", outline_width)
    _assign_property(new_mat, "_AlphaCutoutEnable", 1.0 if alpha_mode == "MASK" else 0.0)
    _assign_property(new_mat, "_BumpScale", mat_props.get("normalTexture", {}).get("scale", 1.0))
    _assign_property(new_mat, "_Cutoff", mat_props.get("alphaCutoff", 0.5))
    _assign_property(new_mat, "_ShadeToony", vrm_mat_props.get("shadingToonyFactor", 0.9))
    _assign_property(new_mat, "_ShadeShift", vrm_mat_props.get("shadingShiftFactor", 0.0))
    _assign_property(
        new_mat, "_ShadingGradeRate", vrm_mat_props.get("shadingShiftTexture", {}).get("scale", 1.0)
    )
    _assign_property(new_mat, "_ReceiveShadowRate", 1.0)
    _assign_property(new_mat, "_LightColorAttenuation", 0.0)
    _assign_property(
        new_mat, "_IndirectLightIntensity", 1.0 - vrm_mat_props.get("giEqualizationFactor", 0.9)
    )
    _assign_property(new_mat, "_OutlineScaledMaxDistance", 99.0)
    _assign_property(new_mat, "_RimLightingMix", vrm_mat_props.get("rimLightingMixFactor", 0.0))
    _assign_property(
        new_mat, "_RimFresnelPower", vrm_mat_props.get("parametricRimFresnelPowerFactor", 1.0)
    )
    _assign_property(new_mat, "_RimLift", vrm_mat_props.get("parametricRimLiftFactor", 0.0))
    _assign_property(new_mat, "_OutlineColorMode", 1.0)
    _assign_property(
        new_mat, "_OutlineLightingMix", vrm_mat_props.get("outlineLightingMixFactor", 1.0)
    )
    _assign_property(
        new_mat, "_UvAnimScrollX", vrm_mat_props.get("uvAnimationScrollXSpeedFactor", 0.0)
    )
    _assign_property(
        new_mat, "_UvAnimScrollY", vrm_mat_props.get("uvAnimationScrollYSpeedFactor", 0.0)
    )
    _assign_property(
        new_mat, "_UvAnimRotation", vrm_mat_props.get("uvAnimationRotationSpeedFactor", 0.0)
    )

    if alpha_mode == "BLEND":
        var delta_render_queue = vrm_mat_props.get("renderQueueOffsetNumber", 0)
        if vrm_mat_props.get("transparentWithZWrite", false) == true:
            delta_render_queue -= 19
        new_mat.render_priority = delta_render_queue
        if outline_mat != null:
            outline_mat.render_priority = delta_render_queue
    else:
        new_mat.render_priority = 0
        if outline_mat != null:
            outline_mat.render_priority = 0

    return new_mat


static func get_texture_info_v0(
    gstate: GLTFState, vrm_mat_props: Dictionary, unity_tex_name: String
) -> Dictionary:
    var gltf_images: Array = gstate.get_images()
    var gltf_textures: Array = gstate.get_textures()
    var texture_info: Dictionary = {}
    texture_info["tex"] = null
    texture_info["offset"] = Vector3(0.0, 0.0, 0.0)
    texture_info["scale"] = Vector3(1.0, 1.0, 1.0)
    if vrm_mat_props["textureProperties"].has(unity_tex_name):
        var mainTexId: int = vrm_mat_props["textureProperties"][unity_tex_name]
        var mainTexImageId = gltf_textures[mainTexId].src_image
        var mainTexImage: Texture2D = gltf_images[mainTexImageId]
        texture_info["tex"] = mainTexImage
    if vrm_mat_props["vectorProperties"].has(unity_tex_name):
        var offsetScale: Array = vrm_mat_props["vectorProperties"][unity_tex_name]
        texture_info["offset"] = Vector3(offsetScale[0], offsetScale[1], 0.0)
        texture_info["scale"] = Vector3(offsetScale[2], offsetScale[3], 1.0)
    return texture_info


static func process_vrm_material_v0(
    orig_mat: Material, gstate: GLTFState, vrm_mat_props: Dictionary
) -> Material:
    var vrm_shader_name: String = vrm_mat_props["shader"]
    if vrm_shader_name == "VRM_USE_GLTFSHADER":
        return orig_mat

    if vrm_shader_name == "Standard" or vrm_shader_name == "UniGLTF/UniUnlit":
        # Not strictly supported but we don't want to crash.
        return orig_mat

    var maintex_info: Dictionary = get_texture_info_v0(gstate, vrm_mat_props, "_MainTex")

    if (
        vrm_shader_name == "VRM/UnlitTransparentZWrite"
        or vrm_shader_name == "VRM/UnlitTransparent"
        or vrm_shader_name == "VRM/UnlitTexture"
        or vrm_shader_name == "VRM/UnlitCutout"
    ):
        if maintex_info["tex"] != null:
            orig_mat.albedo_texture = maintex_info["tex"]
            orig_mat.uv1_offset = maintex_info["offset"]
            orig_mat.uv1_scale = maintex_info["scale"]
        orig_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        if vrm_shader_name == "VRM/UnlitTransparentZWrite":
            orig_mat.depth_draw_mode = StandardMaterial3D.DEPTH_DRAW_ALWAYS
        orig_mat.no_depth_test = false
        if (
            vrm_shader_name == "VRM/UnlitTransparent"
            or vrm_shader_name == "VRM/UnlitTransparentZWrite"
        ):
            orig_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
            orig_mat.blend_mode = StandardMaterial3D.BLEND_MODE_MIX
        if vrm_shader_name == "VRM/UnlitCutout":
            orig_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
            orig_mat.alpha_scissor_threshold = vrm_mat_props["floatProperties"].get("_Cutoff", 0.5)
        return orig_mat

    if vrm_shader_name != "VRM/MToon":
        VRMLogger.error(
            "vrm_material_processor.gd",
            "Unknown VRM shader " + vrm_shader_name + " on material " + str(orig_mat.resource_name)
        )
        return orig_mat

    var outline_width_mode = int(vrm_mat_props["floatProperties"].get("_OutlineWidthMode", 0))
    var blend_mode = int(vrm_mat_props["floatProperties"].get("_BlendMode", 0))
    var cull_mode = int(vrm_mat_props["floatProperties"].get("_CullMode", 2))

    var godot_shader_name = mtoon_shader_base_path
    var godot_outline_shader_name = null

    if blend_mode == 0:  # Opaque
        if cull_mode == 0:
            godot_shader_name += "_cull_off"
    elif blend_mode == 1:  # Cutout
        godot_shader_name += "_cutout"
        if cull_mode == 0:
            godot_shader_name += "_cull_off"
    elif blend_mode == 2:  # Transparent
        godot_shader_name += "_trans"
        if cull_mode == 0:
            godot_shader_name += "_cull_off"
    elif blend_mode == 3:  # TransparentWithZWrite
        godot_shader_name += "_trans_zwrite"
        if cull_mode == 0:
            godot_shader_name += "_cull_off"

    if outline_width_mode != 0:
        godot_outline_shader_name = mtoon_shader_base_path + "_outline"
        if blend_mode == 1:
            godot_outline_shader_name += "_cutout"
        elif blend_mode == 2:
            godot_outline_shader_name += "_trans"
        elif blend_mode == 3:
            godot_outline_shader_name += "_trans_zwrite"

    var godot_shader: Shader = ResourceLoader.load(godot_shader_name + ".gdshader")
    var new_mat: ShaderMaterial = ShaderMaterial.new()
    new_mat.resource_name = orig_mat.resource_name
    new_mat.shader = godot_shader

    var outline_mat: ShaderMaterial = null
    if godot_outline_shader_name != null:
        var godot_shader_outline: Shader = ResourceLoader.load(
            godot_outline_shader_name + ".gdshader"
        )
        if godot_shader_outline != null:
            outline_mat = ShaderMaterial.new()
            outline_mat.resource_name = orig_mat.resource_name + "_Outline"
            outline_mat.shader = godot_shader_outline
            new_mat.next_pass = outline_mat

    var texture_repeat = Vector4(
        maintex_info["scale"].x,
        maintex_info["scale"].y,
        maintex_info["offset"].x,
        maintex_info["offset"].y
    )
    new_mat.set_shader_parameter("_MainTex_ST", texture_repeat)
    if outline_mat != null:
        outline_mat.set_shader_parameter("_MainTex_ST", texture_repeat)

    for param_name in [
        "_MainTex",
        "_ShadeTexture",
        "_BumpMap",
        "_RimTexture",
        "_SphereAdd",
        "_EmissionMap",
        "_OutlineWidthTexture",
        "_UvAnimMaskTexture"
    ]:
        var tex_info = get_texture_info_v0(gstate, vrm_mat_props, param_name)
        if tex_info.get("tex") != null:
            _assign_property(new_mat, param_name, tex_info["tex"])
            if param_name == "_SphereAdd":
                _assign_property(new_mat, "_MatcapColor", Color(1, 1, 1, 1))

    for param_name in vrm_mat_props["floatProperties"]:
        _assign_property(new_mat, param_name, vrm_mat_props["floatProperties"][param_name])

    for param_name in ["_Color", "_ShadeColor", "_RimColor", "_EmissionColor", "_OutlineColor"]:
        if param_name in vrm_mat_props["vectorProperties"]:
            var val = vrm_mat_props["vectorProperties"][param_name]
            var col: Color = Color(val[0], val[1], val[2], val[3])
            if param_name == "_RimColor":
                col = col.linear_to_srgb()
            if param_name == "_EmissionColor":
                var mult = maxf(col.r, maxf(col.g, col.b))
                var emission_mult = 1.0
                if mult > 1.0:
                    emission_mult = mult
                    col = col / mult
                col = col.linear_to_srgb()
                new_mat.set_shader_parameter("_EmissionMultiplier", emission_mult)
                if outline_mat != null:
                    outline_mat.set_shader_parameter("_EmissionMultiplier", emission_mult)
            _assign_property(new_mat, param_name, col)

    if blend_mode == 1:
        _assign_property(new_mat, "_AlphaCutoutEnable", 1.0)

    return new_mat
