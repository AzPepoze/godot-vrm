#ifndef VRM_CONSTRAINT_SIMULATOR_H
#define VRM_CONSTRAINT_SIMULATOR_H

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/skeleton3d.hpp>
#include <godot_cpp/classes/skeleton_modifier3d.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/node_path.hpp>
#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <vector>

using namespace godot;

class VRMConstraintSimulator : public SkeletonModifier3D {
  GDCLASS(VRMConstraintSimulator, SkeletonModifier3D);

public:
  enum ConstraintType {
    NONE = 0,
    AIM = 1,
    ROLL = 2,
    ROTATION = 3,
  };

  enum AimRollAxis {
    AXIS_NONE = 0,
    POSITIVE_X = 1,
    POSITIVE_Y = 2,
    POSITIVE_Z = 3,
    NEGATIVE_X = 4,
    NEGATIVE_Y = 5,
    NEGATIVE_Z = 6,
  };

  struct CPPConstraint {
    ConstraintType constraint_type;
    AimRollAxis aim_or_roll_axis;
    float weight;

    NodePath source_node_path;
    StringName source_bone_name;
    Transform3D source_rest_transform;
    Node3D *source_node;
    int source_bone;

    NodePath target_node_path;
    StringName target_bone_name;
    Transform3D
        source_rest_transform_compat; // Unused but matching fields if needed
    Node3D *target_node;
    int target_bone;

    Quaternion target_rest_rotation;
    Vector3 target_rest_origin;

    bool same_skeleton;
  };

private:
  std::vector<CPPConstraint> constraints;
  bool is_setup = false;

protected:
  static void _bind_methods();

public:
  VRMConstraintSimulator();
  ~VRMConstraintSimulator();

  void setup(Array p_constraints);
  void _process_modification() override;

private:
  Transform3D _get_posed_source_transform(const CPPConstraint &c);
  Transform3D _get_source_global_transform(const CPPConstraint &c,
                                           Skeleton3D *skel);
  Transform3D _get_target_global_transform(const CPPConstraint &c,
                                           Skeleton3D *skel);
  void _set_weighted_posed_target_rotation(const CPPConstraint &c,
                                           Skeleton3D *skel,
                                           Quaternion rotation_quat);
  Vector3 _aim_get_rest_direction(const CPPConstraint &c,
                                  const Basis &rest_basis);
};

#endif // VRM_CONSTRAINT_SIMULATOR_H
