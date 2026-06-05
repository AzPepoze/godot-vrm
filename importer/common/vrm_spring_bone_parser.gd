@tool
extends RefCounted

const VRMLogger = preload("../../core/logger.gd")
const vrm_spring_bone = preload("../../runtime/vrm_spring_bone.gd")
const vrm_collider_group = preload("../../runtime/vrm_collider_group.gd")
const vrm_collider = preload("../../runtime/vrm_collider.gd")


# Detect a human-readable group label from a bone name or VRM comment.
static func detect_group(bone_name: String, comment: String) -> String:
    var name = comment.split("\n")[0].strip_edges() if not comment.is_empty() else bone_name

    for prefix in ["J_Sec_", "J_", "S_J_"]:
        if name.begins_with(prefix):
            name = name.trim_prefix(prefix)
            break

    if (
        name.begins_with("L_")
        or name.begins_with("R_")
        or name.begins_with("l_")
        or name.begins_with("r_")
    ):
        name = name.substr(2)

    if name.ends_with("_end"):
        name = name.trim_suffix("_end")

    if name.ends_with("_L") or name.ends_with("_R") or name.ends_with("_l") or name.ends_with("_r"):
        name = name.substr(0, name.length() - 2)

    var underscore_idx = name.rfind("_")
    if underscore_idx != -1:
        var suffix = name.substr(underscore_idx + 1)
        if suffix.is_valid_int():
            name = name.substr(0, underscore_idx)

    while name.length() > 0:
        var c = name.unicode_at(name.length() - 1)
        if (c >= 48 and c <= 57) or c == 95:  # '0'-'9' or '_'
            name = name.substr(0, name.length() - 1)
        else:
            break

    if name.is_empty() or name.is_valid_int():
        return "Other"
    return name


static func _get_skel_godot_node(gstate: GLTFState, skeletons: Array, skel_id: int) -> Node:
    if skel_id < 0 or skel_id >= skeletons.size():
        return null
    var gltfskel: GLTFSkeleton = skeletons[skel_id]
    if gltfskel.roots.is_empty():
        return null
    var skel_node_idx = gltfskel.roots[0]
    return gstate.get_scene_node(skel_node_idx)


static func create_joints_recursive(
    joint_chains: Array[PackedStringArray], skeleton: Skeleton3D, bone_idx: int, current_chain: int
):
    if current_chain == -1:
        current_chain = len(joint_chains)
        joint_chains.push_back(PackedStringArray())

    joint_chains[current_chain].push_back(skeleton.get_bone_name(bone_idx))

    var bone_children = skeleton.get_bone_children(bone_idx)
    if bone_children.is_empty():
        joint_chains[current_chain].push_back("")
    else:
        for i in range(len(bone_children)):
            var child_bone: int = bone_children[i]
            if i == 0:
                create_joints_recursive(joint_chains, skeleton, child_bone, current_chain)
            else:
                create_joints_recursive(joint_chains, skeleton, child_bone, -1)


static func parse_colliders_v0(
    collider_groups_json: Array,
    gstate: GLTFState,
    pose_diffs: Array[Basis],
    spring_bone_controller: Node,
    offset_flip: Vector3 = Vector3(-1, 1, 1)
) -> Array[VRMColliderGroup]:
    var nodes = gstate.get_nodes()
    var skeletons = gstate.get_skeletons()
    var result: Array[VRMColliderGroup] = []

    for cgroup in collider_groups_json:
        var gltfnode: GLTFNode = nodes[int(cgroup["node"])]
        var collider_group: vrm_collider_group = vrm_collider_group.new()
        var node_path: NodePath
        var bone: String = ""
        var pose_diff: Basis = Basis()

        if gltfnode.skeleton == -1:
            var found_node: Node = gstate.get_scene_node(int(cgroup["node"]))
            node_path = spring_bone_controller.get_path_to(found_node)
        else:
            var skeleton: Skeleton3D = _get_skel_godot_node(gstate, skeletons, gltfnode.skeleton)
            bone = nodes[int(cgroup["node"])].resource_name
            pose_diff = pose_diffs[skeleton.find_bone(bone)]

        for collider_info in cgroup["colliders"]:
            var collider: vrm_collider = vrm_collider.new()
            collider.node_path = node_path
            collider.bone = bone
            collider.resource_name = (
                bone if not bone.is_empty() else gstate.get_scene_node(int(cgroup["node"])).name
            )

            var offset_obj = collider_info.get("offset", {"x": 0.0, "y": 0.0, "z": 0.0})
            var offset_vec = (
                offset_flip * Vector3(offset_obj["x"], offset_obj["y"], offset_obj["z"])
            )
            var local_pos: Vector3 = pose_diff * offset_vec

            collider.is_capsule = false
            collider.offset = local_pos
            collider.tail = local_pos
            collider.radius = collider_info.get("radius", 0.0)
            collider_group.colliders.append(collider)
        result.append(collider_group)
    return result


