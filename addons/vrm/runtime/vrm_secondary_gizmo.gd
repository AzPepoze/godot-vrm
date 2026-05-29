@tool
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
