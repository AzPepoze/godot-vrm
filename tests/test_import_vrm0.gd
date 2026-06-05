@tool
extends SceneTree


func _init():
    print("Loading VRM...")
    var packed_scene = ResourceLoader.load(
        "res://assets/vrm/AliciaSolid_vrm-0.51.vrm",
        "PackedScene",
        ResourceLoader.CACHE_MODE_REPLACE
    )
    if not packed_scene:
        print("Failed to load PackedScene")
        quit()
        return

    var vrm_node = packed_scene.instantiate()
    if not vrm_node:
        print("Failed to instantiate scene")
        quit()
        return

    print("--- VRM0 Spring Bone Groups ---")
    var controller = vrm_node.find_children("*", "VRMSpringBoneController", true, false)
    if controller.size() > 0:
        var spring_bones = controller[0].spring_bones
        for sb in spring_bones:
            print("Resource Name: %s | Group: %s" % [sb.resource_name, sb.group])
    else:
        print("No VRMSpringBoneController found.")
    print("--- Done ---")
    quit()
