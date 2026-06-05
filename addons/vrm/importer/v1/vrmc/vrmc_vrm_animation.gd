extends GLTFDocumentExtension

const vrm_animation_import = preload("../vrm_animation_import.gd")
const vrm_utils = preload("../../common/vrm_utils.gd")

var vrm_animation_data: Dictionary = {}


func _import_preflight(_state: GLTFState, extensions: PackedStringArray) -> Error:
    if not extensions.has("VRMC_vrm_animation"):
        return ERR_SKIP
    return OK


func _import_node(_state: GLTFState, gltf_node: GLTFNode, json: Dictionary, _node: Node) -> Error:
    if json.get("extensions", {}).has("VRMC_vrm_animation"):
        vrm_animation_data[gltf_node.index] = json["extensions"]["VRMC_vrm_animation"]
    return OK


func _import_post_parse(gstate: GLTFState) -> Error:
    if vrm_animation_data.is_empty():
        return OK

    # Find the VRMC_vrm extension data to get human bone mapping
    var vrm_extension_data: Dictionary = {}
    for ext in gstate.json.get("extensions", {}).keys():
        if ext == "VRMC_vrm":
            vrm_extension_data = gstate.json["extensions"]["VRMC_vrm"]
            break

    if vrm_extension_data.is_empty():
        return OK

    # Get human bone mapping
    var humanoid: Dictionary = vrm_extension_data.get("humanoid", {})
    var human_bones: Dictionary = humanoid.get("humanBones", {})
    var human_bone_to_idx: Dictionary = {}

    var nodes: Array = gstate.get_nodes()
    var skeletons: Array = gstate.get_skeletons()

    for bone_name in human_bones.keys():
        var bone_data: Dictionary = human_bones[bone_name]
        var node_index: int = bone_data.get("node", -1)
        if node_index >= 0 and node_index < nodes.size():
            var gltf_node: GLTFNode = nodes[node_index]
            if gltf_node.skeleton >= 0 and gltf_node.skeleton < skeletons.size():
                var gltf_skel: GLTFSkeleton = skeletons[gltf_node.skeleton]
                if not gltf_skel.roots.is_empty():
                    var skeleton_node: Skeleton3D = gstate.get_scene_node(gltf_skel.roots[0])
                    var bone_idx: int = skeleton_node.find_bone(gltf_node.resource_name)
                    if bone_idx >= 0:
                        human_bone_to_idx[bone_name] = bone_idx

    if human_bone_to_idx.is_empty():
        return OK

    # Get skeleton for pose diffs
    var skeleton: Skeleton3D = null
    var pose_diffs: Array[Basis] = []

    if not human_bone_to_idx.is_empty():
        var first_bone_idx: int = human_bone_to_idx.values()[0]
        for gltf_node in nodes:
            if gltf_node.skeleton >= 0:
                var gltf_skel: GLTFSkeleton = skeletons[gltf_node.skeleton]
                if not gltf_skel.roots.is_empty():
                    skeleton = gstate.get_scene_node(gltf_skel.roots[0])
                    # Generate pose diffs for retargeting
                    var bone_map: BoneMap = BoneMap.new()
                    bone_map.profile = SkeletonProfileHumanoid.new()
                    pose_diffs = vrm_utils.perform_retarget(
                        gstate, gstate.get_scene_node(gltf_skel.roots[0]), skeleton, bone_map
                    )
                    break

    # Setup animation player
    var root_node: Node = gstate.get_scene_node(0)
    var animplayer: AnimationPlayer = root_node.get_node_or_null("*AnimationPlayer")
    if animplayer == null:
        animplayer = AnimationPlayer.new()
        animplayer.name = "AnimationPlayer"
        root_node.add_child(animplayer)
        animplayer.owner = root_node

    # Create animations from VRMC_vrm_animation data
    var firstperson: Dictionary = vrm_extension_data.get("firstPerson", {})
    var lookAt: Dictionary = vrm_extension_data.get("lookAt", {})

    for node_index in vrm_animation_data.keys():
        var node_anim_data: Dictionary = vrm_animation_data[node_index]
        var anim_name: String = node_anim_data.get("name", "")

        # Create animation using the import module
        var default_values: Dictionary = {}
        var default_blend_shapes: Dictionary = {}
        var mesh_idx_to_meshinstance: Dictionary = (
            vrm_utils.generate_mesh_index_to_meshinstance_mapping(gstate)
        )
        var material_idx_to_mesh_and_surface_idx: Dictionary = {}
        var meshes: Array = gstate.get_meshes()

        for i in range(meshes.size()):
            var gltfmesh: GLTFMesh = meshes[i]
            for j in range(gltfmesh.mesh.get_surface_count()):
                material_idx_to_mesh_and_surface_idx[gltfmesh.mesh.get_surface_material(j).resource_name] = [
                    i, j
                ]

        var node_to_head_hidden_node: Dictionary = {}

        var anim: Animation = vrm_animation_import.create_animation_v1(
            default_values,
            default_blend_shapes,
            anim_name,
            node_anim_data,
            animplayer,
            gstate,
            material_idx_to_mesh_and_surface_idx,
            mesh_idx_to_meshinstance,
            node_to_head_hidden_node,
            lookAt
        )

        if anim:
            var anim_lib: AnimationLibrary = AnimationLibrary.new()
            anim_lib.add_animation(anim_name, anim)
            if not animplayer.has_animation_library(&""):
                animplayer.add_animation_library("", anim_lib)
            else:
                var existing_lib: AnimationLibrary = animplayer.get_animation_library("")
                for existing_anim_name in existing_lib.get_animation_list():
                    if existing_anim_name == anim_name:
                        existing_lib.remove_animation(existing_anim_name)
                existing_lib.add_animation(anim_name, anim)

    return OK
