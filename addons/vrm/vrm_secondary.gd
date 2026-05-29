@tool
class_name VRMSecondary
extends Node3D

const spring_bone_class = preload("./vrm_spring_bone.gd")
const collider_class = preload("./vrm_collider.gd")
const collider_group_class = preload("./vrm_collider_group.gd")

@export_category("Springbone Settings")
@export var update_secondary_fixed: bool = false:
	set(value):
		update_secondary_fixed = value
		if is_child_of_vrm:
			get_parent().update_secondary_fixed = value
@export var disable_colliders: bool = false:
	set(value):
		disable_colliders = value
		if is_child_of_vrm:
			get_parent().disable_colliders = value
@export var override_springbone_center: bool = false:
	set(value):
		override_springbone_center = value
		if is_child_of_vrm:
			get_parent().override_springbone_center = value

@export var default_springbone_center: Node3D:
	set(value):
		default_springbone_center = value
		if is_child_of_vrm:
			get_parent().default_springbone_center = value

@export var springbone_gravity_multiplier: float = 1.0:
	set(value):
		springbone_gravity_multiplier = value
		if is_child_of_vrm:
			get_parent().springbone_gravity_multiplier = value
			modify_gravity = true
@export var springbone_gravity_rotation: Quaternion = Quaternion.IDENTITY:
	set(value):
		springbone_gravity_rotation = value
		if is_child_of_vrm:
			get_parent().springbone_gravity_rotation = value
			modify_gravity = true
@export var springbone_add_force: Vector3 = Vector3.ZERO:
	set(value):
		springbone_add_force = value
		if is_child_of_vrm:
			get_parent().springbone_add_force = value
			modify_gravity = true

@export_category("Run in Editor")
@export var update_in_editor: bool = false:
	set(value):
		update_in_editor = value
		if is_child_of_vrm:
			get_parent().update_in_editor = value
		if Engine.is_editor_hint() and is_inside_tree():
			if value:
				_ready()
			else:
				for spring_bone in spring_bones_internal:
					spring_bone.skel.clear_bones_global_pose_override()
@export var gizmo_spring_bone: bool = false:
	set(value):
		gizmo_spring_bone = value
		if is_child_of_vrm:
			get_parent().gizmo_spring_bone = value
@export var gizmo_spring_bone_color: Color = Color.LIGHT_YELLOW:
	set(value):
		gizmo_spring_bone_color = value
		if is_child_of_vrm:
			get_parent().gizmo_spring_bone_color = value

@export_category("Spring bones")
@export_node_path("Skeleton3D") var skeleton: NodePath:
	set(value):
		if skel is Skeleton3D and skel != null:
			skel.clear_bones_global_pose_override()
		skeleton = value
		if is_inside_tree():
			_ready()

@export var spring_bones: Array[spring_bone_class]:
	set(value):
		spring_bones = value
		if is_child_of_vrm:
			get_parent().spring_bones = value

var skel: Skeleton3D
var internal_modifier_node: Node3D

# Props

var spring_bones_internal: Array[spring_bone_class.SpringBoneRuntimeState]
var springs_centers: PackedInt32Array

var colliders_internal: Array[collider_class.VrmRuntimeCollider]
var colliders_centers: PackedInt32Array
var center_bones: PackedInt32Array
var center_nodes: Array[Node3D]

# Updated every frame
var center_transforms: Array[Transform3D]
var center_transforms_inv: Array[Transform3D]

var secondary_gizmo: SecondaryGizmo
var is_child_of_vrm: bool = false
var colliders_changed: bool = false
var modify_gravity: bool = false
var _has_skeleton_modifier: bool = false
var _parent_ref: Node = null

@export var collider_groups: Array[collider_group_class]  # Unused, but this way we don't break script compatibility.
@export var collider_library: Array[collider_class]  # Unused, intended to make inspecting easier
var spring_bones_cached: Array[spring_bone_class]


func _on_recreate_collider():
	colliders_changed = true


