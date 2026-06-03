#ifndef SPRING_BONE_FORCES_H
#define SPRING_BONE_FORCES_H

#include "spring_bone_types.h"

#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cstddef>

namespace godot {
namespace SpringBoneForces {
struct JointForces {
  float stiffness = 0.0f;
  float drag = 0.0f;
  Vector3 external;
  float radius = 0.0f;
};

struct ForceContext {
  float delta = 0.0f;
  float stiffness_multiplier = 1.0f;
  float drag_multiplier = 1.0f;
  float hit_radius_multiplier = 1.0f;
  float gravity_multiplier = 1.0f;
  Quaternion gravity_rotation;
  Vector3 add_force;
  Quaternion center_rot_inv;
  Transform3D skel_global_inv;
  Vector3 wind_direction;
  float wind_strength = 0.0f;
  float wind_turbulence = 0.0f;
  float wind_frequency = 1.0f;
  float wind_time = 0.0f;
};

JointForces compute_joint_forces(const SpringBoneTypes::Chain &chain,
                                 size_t joint_index,
                                 const SpringBoneTypes::Joint &joint,
                                 const ForceContext &context);
} // namespace SpringBoneForces
} // namespace godot

#endif // SPRING_BONE_FORCES_H
