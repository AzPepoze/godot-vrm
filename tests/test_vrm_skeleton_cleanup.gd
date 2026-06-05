extends "res://tests/test_base.gd"

var allow_errors = true
const Cleanup = preload("res://addons/vrm/importer/common/vrm_skeleton_cleanup.gd")

# ── remove_end_bone_nodes: edge cases ────────────────────────────────────────


func test_cleanup_null_skeleton():
    assert_eq(Cleanup.remove_end_bone_nodes(null, null), 0, "null skeleton → 0")
    test_completed = true


func test_cleanup_empty_skeleton():
    var skel := Skeleton3D.new()
    runner.root.add_child(skel)
    await runner.process_frame
    assert_eq(Cleanup.remove_end_bone_nodes(null, skel), 0, "empty skeleton → 0")
    skel.queue_free()
    await runner.process_frame
    test_completed = true

# ── remove_end_bone_nodes: basic removal ─────────────────────────────────────
    test_completed = true


func test_cleanup_removes_bare_node3d_matching_bone():
    var skel := Skeleton3D.new()
    skel.add_bone("J_Sec_L_Skirt_End")
    skel.add_bone("J_Sec_R_Skirt_End")
    var child := Node3D.new()
    child.name = "J_Sec_L_Skirt_End"
    skel.add_child(child)
    var child2 := Node3D.new()
    child2.name = "J_Sec_R_Skirt_End"
    skel.add_child(child2)
    runner.root.add_child(skel)
    await runner.process_frame

    var removed := Cleanup.remove_end_bone_nodes(null, skel)
    assert_eq(removed, 2, "Should remove 2 end-bone Node3D children")
    assert_eq(skel.get_child_count(), 0, "Skeleton should have 0 children after cleanup")
    skel.queue_free()
    await runner.process_frame
    test_completed = true

# ── remove_end_bone_nodes: keeps non-bone-named Node3D ───────────────────────
    test_completed = true


func test_cleanup_keeps_non_bone_node3d():
    var skel := Skeleton3D.new()
    skel.add_bone("Hips")
    var non_bone := Node3D.new()
    non_bone.name = "NotABone"
    skel.add_child(non_bone)
    runner.root.add_child(skel)
    await runner.process_frame

    var removed := Cleanup.remove_end_bone_nodes(null, skel)
    assert_eq(removed, 0, "Should not remove nodes not matching bone names")
    assert_eq(skel.get_child_count(), 1, "Skeleton should keep 1 child")
    skel.queue_free()
    await runner.process_frame
    test_completed = true

# ── remove_end_bone_nodes: keeps MeshInstance3D children ─────────────────────
    test_completed = true


func test_cleanup_keeps_mesh_instance():
    var skel := Skeleton3D.new()
    skel.add_bone("Body")
    var mesh := MeshInstance3D.new()
    mesh.name = "Body"
    skel.add_child(mesh)
    runner.root.add_child(skel)
    await runner.process_frame

    var removed := Cleanup.remove_end_bone_nodes(null, skel)
    assert_eq(removed, 0, "Should not remove MeshInstance3D")
    skel.queue_free()
    await runner.process_frame
    test_completed = true

# ── remove_end_bone_nodes: keeps nodes with meaningful descendants ───────────
    test_completed = true


func test_cleanup_keeps_node_with_mesh_descendant():
    var skel := Skeleton3D.new()
    skel.add_bone("Arm")
    var parent := Node3D.new()
    parent.name = "Arm"
    var mesh := MeshInstance3D.new()
    mesh.name = "HandMesh"
    parent.add_child(mesh)
    skel.add_child(parent)
    runner.root.add_child(skel)
    await runner.process_frame

    var removed := Cleanup.remove_end_bone_nodes(null, skel)
    assert_eq(removed, 0, "Should keep bone-matching node that has MeshInstance3D descendant")
    skel.queue_free()
    await runner.process_frame
    test_completed = true


func test_cleanup_keeps_node_with_unique_name_descendant():
    var skel := Skeleton3D.new()
    skel.add_bone("Head")
    var head := Node3D.new()
    head.name = "Head"
    var look_offset := Node3D.new()
    look_offset.name = "LookOffset"
    look_offset.set_unique_name_in_owner(true)
    head.add_child(look_offset)
    skel.add_child(head)
    runner.root.add_child(skel)
    await runner.process_frame

    var removed := Cleanup.remove_end_bone_nodes(null, skel)
    assert_eq(removed, 0, "Should keep node with unique_name_in_owner descendant (e.g. LookOffset)")
    skel.queue_free()
    await runner.process_frame
    test_completed = true


