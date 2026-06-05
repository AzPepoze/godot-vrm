@tool
extends SceneTree

const vrm_spring_bone_parser = preload("res://addons/vrm/importer/common/vrm_spring_bone_parser.gd")


func _init():
    var test_cases = [
        ["hair1_L", ""],
        ["hair1_R", ""],
        ["hair_01_01", ""],
        ["mituami1", ""],
        ["ribbon_L", ""],
        ["skirt_01_01", ""],
        ["skirt_", "skirt_"],
        ["J_Sec_hair1_L", "hair1_L"],
    ]

    print("--- Running detect_group Tests ---")
    for tc in test_cases:
        var bone_name = tc[0]
        var comment = tc[1]
        var result = vrm_spring_bone_parser.detect_group(bone_name, comment)
        print('detect_group("%s", "%s") => "%s"' % [bone_name, comment, result])

    print("--- Done ---")
    quit()
