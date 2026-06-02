@tool
class_name VRMSpringBone
extends Resource

const vrm_collider_group = preload("./vrm_collider_group.gd")

# Annotation comment
@export var comment: String

# Auto-detected group category (e.g. "Hair", "Skirt", "Bust").
# Set during import based on bone name prefix or VRM comment.
# Can be manually edited to regroup bones in the inspector.
@export var group: String = ""

@export_group("Bone List (End bone may be left blank)")
# bone name of the root bone of the swaying object, within skeleton.
@export var joint_nodes: PackedStringArray

@export_group("Spring Settings")
@export_range(0, 10, 0.001, "or_greater") var stiffness_scale: float = 1.0

@export_range(0, 3, 0.001, "or_greater") var drag_force_scale: float = 1.0

@export_range(0, 1, 0.001, "or_greater") var hit_radius_scale: float = 1.0

@export_range(-10, 10, 0.001, "or_lesser", "or_greater") var gravity_scale: float = 1.0

@export var gravity_dir_default: Vector3 = Vector3(0, -1, 0)

@export_group("Environment Collision Settings")
@export var enable_environment_collision: bool = true
@export var environment_collision_mask: int = 1
## 0 = no damping (bouncy), higher values stick to surface
@export_range(0.0, 1.0, 0.01) var environment_collision_bounce_damping: float = 0.8

# Reference to the vrm_collidergroup for collisions with swaying objects.
@export var collider_groups: Array[VRMColliderGroup]

@export_group("Per-Joint Bone Settings (Optional)")
# The resilience of the swaying object (the power of returning to the initial pose).
@export var stiffness_force: PackedFloat64Array
# The strength of gravity.
@export var gravity_power: PackedFloat64Array
# The direction of gravity. Set (0, -1, 0) for simulating the gravity.
# Set (1, 0, 0) for simulating the wind.
@export var gravity_dir: PackedVector3Array
# The resistance (deceleration) of automatic animation.
@export var drag_force: PackedFloat64Array
# The radius of the sphere used for the collision detection with colliders.
@export var hit_radius: PackedFloat64Array

@export_group("Frame of Reference Node")
# The reference point of a swaying object can be set at any location except the origin.
# When implementing UI moving with warp, the parent node to move with warp can be
# specified if you don't want to make the object swaying with warp movement.",
# Exactly one of the following must be set.
@export var center_bone: String = ""
@export var center_node: NodePath = NodePath()