static func parse_colliders_v1(
    colliders_json: Array, gstate: GLTFState, spring_bone_controller: Node
) -> Array[VRMCollider]:
    var nodes = gstate.get_nodes()
    var skeletons = gstate.get_skeletons()
    var result: Array[VRMCollider] = []

    for collider_json in colliders_json:
        var gltfnode: GLTFNode = nodes[int(collider_json["node"])]
        var collider: vrm_collider = vrm_collider.new()
        var node_path: NodePath
        var bone: String = ""
        var pose_diff: Basis = Basis()

        if gltfnode.skeleton == -1:
            var found_node: Node = gstate.get_scene_node(int(collider_json["node"]))
            node_path = spring_bone_controller.get_path_to(found_node)
        else:
            var skeleton: Skeleton3D = _get_skel_godot_node(gstate, skeletons, gltfnode.skeleton)
            bone = nodes[int(collider_json["node"])].resource_name
            if skeleton != null:
                var pose_diffs = skeleton.get_meta("vrm_pose_diffs", [])
                if not pose_diffs.is_empty():
                    pose_diff = pose_diffs[skeleton.find_bone(bone)]

        collider.node_path = node_path
        collider.bone = bone
        collider.resource_name = (
            bone if not bone.is_empty() else gstate.get_scene_node(int(collider_json["node"])).name
        )

        var shape = collider_json.get("shape", {})
        if shape.has("sphere"):
            var offset_obj = shape["sphere"].get("offset", [0.0, 0.0, 0.0])
            var offset_vec = Vector3(offset_obj[0], offset_obj[1], offset_obj[2])
            collider.offset = pose_diff * offset_vec
            collider.tail = collider.offset
            collider.radius = shape["sphere"].get("radius", 0.0)
            collider.is_capsule = false
        elif shape.has("capsule"):
            var offset_obj = shape["capsule"].get("offset", [0.0, 0.0, 0.0])
            var offset_vec = Vector3(offset_obj[0], offset_obj[1], offset_obj[2])
            collider.offset = pose_diff * offset_vec
            var tail_obj = shape["capsule"].get("tail", [0.0, 0.0, 0.0])
            collider.tail = pose_diff * Vector3(tail_obj[0], tail_obj[1], tail_obj[2])
            collider.radius = shape["capsule"].get("radius", 0.0)
            collider.is_capsule = true
        result.append(collider)
    return result


