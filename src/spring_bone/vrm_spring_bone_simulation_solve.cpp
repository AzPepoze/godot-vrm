#include "spring_bone_collision.h"
#include "spring_bone_constants.h"
#include "spring_bone_forces.h"
#include "spring_bone_physics.h"
#include "spring_bone_runtime.h"
#include "spring_bone_util.h"
#include "vrm_spring_bone_simulation.h"

#include <godot_cpp/classes/skeleton3d.hpp>

namespace godot {

void VRMSpringBoneSimulation::_reset_chains(
    Skeleton3D *skel, const Transform3D &skel_global_inv) {

  for (auto &chain : chains) {
    Transform3D center = SpringBoneUtil::get_center_transform(
        chain, skel, skel_global_inv, simulate_in_local_space);
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
    auto collider_views = SpringBoneRuntime::gather_collider_views(
        chain, all_colliders, all_collider_groups, center_inv,
        body_collider_radius_multiplier);
    for (int pass = 0; pass < SpringBoneConstants::PUSH_OUT_PASSES; ++pass) {
      for (size_t i = 0; i < chain.joints.size(); ++i) {
        auto &joint = chain.joints[i];
        Vector3 origin = center_inv.xform(joint.global_pose.origin);
        float radius = chain.hit_radius_scale *
                       SpringBoneUtil::joint_param(chain.hit_radius, i);
        joint.current_tail = SpringBoneCollision::resolve_all_colliders(
            joint.current_tail, origin, radius, joint.length, collider_views);
        joint.prev_tail = joint.current_tail;
      }
    }
  }
}

void VRMSpringBoneSimulation::_simulate_chains(
    Skeleton3D *skel, const Transform3D &skel_global_inv, float delta) {
  SpringBoneRuntime::age_impacts(recent_impacts, delta);

  for (auto &chain : chains) {
    Transform3D center = SpringBoneUtil::get_center_transform(
        chain, skel, skel_global_inv, simulate_in_local_space);
    Transform3D center_inv = center.affine_inverse();
    Quaternion center_rot = center.basis.get_rotation_quaternion();
    Quaternion center_rot_inv = center_rot.inverse();

    auto collider_views = SpringBoneRuntime::gather_collider_views(
        chain, all_colliders, all_collider_groups, center_inv,
        body_collider_radius_multiplier);

    SpringBoneForces::ForceContext force_context;
    force_context.delta = delta;
    force_context.stiffness_multiplier = stiffness_multiplier;
    force_context.drag_multiplier = drag_multiplier;
    force_context.hit_radius_multiplier = hit_radius_multiplier;
    force_context.gravity_multiplier = gravity_multiplier;
    force_context.gravity_rotation = gravity_rotation;
    force_context.add_force = add_force;
    force_context.center_rot_inv = center_rot_inv;
    force_context.skel_global_inv = skel_global_inv;
    force_context.wind_direction = wind_direction;
    force_context.wind_strength = wind_strength;
    force_context.wind_turbulence = wind_turbulence;
    force_context.wind_frequency = wind_frequency;
    force_context.wind_time = wind_time;

    for (size_t i = 0; i < chain.joints.size(); ++i) {
      auto &joint = chain.joints[i];

      SpringBoneForces::JointForces jf = SpringBoneForces::compute_joint_forces(
          chain, i, joint, force_context);

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

      // 2. Environment Colliders (External physics objects)
      if (chain.enable_environment_collision) {
        Vector3 contact_normal;
        float contact_t = 1.0f;
        Vector3 impact_point_world;
        if (_resolve_angular_env_push(
                skel, center, center_inv, origin, jf.radius,
                chain.environment_collision_mask, next_tail, joint.prev_tail,
                contact_normal, contact_t, impact_point_world)) {
          if (debug_collision) {
            SpringBoneRuntime::add_impact(recent_impacts, impact_point_world,
                                          contact_normal);
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
      _resolve_angular_collisions(skel, center, center_inv, chain, joint,
                                  origin, jf.radius);

      // Final length guard and expansion damping
      joint.current_tail = SpringBonePhysics::apply_length_constraint(
          joint.current_tail, origin, joint.length);
      Vector3 bone_vec = joint.current_tail - origin;
      float current_len = bone_vec.length();
      if (current_len < joint.length) {
        Vector3 cur_vel = joint.current_tail - joint.prev_tail;
        Vector3 bone_dir = bone_vec / (current_len + 1e-8f);
        float v_expansion = cur_vel.dot(bone_dir);
        if (v_expansion > 0.0f) {
          cur_vel -=
              bone_dir * v_expansion * SpringBoneConstants::EXPANSION_DAMPING;
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

} // namespace godot
