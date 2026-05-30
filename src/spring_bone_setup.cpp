#include "spring_bone_setup.h"

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/skeleton3d.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

namespace SpringBoneSetup {

// Helper: copy PackedFloat64Array into std::vector<float>
static void copy_float_array(const Ref<Resource> &res, const StringName &prop, std::vector<float> &out) {
    PackedFloat64Array arr = res->get(prop);
    out.reserve(arr.size());
    for (int i = 0; i < arr.size(); ++i) {
        out.push_back((float)arr[i]);
    }
}

void parse_collider_groups(
    const Array &p_collider_groups,
    Skeleton3D *skel,
    Node *resolver_root,
    std::vector<VRMSpringBoneSimulator::CPPSpringBoneCollider> &out_colliders,
    std::vector<VRMSpringBoneSimulator::CPPSpringBoneColliderGroup> &out_groups) {

    for (int i = 0; i < p_collider_groups.size(); ++i) {
        Ref<Resource> group = p_collider_groups[i];
        if (group.is_null()) {
            continue;
        }

        VRMSpringBoneSimulator::CPPSpringBoneColliderGroup cpp_group;
        Array colliders_arr = group->get("colliders");

        for (int j = 0; j < colliders_arr.size(); ++j) {
            Ref<Resource> coll_res = colliders_arr[j];
            if (coll_res.is_null()) {
                continue;
            }

            VRMSpringBoneSimulator::CPPSpringBoneCollider c;
            String bone_name = coll_res->get("bone");
            if (!bone_name.is_empty()) {
                c.bone_idx = skel->find_bone(bone_name);
            }

            NodePath np = coll_res->get("node_path");
            if (!np.is_empty() && resolver_root) {
                c.node = Object::cast_to<Node3D>(resolver_root->get_node_or_null(np));
            }

            c.offset = coll_res->get("offset");
            c.tail = coll_res->get("tail");
            c.radius = coll_res->get("radius");
            c.is_capsule = coll_res->get("is_capsule");
            c.gizmo_color = coll_res->get("gizmo_color");

            cpp_group.collider_indices.push_back((int)out_colliders.size());
            out_colliders.push_back(c);
        }
        out_groups.push_back(cpp_group);
    }
}

void parse_spring_bones(
    const Array &p_spring_bones,
    const Array &p_collider_groups,
    Skeleton3D *skel,
    Node *resolver_root,
    std::vector<VRMSpringBoneSimulator::CPPSpringBoneChain> &out_chains) {

    Transform3D skel_global_inv = skel->get_global_transform().affine_inverse();

    for (int i = 0; i < p_spring_bones.size(); ++i) {
        Ref<Resource> sb_res = p_spring_bones[i];
        if (sb_res.is_null()) {
            continue;
        }

        VRMSpringBoneSimulator::CPPSpringBoneChain chain;
        PackedStringArray joint_nodes = sb_res->get("joint_nodes");

        // Scale parameters
        chain.stiffness_scale = sb_res->get("stiffness_scale");
        chain.drag_force_scale = sb_res->get("drag_force_scale");
        chain.hit_radius_scale = sb_res->get("hit_radius_scale");
        chain.gravity_scale = sb_res->get("gravity_scale");
        chain.gravity_dir_default = sb_res->get("gravity_dir_default");

        // Environment collision (optional per-chain)
        Variant env_coll_val = sb_res->get("enable_environment_collision");
        if (env_coll_val.get_type() != Variant::NIL) {
            chain.enable_environment_collision = env_coll_val;
        }
        Variant env_mask_val = sb_res->get("environment_collision_mask");
        if (env_mask_val.get_type() != Variant::NIL) {
            chain.environment_collision_mask = env_mask_val;
        }

        // Per-joint arrays
        copy_float_array(sb_res, "stiffness_force", chain.stiffness_force);
        copy_float_array(sb_res, "gravity_power", chain.gravity_power);
        copy_float_array(sb_res, "drag_force", chain.drag_force);
        copy_float_array(sb_res, "hit_radius", chain.hit_radius);

        PackedVector3Array gravity_dir = sb_res->get("gravity_dir");
        for (int j = 0; j < gravity_dir.size(); ++j) {
            chain.gravity_dir.push_back(gravity_dir[j]);
        }

        // Center bone / node
        String center_bone_name = sb_res->get("center_bone");
        if (!center_bone_name.is_empty()) {
            chain.center_bone = skel->find_bone(center_bone_name);
        }
        NodePath center_np = sb_res->get("center_node");
        if (!center_np.is_empty() && resolver_root) {
            chain.center_node = Object::cast_to<Node3D>(resolver_root->get_node_or_null(center_np));
        }

        // Center transform for initial tail positions
        Transform3D center_transform;
        if (chain.center_bone != -1) {
            center_transform = skel->get_bone_global_pose(chain.center_bone);
        } else if (chain.center_node) {
            center_transform = skel_global_inv * chain.center_node->get_global_transform();
        }
        Transform3D center_transform_inv = center_transform.affine_inverse();

        // Build joints
        for (int j = 0; j < joint_nodes.size() - 1; ++j) {
            VRMSpringBoneSimulator::CPPSpringBoneJoint joint;
            joint.bone_idx = skel->find_bone(joint_nodes[j]);
            if (joint.bone_idx == -1) {
                continue;
            }

            joint.parent_idx = skel->get_bone_parent(joint.bone_idx);

            Vector3 pos;
            if (joint_nodes[j + 1].is_empty()) {
                Vector3 delta = skel->get_bone_rest(joint.bone_idx).origin;
                pos = delta.normalized() * 0.07f;
            } else {
                int first_child = skel->find_bone(joint_nodes[j + 1]);
                if (first_child != -1) {
                    Vector3 local_position = skel->get_bone_rest(first_child).origin;
                    Vector3 sca = skel->get_bone_rest(first_child).basis.get_scale();
                    pos = Vector3(local_position.x * sca.x, local_position.y * sca.y,
                                  local_position.z * sca.z);
                } else {
                    pos = Vector3(0, -0.07f, 0);
                }
            }

            joint.initial_transform = skel->get_bone_global_pose_no_override(joint.bone_idx);
            joint.global_pose = joint.initial_transform;
            joint.bone_axis = pos.normalized();
            joint.length = pos.length();

            Vector3 world_child_position = joint.initial_transform.xform(pos);
            joint.current_tail = center_transform_inv.xform(world_child_position);
            joint.prev_tail = joint.current_tail;

            chain.joints.push_back(joint);
        }

        // Link collider group indices by instance ID
        Array c_groups = sb_res->get("collider_groups");
        for (int j = 0; j < c_groups.size(); ++j) {
            Ref<Resource> c_group_res = c_groups[j];
            if (c_group_res.is_null()) {
                continue;
            }
            for (int k = 0; k < p_collider_groups.size(); ++k) {
                Ref<Resource> p_group_res = p_collider_groups[k];
                if (p_group_res.is_null()) {
                    continue;
                }
                if (p_group_res->get_instance_id() == c_group_res->get_instance_id()) {
                    chain.collider_group_indices.push_back(k);
                    break;
                }
            }
        }

        out_chains.push_back(chain);
    }
}

} // namespace SpringBoneSetup

} // namespace godot
