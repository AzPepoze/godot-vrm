@tool
extends RefCounted

const VRMLogger = preload("../../core/logger.gd")
const vrm_spring_bone_controller = preload("../../runtime/vrm_spring_bone_controller.gd")
const vrm_spring_bone_parser = preload("../common/vrm_spring_bone_parser.gd")
const vrm_spring_bone_group_setting = preload("../../core/vrm_spring_bone_group_setting.gd")


static func parse_spring_bone_controller(
    spring_bone_controller: Node,
    vrm_extension: Dictionary,
    gstate: GLTFState,
    skeleton: Skeleton3D,
    pose_diffs: Array[Basis],
    _is_vrm_0: bool
) -> void:
    VRMLogger.debug(
        "vrm_spring_bone_controller_setup.gd",
        "parse_spring_bone_controller: parsing spring_bone_controller animation"
    )

    var skeleton_path: NodePath = spring_bone_controller.get_path_to(skeleton)

    # Parse Colliders (v0 style)
    var collider_groups = vrm_spring_bone_parser.parse_colliders_v0(
        vrm_extension["secondaryAnimation"]["colliderGroups"],
        gstate,
        pose_diffs,
        spring_bone_controller
    )

    # Parse Spring Bones (v0 style)
    var spring_bones = vrm_spring_bone_parser.parse_springs_v0(
        vrm_extension["secondaryAnimation"]["boneGroups"],
        gstate,
        collider_groups,
        spring_bone_controller
    )

    # Collect all colliders into a flat library
    var collider_library: Array[VRMCollider] = []
    for cg in collider_groups:
        collider_library.append_array(cg.colliders)

    spring_bone_controller.set_script(vrm_spring_bone_controller)
    spring_bone_controller.set("skeleton", skeleton_path)
    spring_bone_controller.set("spring_bones", Array(spring_bones))
    spring_bone_controller.set("collider_groups", Array(collider_groups))
    spring_bone_controller.set("collider_library", Array(collider_library))

    var unique_groups := {}
    for sb in spring_bones:
        if not sb.group.is_empty() and sb.group != "Other":
            unique_groups[sb.group] = true

    if not unique_groups.is_empty():
        var group_settings: Array[VRMSpringBoneGroupSetting] = []
        var sorted_groups = unique_groups.keys()
        sorted_groups.sort()
        for group_name in sorted_groups:
            var gs = vrm_spring_bone_group_setting.new()
            gs.resource_name = group_name
            gs.group_name = group_name
            group_settings.append(gs)
        spring_bone_controller.get_parent().set("springbone_group_multipliers", group_settings)
