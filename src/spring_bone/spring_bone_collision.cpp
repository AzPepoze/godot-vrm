#include "spring_bone_collision.h"

#include <godot_cpp/core/math.hpp>

namespace godot {

namespace SpringBoneCollision {

Vector3 closest_point_on_capsule(const Vector3 &head, const Vector3 &tail,
                                 const Vector3 &point) {
  Vector3 P = tail - head;
  Vector3 Q = point - head;
  float p_len_sq = P.length_squared();
  if (p_len_sq <= 0.00001f) {
    return head;
  }
  float dot = P.dot(Q);
  float t = CLAMP(dot / p_len_sq, 0.0f, 1.0f);
  return head + P * t;
}

Vector3 resolve_sphere_collision(const Vector3 &tail, const Vector3 &origin,
                                 const Vector3 &collider_pos,
                                 float joint_radius, float collider_radius,
                                 float joint_length) {
  Vector3 diff = tail - collider_pos;
  float r = joint_radius + collider_radius;
  if (diff.length_squared() <= r * r) {
    Vector3 normal = diff.normalized();
    if (normal.is_zero_approx()) {
      normal = Vector3(0, 1, 0);
    }
    Vector3 pos_from_collider = collider_pos + normal * r;
    Vector3 new_diff = pos_from_collider - origin;
    if (new_diff.is_zero_approx()) {
      return origin + Vector3(0, -joint_length, 0);
    }
    return origin + new_diff.normalized() * joint_length;
  }
  return tail;
}

Vector3 resolve_capsule_collision(const Vector3 &tail, const Vector3 &origin,
                                  const Vector3 &capsule_head,
                                  const Vector3 &capsule_tail,
                                  float joint_radius, float collider_radius,
                                  float joint_length) {
  Vector3 coll_pos = closest_point_on_capsule(capsule_head, capsule_tail, tail);
  return resolve_sphere_collision(tail, origin, coll_pos, joint_radius,
                                  collider_radius, joint_length);
}

Vector3 resolve_all_colliders(const Vector3 &tail, const Vector3 &origin,
                              float joint_radius, float joint_length,
                              const std::vector<ColliderView> &colliders) {

  Vector3 result = tail;
  for (const auto &cv : colliders) {
    if (cv.is_capsule) {
      if (!broad_phase_capsule_check(origin, joint_length, joint_radius,
                                     cv.position, cv.tail_position,
                                     cv.radius)) {
        continue;
      }
      result = resolve_capsule_collision(result, origin, cv.position,
                                         cv.tail_position, joint_radius,
                                         cv.radius, joint_length);
    } else {
      if (!broad_phase_check(origin, joint_length, joint_radius, cv.position,
                             cv.radius)) {
        continue;
      }
      result = resolve_sphere_collision(result, origin, cv.position,
                                        joint_radius, cv.radius, joint_length);
    }
  }
  return result;
}

} // namespace SpringBoneCollision

} // namespace godot
