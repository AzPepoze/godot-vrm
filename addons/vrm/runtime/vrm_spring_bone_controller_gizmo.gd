@tool
extends MeshInstance3D

var spring_bone_controller: Node3D
var m: StandardMaterial3D = StandardMaterial3D.new()


func _init(parent: Node3D) -> void:
    mesh = ImmediateMesh.new()
    spring_bone_controller = parent
    m.no_depth_test = true
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.vertex_color_use_as_albedo = true
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    set_material_override(m)
