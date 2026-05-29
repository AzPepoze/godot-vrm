#ifndef VRM_SPRING_BONE_SIMULATOR_H
#define VRM_SPRING_BONE_SIMULATOR_H

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

class VRMSpringBoneSimulator : public SkeletonModifier3D {
  GDCLASS(VRMSpringBoneSimulator, SkeletonModifier3D);

public:
  struct CPPSpringBoneJoint {
    int bone_idx = -1;
    int parent_idx = -1;
    float radius = 0.0f;
    float length = 0.0f;
    Vector3 bone_axis;
    Vector3 current_tail;
    Vector3 prev_tail;
    Transform3D initial_transform;
    Transform3D global_pose;
  };

  struct CPPSpringBoneCollider {
    int bone_idx = -1;
    Node3D *node = nullptr;
    Vector3 offset;
    Vector3 tail; // For capsule
    float radius = 0.0f;
    bool is_capsule = false;
    Vector3 position;
    Vector3 tail_position;
  };

  struct CPPSpringBoneChain {
    std::vector<CPPSpringBoneJoint> joints;
    std::vector<int> collider_group_indices;

    float stiffness_scale = 1.0f;
    float drag_force_scale = 1.0f;
    float hit_radius_scale = 1.0f;
    float gravity_scale = 1.0f;
    Vector3 gravity_dir_default = Vector3(0, -1, 0);

    // Per-joint arrays (if provided)
    std::vector<float> stiffness_force;
    std::vector<float> gravity_power;
    std::vector<Vector3> gravity_dir;
    std::vector<float> drag_force;
    std::vector<float> hit_radius;

    Node3D *center_node = nullptr;
    int center_bone = -1;
  };

private:
  std::vector<CPPSpringBoneChain> chains;
  std::vector<CPPSpringBoneCollider> all_colliders;
  bool is_setup = false;

  float gravity_multiplier = 1.0f;
  Quaternion gravity_rotation;
  Vector3 add_force;

protected:
  static void _bind_methods();

public:
  VRMSpringBoneSimulator();
  ~VRMSpringBoneSimulator();

  void setup(Array p_spring_bones, Array p_collider_groups);
  void update_parameters(float p_gravity_multiplier,
                         Quaternion p_gravity_rotation, Vector3 p_add_force);
  void _process_modification() override;

private:
  void _update_colliders(Skeleton3D *skel);
  Quaternion _from_to_rotation_safe(Vector3 from, Vector3 to);
};

#endif // VRM_SPRING_BONE_SIMULATOR_H
