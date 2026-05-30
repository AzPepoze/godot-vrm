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

@export var springbone_hit_radius_multiplier: float = 1.0:
	set(value):
		springbone_hit_radius_multiplier = value
		settings_changed.emit()

@export var constraint_weight_multiplier: float = 1.0:
	set(value):
		constraint_weight_multiplier = value
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

@export var environment_collision_mask: int = 1:
	set(value):
		environment_collision_mask = value
		settings_changed.emit()
