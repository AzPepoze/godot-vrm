extends SceneTree

# Standard GDScript spring bone logic implementation for verification
class GDSpringBoneLogic:
	var bone_idx: int
	var parent_idx: int
	var bone_axis: Vector3
	var length: float
	var current_tail: Vector3
	var prev_tail: Vector3
	var initial_transform: Transform3D
	var global_pose: Transform3D
	var radius: float = 0.0

	func _init(skel: Skeleton3D, idx: int, center_transform_inv: Transform3D, local_child_position: Vector3, default_pose: Transform3D):
		initial_transform = default_pose
		global_pose = default_pose
		bone_idx = idx
		parent_idx = skel.get_bone_parent(idx)
		var world_child_position: Vector3 = (skel.get_bone_global_pose(parent_idx) * skel.get_bone_pose(bone_idx)) * local_child_position
		current_tail = center_transform_inv * world_child_position
		prev_tail = current_tail
		bone_axis = local_child_position.normalized()
		length = local_child_position.length()

	func update(skel: Skeleton3D, center_transform: Transform3D, center_transform_inv: Transform3D, stiffness_force: float, drag_force: float, external: Vector3):
		global_pose = skel.get_bone_global_pose(parent_idx) * skel.get_bone_pose(bone_idx)
		var local_pose_rotation = global_pose.basis.get_rotation_quaternion()
		
		# GDScript Verlet Integration
		var next_tail = current_tail + (current_tail - prev_tail) * (1.0 - drag_force) + center_transform.basis.get_rotation_quaternion() * (local_pose_rotation * bone_axis * stiffness_force + external)
		
		var origin = center_transform * global_pose.origin
		next_tail = origin + (next_tail - origin).normalized() * length
		
		prev_tail = current_tail
		current_tail = next_tail
		
		var ft = GDSpringBoneLogic.from_to_rotation_safe(local_pose_rotation * bone_axis, center_transform_inv.basis * (next_tail - origin))
		if ft != Quaternion():
			var qt = ft * local_pose_rotation
			global_pose.basis = Basis(qt).scaled(global_pose.basis.get_scale())
			skel.set_bone_global_pose(bone_idx, global_pose)

	static func from_to_rotation_safe(from: Vector3, to: Vector3) -> Quaternion:
		var axis = from.cross(to)
		if is_equal_approx(axis.x, 0.0) and is_equal_approx(axis.y, 0.0) and is_equal_approx(axis.z, 0.0):
			return Quaternion.IDENTITY
		var angle = from.angle_to(to)
		if is_equal_approx(angle, 0.0):
			angle = 0.0
		return Quaternion(axis.normalized(), angle)

var last_cpp_rot = Quaternion.IDENTITY
var last_cpp_child_pos = Vector3.ZERO
var bone_idx: int = -1
var local_child_pos: Vector3
var skel_cpp: Skeleton3D

func _on_cpp_modification_processed():
	if bone_idx != -1 and skel_cpp:
		last_cpp_rot = skel_cpp.get_bone_global_pose(bone_idx).basis.get_rotation_quaternion()
		last_cpp_child_pos = skel_cpp.get_bone_global_pose(bone_idx) * local_child_pos