# Collider state
# TODO: explore packed data to make processing optimization such as c++ easier.
#var collider_skel_positions: PackedVector3Array
#var collider_skel_tails: PackedVector3Array # is_capsule if not equal to collider_skel_positions
#var collider_radius: PackedFloat32Array
#const springbone_runtime = preload("./runtime/springbone_runtime.gd")
#var spring_logic: Array[springbone_runtime]

var _has_spring_bone_simulator: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_has_skeleton_modifier = ClassDB.class_exists(&"SkeletonModifier3D")
	_has_spring_bone_simulator = ClassDB.class_exists(&"SpringBoneSimulator3D")
	_parent_ref = get_parent()
	skel = get_node(skeleton)
	if skel == null:
		return  # Not supported.

	if _has_spring_bone_simulator:
		_setup_spring_bone_simulator()
		return

	if _has_skeleton_modifier:
		if internal_modifier_node != null:
			if internal_modifier_node.get_parent() != null:
				internal_modifier_node.get_parent().remove_child(internal_modifier_node)
			internal_modifier_node.queue_free()
		internal_modifier_node = ClassDB.instantiate("SkeletonModifier3D")
		internal_modifier_node.name = "VRM_internal_skeleton_modifier"
		skel.add_child(internal_modifier_node, false, Node.INTERNAL_MODE_BACK)
		internal_modifier_node.connect(
			&"modification_processed", self._on_secondary_process_modification_processed
		)

	spring_bones_cached = spring_bones
	var gizmo_spring_bone: bool = false
	if (
		_parent_ref != null
		and _parent_ref.script != null
		and _parent_ref.script.resource_path.get_file() == "vrm_toplevel.gd"
	):
		is_child_of_vrm = true
	if is_child_of_vrm:
		_parent_ref.spring_bones = spring_bones
		_parent_ref.collider_groups = collider_groups
		_parent_ref.collider_library = collider_library
		update_secondary_fixed = _parent_ref.get("update_secondary_fixed")
		gizmo_spring_bone = _parent_ref.get("gizmo_spring_bone")
		disable_colliders = _parent_ref.get("disable_colliders")

	if secondary_gizmo == null and (Engine.is_editor_hint() or gizmo_spring_bone):
		secondary_gizmo = SecondaryGizmo.new(self)
		skel.add_child(secondary_gizmo, true, Node.INTERNAL_MODE_FRONT)
	colliders_internal.clear()
	spring_bones_internal.clear()
	colliders_centers.clear()
	center_bones.clear()
	center_nodes.clear()
	center_transforms.clear()
	center_transforms_inv.clear()
	var center_to_collider_to_internal: Dictionary = {}
	var center_to_index: Dictionary = {}
	for spring_bone in spring_bones:
		if not spring_bone:
			spring_bone = spring_bone_class.new()
		var center_key: Variant = spring_bone.center_bone
		if spring_bone.center_bone == "":
			center_key = spring_bone.center_node

		if not center_to_index.has(center_key):
			center_to_index[center_key] = len(center_bones)
			if spring_bone.center_bone != "":
				center_bones.push_back(skel.find_bone(spring_bone.center_bone))
			else:
				center_bones.push_back(-1)
			if spring_bone.center_node == NodePath():
				center_nodes.push_back(null)
			else:
				center_nodes.push_back(get_node(spring_bone.center_node))
			center_transforms.push_back(Transform3D.IDENTITY)
			center_transforms_inv.push_back(Transform3D.IDENTITY)

	update_centers(skel.global_transform)

	collider_groups.clear()
	collider_library.clear()
	var seen_collider_groups: Dictionary
	var seen_colliders: Dictionary
	for spring_bone in spring_bones:
		if not spring_bone:
			spring_bone = spring_bone_class.new()
		var center_key: Variant = spring_bone.center_bone
		if spring_bone.center_bone == "":
			center_key = spring_bone.center_node
		var center_idx: int = center_to_index[center_key]

		var tmp_colliders: Array[collider_class.VrmRuntimeCollider] = []
		for collider_group in spring_bone.collider_groups:
			if not seen_collider_groups.has(collider_group):
				seen_collider_groups[collider_group] = true
				collider_groups.append(collider_group)
			for collider in collider_group.colliders:
				if not seen_colliders.has(collider):
					seen_colliders[collider] = true
					collider_library.append(collider)
				if not collider.recreate_collider.is_connected(self._on_recreate_collider):
					collider.recreate_collider.connect(self._on_recreate_collider)  # Rebuild everything if anything changes.
				var collider_runtime: collider_class.VrmRuntimeCollider
				if center_key not in center_to_collider_to_internal:
					center_to_collider_to_internal[center_key] = {}
				if center_to_collider_to_internal[center_key].has(collider):
					collider_runtime = center_to_collider_to_internal[center_key][collider]
				else:
					collider_runtime = collider.create_runtime(self, skel)
					collider_runtime.gizmo_color = collider.gizmo_color
					colliders_internal.append(collider_runtime)
					colliders_centers.append(center_idx)
					center_to_collider_to_internal[center_key][collider] = collider_runtime
				tmp_colliders.append(collider_runtime)

		var new_spring_bone := spring_bone.create_runtime(skel)
		new_spring_bone.ready(skel, tmp_colliders, center_transforms_inv[center_idx])
		new_spring_bone.disable_colliders = disable_colliders
		spring_bones_internal.append(new_spring_bone)
		springs_centers.append(center_idx)


