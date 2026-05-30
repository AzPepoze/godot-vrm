@tool
extends MeshInstance3D

const VRMLogger = preload("../core/logger.gd")

var secondary_node: Node3D
var m: StandardMaterial3D = StandardMaterial3D.new()
var _logged_missing_condition: bool = false


func _init(parent: Node3D) -> void:
	mesh = ImmediateMesh.new()
	secondary_node = parent
	m.no_depth_test = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func draw_in_editor(_do_draw_spring_bones: bool = false) -> void:
	mesh.clear_surfaces()
	if not secondary_node.is_child_of_vrm:
		if not _logged_missing_condition:
			VRMLogger.warning(
				"vrm_secondary_gizmo.gd", "gizmo: parent is not VRM toplevel, no gizmo drawn"
			)
			_logged_missing_condition = true
		return
	if secondary_node.gizmo_spring_bone:
		draw_spring_bones(secondary_node.gizmo_spring_bone_color)
	if secondary_node.gizmo_show_colliders:
		draw_collider_groups()


func draw_in_game() -> void:
	mesh.clear_surfaces()
	if not secondary_node.is_child_of_vrm:
		if not _logged_missing_condition:
			VRMLogger.warning(
				"vrm_secondary_gizmo.gd", "gizmo: parent is not VRM toplevel, no gizmo drawn"
			)
			_logged_missing_condition = true
		return
	if secondary_node.gizmo_spring_bone:
		draw_spring_bones(secondary_node.gizmo_spring_bone_color)
	if secondary_node.gizmo_show_colliders:
		draw_collider_groups()


func _get_bone_global_position(bone_name: String) -> Vector3:
	var skel: Skeleton3D = secondary_node.skel
	if skel == null or bone_name.is_empty():
		return Vector3.ZERO
	var bone_idx: int = skel.find_bone(bone_name)
	if bone_idx == -1:
		return Vector3.ZERO
	return skel.global_transform * skel.get_bone_global_pose(bone_idx).origin


func _get_collider_world_position(collider: Resource, skel: Skeleton3D) -> Vector3:
	return _get_transformed_position(collider, skel, collider.offset)


func _get_transformed_position(collider: Resource, skel: Skeleton3D, local_vec: Vector3) -> Vector3:
	if collider.node_path and not collider.node_path.is_empty():
		var node := secondary_node.get_node_or_null(collider.node_path)
		if node is Node3D:
			return (node as Node3D).global_transform * local_vec
	if not collider.bone.is_empty() and skel != null:
		return (
			skel.global_transform
			* (skel.get_bone_global_pose(skel.find_bone(collider.bone)) * local_vec)
		)
	return local_vec


func draw_spring_bones(color: Color) -> void:
	var skel: Skeleton3D = secondary_node.skel
	if skel == null:
		return
	var spring_bones: Array = secondary_node.spring_bones
	if spring_bones.is_empty():
		return

	set_material_override(m)

	# Joint chain lines
	var has_lines := false
	for sb in spring_bones:
		if sb == null:
			continue
		var joints: PackedStringArray = sb.joint_nodes
		var non_empty := 0
		for j in joints:
			if not j.is_empty():
				non_empty += 1
		if non_empty >= 2:
			has_lines = true
			break
	if has_lines:
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for sb in spring_bones:
			if sb == null:
				continue
			var joints: PackedStringArray = sb.joint_nodes
			if joints.is_empty():
				continue
			var prev_pos: Vector3
			var first: bool = true
			for bone_name in joints:
				if bone_name.is_empty():
					continue
				var pos: Vector3 = secondary_node.to_local(_get_bone_global_position(bone_name))
				if first:
					first = false
				else:
					draw_line(prev_pos, pos, color)
				prev_pos = pos
		mesh.surface_end()

	# Hit-radius spheres (skip if all scales are zero)
	var has_hit_radius := false
	for sb in spring_bones:
		if sb != null and sb.hit_radius_scale > 0.0:
			has_hit_radius = true
			break
	if has_hit_radius:
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for sb in spring_bones:
			if sb == null:
				continue
			var joints: PackedStringArray = sb.joint_nodes
			if joints.is_empty():
				continue
			var hit_radius_scale: float = sb.hit_radius_scale
			if hit_radius_scale <= 0.0:
				continue
			for bone_name in joints:
				if bone_name.is_empty():
					continue
				var pos: Vector3 = secondary_node.to_local(_get_bone_global_position(bone_name))
				draw_sphere(Basis.IDENTITY, pos, hit_radius_scale * 0.05, color)
		mesh.surface_end()

	# Small joint indicator spheres at every joint
	var has_joints := false
	for sb in spring_bones:
		if sb == null:
			continue
		for j in sb.joint_nodes:
			if not j.is_empty():
				has_joints = true
				break
		if has_joints:
			break
	if has_joints:
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for sb in spring_bones:
			if sb == null:
				continue
			var joints: PackedStringArray = sb.joint_nodes
			if joints.is_empty():
				continue
			for bone_name in joints:
				if bone_name.is_empty():
					continue
				var joint_pos: Vector3 = secondary_node.to_local(
					_get_bone_global_position(bone_name)
				)
				draw_sphere(Basis.IDENTITY, joint_pos, 0.015, color)
		mesh.surface_end()


func draw_collider_groups() -> void:
	var skel: Skeleton3D = secondary_node.skel
	var collider_groups: Array = secondary_node.collider_groups
	if collider_groups.is_empty():
		return
	var all_colliders: Array = []
	for cg in collider_groups:
		if cg == null:
			continue
		for c in cg.colliders:
			if c != null:
				all_colliders.append(c)
	if all_colliders.is_empty():
		return
	set_material_override(m)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for collider in all_colliders:
		var pos: Vector3 = secondary_node.to_local(_get_collider_world_position(collider, skel))
		var col: Color = collider.gizmo_color if collider.gizmo_color else Color.MAGENTA
		if collider.is_capsule:
			var tail_pos: Vector3 = secondary_node.to_local(
				_get_transformed_position(collider, skel, collider.tail)
			)
			draw_line(pos, tail_pos, col)
			draw_sphere(Basis.IDENTITY, pos, collider.radius, col)
			draw_sphere(Basis.IDENTITY, tail_pos, collider.radius, col)
		else:
			draw_sphere(Basis.IDENTITY, pos, collider.radius, col)
	mesh.surface_end()


func draw_sphere(bas: Basis, center: Vector3, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	var step: int = 15
	var sppi: float = 2.0 * PI / step
	for i in range(1, step + 1):
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(
			(
				center
				+ ((bas * Vector3.UP * radius).rotated(bas * Vector3.RIGHT, sppi * (i - 1 % step)))
			)
		)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(
			center + ((bas * Vector3.UP * radius).rotated(bas * Vector3.RIGHT, sppi * (i % step)))
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
				+ ((bas * Vector3.RIGHT * radius).rotated(bas * Vector3.FORWARD, sppi * (i % step)))
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
			center + ((bas * Vector3.FORWARD * radius).rotated(bas * Vector3.UP, sppi * (i % step)))
		)


func draw_line(begin_pos: Vector3, end_pos: Vector3, color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(begin_pos)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(end_pos)
