## Attach this node in the scene and it will process the array of constraint
## resources on either bones or nodes, whatever the constraints reference.
@tool
@icon("res://addons/vrm/icons/vrm_constraint_applier.svg")
class_name VRMConstraintApplier
extends Node

@export_node_path("Skeleton3D") var skeleton: NodePath:
    set(value):
        skeleton = value
        if is_inside_tree():
            _ready()

const vrm_constraint = preload("./vrm_constraint.gd")

@export var constraints: Array[VRMConstraint] = []
#@export_node_path("Skeleton3D") var skeleton_node_path: NodePath = ^"%Skeleton3D"
#var skeleton: Skeleton3D

var skel: Skeleton3D
var internal_modifier_node: Node3D
var _use_cpp_simulator: bool = false
var global_weight_multiplier: float = 1.0


func _ready() -> void:
    if skeleton != NodePath():
        skel = get_node(skeleton)

    # Try to find VRMInstance or VRMSpringBoneController for global config
    var parent = get_parent()
    while parent:
        if parent is VRMInstance or parent is VRMSpringBoneController:
            var settings = parent.get("settings")
            if settings == null and "_settings" in parent:
                settings = parent.get("_settings")
            if settings is VRMSettings:
                global_weight_multiplier = settings.constraint_weight_multiplier
            else:
                var multiplier = parent.get("constraint_weight_multiplier")
                if multiplier != null:
                    global_weight_multiplier = multiplier
            break
        parent = parent.get_parent()

    for constraint in constraints:
        constraint.set_node_references_from_paths(self)
        if skel == null:
            skel = constraint.target_node as Skeleton3D
        if skel == null:
            skel = constraint.source_node as Skeleton3D

    if skel == null:
        return  # Not supported.

    if skeleton == NodePath():
        skeleton = get_path_to(skel)

    _use_cpp_simulator = ClassDB.class_exists(&"VRMConstraintSimulator")

    if _use_cpp_simulator:
        if internal_modifier_node != null:
            if internal_modifier_node.get_parent() != null:
                internal_modifier_node.get_parent().remove_child(internal_modifier_node)
            internal_modifier_node.queue_free()
        internal_modifier_node = ClassDB.instantiate("VRMConstraintSimulator")
        internal_modifier_node.name = "VRM_ConstraintSimulator"
        skel.add_child(internal_modifier_node, false, Node.INTERNAL_MODE_BACK)
        internal_modifier_node.setup(constraints)
        if internal_modifier_node.has_method("set_weight_multiplier"):
            internal_modifier_node.set_weight_multiplier(global_weight_multiplier)
    else:
        if ClassDB.class_exists(&"SkeletonModifier3D"):
            if internal_modifier_node != null:
                if internal_modifier_node.get_parent() != null:
                    internal_modifier_node.get_parent().remove_child(internal_modifier_node)
                internal_modifier_node.queue_free()
            internal_modifier_node = ClassDB.instantiate("SkeletonModifier3D")
            internal_modifier_node.name = "VRM_internal_skeleton_modifier"
            skel.add_child(internal_modifier_node, false, Node.INTERNAL_MODE_BACK)
            internal_modifier_node.connect(&"modification_processed", self.do_process)


func _process(_delta: float):
    if not _use_cpp_simulator:
        if not ClassDB.class_exists(&"SkeletonModifier3D"):
            do_process()


func do_process() -> void:
    if _use_cpp_simulator:
        return
    for constraint in constraints:
        constraint.evaluate(global_weight_multiplier)


func set_global_weight_multiplier(value: float) -> void:
    global_weight_multiplier = value
    if internal_modifier_node and internal_modifier_node.has_method("set_weight_multiplier"):
        internal_modifier_node.set_weight_multiplier(global_weight_multiplier)