func _setup_spring_bone_simulator() -> void:
	if internal_modifier_node != null:
		if internal_modifier_node.get_parent() != null:
			internal_modifier_node.get_parent().remove_child(internal_modifier_node)
		internal_modifier_node.queue_free()

	internal_modifier_node = ClassDB.instantiate("SpringBoneSimulator3D")
	internal_modifier_node.name = "VRM_SpringBoneSimulator3D"
	skel.add_child(internal_modifier_node, false, Node.INTERNAL_MODE_BACK)

	# 1. Gather all unique colliders
	var all_colliders_map: Dictionary = {}
	for spring_bone in spring_bones:
		if not spring_bone:
			continue
		for cg in spring_bone.collider_groups:
			if not cg:
				continue
			for c in cg.colliders:
				if c:
					all_colliders_map[c] = true

	# 2. Instantiate Godot collision nodes as children of the simulator
	var godot_colliders: Dictionary = {}
	for c in all_colliders_map:
		var col_node: Node3D
		if c.is_capsule:
			var cap = SpringBoneCollisionCapsule3D.new()
			cap.radius = c.radius
			var diff = c.tail - c.offset
			var length = diff.length()
			cap.mid_height = length
			cap.position_offset = (c.offset + c.tail) / 2.0
			if length > 0.00001:
				cap.rotation_offset = Quaternion(Vector3(0, 1, 0), diff / length)
			else:
				cap.rotation_offset = Quaternion.IDENTITY
			col_node = cap
		else:
			var sph = SpringBoneCollisionSphere3D.new()
			sph.radius = c.radius
			sph.position_offset = c.offset
			col_node = sph

		col_node.name = "Collider_" + str(c.get_instance_id())
		if c.bone != "":
			col_node.set("bone_name", c.bone)
		elif c.node_path != NodePath():
			# If attached to a node, we will add it to that node instead
			var target_node = get_node_or_null(c.node_path)
			if target_node:
				target_node.add_child(col_node)
				godot_colliders[c] = col_node
				continue

		internal_modifier_node.add_child(col_node)
		godot_colliders[c] = col_node

	# 3. Configure settings
	var valid_spring_bones: Array[spring_bone_class] = []
	for sb in spring_bones:
		if sb:
			valid_spring_bones.append(sb)

	internal_modifier_node.set_setting_count(len(valid_spring_bones))

	for idx in range(len(valid_spring_bones)):
		var sb = valid_spring_bones[idx]
		var active_joints: PackedStringArray = []
		for node_name in sb.joint_nodes:
			if not node_name.is_empty():
				active_joints.append(node_name)

		if active_joints.is_empty():
			continue

		internal_modifier_node.set_root_bone_name(idx, active_joints[0])
		internal_modifier_node.set_end_bone_name(idx, active_joints[-1])

		# Check if we should extend end bone
		if sb.joint_nodes[-1] == "":
			internal_modifier_node.set_extend_end_bone(idx, true)
			internal_modifier_node.set_end_bone_length(idx, 0.07)
			var last_bone_name = active_joints[-1]
			var last_bone_idx = skel.find_bone(last_bone_name)
			if last_bone_idx != -1:
				var rest_pos = skel.get_bone_rest(last_bone_idx).origin
				if rest_pos.length_squared() > 0.00001:
					internal_modifier_node.set_end_bone_direction(idx, rest_pos.normalized())
		else:
			internal_modifier_node.set_extend_end_bone(idx, false)

		# Center bone/node
		if sb.center_bone != "":
			internal_modifier_node.set_center_bone_name(idx, sb.center_bone)
		elif sb.center_node != NodePath():
			var target_node = get_node_or_null(sb.center_node)
			if target_node:
				var rel_path = internal_modifier_node.get_path_to(target_node)
				internal_modifier_node.set_center_node(idx, rel_path)

		# Configure base settings
		internal_modifier_node.set_stiffness(idx, sb.stiffness_scale)
		internal_modifier_node.set_drag(idx, sb.drag_force_scale)
		internal_modifier_node.set_radius(idx, sb.hit_radius_scale)
		internal_modifier_node.set_gravity(idx, sb.gravity_scale)
		internal_modifier_node.set_gravity_direction(idx, sb.gravity_dir_default)
		internal_modifier_node.set_external_force(springbone_add_force)

		# Configure per-joint individual configs
		internal_modifier_node.set_individual_config(idx, true)

		for joint_idx in range(len(active_joints)):
			var stiffness_val = sb.stiffness_scale
			if not sb.stiffness_force.is_empty():
				stiffness_val *= (
					sb.stiffness_force[joint_idx]
					if joint_idx < len(sb.stiffness_force)
					else sb.stiffness_force[-1]
				)
			internal_modifier_node.set_joint_stiffness(idx, joint_idx, stiffness_val)

			var drag_val = sb.drag_force_scale
			if not sb.drag_force.is_empty():
				drag_val *= (
					sb.drag_force[joint_idx]
					if joint_idx < len(sb.drag_force)
					else sb.drag_force[-1]
				)
			internal_modifier_node.set_joint_drag(idx, joint_idx, drag_val)

			var radius_val = sb.hit_radius_scale
			if not sb.hit_radius.is_empty():
				radius_val *= (
					sb.hit_radius[joint_idx]
					if joint_idx < len(sb.hit_radius)
					else sb.hit_radius[-1]
				)
			internal_modifier_node.set_joint_radius(idx, joint_idx, radius_val)

			var grav_val = sb.gravity_scale
			if not sb.gravity_power.is_empty():
				grav_val *= (
					sb.gravity_power[joint_idx]
					if joint_idx < len(sb.gravity_power)
					else sb.gravity_power[-1]
				)
			internal_modifier_node.set_joint_gravity(idx, joint_idx, grav_val)

			var grav_dir = sb.gravity_dir_default
			if not sb.gravity_dir.is_empty():
				grav_dir = (
					sb.gravity_dir[joint_idx]
					if joint_idx < len(sb.gravity_dir)
					else sb.gravity_dir[-1]
				)
			internal_modifier_node.set_joint_gravity_direction(idx, joint_idx, grav_dir)

		# Configure allowed collisions using exclude list
		internal_modifier_node.set("settings/%d/enable_all_child_collisions" % idx, true)

		var allowed_nodes: Array[Node3D] = []
		for cg in sb.collider_groups:
			if cg:
				for c in cg.colliders:
					if c in godot_colliders:
						allowed_nodes.append(godot_colliders[c])

		var to_exclude: Array[Node3D] = []
		for c in godot_colliders.values():
			if not c in allowed_nodes:
				to_exclude.append(c)

		internal_modifier_node.set_exclude_collision_count(idx, len(to_exclude))
		for j in range(len(to_exclude)):
			var path = internal_modifier_node.get_path_to(to_exclude[j])
			internal_modifier_node.set_exclude_collision_path(idx, j, path)

	internal_modifier_node.active = true
	internal_modifier_node.reset()


