#include "vrm_spring_bone_simulation.h"

#include "spring_bone_constants.h"
#include "spring_bone_runtime.h"

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/skeleton3d.hpp>

namespace godot {
void VRMSpringBoneSimulation::_update_colliders(Skeleton3D *skel) {
  Transform3D skel_global_inv = skel->get_global_transform().affine_inverse();
  for (auto &collider : all_colliders) {
    Transform3D transform;
    if (collider.bone_idx != -1) {
      transform = skel->get_bone_global_pose(collider.bone_idx);
    } else if (collider.node) {
      transform = skel_global_inv * collider.node->get_global_transform();
    } else {
      continue;
    }

    collider.position = transform.xform(collider.offset);
    if (collider.is_capsule) {
      collider.tail_position = transform.xform(collider.tail);
    }
  }
}

bool VRMSpringBoneSimulation::_resolve_angular_env_push(
    Skeleton3D *skel, const Transform3D &center, const Transform3D &center_inv,
    const Vector3 &origin, float radius, uint32_t mask, Vector3 &current_tail,
    Vector3 &prev_tail, Vector3 &out_contact_normal, float &out_contact_t,
    Vector3 &out_impact_point_world) {
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

  if (v_impact.length_squared() <= 1e-8f ||
      v_target.length_squared() <= 1e-8f) {
    return false;
  }

  Quaternion rotation =
      Quaternion(v_impact.normalized(), v_target.normalized());
  Basis local_rotation = center_inv.basis * skel_world.affine_inverse().basis *
                         Basis(rotation) * skel_world.basis * center.basis;

  current_tail = origin + local_rotation.xform(current_tail - origin);
  prev_tail = origin + local_rotation.xform(prev_tail - origin);
  return true;
}

void VRMSpringBoneSimulation::_resolve_angular_collisions(
    Skeleton3D *skel, const Transform3D &center, const Transform3D &center_inv,
    SpringBoneTypes::Chain &chain, SpringBoneTypes::Joint &joint,
    const Vector3 &origin, float radius) {
  for (int iter = 0; iter < SpringBoneConstants::ANGULAR_COLLISION_ITERATIONS;
       ++iter) {
    bool collision_happened = false;
    Vector3 contact_normal;

    Vector3 contact_normal_out;
    float contact_t = 1.0f;
    Vector3 impact_point_world;
    if (_resolve_angular_env_push(skel, center, center_inv, origin, radius,
                                  chain.environment_collision_mask,
                                  joint.current_tail, joint.prev_tail,
                                  contact_normal_out, contact_t,
                                  impact_point_world)) {
      collision_happened = true;
      contact_normal = contact_normal_out;

      if (debug_collision && iter == 0) {
        SpringBoneRuntime::add_impact(recent_impacts, impact_point_world,
                                      contact_normal);
      }
    }

    if (collision_happened) {
      Vector3 velocity = joint.current_tail - joint.prev_tail;
      Vector3 contact_normal_local = center_inv.basis.xform(skel->get_global_transform().affine_inverse().basis.xform(contact_normal)).normalized();
      const float normal_velocity = velocity.dot(contact_normal_local);
      if (normal_velocity < 0.0f) {
        velocity -= contact_normal_local * normal_velocity;
        velocity *= SpringBoneConstants::CONTACT_VELOCITY_DAMPING;
        joint.prev_tail = joint.current_tail - velocity;
      }
      joint.env_in_contact = true;
      joint.env_contact_normal = contact_normal_local;
    } else {
      if (joint.env_in_contact && iter == 0) {
        Vector3 velocity = joint.current_tail - joint.prev_tail;
        velocity *= (1.0f - environment_collision_bounce_damping);
        joint.prev_tail = joint.current_tail - velocity;
      }
      joint.env_in_contact = false;
      break;
    }
  }
}
} // namespace godot
