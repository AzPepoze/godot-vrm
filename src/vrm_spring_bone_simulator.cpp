#include "vrm_spring_bone_simulator.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void VRMSpringBoneSimulator::_bind_methods() {
  ClassDB::bind_method(D_METHOD("setup", "spring_bones", "collider_groups"),
                       &VRMSpringBoneSimulator::setup);
  ClassDB::bind_method(D_METHOD("update_parameters", "gravity_multiplier",
                                "gravity_rotation", "add_force"),
                       &VRMSpringBoneSimulator::update_parameters);
  ClassDB::bind_method(D_METHOD("get_chain_count"),
                       &VRMSpringBoneSimulator::get_chain_count);
  ClassDB::bind_method(D_METHOD("get_joint_count", "chain_idx"),
                       &VRMSpringBoneSimulator::get_joint_count);
  ClassDB::bind_method(
      D_METHOD("get_joint_current_tail", "chain_idx", "joint_idx"),
      &VRMSpringBoneSimulator::get_joint_current_tail);
  ClassDB::bind_method(
      D_METHOD("draw_gizmo", "mesh", "skel_to_gizmo", "color",
               "draw_spring_bones", "draw_colliders"),
      &VRMSpringBoneSimulator::draw_gizmo);
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
  all_collider_groups.clear();
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

    CPPSpringBoneColliderGroup cpp_group;
    Array colliders_arr = group->get("colliders");
    UtilityFunctions::print("SETUP group ", i, " colliders_arr.size()=", colliders_arr.size());
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
      c.gizmo_color = coll_res->get("gizmo_color");

      cpp_group.collider_indices.push_back((int)all_colliders.size());
      all_colliders.push_back(c);
    }
    all_collider_groups.push_back(cpp_group);
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

    Transform3D skel_global_inv = skel->get_global_transform().affine_inverse();
    Transform3D center_transform;
    if (chain.center_bone != -1) {
      center_transform = skel->get_bone_global_pose(chain.center_bone);
    } else if (chain.center_node) {
      center_transform =
          skel_global_inv * chain.center_node->get_global_transform();
    }
    Transform3D center_transform_inv = center_transform.affine_inverse();

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
          pos = Vector3(0, -0.07f, 0);
        }
      }

      joint.initial_transform =
          skel->get_bone_global_pose_no_override(joint.bone_idx);
      joint.global_pose = joint.initial_transform;
      joint.bone_axis = pos.normalized();
      joint.length = pos.length();

      // Initial tail positions in center frame
      Vector3 world_child_position = joint.initial_transform.xform(pos);
      joint.current_tail = center_transform_inv.xform(world_child_position);
      joint.prev_tail = joint.current_tail;

      chain.joints.push_back(joint);
    }

    // Collider group indices
    Array c_groups = sb_res->get("collider_groups");
    UtilityFunctions::print("SETUP chain ", i, " c_groups.size()=", c_groups.size(), " p_groups.size()=", p_collider_groups.size());
    for (int j = 0; j < c_groups.size(); ++j) {
      Ref<Resource> c_group_res = c_groups[j];
      if (c_group_res.is_null()) continue;
      
      for (int k = 0; k < p_collider_groups.size(); ++k) {
        Ref<Resource> p_group_res = p_collider_groups[k];
        if (p_group_res.is_null()) continue;
        
        if (p_group_res->get_instance_id() == c_group_res->get_instance_id()) {
          chain.collider_group_indices.push_back(k);
          break;
        }
      }
    }
    UtilityFunctions::print("SETUP chain ", i, " mapped_indices.size()=", (int)chain.collider_group_indices.size());
    
    chains.push_back(chain);
  }

  is_setup = true;
  need_reset = true;
}