func update_simulator_gravity() -> void:
	if not internal_modifier_node or not _has_spring_bone_simulator:
		return

	internal_modifier_node.set_external_force(springbone_add_force)

	var valid_spring_bones: Array[spring_bone_class] = []
	for sb in spring_bones:
		if sb:
			valid_spring_bones.append(sb)

	for idx in range(len(valid_spring_bones)):
		var sb = valid_spring_bones[idx]
		var active_joints: PackedStringArray = []
		for node_name in sb.joint_nodes:
			if not node_name.is_empty():
				active_joints.append(node_name)

		for joint_idx in range(len(active_joints)):
			var grav_val = sb.gravity_scale
			if not sb.gravity_power.is_empty():
				grav_val *= (
					sb.gravity_power[joint_idx]
					if joint_idx < len(sb.gravity_power)
					else sb.gravity_power[-1]
				)

			var grav_dir = sb.gravity_dir_default
			if not sb.gravity_dir.is_empty():
				grav_dir = (
					sb.gravity_dir[joint_idx]
					if joint_idx < len(sb.gravity_dir)
					else sb.gravity_dir[-1]
				)

			var total_gravity_vec = (
				springbone_gravity_rotation * (grav_val * grav_dir) * springbone_gravity_multiplier
			)
			internal_modifier_node.set_joint_gravity(idx, joint_idx, total_gravity_vec.length())
			if total_gravity_vec.length_squared() > 0.00001:
				internal_modifier_node.set_joint_gravity_direction(
					idx, joint_idx, total_gravity_vec.normalized()
				)


