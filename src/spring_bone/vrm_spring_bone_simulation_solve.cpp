#include "vrm_spring_bone_simulation.h"
#include "spring_bone_collision.h"
#include "spring_bone_gizmo.h"
#include "spring_bone_physics.h"
#include "spring_bone_setup.h"
#include "spring_bone_wind.h"
#include "spring_bone_util.h"
#include "spring_bone_constants.h"

#include <godot_cpp/classes/skeleton3d.hpp>

namespace godot {

// ---------------------------------------------------------------------------
// Struct to hold computed forces and params for a joint
// ---------------------------------------------------------------------------
struct JointForces {
  float stiffness;
  float drag;
  Vector3 external;
  float radius;
};

// ---------------------------------------------------------------------------
// Compute joint-specific forces and physics params
// ---------------------------------------------------------------------------
static inline JointForces compute_joint_forces(
    const VRMSpringBoneSimulation::CPPSpringBoneChain &chain, size_t i, float delta,
    float stiffness_multiplier, float drag_multiplier, float hit_radius_multiplier,
    float gravity_multiplier, const Quaternion &gravity_rotation,
    const Vector3 &add_force, const Quaternion &center_rot_inv,
    const Transform3D &skel_global_inv, const Vector3 &current_tail,
    float wind_strength, const Vector3 &wind_direction, float wind_turbulence,
    float wind_frequency, float wind_time, int bone_idx) {

  JointForces jf;
  jf.stiffness = stiffness_multiplier * chain.stiffness_scale * delta *
                 SpringBoneUtil::joint_param(chain.stiffness_force, i);
  jf.drag = drag_multiplier * chain.drag_force_scale *
            SpringBoneUtil::joint_param(chain.drag_force, i);
  float grav_pow = SpringBoneUtil::joint_param(chain.gravity_power, i);
  Vector3 grav_dir =
      SpringBoneUtil::joint_param_vec(chain.gravity_dir, i, chain.gravity_dir_default);
  jf.radius = hit_radius_multiplier * chain.hit_radius_scale *
              SpringBoneUtil::joint_param(chain.hit_radius, i);

  Vector3 total_gravity =
      gravity_rotation.xform(grav_dir * grav_pow * gravity_multiplier);
  jf.external =
      center_rot_inv.xform(total_gravity * delta * chain.gravity_scale) +
      (add_force * delta);

  if (wind_strength > 0.0001f) {
    SpringBoneWind::WindParams wp;
    wp.direction =
        center_rot_inv.xform(skel_global_inv.basis.xform(wind_direction));
    wp.strength = wind_strength;
    wp.turbulence = wind_turbulence;
    wp.frequency = wind_frequency;
    Vector3 wind_val = SpringBoneWind::compute_wind_force(
        wp, current_tail, wind_time,
        bone_idx + (int)i * 100);
    jf.external += wind_val * delta;
  }

  return jf;
}

// ---------------------------------------------------------------------------
// Build a flat list of ColliderViews in center space for the given chain.
// ---------------------------------------------------------------------------
static std::vector<SpringBoneCollision::ColliderView> gather_collider_views(
    const VRMSpringBoneSimulation::CPPSpringBoneChain &chain,
    const std::vector<VRMSpringBoneSimulation::CPPSpringBoneCollider>
        &all_colliders,
    const std::vector<VRMSpringBoneSimulation::CPPSpringBoneColliderGroup>
        &all_groups,
    const Transform3D &center_inv, float body_collider_radius_multiplier) {

  std::vector<SpringBoneCollision::ColliderView> views;
  for (int group_idx : chain.collider_group_indices) {
    if (group_idx < 0 || group_idx >= (int)all_groups.size()) {
      continue;
    }
    for (int coll_idx : all_groups[group_idx].collider_indices) {
      const auto &coll = all_colliders[coll_idx];
      SpringBoneCollision::ColliderView cv;
      cv.position = center_inv.xform(coll.position);
      cv.radius = coll.radius * body_collider_radius_multiplier;
      cv.is_capsule = coll.is_capsule;
      if (coll.is_capsule) {
        cv.tail_position = center_inv.xform(coll.tail_position);
      }
      views.push_back(cv);
    }
  }
  return views;
}

void VRMSpringBoneSimulation::_reset_chains(
    Skeleton3D *skel, const Transform3D &skel_global_inv) {

  for (auto &chain : chains) {
    Transform3D center = SpringBoneUtil::get_center_transform(chain, skel, skel_global_inv,
                                                              simulate_in_local_space);
    Transform3D center_inv = center.affine_inverse();

    // Reset tail positions to rest pose
    for (auto &joint : chain.joints) {
      if (joint.parent_idx == -1) {
        joint.initial_transform = skel->get_bone_pose(joint.bone_idx);
      } else {
        joint.initial_transform = skel->get_bone_global_pose(joint.parent_idx) *
                                  skel->get_bone_pose(joint.bone_idx);
      }
      joint.global_pose = joint.initial_transform;
      Vector3 world_child =
          joint.initial_transform.xform(joint.bone_axis * joint.length);
      joint.current_tail = center_inv.xform(world_child);
      joint.prev_tail = joint.current_tail;
    }

    // Push-out pass: resolve initial collider penetration
    auto collider_views =
        gather_collider_views(chain, all_colliders, all_collider_groups,
                              center_inv, body_collider_radius_multiplier);
    for (int pass = 0; pass < SpringBoneConstants::PUSH_OUT_PASSES; ++pass) {
      for (size_t i = 0; i < chain.joints.size(); ++i) {
        auto &joint = chain.joints[i];
        Vector3 origin = center_inv.xform(joint.global_pose.origin);
        float radius =
            chain.hit_radius_scale * SpringBoneUtil::joint_param(chain.hit_radius, i);
        joint.current_tail = SpringBoneCollision::resolve_all_colliders(
            joint.current_tail, origin, radius, joint.length, collider_views);
        joint.prev_tail = joint.current_tail;
      }
    }
  }
}

void VRMSpringBoneSimulation::_simulate_chains(
    Skeleton3D *skel, const Transform3D &skel_global_inv, float delta) {
  // Age recent impacts and remove old ones
  for (auto it = recent_impacts.begin(); it != recent_impacts.end();) {
    it->age += delta;
    if (it->age > SpringBoneConstants::IMPACT_FADE_DURATION) {
      it = recent_impacts.erase(it);
    } else {
      ++it;
    }
  }

  for (auto &chain : chains) {
    Transform3D center = SpringBoneUtil::get_center_transform(chain, skel, skel_global_inv,
                                                              simulate_in_local_space);
    Transform3D center_inv = center.affine_inverse();
    Quaternion center_rot = center.basis.get_rotation_quaternion();
    Quaternion center_rot_inv = center_rot.inverse();

    auto collider_views =
        gather_collider_views(chain, all_colliders, all_collider_groups,
                              center_inv, body_collider_radius_multiplier);

    for (size_t i = 0; i < chain.joints.size(); ++i) {
      auto &joint = chain.joints[i];

      // Decompose force calculation (Item 2)
      JointForces jf = compute_joint_forces(
          chain, i, delta,
          stiffness_multiplier, drag_multiplier, hit_radius_multiplier,
          gravity_multiplier, gravity_rotation,
          add_force, center_rot_inv,
          skel_global_inv, joint.current_tail,
          wind_strength, wind_direction, wind_turbulence,
          wind_frequency, wind_time, (int)joint.bone_idx);

      // Update global pose from skeleton
      if (joint.parent_idx == -1) {
        joint.global_pose = skel->get_bone_pose(joint.bone_idx);
      } else {
        joint.global_pose = skel->get_bone_global_pose(joint.parent_idx) *
                            skel->get_bone_pose(joint.bone_idx);
      }

      Vector3 origin = center_inv.xform(joint.global_pose.origin);
      Quaternion local_rot_center =
          center_rot_inv * joint.global_pose.basis.get_rotation_quaternion();

      // Verlet step
      SpringBonePhysics::VerletState vs{joint.current_tail, joint.prev_tail,
                                        joint.length, joint.bone_axis};
      SpringBonePhysics::ForceParams fp{jf.stiffness, jf.drag, jf.external};
      Vector3 next_tail =
          SpringBonePhysics::step_verlet(vs, fp, origin, local_rot_center);
      next_tail = SpringBonePhysics::apply_length_constraint(next_tail, origin,
                                                             joint.length);

      // Clamp Verlet output to surface tangent plane if in contact from
      // previous frame. Prevents stiffness from creating new velocity into
      // the surface each frame.
      if (joint.env_in_contact) {
        Vector3 move = next_tail - joint.current_tail;
        float mn = move.dot(joint.env_contact_normal);
        if (mn < 0.0f) {
          // Tail moved into surface — cancel that component
          next_tail -= joint.env_contact_normal * mn;
          next_tail = SpringBonePhysics::apply_length_constraint(
              next_tail, origin, joint.length);
        }
      }

      // --- COLLISION SOLVE ---

      // 1. VRM Colliders (Spheres and Capsules attached to the body)
      if (enable_body_collisions) {
        next_tail = SpringBoneCollision::resolve_all_colliders(
            next_tail, origin, jf.radius, joint.length, collider_views);
      }

      // 2. Environment Colliders (External physics objects) - Item 2 & Item 3 Decomposition
      if (chain.enable_environment_collision) {
        Vector3 contact_normal;
        float contact_t = 1.0f;
        Vector3 impact_point_world;
        if (_resolve_angular_env_push(skel, center, center_inv, origin, jf.radius,
                                      chain.environment_collision_mask,
                                      next_tail, joint.prev_tail,
                                      contact_normal, contact_t, impact_point_world)) {
          if (debug_collision) {
            CPPCollisionImpact impact;
            impact.position = impact_point_world;
            impact.normal = contact_normal;
            impact.age = 0.0f;
            recent_impacts.push_back(impact);
            if (recent_impacts.size() > SpringBoneConstants::MAX_IMPACT_HISTORY) {
              recent_impacts.erase(recent_impacts.begin());
            }
          }
        }
      }

      // 3. Length Constraint (Final pass to keep skeleton intact)
      next_tail = SpringBonePhysics::apply_length_constraint(next_tail, origin,
                                                             joint.length);

      // --- STATE UPDATE (Standard Verlet) ---
      joint.prev_tail = joint.current_tail;
      joint.current_tail = next_tail;

      // --- COLLISION RESOLUTION (ANGULAR ITERATIVE) ---
      _resolve_angular_collisions(skel, center, center_inv, chain, joint, origin, jf.radius);

      // Final length guard and expansion damping
      joint.current_tail = SpringBonePhysics::apply_length_constraint(joint.current_tail, origin, joint.length);
      Vector3 bone_vec = joint.current_tail - origin;
      float current_len = bone_vec.length();
      if (current_len < joint.length) {
        Vector3 cur_vel = joint.current_tail - joint.prev_tail;
        Vector3 bone_dir = bone_vec / (current_len + 1e-8f);
        float v_expansion = cur_vel.dot(bone_dir);
        if (v_expansion > 0.0f) {
          cur_vel -= bone_dir * v_expansion * SpringBoneConstants::EXPANSION_DAMPING;
          joint.prev_tail = joint.current_tail - cur_vel;
        }
      }
      next_tail = joint.current_tail;

      // Apply rotation to skeleton
      Transform3D tf = joint.global_pose;
      Vector3 local_target_dir =
          tf.affine_inverse()
              .basis.xform(center.xform(next_tail) - tf.origin)
              .normalized();
      Quaternion rot_diff = SpringBonePhysics::compute_bone_rotation(
          joint.bone_axis, local_target_dir);
      if (rot_diff != Quaternion()) {
        Quaternion new_rot = tf.basis.get_rotation_quaternion() * rot_diff;
        joint.global_pose.basis = Basis(new_rot).scaled(tf.basis.get_scale());
        skel->set_bone_global_pose(joint.bone_idx, joint.global_pose);
      }
    }
  }
}

void VRMSpringBoneSimulation::_update_colliders(Skeleton3D *skel) {
  Transform3D skel_global_inv = skel->get_global_transform().affine_inverse();
  for (auto &c : all_colliders) {
    Transform3D tf;
    if (c.bone_idx != -1) {
      tf = skel->get_bone_global_pose(c.bone_idx);
    } else if (c.node) {
      tf = skel_global_inv * c.node->get_global_transform();
    } else {
      continue;
    }
    c.position = tf.xform(c.offset);
    if (c.is_capsule) {
      c.tail_position = tf.xform(c.tail);
    }
  }
}

bool VRMSpringBoneSimulation::_resolve_angular_env_push(
    Skeleton3D *skel, const Transform3D &center, const Transform3D &center_inv,
    const Vector3 &origin, float radius, uint32_t mask,
    Vector3 &current_tail, Vector3 &prev_tail,
    Vector3 &out_contact_normal, float &out_contact_t, Vector3 &out_impact_point_world) {

  if (!environment_collision_enabled) {
    return false;
  }

  Transform3D skel_world = skel->get_global_transform();
  Vector3 origin_world = skel_world.xform(center.xform(origin));
  Vector3 tail_world = skel_world.xform(center.xform(current_tail));

  Vector3 env_push;
  _query_game_object_collisions(skel, origin_world, tail_world, radius, mask,
                                env_push, out_contact_t);

  if (env_push.is_zero_approx()) {
    return false;
  }

  out_contact_normal = env_push.normalized();
  out_impact_point_world = origin_world.lerp(tail_world, out_contact_t);
  Vector3 target_point_world = out_impact_point_world + env_push;

  Vector3 v_impact = out_impact_point_world - origin_world;
  Vector3 v_target = target_point_world - origin_world;

  if (v_impact.length_squared() > 1e-8f && v_target.length_squared() > 1e-8f) {
    Quaternion rot = Quaternion(v_impact.normalized(), v_target.normalized());
    Basis local_rot = center_inv.basis * skel_world.affine_inverse().basis *
                      Basis(rot) * skel_world.basis * center.basis;

    // Rotate both current and prev to cancel artificial velocity
    current_tail = origin + local_rot.xform(current_tail - origin);
    prev_tail = origin + local_rot.xform(prev_tail - origin);
    return true;
  }

  return false;
}

void VRMSpringBoneSimulation::_resolve_angular_collisions(
    Skeleton3D *skel, const Transform3D &center, const Transform3D &center_inv,
    CPPSpringBoneChain &chain, CPPSpringBoneJoint &joint, const Vector3 &origin,
    float radius) {

  for (int iter = 0; iter < SpringBoneConstants::ANGULAR_COLLISION_ITERATIONS; ++iter) {
    bool collision_happened = false;
    Vector3 contact_normal;

    Vector3 contact_normal_out;
    float contact_t = 1.0f;
    Vector3 impact_point_world;
    if (_resolve_angular_env_push(skel, center, center_inv, origin, radius,
                                  chain.environment_collision_mask,
                                  joint.current_tail, joint.prev_tail,
                                  contact_normal_out, contact_t, impact_point_world)) {
      collision_happened = true;
      contact_normal = contact_normal_out;

      if (debug_collision && iter == 0) {
        CPPCollisionImpact impact;
        impact.position = impact_point_world;
        impact.normal = contact_normal;
        impact.age = 0.0f;
        recent_impacts.push_back(impact);
        if (recent_impacts.size() > SpringBoneConstants::MAX_IMPACT_HISTORY) {
          recent_impacts.erase(recent_impacts.begin());
        }
      }
    }

    // --- KINEMATIC CONTACT RESOLUTION ---
    if (collision_happened) {
      Vector3 vel = joint.current_tail - joint.prev_tail;
      float vn = vel.dot(contact_normal);
      if (vn < 0.0f) {
        vel -= contact_normal * vn;
        vel *= SpringBoneConstants::CONTACT_VELOCITY_DAMPING;
        joint.prev_tail = joint.current_tail - vel;
      }
      joint.env_in_contact = true;
      joint.env_contact_normal = contact_normal;
    } else {
      if (joint.env_in_contact && iter == 0) {
        Vector3 vel = joint.current_tail - joint.prev_tail;
        vel *= (1.0f - environment_collision_bounce_damping);
        joint.prev_tail = joint.current_tail - vel;
      }
      joint.env_in_contact = false;
      break; // Exit early if no collision in this pass
    }
  }
}

} // namespace godot
