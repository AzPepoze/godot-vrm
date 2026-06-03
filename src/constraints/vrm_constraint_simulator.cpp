#include "vrm_constraint_simulator.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>

namespace godot {

void VRMConstraintSimulator::_bind_methods() {
  ClassDB::bind_method(D_METHOD("setup", "constraints"),
                       &VRMConstraintSimulator::setup);
  ClassDB::bind_method(D_METHOD("set_weight_multiplier", "multiplier"),
                       &VRMConstraintSimulator::set_weight_multiplier);
  ClassDB::bind_method(D_METHOD("get_weight_multiplier"),
                       &VRMConstraintSimulator::get_weight_multiplier);
  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "weight_multiplier"),
               "set_weight_multiplier", "get_weight_multiplier");
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
      Transform3D source_global_transform = _get_source_global_transform(c);
      Transform3D target_global_transform = _get_target_global_transform(c);

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
      float final_weight = c.weight * weight_multiplier;
      if (final_weight != 1.0f) {
        arc = Quaternion().slerp(arc, final_weight);
      }
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
      _set_weighted_posed_target_rotation(c, rotation_quat);
    } else if (c.constraint_type == ROTATION) {
      Transform3D source_transform = _get_posed_source_transform(c);
      Quaternion source_quat = source_transform.basis.get_rotation_quaternion();
      _set_weighted_posed_target_rotation(c, source_quat);
    }
  }
}

} // namespace godot
