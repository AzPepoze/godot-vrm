#include "vrm_spring_bone_simulator.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>

using namespace godot;

void VRMSpringBoneSimulator::_bind_methods() {
  ClassDB::bind_method(D_METHOD("setup", "spring_bones", "collider_groups"),
                       &VRMSpringBoneSimulator::setup);
  ClassDB::bind_method(D_METHOD("update_parameters", "gravity_multiplier",
                                "gravity_rotation", "add_force"),
                       &VRMSpringBoneSimulator::update_parameters);
}

VRMSpringBoneSimulator::VRMSpringBoneSimulator() {}

VRMSpringBoneSimulator::~VRMSpringBoneSimulator() {}

void VRMSpringBoneSimulator::update_parameters(float p_gravity_multiplier,
                                               Quaternion p_gravity_rotation,
                                               Vector3 p_add_force) {
  gravity_multiplier = p_gravity_multiplier;
  gravity_rotation = p_gravity_rotation;
  add_force = p_add_force;
}

void VRMSpringBoneSimulator::setup(Array p_spring_bones,
                                   Array p_collider_groups) {
  chains.clear();
  all_colliders.clear();
  is_setup = false;

  Skeleton3D *skel = get_skeleton();
  if (!skel) {
    return;
  }

  // 1. Process Colliders
  for (int i = 0; i < p_collider_groups.size(); ++i) {
    Ref<Resource> group = p_collider_groups[i];
    if (group.is_null())
      continue;

    Array colliders_arr = group->get("colliders");
    for (int j = 0; j < colliders_arr.size(); ++j) {
      Ref<Resource> coll_res = colliders_arr[j];
      if (coll_res.is_null())
        continue;

      CPPSpringBoneCollider c;
      String bone_name = coll_res->get("bone");
      if (!bone_name.is_empty()) {
        c.bone_idx = skel->find_bone(bone_name);
      }

      NodePath np = coll_res->get("node_path");
      if (!np.is_empty()) {
        c.node = Object::cast_to<Node3D>(get_node_or_null(np));
      }

      c.offset = coll_res->get("offset");
      c.tail = coll_res->get("tail");
      c.radius = coll_res->get("radius");
      c.is_capsule = coll_res->get("is_capsule");

      all_colliders.push_back(c);
    }
  }

  // 2. Process Spring Bones (Chains)
  for (int i = 0; i < p_spring_bones.size(); ++i) {
    Ref<Resource> sb_res = p_spring_bones[i];
    if (sb_res.is_null())
      continue;

    CPPSpringBoneChain chain;
    PackedStringArray joint_nodes = sb_res->get("joint_nodes");

    chain.stiffness_scale = sb_res->get("stiffness_scale");
    chain.drag_force_scale = sb_res->get("drag_force_scale");
    chain.hit_radius_scale = sb_res->get("hit_radius_scale");
    chain.gravity_scale = sb_res->get("gravity_scale");
    chain.gravity_dir_default = sb_res->get("gravity_dir_default");

    // Joint specific arrays
    PackedFloat64Array stiffness_force = sb_res->get("stiffness_force");
    for (int j = 0; j < stiffness_force.size(); ++j)
      chain.stiffness_force.push_back((float)stiffness_force[j]);

    PackedFloat64Array gravity_power = sb_res->get("gravity_power");
    for (int j = 0; j < gravity_power.size(); ++j)
      chain.gravity_power.push_back((float)gravity_power[j]);

    PackedVector3Array gravity_dir = sb_res->get("gravity_dir");
    for (int j = 0; j < gravity_dir.size(); ++j)
      chain.gravity_dir.push_back(gravity_dir[j]);

    PackedFloat64Array drag_force = sb_res->get("drag_force");
    for (int j = 0; j < drag_force.size(); ++j)
      chain.drag_force.push_back((float)drag_force[j]);

    PackedFloat64Array hit_radius = sb_res->get("hit_radius");
    for (int j = 0; j < hit_radius.size(); ++j)
      chain.hit_radius.push_back((float)hit_radius[j]);

    // Center
    String center_bone_name = sb_res->get("center_bone");
    if (!center_bone_name.is_empty()) {
      chain.center_bone = skel->find_bone(center_bone_name);
    }
    NodePath center_np = sb_res->get("center_node");
    if (!center_np.is_empty()) {
      chain.center_node = Object::cast_to<Node3D>(get_node_or_null(center_np));
    }

    // Build joints
    for (int j = 0; j < joint_nodes.size() - 1; ++j) {
      CPPSpringBoneJoint joint;
      joint.bone_idx = skel->find_bone(joint_nodes[j]);
      if (joint.bone_idx == -1)
        continue;

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
          pos = Vector3(0, 0.07f, 0);
        }
      }

      joint.initial_transform =
          skel->get_bone_global_pose_no_override(joint.bone_idx);
      joint.global_pose = joint.initial_transform;
      joint.bone_axis = pos.normalized();
      joint.length = pos.length();

      // Initial tail positions
      Vector3 world_child_position = joint.initial_transform.xform(pos);
      joint.current_tail = world_child_position;
      joint.prev_tail = joint.current_tail;

      chain.joints.push_back(joint);
    }

    // Collider group indices
    Array c_groups = sb_res->get("collider_groups");
    for (int j = 0; j < c_groups.size(); ++j) {
      for (int k = 0; k < p_collider_groups.size(); ++k) {
        if (p_collider_groups[k] == c_groups[j]) {
          chain.collider_group_indices.push_back(k);
          break;
        }
      }
    }

    chains.push_back(chain);
  }

  is_setup = true;
}

