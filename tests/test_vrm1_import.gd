extends "res://tests/test_base.gd"

# End-to-end VRM 1.0 integration tests using AvatarSample_M.vrm.
# Registers all 6 V1 GLTF extensions (matching plugin.gd) and imports the VRM file,
# then verifies the resulting scene tree, skeleton, meta, animations, spring bones,
# collider groups, materials, and secondary node ownership.

# Preload all V1 extension classes (matching plugin.gd registration order)
const VRMC_NODE_CONSTRAINT = preload("res://addons/vrm/importer/v1/vrmc/vrmc_node_constraint.gd")
const VRMC_SPRING_BONE = preload("res://addons/vrm/importer/v1/vrmc/vrmc_spring_bone.gd")
const VRMC_MTOON = preload("res://addons/vrm/importer/v1/vrmc/vrmc_materials_mtoon.gd")
const VRMC_HDR_EMISSIVE = preload(
	"res://addons/vrm/importer/v1/vrmc/vrmc_materials_hdr_emissive_multiplier.gd"
)
const VRMC_VRM = preload("res://addons/vrm/importer/v1/vrmc/vrmc_vrm.gd")
const VRMC_VRM_ANIMATION = preload("res://addons/vrm/importer/v1/vrmc/vrmc_vrm_animation.gd")

const VRM_FILE := "res://vrm_samples/AvatarSample_M.vrm"

# Cached import results — imported once, shared across all test methods
var _scene_root: Node = null
var _gltf: GLTFDocument = null
var _skeleton: Skeleton3D = null
var _anim_player: AnimationPlayer = null
var _secondary: Node = null
var _import_error: Error = OK
var _extensions := []


func before_each():
	if _scene_root != null:
		return

	_gltf = GLTFDocument.new()
	_extensions = [
		VRMC_NODE_CONSTRAINT.new(),
		VRMC_SPRING_BONE.new(),
		VRMC_MTOON.new(),
		VRMC_HDR_EMISSIVE.new(),
		VRMC_VRM.new(),
		VRMC_VRM_ANIMATION.new(),
	]

	for ext in _extensions:
		GLTFDocument.register_gltf_document_extension(ext, true)

	var state := GLTFState.new()
	# Pre-seed additional_data keys to avoid Godot 4.6 Dictionary::operator[] bug
	# in vrm_head_hiding.gd when keys are absent (same as import_vrm.gd does).
	const VRMConstants = preload("res://addons/vrm/core/vrm_constants.gd")
	state.set_additional_data(
		&"vrm/head_hiding_method", VRMConstants.HeadHidingSetting.ThirdPersonOnly
	)
	state.set_additional_data(&"vrm/first_person_layers", 2)
	state.set_additional_data(&"vrm/third_person_layers", 4)
	state.set_additional_data(&"vrm/remove_end_bones", true)
	_import_error = _gltf.append_from_file(VRM_FILE, state, 8)

	if _import_error == OK:
		_scene_root = _gltf.generate_scene(state)
		if _scene_root:
			runner.root.add_child(_scene_root)
			await runner.wait_frame

			_skeleton = _find_skeleton(_scene_root)
			_anim_player = _find_animation_player(_scene_root)
			_secondary = _scene_root.get_node_or_null("secondary")


func _find_skeleton(root: Node) -> Skeleton3D:
	var children := root.find_children("*", "Skeleton3D", true, false)
	if children.size() > 0:
		return children[0]
	return null


func _find_animation_player(root: Node) -> AnimationPlayer:
	return root.get_node_or_null("AnimationPlayer")


# ── Import success ───────────────────────────────────────────────────────────


func test_vrm1_import_succeeds():
	assert_eq(_import_error, OK, "VRM 1.0 import (append_from_file) must not error")


func test_vrm1_scene_generated():
	assert_not_null(_scene_root, "generate_scene must return a non-null root node")


# ── Skeleton ─────────────────────────────────────────────────────────────────


func test_vrm1_scene_has_skeleton():
	assert_not_null(_skeleton, "Scene must contain a Skeleton3D")
	if _skeleton:
		assert_ge(
			_skeleton.get_bone_count(),
			50,
			"Must have 50+ bones, got %d" % _skeleton.get_bone_count()
		)
		assert_ge(_skeleton.find_bone("Hips"), 0, "Hips bone must exist")
		assert_ge(_skeleton.find_bone("Head"), 0, "Head bone must exist")


# ── Root node ────────────────────────────────────────────────────────────────


func test_vrm1_scene_root_is_vrm_toplevel():
	assert_not_null(_scene_root, "Scene root must exist")
	if _scene_root:
		var meta = _scene_root.get("vrm_meta")
		assert_not_null(meta, "Root node must have vrm_meta property set")


# ── Meta ─────────────────────────────────────────────────────────────────────


