#ifndef SPRING_BONE_TYPES_H
#define SPRING_BONE_TYPES_H

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cstdint>
#include <vector>

namespace godot {
namespace SpringBoneTypes {
struct Joint {
  int bone_idx = -1;
  int parent_idx = -1;
  float length = 0.0f;
  Vector3 bone_axis;
  Vector3 current_tail;
  Vector3 prev_tail;
  Transform3D initial_transform;
  Transform3D global_pose;
  bool env_in_contact = false;
  Vector3 env_contact_normal;
};

struct CollisionImpact {
  Vector3 position;
  Vector3 normal;
  float age = 0.0f;
};

struct Collider {
  int bone_idx = -1;
  Node3D *node = nullptr;
  Vector3 offset;
  Vector3 tail;
  float radius = 0.0f;
  bool is_capsule = false;
  Vector3 position;
  Vector3 tail_position;
  Color gizmo_color;
};

struct ColliderGroup {
  std::vector<int> collider_indices;
};

struct Chain {
  std::vector<Joint> joints;
  std::vector<int> collider_group_indices;

  float stiffness_scale = 1.0f;
  float drag_force_scale = 1.0f;
  float hit_radius_scale = 1.0f;
  float gravity_scale = 1.0f;
  Vector3 gravity_dir_default = Vector3(0, -1, 0);

  std::vector<float> stiffness_force;
  std::vector<float> gravity_power;
  std::vector<Vector3> gravity_dir;
  std::vector<float> drag_force;
  std::vector<float> hit_radius;

  Node3D *center_node = nullptr;
  int center_bone = -1;

  bool enable_environment_collision = false;
  uint32_t environment_collision_mask = 1;
};
} // namespace SpringBoneTypes
} // namespace godot

#endif // SPRING_BONE_TYPES_H
