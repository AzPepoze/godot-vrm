@tool
class_name VRMSpringBoneController
extends Node3D

const VRMLogger = preload("../core/logger.gd")
const spring_bone_adapter_class = preload("./vrm_spring_bone_adapter.gd")
const SpringBoneGizmo = preload("./vrm_spring_bone_controller_gizmo.gd")

@export_category("Springbone Control")

@export_group("Spring Bone Collisions")
@export var disable_spring_bone_collisions: bool:
    get:
        return _get_settings().disable_spring_bone_collisions
    set(value):
        _get_settings().disable_spring_bone_collisions = value
        if spring_bone_adapter:
            spring_bone_adapter.update_parameters(_settings)

@export_group("Body Collisions")
@export var disable_body_collisions: bool:
    get:
        return _get_settings().disable_body_collisions
    set(value):
        _get_settings().disable_body_collisions = value
        if spring_bone_adapter:
            spring_bone_adapter.update_parameters(_settings)

@export_group("Advanced & Runtime")
@export var update_spring_bone_controller_in_physics: bool:
    get:
        return _get_settings().update_spring_bone_controller_in_physics
    set(value):
        _get_settings().update_spring_bone_controller_in_physics = value

@export var override_springbone_center: bool:
    get:
        return _get_settings().override_springbone_center
    set(value):
        _get_settings().override_springbone_center = value

@export var default_springbone_center: Node3D

@export_group("Run in Editor")
@export var update_in_editor: bool:
    get:
        return _get_settings().update_in_editor
    set(value):
        _get_settings().update_in_editor = value
        if spring_bone_adapter:
            spring_bone_adapter.update_parameters(_settings)
        if Engine.is_editor_hint():
            update_configuration_warnings()

@export_group("Gizmos")
@export var gizmo_spring_bone: bool:
    get:
        return _get_settings().gizmo_spring_bone
    set(value):
        _get_settings().gizmo_spring_bone = value
        if Engine.is_editor_hint():
            update_configuration_warnings()

@export var gizmo_spring_bone_color: Color:
    get:
        return _get_settings().gizmo_spring_bone_color
    set(value):
        _get_settings().gizmo_spring_bone_color = value

@export_enum("Line Circle", "Capsule") var gizmo_display_mode: int:
    get:
        return _get_settings().gizmo_display_mode
    set(value):
        _get_settings().gizmo_display_mode = value
        if spring_bone_adapter:
            spring_bone_adapter.set_gizmo_display_mode(value)

@export var gizmo_show_body_collisions: bool:
    get:
        return _get_settings().gizmo_show_body_collisions
    set(value):
        _get_settings().gizmo_show_body_collisions = value
        if Engine.is_editor_hint():
            update_configuration_warnings()

@export var gizmo_show_wind: bool:
    get:
        return _get_settings().gizmo_show_wind
    set(value):
        _get_settings().gizmo_show_wind = value
        if Engine.is_editor_hint():
            update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
    var warnings = PackedStringArray()
    if (
        not update_in_editor
        and (gizmo_spring_bone or gizmo_show_body_collisions or gizmo_show_wind)
    ):
        warnings.append(
            "Please enable 'Update In Editor' to correctly display the spring bone gizmos."
        )
    return warnings


@export var gizmo_wind_color: Color:
    get:
        return _get_settings().gizmo_wind_color
    set(value):
        _get_settings().gizmo_wind_color = value

@export_category("Spring bones")
@export_node_path("Skeleton3D") var skeleton: NodePath:
    set(value):
        skeleton = value
        if is_inside_tree():
            _ready()

@export var spring_bones: Array[VRMSpringBone]:
    set(value):
        spring_bones = value
        if is_inside_tree():
            _ready()

@export var collider_groups: Array[VRMColliderGroup]:
    set(value):
        collider_groups = value
        if skel != null:
            _setup_spring_bone_adapter()

@export var collider_library: Array[VRMCollider]

var skel: Skeleton3D
var is_child_of_vrm: bool = false
var _parent_ref: Node = null
var spring_bone_adapter: RefCounted = null
var _gizmo: MeshInstance3D = null
var _settings: VRMSettings = null


func _get_settings() -> VRMSettings:
    if _settings == null:
        _settings = VRMSettings.new()
    return _settings


func _enter_tree() -> void:
    _parent_ref = get_parent()
    if _parent_ref != null and _parent_ref.has_method("is_vrm_root"):
        is_child_of_vrm = true
        _parent_ref.set("spring_bone_controller", self)
        # Pull settings resource
        var parent_settings = _parent_ref.get("settings")
        if parent_settings is VRMSettings:
            update_from_settings(parent_settings)


func _ready() -> void:
    if skeleton.is_empty():
        var parent = get_parent()
        if parent is Skeleton3D:
            skel = parent
        else:
            var children = parent.find_children("*", "Skeleton3D", true, false)
            if not children.is_empty():
                skel = children[0]
        if skel:
            skeleton = get_path_to(skel)
    else:
        skel = get_node_or_null(skeleton)

    if skel == null:
        VRMLogger.warning(
            "vrm_spring_bone_controller.gd", "_ready: no skeleton found, skipping setup"
        )
        return

    spring_bones.sort_custom(func(a, b): return a.group < b.group)

    _setup_spring_bone_adapter()
    _setup_gizmo()
    VRMLogger.debug(
        "vrm_spring_bone_controller.gd",
        "_ready: setup complete for %d spring bones" % spring_bones.size()
    )
    if Engine.is_editor_hint():
        update_configuration_warnings()


