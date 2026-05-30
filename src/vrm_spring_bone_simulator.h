#ifndef VRM_SPRING_BONE_SIMULATOR_H
#define VRM_SPRING_BONE_SIMULATOR_H

#include <godot_cpp/classes/immediate_mesh.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/skeleton3d.hpp>
#include <godot_cpp/classes/skeleton_modifier3d.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
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
    Color gizmo_color;
  };

  struct CPPSpringBoneColliderGroup {
    std::vector<int> collider_indices;
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
  std::vector<CPPSpringBoneColliderGroup> all_collider_groups;
  bool is_setup = false;
  bool need_reset = true;

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
  void step_simulation();
  void _process_modification() override;

  int get_chain_count() const;
  int get_joint_count(int p_chain_idx) const;
  Vector3 get_joint_current_tail(int p_chain_idx, int p_joint_idx) const;

  void draw_gizmo(Object *p_mesh_obj, Transform3D p_skel_to_gizmo,
                  Color p_color, bool p_draw_spring_bones,
                  bool p_draw_colliders);

private:
  void _draw_sphere(ImmediateMesh *p_mesh, const Basis &p_bas,
                    const Vector3 &p_center, float p_radius, Color p_color);
  void _draw_line(ImmediateMesh *p_mesh, const Vector3 &p_begin,
                  const Vector3 &p_end, Color p_color);
  void _update_colliders(Skeleton3D *skel);
  Quaternion _from_to_rotation_safe(Vector3 from, Vector3 to);
};

#endif // VRM_SPRING_BONE_SIMULATOR_H
