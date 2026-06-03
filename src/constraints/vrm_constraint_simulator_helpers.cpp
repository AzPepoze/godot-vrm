#include "vrm_constraint_simulator.h"

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/skeleton3d.hpp>

namespace godot {
Transform3D
VRMConstraintSimulator::_get_posed_source_transform(const CPPConstraint &c) {
  if (c.source_bone == -1) {
    return c.source_rest_transform.affine_inverse() *
           c.source_node->get_transform();
  }

  Skeleton3D *skeleton = Object::cast_to<Skeleton3D>(c.source_node);
  if (!skeleton) {
    return Transform3D();
  }

  Transform3D rest_inverse =
      skeleton->get_bone_rest(c.source_bone).affine_inverse();
  return rest_inverse * skeleton->get_bone_pose(c.source_bone);
}

Transform3D
VRMConstraintSimulator::_get_source_global_transform(const CPPConstraint &c) {
  if (c.source_bone == -1) {
    return c.source_node->get_global_transform();
  }

  Skeleton3D *skeleton = Object::cast_to<Skeleton3D>(c.source_node);
  if (!skeleton) {
    return Transform3D();
  }

  Transform3D transform = skeleton->get_bone_global_pose(c.source_bone);
  if (!c.same_skeleton) {
    return skeleton->get_global_transform() * transform;
  }
  return transform;
}

Transform3D
VRMConstraintSimulator::_get_target_global_transform(const CPPConstraint &c) {
  if (c.target_bone == -1) {
    return c.target_node->get_global_transform();
  }

  Skeleton3D *skeleton = Object::cast_to<Skeleton3D>(c.target_node);
  if (!skeleton) {
    return Transform3D();
  }

  Transform3D transform = skeleton->get_bone_global_pose(c.target_bone);
  if (!c.same_skeleton) {
    return skeleton->get_global_transform() * transform;
  }
  return transform;
}

void VRMConstraintSimulator::_set_weighted_posed_target_rotation(
    const CPPConstraint &c, Quaternion rotation_quat) {
  Quaternion final_rotation = rotation_quat;
  float final_weight = c.weight * weight_multiplier;
  if (final_weight != 1.0f) {
    final_rotation = Quaternion().slerp(rotation_quat, final_weight);
  }

  if (c.target_bone == -1) {
    Quaternion rest_quat = c.target_rest_rotation;
    c.target_node->set_quaternion(rest_quat * final_rotation);
    return;
  }

  Skeleton3D *skeleton = Object::cast_to<Skeleton3D>(c.target_node);
  if (skeleton) {
    Quaternion rest_quat = c.target_rest_rotation;
    skeleton->set_bone_pose_rotation(c.target_bone, rest_quat * final_rotation);
  }
}

Vector3
VRMConstraintSimulator::_aim_get_rest_direction(const CPPConstraint &c,
                                                const Basis &rest_basis) {
  switch (c.aim_or_roll_axis) {
  case POSITIVE_X:
    return rest_basis.get_column(0);
  case POSITIVE_Y:
    return rest_basis.get_column(1);
  case POSITIVE_Z:
    return rest_basis.get_column(2);
  case NEGATIVE_X:
    return -rest_basis.get_column(0);
  case NEGATIVE_Y:
    return -rest_basis.get_column(1);
  case NEGATIVE_Z:
    return -rest_basis.get_column(2);
  default:
    return Vector3();
  }
}
} // namespace godot
