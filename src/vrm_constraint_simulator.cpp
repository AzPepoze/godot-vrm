#include "vrm_constraint_simulator.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>

using namespace godot;

void VRMConstraintSimulator::_bind_methods() {
  ClassDB::bind_method(D_METHOD("setup", "constraints"),
                       &VRMConstraintSimulator::setup);
}

VRMConstraintSimulator::VRMConstraintSimulator() {}

VRMConstraintSimulator::~VRMConstraintSimulator() {}

void VRMConstraintSimulator::setup(Array p_constraints) {
  constraints.clear();
  is_setup = false;

  for (int i = 0; i < p_constraints.size(); ++i) {
    Ref<Resource> res = p_constraints[i];
    if (res.is_null()) {
      continue;
    }

    CPPConstraint c;
    c.constraint_type = (ConstraintType)(int)res->get("constraint_type");
    c.aim_or_roll_axis = (AimRollAxis)(int)res->get("aim_or_roll_axis");
    c.weight = (float)res->get("weight");

    c.source_node_path = res->get("source_node_path");
    c.source_bone_name = res->get("source_bone_name");
    c.source_rest_transform = res->get("source_rest_transform");
    c.source_node = Object::cast_to<Node3D>(res->get("source_node"));
    c.source_bone = (int)res->get("source_bone");

    c.target_node_path = res->get("target_node_path");
    c.target_bone_name = res->get("target_bone_name");
    c.target_node = Object::cast_to<Node3D>(res->get("target_node"));
    c.target_bone = (int)res->get("target_bone");

    c.target_rest_rotation = res->get("target_rest_rotation");
    c.target_rest_origin = res->get("target_rest_origin");

    c.same_skeleton = (bool)res->get("same_skeleton");

    constraints.push_back(c);
  }

  is_setup = true;
}

void VRMConstraintSimulator::_process_modification() {
  Skeleton3D *skel = get_skeleton();
  if (!skel || !is_setup) {
    return;
  }

  for (const auto &c : constraints) {
    if (!c.source_node || !c.target_node) {
      continue;
    }

    if (c.constraint_type == AIM) {
      Transform3D source_global_transform =
          _get_source_global_transform(c, skel);
      Transform3D target_global_transform =
          _get_target_global_transform(c, skel);

      if (c.target_bone != -1) {
        Skeleton3D *t_skel = Object::cast_to<Skeleton3D>(c.target_node);
        if (t_skel) {
          target_global_transform =
              target_global_transform *
              t_skel->get_bone_pose(c.target_bone).affine_inverse();
        }
      }

      Transform3D target_rest_transform = Transform3D();
      if (c.target_bone != -1) {
        Skeleton3D *t_skel = Object::cast_to<Skeleton3D>(c.target_node);
        if (t_skel) {
          target_rest_transform = t_skel->get_bone_rest(c.target_bone);
        }
      }

      Transform3D relative_source_transform =
          target_global_transform.affine_inverse() * source_global_transform *
          c.source_rest_transform;
      Vector3 rest_dir =
          _aim_get_rest_direction(c, target_rest_transform.basis);
      Vector3 aim_dir =
          (relative_source_transform.origin - c.target_rest_origin)
              .normalized();

      Quaternion arc = Quaternion(rest_dir, aim_dir).normalized();
      if (c.target_bone != -1) {
        Skeleton3D *t_skel = Object::cast_to<Skeleton3D>(c.target_node);
        if (t_skel) {
          t_skel->set_bone_pose_rotation(
              c.target_bone,
              target_rest_transform.basis.get_rotation_quaternion() * arc);
        }
      }
    } else if (c.constraint_type == ROLL) {
      if (c.aim_or_roll_axis < POSITIVE_X || c.aim_or_roll_axis > POSITIVE_Z) {
        continue;
      }
      Transform3D source_transform = _get_posed_source_transform(c);
      Quaternion source_quat = source_transform.basis.get_rotation_quaternion();
      Vector3 source_axis = source_quat.get_axis();
      float source_angle = source_quat.get_angle();

      int axis_index = (int)c.aim_or_roll_axis - 1;
      float axis_value = source_axis[axis_index];
      Quaternion rotation_quat = Quaternion();
      if (axis_value > 0.00001f || axis_value < -0.00001f) {
        Vector3 target_axis = Vector3();
        target_axis[axis_index] = 1.0f;
        rotation_quat = Quaternion(target_axis, source_angle * axis_value);
      }
      _set_weighted_posed_target_rotation(c, skel, rotation_quat);
    } else if (c.constraint_type == ROTATION) {
      Transform3D source_transform = _get_posed_source_transform(c);
      Quaternion source_quat = source_transform.basis.get_rotation_quaternion();
      _set_weighted_posed_target_rotation(c, skel, source_quat);
    }
  }
}

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
VRMConstraintSimulator::_get_source_global_transform(const CPPConstraint &c,
                                                     Skeleton3D *skel) {
  if (c.source_bone == -1) {
    return c.source_node->get_global_transform();
  }
  Skeleton3D *skeleton = Object::cast_to<Skeleton3D>(c.source_node);
  if (!skeleton) {
    return Transform3D();
  }
  Transform3D ret = skeleton->get_bone_global_pose(c.source_bone);
  if (!c.same_skeleton) {
    return skeleton->get_global_transform() * ret;
  }
  return ret;
}

Transform3D
VRMConstraintSimulator::_get_target_global_transform(const CPPConstraint &c,
                                                     Skeleton3D *skel) {
  if (c.target_bone == -1) {
    return c.target_node->get_global_transform();
  }
  Skeleton3D *skeleton = Object::cast_to<Skeleton3D>(c.target_node);
  if (!skeleton) {
    return Transform3D();
  }
  Transform3D ret = skeleton->get_bone_global_pose(c.target_bone);
  if (!c.same_skeleton) {
    return skeleton->get_global_transform() * ret;
  }
  return ret;
}

void VRMConstraintSimulator::_set_weighted_posed_target_rotation(
    const CPPConstraint &c, Skeleton3D *skel, Quaternion rotation_quat) {
  Quaternion final_rotation = rotation_quat;
  if (c.weight != 1.0f) {
    final_rotation = Quaternion().slerp(rotation_quat, c.weight);
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
    break;
  }
  return Vector3();
}
