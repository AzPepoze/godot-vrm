@tool
class_name VRMSettings
extends Resource

signal settings_changed

@export_group("Global Multipliers")
@export var springbone_stiffness_multiplier: float = 1.0:
    set(value):
        springbone_stiffness_multiplier = value
        settings_changed.emit()

@export var springbone_drag_multiplier: float = 1.0:
    set(value):
        springbone_drag_multiplier = value
        settings_changed.emit()

@export var springbone_gravity_multiplier: float = 1.0:
    set(value):
        springbone_gravity_multiplier = value
        settings_changed.emit()

@export var constraint_weight_multiplier: float = 1.0:
    set(value):
        constraint_weight_multiplier = value
        settings_changed.emit()

@export_group("Spring Bone Collisions")
@export var disable_spring_bone_collisions: bool = false:
    set(value):
        disable_spring_bone_collisions = value
        settings_changed.emit()

@export var springbone_hit_radius_multiplier: float = 1.0:
    set(value):
        springbone_hit_radius_multiplier = value
        settings_changed.emit()

@export_group("Body Collisions")
@export var disable_body_collisions: bool = false:
    set(value):
        disable_body_collisions = value
        settings_changed.emit()

@export var body_collision_radius_multiplier: float = 1.0:
    set(value):
        body_collision_radius_multiplier = value
        settings_changed.emit()

@export_group("Force & Gravity")
@export var springbone_gravity_rotation: Quaternion = Quaternion.IDENTITY:
    set(value):
        var normalized = value.normalized()
        if springbone_gravity_rotation.is_equal_approx(normalized):
            return
        springbone_gravity_rotation = normalized
        settings_changed.emit()

@export var springbone_add_force: Vector3 = Vector3.ZERO:
    set(value):
        springbone_add_force = value
        settings_changed.emit()

@export_group("Wind Settings")
@export var wind_direction: Vector3 = Vector3.ZERO:
    set(value):
        wind_direction = value
        settings_changed.emit()

@export var wind_strength: float = 0.0:
    set(value):
        wind_strength = value
        settings_changed.emit()

@export var wind_turbulence: float = 0.2:
    set(value):
        wind_turbulence = value
        settings_changed.emit()

@export var wind_frequency: float = 1.0:
    set(value):
        wind_frequency = value
        settings_changed.emit()

@export_group("Environment Collision")
@export var environment_collision_enabled: bool = false:
    set(value):
        environment_collision_enabled = value
        settings_changed.emit()

@export var environment_collision_debug: bool = false:
    set(value):
        environment_collision_debug = value
        settings_changed.emit()

@export var environment_collision_mask: int = 1:
    set(value):
        environment_collision_mask = value
        settings_changed.emit()

## 0 = bouncy, higher = sticks to surface
@export_range(0.0, 1.0, 0.01) var environment_collision_bounce_damping: float = 0.8:
    set(value):
        environment_collision_bounce_damping = value
        settings_changed.emit()

@export_group("Springbone Gizmos")
@export_enum("Line Circle", "Capsule") var gizmo_display_mode: int = 0:
    set(value):
        gizmo_display_mode = value
        settings_changed.emit()

@export var gizmo_spring_bone: bool = false:
    set(value):
        gizmo_spring_bone = value
        settings_changed.emit()

@export var gizmo_spring_bone_color: Color = Color.LIGHT_YELLOW:
    set(value):
        gizmo_spring_bone_color = value
        settings_changed.emit()

@export var gizmo_show_body_collisions: bool = false:
    set(value):
        gizmo_show_body_collisions = value
        settings_changed.emit()

@export var gizmo_show_wind: bool = false:
    set(value):
        gizmo_show_wind = value
        settings_changed.emit()

@export var gizmo_wind_color: Color = Color.CYAN:
    set(value):
        gizmo_wind_color = value
        settings_changed.emit()

@export_group("Advanced & Runtime")
@export var update_in_editor: bool = false:
    set(value):
        update_in_editor = value
        settings_changed.emit()

@export var update_spring_bone_controller_in_physics: bool = false:
    set(value):
        update_spring_bone_controller_in_physics = value
        settings_changed.emit()

@export var springbone_simulate_in_local_space: bool = false:
    set(value):
        springbone_simulate_in_local_space = value
        settings_changed.emit()

@export var override_springbone_center: bool = false:
    set(value):
        override_springbone_center = value
        settings_changed.emit()