void VRMSpringBoneSimulator::_process_modification() {
  Skeleton3D *skel = get_skeleton();
  if (!skel) {
    return;
  }
  if (!is_setup) {
    return;
  }

  float delta = (float)get_process_delta_time();
  if (delta <= 0.0001f) {
    // If called during a forced update where delta is zero (e.g., mid-frame get_bone_global_pose), 
    // use a fallback delta to maintain the physics state.
    delta = 0.016666f; 
  }
  
  if (add_force.length_squared() > 10.0f || chains.size() == 1) {
    UtilityFunctions::print("CPP_MODIFIER delta=", delta, " chains=", (int)chains.size(), " add_force=", add_force);
  }

  _update_colliders(skel);

  Transform3D skel_global_inv = skel->get_global_transform().affine_inverse();

  if (need_reset) {
    for (auto &chain : chains) {
      Transform3D center_transform;
      if (chain.center_bone != -1) {
        center_transform = skel->get_bone_global_pose(chain.center_bone);
      } else if (chain.center_node) {
        center_transform =
            skel_global_inv * chain.center_node->get_global_transform();
      }
      Transform3D center_transform_inv = center_transform.affine_inverse();

      for (auto &joint : chain.joints) {
        if (joint.parent_idx == -1) {
          joint.initial_transform = skel->get_bone_pose(joint.bone_idx);
        } else {
          joint.initial_transform =
              skel->get_bone_global_pose(joint.parent_idx) *
              skel->get_bone_pose(joint.bone_idx);
        }
        joint.global_pose = joint.initial_transform;
        Vector3 pos = joint.bone_axis * joint.length;
        Vector3 world_child_position = joint.initial_transform.xform(pos);
        joint.current_tail = center_transform_inv.xform(world_child_position);
        joint.prev_tail = joint.current_tail;
      }
    }
    need_reset = false;
  }

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
      Vector3 gravity_part = total_gravity * delta * chain.gravity_scale;
      Vector3 external =
          center_rot_inv.xform(gravity_part) + (add_force * delta);

      if (joint.parent_idx == -1) {
        joint.global_pose = skel->get_bone_pose(joint.bone_idx);
      } else {
        joint.global_pose = skel->get_bone_global_pose(joint.parent_idx) *
                            skel->get_bone_pose(joint.bone_idx);
      }

      // origin in center space
      Vector3 origin = center_transform_inv.xform(joint.global_pose.origin);
      Quaternion local_rot = joint.global_pose.basis.get_rotation_quaternion();
      Quaternion local_rot_center = center_rot_inv * local_rot;

      Vector3 next_tail =
          joint.current_tail +
          (joint.current_tail - joint.prev_tail) * (1.0f - drag) +
          (local_rot_center.xform(joint.bone_axis * stiffness) +
                            external);

      next_tail = origin + (next_tail - origin).normalized() * joint.length;

      float radius_val = chain.hit_radius_scale;
      if (!chain.hit_radius.empty()) {
        radius_val *= (i < chain.hit_radius.size()) ? chain.hit_radius[i]
                                                    : chain.hit_radius.back();
      }

      // Collision
      for (auto &coll_group_idx : chain.collider_group_indices) {
        if (coll_group_idx < 0 || coll_group_idx >= (int)all_collider_groups.size())
          continue;
        
        const auto &cpp_group = all_collider_groups[coll_group_idx];
        for (auto &coll_idx : cpp_group.collider_indices) {
          const auto &coll = all_colliders[coll_idx];
          Vector3 world_coll_pos = coll.position;
          Vector3 coll_pos = center_transform_inv.xform(world_coll_pos);
          
          if (coll.is_capsule) {
            Vector3 world_tail_pos = coll.tail_position;
            Vector3 tail_pos = center_transform_inv.xform(world_tail_pos);
            Vector3 P = tail_pos - coll_pos;
            Vector3 Q = next_tail - coll_pos;
            float dot = P.dot(Q);
            float p_len_sq = P.length_squared();
            if (p_len_sq > 0.00001f) {
              float t = CLAMP(dot / p_len_sq, 0.0f, 1.0f);
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
      }

      joint.prev_tail = joint.current_tail;
      joint.current_tail = next_tail;

      // Apply rotation to bone
      // 1. Get current bone global transform (skel-local)
      Transform3D current_global_tf = joint.global_pose;
      
      // 2. Transform the simulated tail position (next_tail) from center space back to skel-local space
      Vector3 next_tail_skel = center_transform.xform(next_tail);
      
      // 3. Calculate target direction in bone's local space
      // We want to find the direction from joint origin to next_tail_skel, in the bone's coordinate system
      Vector3 local_target_dir = current_global_tf.affine_inverse().basis.xform(next_tail_skel - current_global_tf.origin).normalized();
      
      // 4. Calculate rotation from bone_axis (default direction) to local_target_dir
      Quaternion local_rot_diff = _from_to_rotation_safe(joint.bone_axis, local_target_dir);
      
      if (local_rot_diff != Quaternion()) {
        // 5. Apply this local rotation to the global pose
        // new_global_rot = current_global_rot * local_rot_diff
        Quaternion new_global_rot = current_global_tf.basis.get_rotation_quaternion() * local_rot_diff;
        
        Vector3 scl = current_global_tf.basis.get_scale();
        joint.global_pose.basis = Basis(new_global_rot).scaled(scl);
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

int VRMSpringBoneSimulator::get_chain_count() const {
  return (int)chains.size();
}

int VRMSpringBoneSimulator::get_joint_count(int p_chain_idx) const {
  if (p_chain_idx < 0 || p_chain_idx >= (int)chains.size()) {
    return 0;
  }
  return (int)chains[p_chain_idx].joints.size();
}

Vector3 VRMSpringBoneSimulator::get_joint_current_tail(int p_chain_idx,
                                                       int p_joint_idx) const {
  if (p_chain_idx < 0 || p_chain_idx >= (int)chains.size()) {
    return Vector3();
  }
  const auto &chain = chains[p_chain_idx];
  if (p_joint_idx < 0 || p_joint_idx >= (int)chain.joints.size()) {
    return Vector3();
  }
  return chain.joints[p_joint_idx].current_tail;
}

void VRMSpringBoneSimulator::draw_gizmo(Object *p_mesh_obj,
                                        Transform3D p_skel_to_gizmo,
                                        Color p_color, bool p_draw_spring_bones,
                                        bool p_draw_colliders) {
  ImmediateMesh *mesh = Object::cast_to<ImmediateMesh>(p_mesh_obj);
  if (!mesh)
    return;

  mesh->clear_surfaces();

  Skeleton3D *skel = get_skeleton();
  if (!skel)
    return;

  Transform3D skel_global_inv = skel->get_global_transform().affine_inverse();

  if (p_draw_spring_bones && !chains.empty()) {
    mesh->surface_begin(Mesh::PRIMITIVE_LINES);
    for (const auto &chain : chains) {
      Transform3D center_transform;
      if (chain.center_bone != -1) {
        center_transform = skel->get_bone_global_pose(chain.center_bone);
      } else if (chain.center_node) {
        center_transform =
            skel_global_inv * chain.center_node->get_global_transform();
      }

      for (const auto &joint : chain.joints) {
        Vector3 start_skel = joint.global_pose.origin;
        Vector3 end_skel = center_transform.xform(joint.current_tail);

        Vector3 start_gizmo = p_skel_to_gizmo.xform(start_skel);
        Vector3 end_gizmo = p_skel_to_gizmo.xform(end_skel);

        _draw_line(mesh, start_gizmo, end_gizmo, p_color);
        _draw_sphere(mesh, Basis(), start_gizmo, 0.015f, p_color);
      }
      if (!chain.joints.empty()) {
        Vector3 end_skel =
            center_transform.xform(chain.joints.back().current_tail);
        Vector3 end_gizmo = p_skel_to_gizmo.xform(end_skel);
        _draw_sphere(mesh, Basis(), end_gizmo, 0.015f, p_color);
      }
    }
    mesh->surface_end();
  }

  if (p_draw_colliders && !all_colliders.empty()) {
    mesh->surface_begin(Mesh::PRIMITIVE_LINES);
    Transform3D world_to_skel = skel->get_global_transform().affine_inverse();
    for (const auto &c : all_colliders) {
      Vector3 pos_skel = world_to_skel.xform(c.position);
      Vector3 pos_gizmo = p_skel_to_gizmo.xform(pos_skel);
      Color col = c.gizmo_color;

      if (c.is_capsule) {
        Vector3 tail_skel = world_to_skel.xform(c.tail_position);
        Vector3 tail_gizmo = p_skel_to_gizmo.xform(tail_skel);
        _draw_line(mesh, pos_gizmo, tail_gizmo, col);
        _draw_sphere(mesh, Basis(), pos_gizmo, c.radius, col);
        _draw_sphere(mesh, Basis(), tail_gizmo, c.radius, col);
      } else {
        _draw_sphere(mesh, Basis(), pos_gizmo, c.radius, col);
      }
    }
    mesh->surface_end();
  }
}

void VRMSpringBoneSimulator::_draw_sphere(ImmediateMesh *p_mesh,
                                          const Basis &p_bas,
                                          const Vector3 &p_center,
                                          float p_radius, Color p_color) {
  if (p_radius <= 0.0f)
    return;
  const int step = 15;
  const float sppi = 2.0f * (float)Math_PI / step;

  for (int i = 1; i <= step; i++) {
    p_mesh->surface_set_color(p_color);
    p_mesh->surface_add_vertex(
        p_center + (p_bas.get_column(1) * p_radius)
                       .rotated(p_bas.get_column(0), sppi * (i - 1)));
    p_mesh->surface_set_color(p_color);
    p_mesh->surface_add_vertex(
        p_center +
        (p_bas.get_column(1) * p_radius).rotated(p_bas.get_column(0), sppi * i));
  }
  for (int i = 1; i <= step; i++) {
    p_mesh->surface_set_color(p_color);
    p_mesh->surface_add_vertex(
        p_center + (p_bas.get_column(0) * p_radius)
                       .rotated(p_bas.get_column(2), sppi * (i - 1)));
    p_mesh->surface_set_color(p_color);
    p_mesh->surface_add_vertex(
        p_center +
        (p_bas.get_column(0) * p_radius).rotated(p_bas.get_column(2), sppi * i));
  }
  for (int i = 1; i <= step; i++) {
    p_mesh->surface_set_color(p_color);
    p_mesh->surface_add_vertex(
        p_center + (p_bas.get_column(2) * p_radius)
                       .rotated(p_bas.get_column(1), sppi * (i - 1)));
    p_mesh->surface_set_color(p_color);
    p_mesh->surface_add_vertex(
        p_center +
        (p_bas.get_column(2) * p_radius).rotated(p_bas.get_column(1), sppi * i));
  }
}

void VRMSpringBoneSimulator::_draw_line(ImmediateMesh *p_mesh,
                                        const Vector3 &p_begin,
                                        const Vector3 &p_end, Color p_color) {
  p_mesh->surface_set_color(p_color);
  p_mesh->surface_add_vertex(p_begin);
  p_mesh->surface_set_color(p_color);
  p_mesh->surface_add_vertex(p_end);
}