func _initialize():
	print("--- PROGRAMMATIC VERIFICATION START ---")
	
	var vrm_loader = load("res://vrm_samples/Godette_vrm_v4.vrm")
	
	# Model 1: GDScript physics
	var model_gd = vrm_loader.instantiate()
	root.add_child(model_gd)
	
	# Model 2: CPP physics
	var model_cpp = vrm_loader.instantiate()
	root.add_child(model_cpp)
	
	await process_frame
	
	# Skeletons
	var skel_gd = model_gd.get_node("secondary").skel
	skel_cpp = model_cpp.get_node("secondary").skel
	
	# Disable model_gd's C++ simulator so it doesn't run!
	var gd_sim = skel_gd.find_child("VRMSpringBoneSimulator", true, false)
	if gd_sim:
		gd_sim.active = false
		
	# Disable automated process ticks for both secondary nodes
	var sec_gd = model_gd.get_node("secondary")
	sec_gd.set_process(false)
	sec_gd.set_physics_process(false)
	
	var sec_cpp = model_cpp.get_node("secondary")
	sec_cpp.set_process(false)
	sec_cpp.set_physics_process(false)
	
	# Identify bone we want to test: "FrontHair_Center_L"
	var bone_name = "FrontHair_Center_L"
	bone_idx = skel_gd.find_bone(bone_name)
	var child_bone_idx = skel_gd.find_bone("FrontHair_Center_L_End")
	local_child_pos = skel_gd.get_bone_rest(child_bone_idx).origin
	
	# GDScript manual setup
	var gd_logic = preload("res://vrm_spring_bone_logic_old.gd").new(
		skel_gd, bone_idx, Transform3D.IDENTITY, local_child_pos, skel_gd.get_bone_global_pose(bone_idx)
	)
	
	# CPP Simulator from adapter
	var cpp_sim = sec_cpp.spring_bone_adapter.simulator
	if not cpp_sim:
		print("CPP Simulator not found in adapter!")
		quit()
		return
		
	# Connect to the modification_processed signal
	cpp_sim.connect("modification_processed", self._on_cpp_modification_processed)
	
	# Configure identical parameters
	var add_force = Vector3(10.0, 20.0, 30.0)
	var gravity_dir = Vector3(0.0, -1.0, 0.0)
	var gravity_scale = 1.0
	var stiffness_scale = 2.5
	var drag_force_scale = 0.4
	
	print("Starting simulation comparison...")
	
	var parent_idx = skel_gd.get_bone_parent(bone_idx)
	print("DEBUG: parent_idx = ", parent_idx)
	print("DEBUG GD: bone_pose = ", skel_gd.get_bone_pose(bone_idx))
	print("DEBUG CPP: bone_pose = ", skel_cpp.get_bone_pose(bone_idx))
	print("DEBUG GD: parent_global_pose = ", skel_gd.get_bone_global_pose(parent_idx))
	print("DEBUG CPP: parent_global_pose = ", skel_cpp.get_bone_global_pose(parent_idx))

	cpp_sim.active = true
	cpp_sim.update_parameters(1.0, Quaternion.IDENTITY, add_force)

	for step in range(10):
		# 1. Await frame first to let C++ run and get the real delta
		await process_frame
		var frame_delta = sec_cpp.get_process_delta_time() # or get_physics_process_delta_time()
		
		# 2. Update GDScript with the exact same delta
		var ext_gravity = gravity_dir * frame_delta * gravity_scale * 1.0
		var ext_total = ext_gravity + add_force * frame_delta
		gd_logic.update(skel_gd, Transform3D.IDENTITY, Transform3D.IDENTITY, stiffness_scale * frame_delta, drag_force_scale, ext_total, [])
		
		skel_cpp.force_update_all_bone_transforms()
		
		# Compare rotations and child positions
		var rot_gd = skel_gd.get_bone_global_pose(bone_idx).basis.get_rotation_quaternion()
		var child_pos_gd = (skel_gd.get_bone_global_pose(bone_idx) * local_child_pos)
		
		var pos_diff = child_pos_gd.distance_to(last_cpp_child_pos)
		var rot_diff = rot_gd.angle_to(last_cpp_rot)
		
		print("Step %d (delta=%f):" % [step, frame_delta])
		print("  GD:  Rot=%s, ChildPos=%s" % [rot_gd, child_pos_gd])
		print("  CPP: Rot=%s, ChildPos=%s" % [last_cpp_rot, last_cpp_child_pos])
		print("  Diff: Pos=%.8f, Rot=%.8f" % [pos_diff, rot_diff])
		
	quit()