func check_for_editor_update() -> bool:
	if not Engine.is_editor_hint():
		return false
	if is_child_of_vrm and _parent_ref != null:
		if _parent_ref.update_in_editor != update_in_editor:
			update_in_editor = _parent_ref.update_in_editor
	return update_in_editor


func update_centers(skel_transform: Transform3D):
	skel.get_bone_global_pose_no_override(0)
	var skel_transform_inv: Transform3D = skel_transform.affine_inverse()
	var center_xform: Transform3D
	var center_xform_inv: Transform3D
	if default_springbone_center != null:
		center_xform = default_springbone_center.global_transform
		center_xform_inv = center_xform.affine_inverse()
	for center_i in range(len(center_nodes)):
		var center_node: Node3D = center_nodes[center_i]
		if (center_bones[center_i] == -1 and center_node == null) or override_springbone_center:
			center_transforms[center_i] = skel_transform
			center_transforms_inv[center_i] = skel_transform_inv
			if default_springbone_center != null:
				center_transforms[center_i] = center_xform_inv * center_transforms[center_i]
				center_transforms_inv[center_i] = center_transforms_inv[center_i] * center_xform
		elif center_bones[center_i] == -1 and center_node != null:
			center_transforms[center_i] = (
				center_node.global_transform.affine_inverse() * skel_transform
			)
			center_transforms_inv[center_i] = skel_transform_inv * center_node.global_transform
		else:
			center_transforms[center_i] = skel.get_bone_global_pose(center_bones[center_i])
			center_transforms_inv[center_i] = center_transforms[center_i].affine_inverse()


