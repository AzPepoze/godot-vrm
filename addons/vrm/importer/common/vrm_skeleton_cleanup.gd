@tool
extends RefCounted


## Remove redundant scene-node representations of skeleton end-bones.
##
## Removes Node3D AND BoneAttachment3D children of `skeleton` when they are
## pure empty markers — no mesh, no script, no uniquely-named descendants.
static func remove_end_bone_nodes(root_node: Node, skeleton: Skeleton3D) -> int:
    if skeleton == null:
        return 0
    var to_remove: Array[Node] = []
    for child in skeleton.get_children():
        if _is_removable_end_node(child, skeleton):
            to_remove.append(child)
    for node in to_remove:
        node.get_parent().remove_child(node)
        node.queue_free()
    return to_remove.size()


static func _is_removable_end_node(node: Node, skeleton: Skeleton3D) -> bool:
    # Allow Node3D and BoneAttachment3D — both can be empty end-bone markers.
    # Exclude anything else (MeshInstance3D, scripted nodes, etc.).
    var cls := node.get_class()
    if cls != "Node3D" and cls != "BoneAttachment3D":
        return false
    # Must not have a custom script.
    if node.get_script() != null:
        return false
    # Must correspond to a bone in the skeleton.
    if skeleton.find_bone(node.name) == -1:
        return false
    # Must have no meaningful descendants.
    return not _has_meaningful_descendant(node)


static func _has_meaningful_descendant(node: Node) -> bool:
    for child in node.get_children():
        # Any visual geometry is meaningful.
        if child is MeshInstance3D or child is ImporterMeshInstance3D:
            return true
        # Nodes with unique_name_in_owner are explicitly %referenced (e.g. LookOffset).
        if child.is_unique_name_in_owner():
            return true
        # Scripted nodes carry custom behaviour.
        if child.get_script() != null:
            return true
        # Recurse.
        if _has_meaningful_descendant(child):
            return true
    return false


static func clear_all_bone_attachments(skeleton: Skeleton3D) -> void:
    if skeleton == null:
        return
    var to_remove: Array[Node] = []
    for child in skeleton.find_children("*", "BoneAttachment3D", true, false):
        to_remove.append(child)
    for node in to_remove:
        if is_instance_valid(node) and node.get_parent() != null:
            node.get_parent().remove_child(node)
            node.queue_free()