static func parse_springs_v0(
    bone_groups_json: Array,
    gstate: GLTFState,
    collider_groups: Array[VRMColliderGroup],
    spring_bone_controller: Node
) -> Array[VRMSpringBone]:
    var nodes = gstate.get_nodes()
    var skeletons = gstate.get_skeletons()
    var result: Array[VRMSpringBone] = []

    for sbone in bone_groups_json:
        if sbone.get("bones", []).size() == 0:
            continue
        var first_bone_node: int = sbone["bones"][0]
        var gltfnode: GLTFNode = nodes[int(first_bone_node)]
        var skeleton: Skeleton3D = _get_skel_godot_node(gstate, skeletons, gltfnode.skeleton)

        var comment: String = sbone.get("comment", "")
        var stiffness_force = float(sbone.get("stiffiness", 1.0))
        var gravity_power = float(sbone.get("gravityPower", 0.0))
        var gravity_dir_json = sbone.get("gravityDir", {"x": 0.0, "y": -1.0, "z": 0.0})
        var gravity_dir = Vector3(
            gravity_dir_json["x"], gravity_dir_json["y"], gravity_dir_json["z"]
        )
        var drag_force = float(sbone.get("dragForce", 0.4))
        var hit_radius = float(sbone.get("hitRadius", 0.02))

        var spring_collider_groups: Array[VRMColliderGroup] = []
        for cgroup_idx in sbone.get("colliderGroups", []):
            spring_collider_groups.append(collider_groups[int(cgroup_idx)])

        var joint_chains: Array[PackedStringArray] = []
        for bone_node in sbone["bones"]:
            create_joints_recursive(
                joint_chains, skeleton, skeleton.find_bone(nodes[int(bone_node)].resource_name), -1
            )

        var center_node: NodePath = NodePath()
        var center_bone: String = ""
        var center_node_idx = sbone.get("center", -1)
        if center_node_idx != null and center_node_idx != -1:
            var center_gltfnode: GLTFNode = nodes[int(center_node_idx)]
            var bone_name: String = center_gltfnode.resource_name
            if (
                center_gltfnode.skeleton == gltfnode.skeleton
                and skeleton.find_bone(bone_name) != -1
            ):
                center_bone = bone_name
            else:
                var found_node: Node = gstate.get_scene_node(int(center_node_idx))
                center_node = spring_bone_controller.get_path_to(found_node)
                if center_node == NodePath():
                    center_node = spring_bone_controller.get_path_to(spring_bone_controller)

        for chain in joint_chains:
            var spring_bone: vrm_spring_bone = vrm_spring_bone.new()
            spring_bone.comment = comment
            spring_bone.center_bone = center_bone
            spring_bone.center_node = center_node
            spring_bone.collider_groups = spring_collider_groups
            for bone_name in chain:
                spring_bone.joint_nodes.push_back(bone_name)
            spring_bone.stiffness_scale = stiffness_force
            spring_bone.gravity_scale = gravity_power
            spring_bone.gravity_dir_default = gravity_dir
            spring_bone.drag_force_scale = drag_force
            spring_bone.hit_radius_scale = hit_radius
            spring_bone.resource_name = (
                "%s · %s" % [comment.split("\n")[0], chain[0]]
                if not comment.is_empty()
                else chain[0]
            )
            spring_bone.group = detect_group(chain[0], comment)
            result.append(spring_bone)
    return result


static func parse_springs_v1(
    springs_json: Array,
    gstate: GLTFState,
    collider_groups: Array[VRMColliderGroup],
    spring_bone_controller: Node
) -> Array[VRMSpringBone]:
    var nodes = gstate.get_nodes()
    var skeletons = gstate.get_skeletons()
    var result: Array[VRMSpringBone] = []

    for sbone in springs_json:
        var comment: String = sbone.get("name", "")
        var spring_bone: vrm_spring_bone = vrm_spring_bone.new()
        spring_bone.comment = comment

        var spring_collider_groups: Array[VRMColliderGroup] = []
        for cgroup_idx in sbone.get("colliderGroups", []):
            spring_collider_groups.append(collider_groups[int(cgroup_idx)])
        spring_bone.collider_groups = spring_collider_groups

        var first_bone_node = -1
        for joint_json in sbone.get("joints", []):
            var bone_node = int(joint_json["node"])
            if first_bone_node == -1:
                first_bone_node = bone_node
            var gltfnode: GLTFNode = nodes[bone_node]
            var bone_name: String = gltfnode.resource_name
            var skeleton: Skeleton3D = _get_skel_godot_node(gstate, skeletons, gltfnode.skeleton)
            if skeleton == null:
                continue

            spring_bone.joint_nodes.append(bone_name)
            spring_bone.stiffness_force.append(float(joint_json.get("stiffness", 1.0)))
            spring_bone.gravity_power.append(float(joint_json.get("gravityPower", 0.0)))
            var gdir_json = joint_json.get("gravityDir", [0.0, -1.0, 0.0])
            spring_bone.gravity_dir.append(Vector3(gdir_json[0], gdir_json[1], gdir_json[2]))
            spring_bone.drag_force.append(float(joint_json.get("dragForce", 0.5)))
            spring_bone.hit_radius.append(float(joint_json.get("hitRadius", 0.0)))

        if spring_bone.joint_nodes.is_empty():
            continue

        # Process per-joint parameters (v1 spec)
        _process_v1_joint_parameters(spring_bone)

        var center_node_idx = sbone.get("center", -1)
        if center_node_idx != null and center_node_idx != -1:
            var center_gltfnode: GLTFNode = nodes[int(center_node_idx)]
            var bone_name: String = center_gltfnode.resource_name
            var skeleton: Skeleton3D = _get_skel_godot_node(
                gstate, skeletons, nodes[int(first_bone_node)].skeleton
            )
            if (
                skeleton != null
                and center_gltfnode.skeleton == nodes[int(first_bone_node)].skeleton
                and skeleton.find_bone(bone_name) != -1
            ):
                spring_bone.center_bone = bone_name
            else:
                var found_node: Node = gstate.get_scene_node(int(center_node_idx))
                spring_bone.center_node = spring_bone_controller.get_path_to(found_node)
                if spring_bone.center_node == NodePath():
                    spring_bone.center_node = spring_bone_controller.get_path_to(
                        spring_bone_controller
                    )

        spring_bone.resource_name = (
            "%s · %s" % [comment.split("\n")[0], spring_bone.joint_nodes[0]]
            if not comment.is_empty()
            else spring_bone.joint_nodes[0]
        )
        spring_bone.group = detect_group(spring_bone.joint_nodes[0], comment)
        result.append(spring_bone)
    return result