void VRMSpringBoneSimulator::_process_modification() {
  Skeleton3D *skel = get_skeleton();
  if (!skel || !is_setup)
    return;

  float delta = (float)get_process_delta_time();
  if (delta <= 0.0f)
    return;

  _update_colliders(skel);

  Transform3D skel_global_inv = skel->get_global_transform().affine_inverse();

  for (auto &chain : chains) {
    Transform3D center_transform;
    if (chain.center_bone != -1) {
      center_transform = skel->get_bone_global_pose(chain.center_bone);
    } else if (chain.center_node) {
      center_transform =
          skel_global_inv * chain.center_node->get_global_transform();
    }

    Transform3D center_transform_inv = center_transform.affine_inverse();
    Quaternion center_rot = center_transform.basis.get_rotation_quaternion();
    Quaternion center_rot_inv = center_rot.inverse();

    for (size_t i = 0; i < chain.joints.size(); ++i) {
      auto &joint = chain.joints[i];

      float stiffness = chain.stiffness_scale * delta;
      if (!chain.stiffness_force.empty()) {
        stiffness *= (i < chain.stiffness_force.size())
                         ? chain.stiffness_force[i]
                         : chain.stiffness_force.back();
      }

      float drag = chain.drag_force_scale;
      if (!chain.drag_force.empty()) {
        drag *= (i < chain.drag_force.size()) ? chain.drag_force[i]
                                              : chain.drag_force.back();
      }

      Vector3 gravity_dir = (i < chain.gravity_dir.size())
                                ? chain.gravity_dir[i]
                                : chain.gravity_dir_default;
      float grav_pow = 1.0f;
      if (!chain.gravity_power.empty()) {
        grav_pow = (i < chain.gravity_power.size())
                       ? chain.gravity_power[i]
                       : chain.gravity_power.back();
      }

      Vector3 total_gravity =
          gravity_rotation.xform(gravity_dir * grav_pow * gravity_multiplier);
      Vector3 external =
          (total_gravity * delta * chain.gravity_scale) + (add_force * delta);
      external = center_rot_inv.xform(external);

      joint.global_pose = skel->get_bone_global_pose(joint.parent_idx) *
                          skel->get_bone_pose(joint.bone_idx);

      Vector3 origin = center_transform.xform(joint.global_pose.origin);
      Quaternion local_rot = joint.global_pose.basis.get_rotation_quaternion();

      Vector3 next_tail =
          joint.current_tail +
          (joint.current_tail - joint.prev_tail) * (1.0f - drag) +
          (center_rot.xform(
              local_rot.xform(joint.bone_axis * stiffness + external)));

      next_tail = origin + (next_tail - origin).normalized() * joint.length;

      float radius_val = chain.hit_radius_scale;
      if (!chain.hit_radius.empty()) {
        radius_val *= (i < chain.hit_radius.size()) ? chain.hit_radius[i]
                                                    : chain.hit_radius.back();
      }

      // Collision
      for (auto &coll : all_colliders) {
        Vector3 coll_pos = coll.position;
        if (coll.is_capsule) {
          Vector3 P = coll.tail_position - coll.position;
          Vector3 Q = origin - coll.position;
          float dot = P.dot(Q);
          float p_len_sq = P.length_squared();
          if (dot > 0 && p_len_sq > 0.00001f) {
            float t = dot / p_len_sq;
            if (t >= 1.0f)
              coll_pos += P;
            else
              coll_pos += P * t;
          }
        }

        Vector3 diff = next_tail - coll_pos;
        float r = radius_val + coll.radius;
        if (diff.length_squared() <= r * r) {
          Vector3 normal = diff.normalized();
          Vector3 pos_from_collider = coll_pos + normal * r;
          next_tail =
              origin + (pos_from_collider - origin).normalized() * joint.length;
        }
      }

      joint.prev_tail = joint.current_tail;
      joint.current_tail = next_tail;

      Quaternion ft = _from_to_rotation_safe(
          local_rot.xform(joint.bone_axis),
          center_transform_inv.basis.xform(next_tail - origin));
      if (ft != Quaternion()) {
        Quaternion qt = ft * local_rot;
        Vector3 scl = joint.global_pose.basis.get_scale();
        joint.global_pose.basis = Basis(qt).scaled(scl);
        skel->set_bone_global_pose(joint.bone_idx, joint.global_pose);
      }
    }
  }
}

void VRMSpringBoneSimulator::_update_colliders(Skeleton3D *skel) {
  Transform3D skel_global = skel->get_global_transform();

  for (auto &c : all_colliders) {
    if (c.bone_idx != -1) {
      Transform3D bone_global =
          skel_global * skel->get_bone_global_pose(c.bone_idx);
      c.position = bone_global.xform(c.offset);
      if (c.is_capsule)
        c.tail_position = bone_global.xform(c.tail);
    } else if (c.node) {
      Transform3D node_global = c.node->get_global_transform();
      c.position = node_global.xform(c.offset);
      if (c.is_capsule)
        c.tail_position = node_global.xform(c.tail);
    }
  }
}

Quaternion VRMSpringBoneSimulator::_from_to_rotation_safe(Vector3 from,
                                                          Vector3 to) {
  Vector3 axis = from.cross(to);
  if (axis.is_zero_approx()) {
    return Quaternion();
  }
  float angle = from.angle_to(to);
  if (Math::is_equal_approx(angle, 0.0f)) {
    return Quaternion();
  }
  return Quaternion(axis.normalized(), angle);
}