func tick_spring_bones(delta: float) -> void:
	if skel == null:
		return

	if _has_spring_bone_simulator:
		if is_child_of_vrm and _parent_ref != null:
			if (
				_parent_ref.springbone_gravity_rotation != springbone_gravity_rotation
				or _parent_ref.springbone_gravity_multiplier != springbone_gravity_multiplier
				or _parent_ref.springbone_add_force != springbone_add_force
			):
				springbone_add_force = _parent_ref.springbone_add_force
				springbone_gravity_rotation = _parent_ref.springbone_gravity_rotation
				springbone_gravity_multiplier = _parent_ref.springbone_gravity_multiplier
				modify_gravity = true
			if _parent_ref.disable_colliders != disable_colliders:
				disable_colliders = _parent_ref.disable_colliders
				# If we want to disable colliders on simulator:
				internal_modifier_node.active = !disable_colliders
			if spring_bones != _parent_ref.spring_bones:
				spring_bones = _parent_ref.spring_bones
				_setup_spring_bone_simulator()

		if modify_gravity:
			modify_gravity = false
			update_simulator_gravity()
		return

	var skel_transform: Transform3D = skel.global_transform
	update_centers(skel_transform)

	var needs_reintialize: bool = false
	# our setter syncs it the other direction.
	if is_child_of_vrm and _parent_ref != null:
		if (
			_parent_ref.springbone_gravity_rotation != springbone_gravity_rotation
			or _parent_ref.springbone_gravity_multiplier != springbone_gravity_multiplier
			or _parent_ref.springbone_add_force != springbone_add_force
		):
			springbone_add_force = _parent_ref.springbone_add_force
			springbone_gravity_rotation = _parent_ref.springbone_gravity_rotation
			springbone_gravity_multiplier = _parent_ref.springbone_gravity_multiplier
			modify_gravity = true
		if _parent_ref.disable_colliders != disable_colliders:
			disable_colliders = _parent_ref.disable_colliders
			for sb in spring_bones_internal:
				sb.disable_colliders = disable_colliders
		override_springbone_center = _parent_ref.override_springbone_center
		default_springbone_center = _parent_ref.default_springbone_center
		if spring_bones != _parent_ref.spring_bones:
			spring_bones = _parent_ref.spring_bones
			needs_reintialize = true
	if modify_gravity:
		for sb in spring_bones_internal:
			sb.add_force = springbone_add_force
			sb.gravity_rotation = springbone_gravity_rotation
			sb.gravity_multiplier = springbone_gravity_multiplier
	for spring_i in range(len(spring_bones_internal)):
		needs_reintialize = spring_bones_internal[spring_i].pre_update() or needs_reintialize

	if needs_reintialize or colliders_changed or spring_bones_cached != spring_bones:
		colliders_changed = false
		skel.clear_bones_global_pose_override()
		_ready()
		for spring_i in range(len(spring_bones_internal)):
			spring_bones_internal[spring_i].pre_update()

	for collider_i in range(len(colliders_internal)):
		colliders_internal[collider_i].update(
			skel_transform, center_transforms[colliders_centers[collider_i]], skel
		)
	for spring_i in range(len(spring_bones_internal)):
		spring_bones_internal[spring_i].update(
			delta,
			center_transforms[springs_centers[spring_i]],
			center_transforms_inv[springs_centers[spring_i]]
		)

	if secondary_gizmo != null:
		if Engine.is_editor_hint():
			secondary_gizmo.draw_in_editor(true)
		else:
			secondary_gizmo.draw_in_game()


func _process(delta: float):
	if not _has_skeleton_modifier:
		if not update_secondary_fixed:
			do_process(delta)


func _physics_process(delta: float) -> void:
	if not _has_skeleton_modifier:
		if update_secondary_fixed:
			do_process(delta)


func _on_secondary_process_modification_processed() -> void:
	var delta: float
	# MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS = 0
	if skel.modifier_callback_mode_process == 0:
		delta = get_physics_process_delta_time()
	else:
		delta = get_process_delta_time()
	do_process(delta)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func do_process(delta: float) -> void:
	if not Engine.is_editor_hint() or check_for_editor_update():
		tick_spring_bones(delta)
	elif Engine.is_editor_hint():
		if secondary_gizmo != null:
			if skel != null:
				var skel_transform: Transform3D = skel.global_transform
				update_centers(skel_transform)
				for collider_i in range(len(colliders_internal)):
					colliders_internal[collider_i].update(
						skel_transform, center_transforms[colliders_centers[collider_i]], skel
					)
				secondary_gizmo.draw_in_editor()