static func _process_v1_joint_parameters(spring_bone: vrm_spring_bone) -> void:
    if not spring_bone.stiffness_force.is_empty():
        spring_bone.stiffness_scale = spring_bone.stiffness_force[0]
        if (
            spring_bone.stiffness_force.count(spring_bone.stiffness_scale)
            == spring_bone.stiffness_force.size()
        ):
            spring_bone.stiffness_force.clear()
        elif spring_bone.stiffness_scale > 0.0:
            for i in range(spring_bone.stiffness_force.size()):
                spring_bone.stiffness_force[i] /= spring_bone.stiffness_scale
        else:
            spring_bone.stiffness_scale = 1.0

    if not spring_bone.gravity_power.is_empty():
        spring_bone.gravity_scale = spring_bone.gravity_power[0]
        if (
            spring_bone.gravity_power.count(spring_bone.gravity_scale)
            == spring_bone.gravity_power.size()
        ):
            spring_bone.gravity_power.clear()
        elif spring_bone.gravity_scale > 0.0:
            for i in range(spring_bone.gravity_power.size()):
                spring_bone.gravity_power[i] /= spring_bone.gravity_scale
        else:
            spring_bone.gravity_scale = 1.0

    if not spring_bone.drag_force.is_empty():
        spring_bone.drag_force_scale = spring_bone.drag_force[0]
        if (
            spring_bone.drag_force.count(spring_bone.drag_force_scale)
            == spring_bone.drag_force.size()
        ):
            spring_bone.drag_force.clear()
        elif spring_bone.drag_force_scale > 0.0:
            for i in range(spring_bone.drag_force.size()):
                spring_bone.drag_force[i] /= spring_bone.drag_force_scale
        else:
            spring_bone.drag_force_scale = 1.0

    if not spring_bone.hit_radius.is_empty():
        spring_bone.hit_radius_scale = spring_bone.hit_radius[0]
        if (
            spring_bone.hit_radius.count(spring_bone.hit_radius_scale)
            == spring_bone.hit_radius.size()
        ):
            spring_bone.hit_radius.clear()
        elif spring_bone.hit_radius_scale > 0.0:
            for i in range(spring_bone.hit_radius.size()):
                spring_bone.hit_radius[i] /= spring_bone.hit_radius_scale
        else:
            spring_bone.hit_radius_scale = 1.0

    if not spring_bone.gravity_dir.is_empty():
        spring_bone.gravity_dir_default = spring_bone.gravity_dir[0]
        if (
            spring_bone.gravity_dir.count(spring_bone.gravity_dir_default)
            == spring_bone.gravity_dir.size()
        ):
            spring_bone.gravity_dir.clear()
