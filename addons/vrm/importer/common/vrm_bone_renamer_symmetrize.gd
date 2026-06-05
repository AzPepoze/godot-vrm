@tool
extends RefCounted

static func symmetrize_vroid_bone_name(name: String) -> String:
	# Matches VRoid bone naming patterns:
	# Optional prefix like J_Bip_ or J_Sec_ or J_Adj_
	# Followed by side indicator _L_, _R_, or _C_
	# Followed by the bone name
	var regex = RegEx.new()
	regex.compile("^J_(?:[A-Za-z0-9]+)_(L|R|C)_(.+)$")
	var match = regex.search(name)
	if match:
		var side = match.get_string(1)
		var base_name = match.get_string(2)
		if side == "L" or side == "R":
			return base_name + "_" + side
		else:
			return base_name
	
	# Fallback if it starts with J_ but doesn't have a side indicator
	var fallback_regex = RegEx.new()
	fallback_regex.compile("^J_(?:[A-Za-z0-9]+)_(.+)$")
	var fallback_match = fallback_regex.search(name)
	if fallback_match:
		return fallback_match.get_string(1)

	return name


static func rename_bones(
	gstate: GLTFState, p_base_scene: Node, p_skeleton: Skeleton3D, p_bone_map: BoneMap
) -> Dictionary:
	var skellen: int = p_skeleton.get_bone_count()

	# 1. Gather all name changes
	var rename_map: Dictionary = {}
	for i in range(skellen):
		var old_name: StringName = p_skeleton.get_bone_name(i)
		var new_name: StringName = StringName(symmetrize_vroid_bone_name(String(old_name)))
		if new_name != old_name:
			rename_map[old_name] = new_name

	# 2. Rename bones on the Skeleton3D
	for i in range(skellen):
		var old_name: StringName = p_skeleton.get_bone_name(i)
		if rename_map.has(old_name):
			p_skeleton.set_bone_name(i, rename_map[old_name])

	# 3. Update GLTFState nodes
	var gnodes = gstate.nodes
	for gnode in gnodes:
		if rename_map.has(gnode.resource_name):
			gnode.resource_name = rename_map[gnode.resource_name]

	# 4. Update Skin binds on ImporterMeshInstance3D nodes
	var nodes: Array[Node] = p_base_scene.find_children("*", "ImporterMeshInstance3D")
	while not nodes.is_empty():
		var mi: ImporterMeshInstance3D = nodes.pop_back() as ImporterMeshInstance3D
		var skin: Skin = mi.skin
		if skin:
			var node = mi.get_node(mi.skeleton_path)
			if node and node is Skeleton3D and node == p_skeleton:
				var bind_count = skin.get_bind_count()
				for i in range(bind_count):
					var bind_bone_name: StringName = skin.get_bind_name(i)
					if bind_bone_name.is_empty():
						if skin.get_bind_bone(i) != -1:
							break
					if rename_map.has(bind_bone_name):
						skin.set_bind_name(i, rename_map[bind_bone_name])

	# 5. Update BoneMap mappings to point to the new bone names
	for old_name in rename_map:
		var profile_bone_name: StringName = p_bone_map.find_profile_bone_name(old_name)
		if profile_bone_name != StringName():
			p_bone_map.set_skeleton_bone_name(profile_bone_name, rename_map[old_name])

	return rename_map
