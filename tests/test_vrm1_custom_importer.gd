extends "res://tests/test_base.gd"

const VRM_IMPORTER = preload("res://addons/vrm/import_vrm.gd")
const VRM0_FILE := "res://assets/vrm/AliciaSolid_vrm-0.51.vrm"
const VRM_FILE := "res://assets/vrm/AvatarSample_M.vrm"


func _skip_without_editor() -> bool:
    if not Engine.is_editor_hint():
        print("[SKIP] EditorSceneFormatImporter requires editor mode")
        test_completed = true
        return true
    return false


func _import_scene(path: String) -> Node:
    var importer: EditorSceneFormatImporter = VRM_IMPORTER.new()
    return importer._import_scene(path, 0, {})


func test_local_document_runs_vrm0_lifecycle_callbacks():
    if _skip_without_editor():
        return

    var scene := _import_scene(VRM0_FILE)
    assert_not_null(scene, "The custom VRM importer should generate a VRM 0 scene")
    if scene == null:
        test_completed = true
        return

    assert_not_null(scene.get_script(), "VRM 0 post-import should attach VRMInstance")
    assert_not_null(scene.get("vrm_meta"), "VRM 0 post-import should set vrm_meta")

    var spring_controller := scene.get_node_or_null("VRMSpringBoneController")
    assert_not_null(
        spring_controller, "VRM 0 post-import should add its spring-bone controller"
    )

    scene.free()
    test_completed = true


func test_local_document_runs_vrm1_lifecycle_callbacks():
    if _skip_without_editor():
        return

    var scene := _import_scene(VRM_FILE)

    assert_not_null(scene, "The custom VRM importer should generate a scene")
    if scene == null:
        test_completed = true
        return

    assert_not_null(scene.get_script(), "VRM 1.0 post-import should attach VRMInstance")
    assert_not_null(scene.get("vrm_meta"), "VRM 1.0 post-import should set vrm_meta")

    var spring_controller := scene.get_node_or_null("VRMSpringBoneController")
    assert_not_null(
        spring_controller, "VRM 1.0 spring-bone post-import should add its controller"
    )
    if spring_controller:
        var spring_bones: Array = spring_controller.get("spring_bones")
        assert_gt(spring_bones.size(), 0, "Spring-bone controller should contain imported springs")

    scene.free()
    test_completed = true