func test_vrm1_meta_fields():
	var meta = _scene_root.get("vrm_meta")
	assert_not_null(meta, "vrm_meta must be set on root")
	if not meta:
		return
	assert_true(meta.title is String, "title must be a String")
	assert_false(meta.title.is_empty(), "title must be non-empty")
	assert_ge(meta.authors.size(), 1, "Must have at least 1 author, got %d" % meta.authors.size())
	assert_eq(meta.spec_version, "1.0", "spec_version must be '1.0', got '%s'" % meta.spec_version)
	assert_not_null(meta.humanoid_bone_mapping, "humanoid_bone_mapping (BoneMap) must be set")


# ── AnimationPlayer ──────────────────────────────────────────────────────────


func test_vrm1_animation_player_exists():
	assert_not_null(_anim_player, "AnimationPlayer must exist in scene root")
	if _anim_player:
		var anim_list: PackedStringArray = _anim_player.get_animation_list()
		assert_gt(anim_list.size(), 0, "Must have at least 1 animation, got %d" % anim_list.size())


func test_vrm1_animation_has_reset():
	if not _anim_player:
		return
	assert_true(_anim_player.has_animation(&"RESET"), "AnimationPlayer must have RESET animation")


func test_vrm1_animation_preset_names():
	if not _anim_player:
		return
	var anim_list: PackedStringArray = _anim_player.get_animation_list()
	# At least one expression preset must be present
	var expected_presets := ["blink", "happy", "sad", "aa", "neutral"]
	var found_presets := []
	for preset in expected_presets:
		if anim_list.has(preset):
			found_presets.append(preset)
	assert_true(
		found_presets.size() > 0,
		(
			"Expected at least one expression preset (%s), found: %s"
			% [str(expected_presets), str(found_presets)]
		)
	)


# ── Secondary / spring bones ─────────────────────────────────────────────────


func test_vrm1_secondary_node_exists():
	assert_not_null(_secondary, "secondary node must exist in scene root")


func test_vrm1_secondary_node_has_owner():
	if not _secondary:
		return
	# Bug 3: secondary.owner must not be null
	assert_not_null(_secondary.owner, "secondary.owner MUST NOT be null (Bug 3 regression)")


func test_vrm1_secondary_has_spring_bones():
	if not _secondary:
		return
	var spring_bones_raw = _secondary.get("spring_bones")
	assert_not_null(spring_bones_raw, "spring_bones property must exist on secondary")
	if spring_bones_raw == null:
		return
	# spring_bones should be an Array
	var spring_bones: Array = spring_bones_raw
	assert_gt(
		spring_bones.size(), 0, "Must have at least 1 spring bone, got %d" % spring_bones.size()
	)
	if spring_bones.size() > 0:
		var sb = spring_bones[0]
		assert_not_null(sb, "First spring bone must not be null")
		if sb:
			assert_gt(sb.joint_nodes.size(), 0, "Spring bone must have at least 1 joint node")


func test_vrm1_spring_bone_group_assigned():
	if not _secondary:
		return
	var spring_bones: Array = _secondary.get("spring_bones")
	if spring_bones.is_empty():
		return
	for i in spring_bones.size():
		var sb = spring_bones[i]
		assert_not_null(sb, "Spring bone %d must not be null" % i)
		if sb == null:
			continue
		assert_false(
			sb.group.is_empty(),
			"Spring bone %d (%s) must have non-empty group, got ''" % [i, sb.resource_name]
		)


func test_vrm1_spring_bone_resource_name_readable():
	if not _secondary:
		return
	var spring_bones: Array = _secondary.get("spring_bones")
	if spring_bones.is_empty():
		return
	# If comment is set, resource_name should contain both group and bone name
	for i in spring_bones.size():
		var sb = spring_bones[i]
		if sb == null or sb.comment.is_empty():
			continue
		assert_true(
			sb.resource_name.contains(sb.comment),
			(
				"Spring bone %d resource_name '%s' should contain comment '%s'"
				% [i, sb.resource_name, sb.comment]
			)
		)
		# Should show the bone name too (not just the comment alone)
		assert_true(
			sb.resource_name.length() > sb.comment.length(),
			(
				"Spring bone %d resource_name '%s' should be more than just comment '%s'"
				% [i, sb.resource_name, sb.comment]
			)
		)


func test_vrm1_spring_bones_sorted_by_group():
	if not _secondary:
		return
	var spring_bones: Array = _secondary.get("spring_bones")
	if spring_bones.size() < 2:
		return
	for i in spring_bones.size() - 1:
		var a = spring_bones[i]
		var b = spring_bones[i + 1]
		if a == null or b == null:
			continue
		assert_ge(
			str(b.group),
			str(a.group),
			(
				"Spring bones must be sorted by group. Index %d ('%s') > index %d ('%s')"
				% [i, a.group, i + 1, b.group]
			)
		)