func test_cleanup_keeps_node_with_scripted_descendant():
    var skel := Skeleton3D.new()
    skel.add_bone("Custom")
    var parent := Node3D.new()
    parent.name = "Custom"
    var scripted := Node3D.new()
    scripted.name = "ScriptedChild"
    scripted.set_script(load("res://addons/vrm/runtime/vrm_spring_bone_controller.gd"))
    parent.add_child(scripted)
    skel.add_child(parent)
    runner.root.add_child(skel)
    await runner.process_frame

    var removed := Cleanup.remove_end_bone_nodes(null, skel)
    assert_eq(removed, 0, "Should keep node with scripted descendant")
    skel.queue_free()
    await runner.process_frame
    test_completed = true


func test_cleanup_keeps_nested_meaningful_descendant():
    var skel := Skeleton3D.new()
    skel.add_bone("Deep")
    var l1 := Node3D.new()
    l1.name = "Deep"
    var l2 := Node3D.new()
    l2.name = "Level2"
    var l3 := Node3D.new()
    l3.name = "Level3"
    var mesh := MeshInstance3D.new()
    mesh.name = "Mesh"
    l3.add_child(mesh)
    l2.add_child(l3)
    l1.add_child(l2)
    skel.add_child(l1)
    runner.root.add_child(skel)
    await runner.process_frame

    var removed := Cleanup.remove_end_bone_nodes(null, skel)
    assert_eq(removed, 0, "Should keep node with deeply nested meaningful descendant")
    skel.queue_free()
    await runner.process_frame
    test_completed = true

# ── remove_end_bone_nodes: BoneAttachment3D handling ─────────────────────────
    test_completed = true


func test_cleanup_removes_bare_bone_attachment():
    var skel := Skeleton3D.new()
    skel.add_bone("J_Sec_End")
    var attach := BoneAttachment3D.new()
    attach.name = "J_Sec_End"
    skel.add_child(attach)
    runner.root.add_child(skel)
    await runner.process_frame

    var removed := Cleanup.remove_end_bone_nodes(null, skel)
    assert_eq(removed, 1, "Should remove bare BoneAttachment3D matching bone name")
    skel.queue_free()
    await runner.process_frame
    test_completed = true

# ── remove_end_bone_nodes: scripted nodes are kept ───────────────────────────
    test_completed = true


func test_cleanup_keeps_scripted_node():
    var skel := Skeleton3D.new()
    skel.add_bone("ScriptedBone")
    var scripted := Node3D.new()
    scripted.name = "ScriptedBone"
    scripted.set_script(load("res://addons/vrm/runtime/vrm_spring_bone_controller.gd"))
    skel.add_child(scripted)
    runner.root.add_child(skel)
    await runner.process_frame

    var removed := Cleanup.remove_end_bone_nodes(null, skel)
    assert_eq(removed, 0, "Should not remove scripted nodes")
    skel.queue_free()
    await runner.process_frame
    test_completed = true

# ── remove_end_bone_nodes: mixed cleanup ─────────────────────────────────────
    test_completed = true


func test_cleanup_mixed_scenario():
    var skel := Skeleton3D.new()
    skel.add_bone("Bone_End")
    skel.add_bone("Bone_Mesh")
    skel.add_bone("Bone_Look")
    skel.add_bone("Bone_Scripted")
    skel.add_bone("Bone_NonBoneName")

    # Should be removed: bare Node3D matching bone name
    var end_node := Node3D.new()
    end_node.name = "Bone_End"
    skel.add_child(end_node)

    # Should be kept: Node3D matching bone but has mesh descendant
    var mesh_parent := Node3D.new()
    mesh_parent.name = "Bone_Mesh"
    var mesh := MeshInstance3D.new()
    mesh.name = "SubMesh"
    mesh_parent.add_child(mesh)
    skel.add_child(mesh_parent)

    # Should be kept: Node3D matching bone but has unique_name_in_owner descendant
    var look_parent := Node3D.new()
    look_parent.name = "Bone_Look"
    var look := Node3D.new()
    look.name = "LookTarget"
    look.set_unique_name_in_owner(true)
    look_parent.add_child(look)
    skel.add_child(look_parent)

    # Should be kept: Node3D matching bone but has script
    var scripted_parent := Node3D.new()
    scripted_parent.name = "Bone_Scripted"
    scripted_parent.set_script(load("res://addons/vrm/runtime/vrm_spring_bone_controller.gd"))
    skel.add_child(scripted_parent)

    # Should be kept: Node3D not matching any bone name
    var non_bone := Node3D.new()
    non_bone.name = "ExtraNode"
    skel.add_child(non_bone)

    runner.root.add_child(skel)
    await runner.process_frame

    var removed := Cleanup.remove_end_bone_nodes(null, skel)
    assert_eq(removed, 1, "Only 1 node should be removed (Bone_End), got %d" % removed)
    var remaining_children = skel.get_children()
    var count = 0
    for c in remaining_children:
        if not (c.name == "VRMSpringBoneSimulation" or c.is_class("VRMSpringBoneSimulation")):
            count += 1
    assert_eq(count, 4, "4 children should remain (mesh, look, scripted, non-bone)")

    # Verify which ones remain
    var remaining_names := []
    for c in skel.get_children():
        remaining_names.append(c.name)
    assert_true(remaining_names.has("Bone_Mesh"), "Bone_Mesh must remain")
    assert_true(remaining_names.has("Bone_Look"), "Bone_Look must remain")
    assert_true(remaining_names.has("Bone_Scripted"), "Bone_Scripted must remain")
    assert_true(remaining_names.has("ExtraNode"), "ExtraNode must remain")
    assert_false(remaining_names.has("Bone_End"), "Bone_End must have been removed")

    skel.queue_free()
    await runner.process_frame
    test_completed = true