func update_from_settings(settings: VRMSettings) -> void:
    if _settings != null and _settings.settings_changed.is_connected(_update_adapter):
        _settings.settings_changed.disconnect(_update_adapter)

    _settings = settings

    if _settings != null:
        if not _settings.settings_changed.is_connected(_update_adapter):
            _settings.settings_changed.connect(_update_adapter)
        _update_adapter()
        _notify_constraint_appliers()
        if Engine.is_editor_hint():
            update_configuration_warnings()


func _setup_spring_bone_adapter() -> void:
    if spring_bone_adapter == null:
        spring_bone_adapter = spring_bone_adapter_class.new(skel)
    else:
        spring_bone_adapter.skeleton = skel

    var group_multipliers: Array = []
    if is_child_of_vrm and _parent_ref != null:
        group_multipliers = _parent_ref.get("springbone_group_multipliers")

    spring_bone_adapter.setup_simulation(
        spring_bones, collider_groups, disable_body_collisions, update_in_editor, group_multipliers
    )
    _update_adapter()


func _setup_gizmo() -> void:
    if _gizmo == null:
        _gizmo = SpringBoneGizmo.new(self)
        add_child(_gizmo, false, Node.INTERNAL_MODE_BACK)


func _update_adapter() -> void:
    if spring_bone_adapter != null and _settings != null:
        spring_bone_adapter.update_parameters(_settings)


func _process(_delta: float):
    if _gizmo != null and spring_bone_adapter != null:
        var skel_to_gizmo: Transform3D = (
            _gizmo.global_transform.affine_inverse() * skel.global_transform
        )
        spring_bone_adapter.draw_gizmo(
            _gizmo.mesh,
            skel_to_gizmo,
            gizmo_spring_bone_color,
            gizmo_spring_bone,
            gizmo_show_body_collisions,
            gizmo_display_mode
        )

        if gizmo_show_wind and _settings != null:
            _draw_wind_arrow(_gizmo.mesh, _settings.wind_direction, gizmo_wind_color, skel_to_gizmo)

    if is_child_of_vrm and _parent_ref != null:
        var val_default_springbone_center = _parent_ref.get("default_springbone_center")
        if val_default_springbone_center != null:
            default_springbone_center = val_default_springbone_center


func _draw_wind_arrow(
    mesh: ImmediateMesh, direction: Vector3, color: Color, skel_to_gizmo: Transform3D
) -> void:
    if direction.length() < 0.001:
        return

    mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    mesh.surface_set_color(color)

    # Gizmo is in skeleton space because of the skel_to_gizmo transform
    # Find Head bone for positioning
    var head_bone_name = "Head"
    if is_child_of_vrm and _parent_ref != null:
        var vrm_meta = _parent_ref.get("vrm_meta")
        if vrm_meta != null and vrm_meta.humanoid_bone_mapping != null:
            var mapped_head = vrm_meta.humanoid_bone_mapping.get_skeleton_bone_name("Head")
            if mapped_head != StringName():
                head_bone_name = String(mapped_head)

    var head_idx = skel.find_bone(head_bone_name)
    var start_pos_skel = Vector3(0, 1.5, 0)  # Fallback
    if head_idx != -1:
        start_pos_skel = skel.get_bone_global_pose(head_idx).origin

    # direction is global, so we add it in global space, then transform to gizmo space
    var start_pos_global = skel.global_transform * start_pos_skel
    var end_pos_global = start_pos_global + direction.normalized() * 0.5
    var start_pos = _gizmo.global_transform.affine_inverse() * start_pos_global
    var end_pos = _gizmo.global_transform.affine_inverse() * end_pos_global

    # Draw Main Line
    mesh.surface_add_vertex(start_pos)
    mesh.surface_add_vertex(end_pos)

    # Draw Arrow Head
    var dir = (end_pos - start_pos).normalized()
    var ortho = dir.cross(Vector3.UP).normalized()
    if ortho.length() < 0.01:
        ortho = dir.cross(Vector3.RIGHT).normalized()

    var arrow_side_1 = end_pos - dir * 0.1 + ortho * 0.05
    var arrow_side_2 = end_pos - dir * 0.1 - ortho * 0.05

    mesh.surface_add_vertex(end_pos)
    mesh.surface_add_vertex(arrow_side_1)
    mesh.surface_add_vertex(end_pos)
    mesh.surface_add_vertex(arrow_side_2)

    mesh.surface_end()


func _notify_constraint_appliers() -> void:
    if not is_inside_tree() or _settings == null:
        return
    var root = _parent_ref if is_child_of_vrm else get_parent()
    if root:
        var appliers = root.find_children("*", "VRMConstraintApplier", true, false)
        for applier in appliers:
            if applier.has_method("set_global_weight_multiplier"):
                applier.set_global_weight_multiplier(_settings.constraint_weight_multiplier)
