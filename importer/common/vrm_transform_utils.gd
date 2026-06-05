@tool
extends RefCounted


static func apply_node_transforms(p_node: Node, p_skeleton: Skeleton3D) -> Vector3:
    var global_transform_scale_local: Vector3 = Vector3.ONE
    var root_node: Node3D = p_node
    if root_node.transform != Transform3D.IDENTITY:
        global_transform_scale_local = root_node.scale
        root_node.transform = Transform3D.IDENTITY

    for bone_idx in range(p_skeleton.get_bone_count()):
        var bone_rest: Transform3D = p_skeleton.get_bone_rest(bone_idx)
        var new_rest: Transform3D = Transform3D(
            bone_rest.basis, bone_rest.origin * global_transform_scale_local
        )
        p_skeleton.set_bone_rest(bone_idx, new_rest)

    var q: PackedInt32Array = p_skeleton.get_parentless_bones()
    var q_off: int = 0
    while q_off < len(q):
        var src_idx: int = q[q_off]
        q_off += 1
        var src_children: PackedInt32Array = p_skeleton.get_bone_children(src_idx)
        q.append_array(src_children)
        var bone_rest: Transform3D = p_skeleton.get_bone_rest(src_idx)
        p_skeleton.set_bone_rest(
            src_idx, Transform3D(bone_rest.basis, bone_rest.origin * global_transform_scale_local)
        )
        p_skeleton.set_bone_pose_position(src_idx, bone_rest.origin * global_transform_scale_local)
        p_skeleton.set_bone_pose_rotation(src_idx, bone_rest.basis.get_rotation_quaternion())
        p_skeleton.set_bone_pose_scale(src_idx, bone_rest.basis.get_scale())

    return global_transform_scale_local
