#ifndef SPRING_BONE_UTIL_H
#define SPRING_BONE_UTIL_H

#include "spring_bone_types.h"

#include <godot_cpp/classes/skeleton3d.hpp>

namespace godot {
namespace SpringBoneUtil {

// Compute center transform based on chain config and simulation space mode.
// Used by solver, gizmo, and setup.
static inline Transform3D
get_center_transform(const SpringBoneTypes::Chain &chain, Skeleton3D *skel,
                     const Transform3D &skel_global_inv,
                     bool simulate_in_local_space) {
  if (!simulate_in_local_space) {
    return skel_global_inv;
  }
  if (chain.center_bone != -1) {
    return skel->get_bone_global_pose(chain.center_bone);
  } else if (chain.center_node) {
    return skel_global_inv * chain.center_node->get_global_transform();
  }
  return Transform3D();
}

// Per-joint float parameter lookup with fallback.
static inline float joint_param(const std::vector<float> &arr, size_t idx,
                                float default_val = 1.0f) {
  if (arr.empty())
    return default_val;
  return (idx < arr.size()) ? arr[idx] : arr.back();
}

// Per-joint Vector3 parameter lookup with fallback.
static inline Vector3 joint_param_vec(const std::vector<Vector3> &arr,
                                      size_t idx, const Vector3 &default_val) {
  if (arr.empty())
    return default_val;
  return (idx < arr.size()) ? arr[idx] : arr.back();
}

} // namespace SpringBoneUtil
} // namespace godot

#endif // SPRING_BONE_UTIL_H
