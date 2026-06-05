@tool
class_name VRMCollider
extends Resource

# Bone name references are only valid within the given Skeleton.
# If the node was not a skeleton, bone is "" and contains a path to the node.
@export var node_path: NodePath:
    set(value):
        node_path = value
        emit_changed()

# The bone within the skeleton with the collider, or "" if not a bone.
@export var bone: String:
    set(value):
        bone = value
        emit_changed()

@export var offset: Vector3:
    set(value):
        offset = value
        emit_changed()

@export var tail: Vector3:  # if is_capsule
    set(value):
        tail = value
        emit_changed()

@export var radius: float:
    set(value):
        radius = value
        emit_changed()

@export var is_capsule: bool = false:
    set(value):
        if value != is_capsule:
            is_capsule = value
            emit_changed()

# Only use in editor
@export var gizmo_color: Color = Color.MAGENTA
