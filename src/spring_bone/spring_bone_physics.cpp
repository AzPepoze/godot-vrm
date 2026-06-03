#include "spring_bone_physics.h"

#include <godot_cpp/core/math.hpp>

namespace godot {

namespace SpringBonePhysics {

Vector3 step_verlet(const VerletState &state, const ForceParams &params,
                    const Vector3 &origin, const Quaternion &local_rot_center) {
  Vector3 inertia =
      (state.current_tail - state.prev_tail) * (1.0f - params.drag);
  Vector3 stiffness_force =
      local_rot_center.xform(state.bone_axis * params.stiffness);
  return state.current_tail + inertia + stiffness_force + params.external_force;
}

Vector3 apply_length_constraint(const Vector3 &tail, const Vector3 &origin,
                                float length) {
  Vector3 diff = tail - origin;
  float current_len = diff.length();

  if (current_len <= 0.00001f) {
    return origin + Vector3(0, -length, 0);
  }

  // ALLOW COMPRESSION: Only enforce the constraint if the bone is stretching.
  // If the bone is compressed (e.g., pushed up by the floor), let it be
  // shorter. This breaks the Tug-of-War between collision push and length
  // constraint.
  if (current_len > length) {
    return origin + (diff / current_len) * length;
  }

  return tail;
}

Quaternion compute_bone_rotation(const Vector3 &bone_axis,
                                 const Vector3 &target_dir) {
  Vector3 axis = bone_axis.cross(target_dir);
  if (axis.is_zero_approx()) {
    return Quaternion();
  }
  float angle = bone_axis.angle_to(target_dir);
  if (angle < 0.00001f) {
    return Quaternion();
  }
  return Quaternion(axis.normalized(), angle);
}

} // namespace SpringBonePhysics

} // namespace godot