# ── _has_meaningful_descendant: direct tests ─────────────────────────────────
    test_completed = true


func test_has_meaningful_descendant_empty():
    var node := Node3D.new()
    assert_false(Cleanup._has_meaningful_descendant(node), "Empty node → false")
    node.queue_free()
    test_completed = true


func test_has_meaningful_descendant_mesh_instance():
    var parent := Node3D.new()
    var mesh := MeshInstance3D.new()
    mesh.name = "Mesh"
    parent.add_child(mesh)
    assert_true(Cleanup._has_meaningful_descendant(parent), "MeshInstance3D child → true")
    parent.queue_free()
    test_completed = true


func test_has_meaningful_descendant_importer_mesh():
    var parent := Node3D.new()
    var mesh := ImporterMeshInstance3D.new()
    mesh.name = "ImpMesh"
    parent.add_child(mesh)
    assert_true(Cleanup._has_meaningful_descendant(parent), "ImporterMeshInstance3D child → true")
    parent.queue_free()
    test_completed = true


func test_has_meaningful_descendant_unique_name():
    var parent := Node3D.new()
    var child := Node3D.new()
    child.name = "LookOffset"
    child.set_unique_name_in_owner(true)
    parent.add_child(child)
    assert_true(Cleanup._has_meaningful_descendant(parent), "unique_name_in_owner child → true")
    parent.queue_free()
    test_completed = true


func test_has_meaningful_descendant_scripted():
    var parent := Node3D.new()
    var child := Node3D.new()
    child.name = "Scripted"
    child.set_script(load("res://addons/vrm/runtime/vrm_spring_bone_controller.gd"))
    parent.add_child(child)
    assert_true(Cleanup._has_meaningful_descendant(parent), "Scripted child → true")
    parent.queue_free()
    test_completed = true


func test_has_meaningful_descendant_nested_empty():
    var l1 := Node3D.new()
    var l2 := Node3D.new()
    var l3 := Node3D.new()
    l2.add_child(l3)
    l1.add_child(l2)
    assert_false(Cleanup._has_meaningful_descendant(l1), "Nested empty nodes → false")
    l1.queue_free()
    test_completed = true


func test_has_meaningful_descendant_deeply_nested_mesh():
    var l1 := Node3D.new()
    var l2 := Node3D.new()
    var l3 := Node3D.new()
    var mesh := MeshInstance3D.new()
    l3.add_child(mesh)
    l2.add_child(l3)
    l1.add_child(l2)
    assert_true(Cleanup._has_meaningful_descendant(l1), "Deeply nested MeshInstance3D → true")
    l1.queue_free()
    test_completed = true


func test_clear_all_bone_attachments():
    var skel := Skeleton3D.new()
    skel.add_bone("Head")
    var attach := BoneAttachment3D.new()
    attach.name = "HeadAttach"
    attach.bone_name = "Head"
    skel.add_child(attach)

    var child := Node3D.new()
    child.name = "LookOffset"
    attach.add_child(child)

    runner.root.add_child(skel)
    await runner.process_frame

    Cleanup.clear_all_bone_attachments(skel)
    assert_eq(skel.get_child_count(), 0, "BoneAttachment3D and its descendants should be cleared")
    skel.queue_free()
    await runner.process_frame
    test_completed = true