func test_vrm1_spring_bone_report():
	"""Print spring bone count and group breakdown for inspection."""
	if not _secondary:
		return
	var spring_bones: Array = _secondary.get("spring_bones")
	if spring_bones.is_empty():
		return
	var groups := {}
	for sb in spring_bones:
		if sb == null:
			continue
		groups[sb.group] = groups.get(sb.group, 0) + 1
	var report := "Spring bone count: %d\nGroup breakdown:" % spring_bones.size()
	for g in groups.keys():
		report += "\n  %s: %d" % [g, groups[g]]
	# Print to stdout for inspection
	print(report)
	# Sanity check: shouldn't be absurdly many chains (e.g., not 500+)
	assert_lt(
		spring_bones.size(), 300, "Spring bone count %d seems excessive" % spring_bones.size()
	)


func test_vrm1_secondary_has_skeleton_path():
	if not _secondary:
		return
	var skeleton_path = _secondary.get("skeleton")
	assert_not_null(skeleton_path, "secondary.skeleton must be set")
	if skeleton_path == null:
		return
	# Bug 1: skeleton path must resolve to a valid node
	var resolved = _secondary.get_node_or_null(skeleton_path)
	assert_not_null(
		resolved, "secondary.skeleton path must resolve to a valid Skeleton3D (Bug 1 regression)"
	)


func test_vrm1_collider_groups_are_groups_not_flat_colliders():
	if not _secondary:
		return
	var collider_groups_raw = _secondary.get("collider_groups")
	assert_not_null(collider_groups_raw, "collider_groups property must exist on secondary")
	if collider_groups_raw == null:
		return
	var collider_groups: Array = collider_groups_raw
	if collider_groups.size() == 0:
		# No collider groups present — not an error, just skip detailed checks
		print("  [INFO] VRM 1.0 file has no collider groups (springs without colliders)")
		return

	# Bug 2: Each collider group should contain VRMCollider objects (not empty)
	for i in range(collider_groups.size()):
		var cg = collider_groups[i]
		assert_not_null(cg, "Collider group %d must not be null" % i)
		if cg:
			var colliders_in_group = cg.get("colliders")
			assert_not_null(colliders_in_group, "Collider group %d must have 'colliders' Array" % i)
			if colliders_in_group != null:
				var colliders_arr: Array = colliders_in_group
				# Each collider in the group should be a valid object with shape info
				for j in range(colliders_arr.size()):
					var col = colliders_arr[j]
					assert_not_null(col, "Collider group %d collider %d must not be null" % [i, j])
					if col:
						assert_ge(
							col.radius, 0.0, "Collider radius must be >= 0, got %f" % col.radius
						)


# ── Meshes & materials ───────────────────────────────────────────────────────


func test_vrm1_meshes_have_materials():
	if not _scene_root:
		return
	var mesh_instances := _scene_root.find_children("*", "MeshInstance3D")
	assert_gt(mesh_instances.size(), 0, "Must have at least one MeshInstance3D")
	for mesh_inst in mesh_instances:
		var mesh: Mesh = mesh_inst.mesh
		assert_not_null(mesh, "MeshInstance3D '%s' must have a mesh" % mesh_inst.name)
		if mesh:
			assert_ge(
				mesh.get_surface_count(),
				1,
				"Mesh '%s' must have at least 1 surface" % mesh_inst.name
			)

			for surf_idx in range(mesh.get_surface_count()):
				var mat = mesh_inst.get_surface_override_material(surf_idx)
				if mat == null:
					mat = mesh.surface_get_material(surf_idx)
				assert_not_null(
					mat, "Mesh '%s' surface %d must have a material" % [mesh_inst.name, surf_idx]
				)


# ── End bone cleanup ─────────────────────────────────────────────────────────


func test_vrm1_end_bone_nodes_removed():
	"""Verify that end-bone Node3D markers are cleaned from the skeleton."""
	if not _skeleton:
		return

	# These are known end-bone patterns in AvatarSample_M.vrm that should be removed.
	# Presence is checked by name pattern (suffix _end or containing _end_).
	var end_bone_nodes := []
	for child in _skeleton.get_children():
		if child.name.contains("_end"):
			end_bone_nodes.append(child)

	assert_eq(
		end_bone_nodes.size(),
		0,
		(
			"Skeleton should have zero children named '*_end*' after cleanup, "
			+"but found %d: %s" % [end_bone_nodes.size(), str(end_bone_nodes)]
		)
	)


func test_vrm1_end_bone_removal_keeps_skeleton_bones():
	"""Skeleton bone count should still be 50+ after end-bone cleanup."""
	if not _skeleton:
		return
	assert_ge(
		_skeleton.get_bone_count(),
		50,
		"Skeleton must retain 50+ bones after cleanup, got %d" % _skeleton.get_bone_count()
	)
