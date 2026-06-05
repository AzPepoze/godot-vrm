extends GLTFDocumentExtension

const vrm_spring_bone_controller = preload("../../../runtime/vrm_spring_bone_controller.gd")
const vrm_spring_bone_parser = preload("../../common/vrm_spring_bone_parser.gd")
const vrm_collider_group = preload("../../../runtime/vrm_collider_group.gd")
const vrm_spring_bone_group_setting = preload("../../../core/vrm_spring_bone_group_setting.gd")
const VRMLogger = preload("../../../core/logger.gd")


func _import_preflight(
    _state: GLTFState, extensions: PackedStringArray = PackedStringArray()
) -> Error:
    if extensions.has("VRMC_springBone"):
        return OK
    return ERR_SKIP


func _import_post(gstate: GLTFState, node: Node) -> Error:
    var vrm_extension: Dictionary = gstate.json["extensions"]["VRMC_springBone"]
    var spring_bone_controller: Node = node.get_node_or_null("VRMSpringBoneController")
    if spring_bone_controller == null:
        spring_bone_controller = Node3D.new()
        spring_bone_controller.name = "VRMSpringBoneController"
        node.add_child(spring_bone_controller, true)
        spring_bone_controller.owner = node

    # Parse Colliders (v1 flat list)
    var colliders = vrm_spring_bone_parser.parse_colliders_v1(
        vrm_extension.get("colliders", []), gstate, spring_bone_controller
    )

    # Parse Collider Groups referencing colliders by index
    var collider_groups: Array[VRMColliderGroup] = []
    for cgroup_json in vrm_extension.get("colliderGroups", []):
        var collider_group: vrm_collider_group = vrm_collider_group.new()
        for collider_idx in cgroup_json.get("colliders", []):
            collider_group.colliders.append(colliders[int(collider_idx)])
        collider_groups.append(collider_group)

    # Parse Spring Bones
    var spring_bones = vrm_spring_bone_parser.parse_springs_v1(
        vrm_extension.get("springs", []), gstate, collider_groups, spring_bone_controller
    )

    # Determine skeleton path from first spring bone
    var skeleton_path: NodePath = NodePath()
    if not spring_bones.is_empty():
        var first_bone_name = spring_bones[0].joint_nodes[0]
        var skeleton: Skeleton3D = null
        for child in node.find_children("*", "Skeleton3D", true, false):
            if child.find_bone(first_bone_name) != -1:
                skeleton = child
                break
        if skeleton:
            skeleton_path = spring_bone_controller.get_path_to(skeleton)

    spring_bone_controller.set_script(vrm_spring_bone_controller)
    spring_bone_controller.set("skeleton", skeleton_path)
    spring_bone_controller.set("spring_bones", Array(spring_bones))
    spring_bone_controller.set("collider_groups", Array(collider_groups))
    spring_bone_controller.set("collider_library", Array(colliders))

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
        node.set("springbone_group_multipliers", group_settings)

    return OK
