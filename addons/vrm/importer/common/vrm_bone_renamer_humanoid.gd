@tool
extends RefCounted

const vrm_to_human_bone: Dictionary = {
    "hips": "Hips",
    "spine": "Spine",
    "chest": "Chest",
    "upperChest": "UpperChest",
    "neck": "Neck",
    "head": "Head",
    "leftEye": "LeftEye",
    "rightEye": "RightEye",
    "jaw": "Jaw",
    "leftShoulder": "LeftShoulder",
    "leftUpperArm": "LeftUpperArm",
    "leftLowerArm": "LeftLowerArm",
    "leftHand": "LeftHand",
    "leftThumbMetacarpal": "LeftThumbMetacarpal",
    "leftThumbProximal": "LeftThumbProximal",
    "leftThumbDistal": "LeftThumbDistal",
    "leftIndexProximal": "LeftIndexProximal",
    "leftIndexIntermediate": "LeftIndexIntermediate",
    "leftIndexDistal": "LeftIndexDistal",
    "leftMiddleProximal": "LeftMiddleProximal",
    "leftMiddleIntermediate": "LeftMiddleIntermediate",
    "leftMiddleDistal": "LeftMiddleDistal",
    "leftRingProximal": "LeftRingProximal",
    "leftRingIntermediate": "LeftRingIntermediate",
    "leftRingDistal": "LeftRingDistal",
    "leftLittleProximal": "LeftLittleProximal",
    "leftLittleIntermediate": "LeftLittleIntermediate",
    "leftLittleDistal": "LeftLittleDistal",
    "rightShoulder": "RightShoulder",
    "rightUpperArm": "RightUpperArm",
    "rightLowerArm": "RightLowerArm",
    "rightHand": "RightHand",
    "rightThumbMetacarpal": "RightThumbMetacarpal",
    "rightThumbProximal": "RightThumbProximal",
    "rightThumbDistal": "RightThumbDistal",
    "rightIndexProximal": "RightIndexProximal",
    "rightIndexIntermediate": "RightIndexIntermediate",
    "rightIndexDistal": "RightIndexDistal",
    "rightMiddleProximal": "RightMiddleProximal",
    "rightMiddleIntermediate": "RightMiddleIntermediate",
    "rightMiddleDistal": "RightMiddleDistal",
    "rightRingProximal": "RightRingProximal",
    "rightRingIntermediate": "RightRingIntermediate",
    "rightRingDistal": "RightRingDistal",
    "rightLittleProximal": "RightLittleProximal",
    "rightLittleIntermediate": "RightLittleIntermediate",
    "rightLittleDistal": "RightLittleDistal",
    "leftUpperLeg": "LeftUpperLeg",
    "leftLowerLeg": "LeftLowerLeg",
    "leftFoot": "LeftFoot",
    "leftToes": "LeftToes",
    "rightUpperLeg": "RightUpperLeg",
    "rightLowerLeg": "RightLowerLeg",
    "rightFoot": "RightFoot",
    "rightToes": "RightToes",
}


static func get_vrm_to_human_bone(is_vrm_0: bool) -> Dictionary:
    if is_vrm_0:
        var vrm0_to_human_bone = vrm_to_human_bone.duplicate()
        vrm0_to_human_bone["leftThumbIntermediate"] = "LeftThumbProximal"
        vrm0_to_human_bone["leftThumbProximal"] = "LeftThumbMetacarpal"
        vrm0_to_human_bone["rightThumbIntermediate"] = "RightThumbProximal"
        vrm0_to_human_bone["rightThumbProximal"] = "RightThumbMetacarpal"
        return vrm0_to_human_bone
    return vrm_to_human_bone


static func create_humanoid_bone_map(
    gstate: GLTFState, human_bone_to_idx: Dictionary, is_vrm_0: bool
) -> BoneMap:
    var humanBones: BoneMap = BoneMap.new()
    humanBones.profile = SkeletonProfileHumanoid.new()

    var gltfnodes: Array = gstate.nodes
    var map = get_vrm_to_human_bone(is_vrm_0)

    for vrm_bone_name in human_bone_to_idx:
        if map.has(vrm_bone_name):
            var node_idx = human_bone_to_idx[vrm_bone_name]
            if node_idx >= 0 and node_idx < gltfnodes.size():
                humanBones.set_skeleton_bone_name(
                    map[vrm_bone_name], gltfnodes[node_idx].resource_name
                )
    return humanBones


static func rename_bones(
    gstate: GLTFState, p_base_scene: Node, p_skeleton: Skeleton3D, p_bone_map: BoneMap
) -> Dictionary:
    var skellen: int = p_skeleton.get_bone_count()

    # 1. Gather all bone name changes based on the BoneMap
    var rename_map: Dictionary = {}
    for i in range(skellen):
        var old_name: StringName = p_skeleton.get_bone_name(i)
        var bn: StringName = p_bone_map.find_profile_bone_name(old_name)
        if bn != StringName():
            rename_map[old_name] = bn

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
        var bn: StringName = rename_map[old_name]
        p_bone_map.set_skeleton_bone_name(bn, bn)

    return rename_map
