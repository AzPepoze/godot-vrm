@tool
extends RefCounted

enum BoneRenameMode {
    NONE = 0,
    HUMANBONES = 1,
    SYMMETRIZE_VROID = 2,
}

const humanoid_strategy = preload("./vrm_bone_renamer_humanoid.gd")
const symmetrize_strategy = preload("./vrm_bone_renamer_symmetrize.gd")


static func rename_skeleton_bones(
    gstate: GLTFState,
    p_base_scene: Node,
    p_skeleton: Skeleton3D,
    p_bone_map: BoneMap,
    mode: int,
    skeleton_name: String = "Skeleton3D"
) -> void:
    var rename_map: Dictionary = {}
    if mode == BoneRenameMode.HUMANBONES:
        rename_map = humanoid_strategy.rename_bones(gstate, p_base_scene, p_skeleton, p_bone_map)
    elif mode == BoneRenameMode.SYMMETRIZE_VROID:
        rename_map = symmetrize_strategy.rename_bones(gstate, p_base_scene, p_skeleton, p_bone_map)

    if not rename_map.is_empty():
        p_skeleton.set_meta("vrm_rename_map", rename_map)
        _update_scene_bone_references(p_base_scene, rename_map)

    # Ensure a single Root bone exists at the top level of the skeleton
    var root_bone_name = "Root"
    if p_skeleton.find_bone(root_bone_name) == -1:
        p_skeleton.add_bone(root_bone_name)
        var new_root_bone_id = p_skeleton.find_bone(root_bone_name)
        for root_bone_id in p_skeleton.get_parentless_bones():
            if root_bone_id != new_root_bone_id:
                p_skeleton.set_bone_parent(root_bone_id, new_root_bone_id)

    p_skeleton.name = skeleton_name

    p_skeleton.set_unique_name_in_owner(true)

    # Notify descendant nodes about bone name changes (e.g. springbone, secondary, etc.)
    var nodes = p_base_scene.find_children("*")
    while not nodes.is_empty():
        var nd = nodes.pop_back()
        if nd.has_method(&"_notify_skeleton_bones_renamed"):
            nd.call(&"_notify_skeleton_bones_renamed", p_base_scene, p_skeleton, p_bone_map)


static func _update_scene_bone_references(p_base_scene: Node, rename_map: Dictionary) -> void:
    # Find all VRMSpringBoneController nodes
    var controllers = p_base_scene.find_children("*", "VRMSpringBoneController", true, false)
    for controller in controllers:
        # Update spring_bones
        var spring_bones: Array = controller.get("spring_bones")
        for spring_bone in spring_bones:
            if spring_bone == null:
                continue

            # 1. Update joint_nodes
            var joints: PackedStringArray = spring_bone.joint_nodes
            var updated_joints := PackedStringArray()
            for joint in joints:
                var sn := StringName(joint)
                if rename_map.has(sn):
                    updated_joints.append(String(rename_map[sn]))
                else:
                    updated_joints.append(joint)
            spring_bone.joint_nodes = updated_joints

            # 2. Update center_bone
            var cb: String = spring_bone.center_bone
            var cb_sn := StringName(cb)
            if cb != "" and rename_map.has(cb_sn):
                spring_bone.center_bone = String(rename_map[cb_sn])

        # Update collider_groups
        var collider_groups: Array = controller.get("collider_groups")
        for group in collider_groups:
            if group == null:
                continue
            for collider in group.colliders:
                if collider == null:
                    continue
                var b: String = collider.bone
                var b_sn := StringName(b)
                if b != "" and rename_map.has(b_sn):
                    collider.bone = String(rename_map[b_sn])

        # Update collider_library
        var collider_library: Array = controller.get("collider_library")
        for collider in collider_library:
            if collider == null:
                continue
            var b: String = collider.bone
            var b_sn := StringName(b)
            if b != "" and rename_map.has(b_sn):
                collider.bone = String(rename_map[b_sn])

    # Find all VRMConstraintApplier nodes
    var appliers = p_base_scene.find_children("*", "VRMConstraintApplier", true, false)
    for applier in appliers:
        var constraints = applier.get("constraints")
        if constraints:
            for constraint in constraints:
                if constraint == null:
                    continue
                var s_bn: StringName = constraint.source_bone_name
                if s_bn != &"" and rename_map.has(s_bn):
                    constraint.source_bone_name = rename_map[s_bn]
                var t_bn: StringName = constraint.target_bone_name
                if t_bn != &"" and rename_map.has(t_bn):
                    constraint.target_bone_name = rename_map[t_bn]