class SecondaryGizmo:
	extends MeshInstance3D

	var secondary_node
	var m: StandardMaterial3D = StandardMaterial3D.new()

	func _init(parent) -> void:
		mesh = ImmediateMesh.new()
		secondary_node = parent
		m.no_depth_test = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	func draw_in_editor(_do_draw_spring_bones: bool = false) -> void:
		mesh.clear_surfaces()
		if secondary_node.is_child_of_vrm && secondary_node.get_parent().gizmo_spring_bone:
			draw_spring_bones(secondary_node.get_parent().gizmo_spring_bone_color)
			draw_collider_groups()

	func draw_in_game() -> void:
		mesh.clear_surfaces()
		if secondary_node.is_child_of_vrm && secondary_node.get_parent().gizmo_spring_bone:
			draw_spring_bones(secondary_node.get_parent().gizmo_spring_bone_color)
			draw_collider_groups()

	func draw_spring_bones(color: Color) -> void:
		if secondary_node.spring_bones_internal.is_empty():
			return
		set_material_override(m)
		var i: int = 0
		var s_sk: Skeleton3D = secondary_node.skel
		# Spring bones
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for spring_bone in secondary_node.spring_bones_internal:
			var center_transform_inv: Transform3D = secondary_node.center_transforms_inv[
				secondary_node.springs_centers[i]
			]
			for v in spring_bone.verlets:
				var s_tr: Transform3D = Transform3D.IDENTITY
				if v.bone_idx != -1:
					s_tr = s_sk.get_bone_global_pose(v.bone_idx)
				draw_line(s_tr.origin, center_transform_inv * v.current_tail, color)
			for v in spring_bone.verlets:
				var s_tr: Transform3D = Transform3D.IDENTITY
				if v.bone_idx != -1:
					s_tr = s_sk.get_bone_global_pose(v.bone_idx)
				draw_sphere(
					(center_transform_inv.basis * s_tr.basis).orthonormalized(),
					center_transform_inv * v.current_tail,
					v.radius,
					color
				)
			i += 1
		mesh.surface_end()

	func draw_collider_groups() -> void:
		if secondary_node.colliders_internal.is_empty():
			return
		set_material_override(m)
		var i: int = 0
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for collider in secondary_node.colliders_internal:
			var center_transform_inv: Transform3D = secondary_node.center_transforms_inv[
				secondary_node.colliders_centers[i]
			]
			collider.draw_debug(mesh, center_transform_inv)
			i += 1
		mesh.surface_end()

	func draw_sphere(bas: Basis, center: Vector3, radius: float, color: Color) -> void:
		var step: int = 15
		var sppi: float = 2 * PI / step
		for i in range(1, step + 1):
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(
				(
					center
					+ ((bas * Vector3.UP * radius).rotated(
						bas * Vector3.RIGHT, sppi * (i - 1 % step)
					))
				)
			)
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(
				(
					center
					+ ((bas * Vector3.UP * radius).rotated(bas * Vector3.RIGHT, sppi * (i % step)))
				)
			)
		for i in range(1, step + 1):
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(
				(
					center
					+ ((bas * Vector3.RIGHT * radius).rotated(
						bas * Vector3.FORWARD, sppi * ((i - 1) % step)
					))
				)
			)
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(
				(
					center
					+ ((bas * Vector3.RIGHT * radius).rotated(
						bas * Vector3.FORWARD, sppi * (i % step)
					))
				)
			)
		for i in range(1, step + 1):
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(
				(
					center
					+ ((bas * Vector3.FORWARD * radius).rotated(
						bas * Vector3.UP, sppi * ((i - 1) % step)
					))
				)
			)
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(
				(
					center
					+ ((bas * Vector3.FORWARD * radius).rotated(
						bas * Vector3.UP, sppi * (i % step)
					))
				)
			)

	func draw_line(begin_pos: Vector3, end_pos: Vector3, color: Color) -> void:
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(begin_pos)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(end_pos)
