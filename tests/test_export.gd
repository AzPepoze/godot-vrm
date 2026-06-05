extends SceneTree


func _init():
    var gltf_extension_classes = [
        load("res://addons/vrm/importer/v1/vrmc/vrmc_node_constraint.gd"),
        load("res://addons/vrm/importer/v1/vrmc/vrmc_spring_bone.gd"),
        load("res://addons/vrm/importer/v1/vrmc/vrmc_materials_mtoon.gd"),
        load("res://addons/vrm/importer/v1/vrmc/vrmc_materials_hdr_emissive_multiplier.gd"),
        load("res://addons/vrm/importer/v1/vrmc/vrmc_vrm.gd"),
        load("res://addons/vrm/importer/v1/vrmc/vrmc_vrm_animation.gd"),
    ]
    var instances = []
    for ext_cls in gltf_extension_classes:
        var instance = ext_cls.new()
        instances.append(instance)
        GLTFDocument.register_gltf_document_extension(instance, true)

    var doc = GLTFDocument.new()
    var state = GLTFState.new()

    print("Loading AvatarSample_M.vrm...")
    var err = doc.append_from_file("res://assets/vrm/AvatarSample_M.vrm", state)
    if err != OK:
        print("Failed to append from file: ", err)
        quit()
        return

    var root = doc.generate_scene(state)
    if root == null:
        print("Failed to generate scene from GLTFDocument")
        quit()
        return

    print("Generated scene successfully. Now exporting to /tmp/exported.vrm...")

    var doc2 = GLTFDocument.new()
    var state2 = GLTFState.new()
    err = doc2.append_from_scene(root, state2)
    if err == OK:
        err = doc2.write_to_filesystem(state2, "/tmp/exported.vrm")
        if err == OK:
            print("Export succeeded to /tmp/exported.vrm")

            print("Testing import of the exported file...")
            var doc3 = GLTFDocument.new()
            var state3 = GLTFState.new()
            err = doc3.append_from_file("/tmp/exported.vrm", state3)
            if err == OK:
                var imported_root = doc3.generate_scene(state3)
                if imported_root != null:
                    print("SUCCESS: Exported file was successfully re-imported as a scene!")
                else:
                    print("ERROR: Failed to generate scene from re-imported file.")
            else:
                print("ERROR: Failed to re-import the exported file: ", err)
        else:
            print("Failed to write to filesystem: ", err)
    else:
        print("Failed to append from scene: ", err)

    quit()
