@tool
class_name VRMInstance
extends Node

const vrm_meta_class = preload("./vrm_meta.gd")

var spring_bone_controller: Node3D:
	set(value):
		spring_bone_controller = value
		if spring_bone_controller:
			var parent_springs = spring_bones
			var child_springs = spring_bone_controller.get("spring_bones")
			if child_springs is Array:
				if parent_springs.is_empty() and not child_springs.is_empty():
					spring_bones = child_springs
				elif not parent_springs.is_empty() and child_springs.is_empty():
					spring_bone_controller.set("spring_bones", parent_springs)
				elif parent_springs != child_springs:
					spring_bone_controller.set("spring_bones", parent_springs)

			var parent_cgroups = collider_groups
			var child_cgroups = spring_bone_controller.get("collider_groups")
			if child_cgroups is Array:
				if parent_cgroups.is_empty() and not child_cgroups.is_empty():
					collider_groups = child_cgroups
				elif not parent_cgroups.is_empty() and child_cgroups.is_empty():
					spring_bone_controller.set("collider_groups", parent_cgroups)
				elif parent_cgroups != child_cgroups:
					spring_bone_controller.set("collider_groups", parent_cgroups)

			var parent_clib = collider_library
			var child_clib = spring_bone_controller.get("collider_library")
			if child_clib is Array:
				if parent_clib.is_empty() and not child_clib.is_empty():
					collider_library = child_clib
				elif not parent_clib.is_empty() and child_clib.is_empty():
					spring_bone_controller.set("collider_library", parent_clib)
				elif parent_clib != child_clib:
					spring_bone_controller.set("collider_library", parent_clib)

@export var vrm_meta: Resource

@export_category("Spring bones")
@export var spring_bones: Array[VRMSpringBone] = []:
	set(value):
		spring_bones = value
		if spring_bone_controller:
			var child_springs = spring_bone_controller.get("spring_bones")
			if child_springs is Array and not child_springs.is_empty() and value.is_empty():
				spring_bones = child_springs
			elif spring_bone_controller.get("spring_bones") != value:
				spring_bone_controller.set("spring_bones", value)

@export var collider_groups: Array[VRMColliderGroup] = []:
	set(value):
		collider_groups = value
		if spring_bone_controller:
			var child_cgroups = spring_bone_controller.get("collider_groups")
			if child_cgroups is Array and not child_cgroups.is_empty() and value.is_empty():
				collider_groups = child_cgroups
			elif spring_bone_controller.get("collider_groups") != value:
				spring_bone_controller.set("collider_groups", value)

@export var collider_library: Array[VRMCollider] = []:
	set(value):
		collider_library = value
		if spring_bone_controller:
			var child_clib = spring_bone_controller.get("collider_library")
			if child_clib is Array and not child_clib.is_empty() and value.is_empty():
				collider_library = child_clib
			elif spring_bone_controller.get("collider_library") != value:
				spring_bone_controller.set("collider_library", value)

@export_tool_button("Recreate Spring Bone Simulation", "Reload")
var recreate_spring_bone_simulation: Callable = recreate_simulation


func recreate_simulation() -> void:
	if spring_bone_controller:
		if spring_bone_controller.get("spring_bones").is_empty() and not spring_bones.is_empty():
			spring_bone_controller.set("spring_bones", spring_bones)
		if (
			spring_bone_controller.get("collider_groups").is_empty()
			and not collider_groups.is_empty()
		):
			spring_bone_controller.set("collider_groups", collider_groups)
		if (
			spring_bone_controller.get("collider_library").is_empty()
			and not collider_library.is_empty()
		):
			spring_bone_controller.set("collider_library", collider_library)

		# Sync child arrays to parent if parent is empty
		if spring_bones.is_empty() and not spring_bone_controller.get("spring_bones").is_empty():
			spring_bones = spring_bone_controller.get("spring_bones")
		if (
			collider_groups.is_empty()
			and not spring_bone_controller.get("collider_groups").is_empty()
		):
			collider_groups = spring_bone_controller.get("collider_groups")
		if (
			collider_library.is_empty()
			and not spring_bone_controller.get("collider_library").is_empty()
		):
			collider_library = spring_bone_controller.get("collider_library")

		spring_bone_controller.call("_ready")
		notify_property_list_changed()


@export_category("VRM Settings")
@export var settings: VRMSettings:
	set(value):
		if settings == value:
			return
		if settings != null and settings.settings_changed.is_connected(_on_settings_changed):
			settings.settings_changed.disconnect(_on_settings_changed)

		settings = value

		if settings != null:
			if not settings.settings_changed.is_connected(_on_settings_changed):
				settings.settings_changed.connect(_on_settings_changed)
		_on_settings_changed()

@export var default_springbone_center: Node3D:
	set(value):
		default_springbone_center = value
		if spring_bone_controller:
			spring_bone_controller.default_springbone_center = value


func _init() -> void:
	if settings == null:
		settings = VRMSettings.new()


func _on_settings_changed() -> void:
	if spring_bone_controller and spring_bone_controller.has_method("update_from_settings"):
		spring_bone_controller.update_from_settings(settings)


func is_vrm_root() -> bool:
	return true
