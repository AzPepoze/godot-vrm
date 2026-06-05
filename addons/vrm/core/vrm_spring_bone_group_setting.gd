@tool
class_name VRMSpringBoneGroupSetting
extends Resource

@export var group_name: String = ""
@export var hit_radius_multiplier: float = 1.0:
    set(value):
        hit_radius_multiplier = value
        emit_changed()
