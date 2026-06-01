#ifndef VRM_SPRING_BONE_SIMULATION_H
#define VRM_SPRING_BONE_SIMULATION_H

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

namespace godot {

class VRMSpringBoneSimulation : public SkeletonModifier3D {
  GDCLASS(VRMSpringBoneSimulation, SkeletonModifier3D);

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
    // Environment collision contact state (center-local space)
    bool env_in_contact = false;
    Vector3 env_contact_normal;
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

    // Game Object Collision settings (per chain)
    bool enable_environment_collision = false;
    uint32_t environment_collision_mask = 1;
  };

private:
  std::vector<CPPSpringBoneChain> chains;
  std::vector<CPPSpringBoneCollider> all_colliders;
  std::vector<CPPSpringBoneColliderGroup> all_collider_groups;
  bool is_setup = false;
  bool need_reset = true;

  float gravity_multiplier = 1.0f;
  float stiffness_multiplier = 1.0f;
  float drag_multiplier = 1.0f;
  float hit_radius_multiplier = 1.0f;
  bool simulate_in_local_space = false;
  Quaternion gravity_rotation;
  Vector3 add_force;

  // Wind System Global settings
  Vector3 wind_direction = Vector3(0, 0, 0);
  float wind_strength = 0.0f;
  float wind_turbulence = 0.0f;
  float wind_frequency = 1.0f;
  float wind_time = 0.0f;

  // Environment Collision Global switches/options
  bool environment_collision_enabled = false;
  uint32_t environment_collision_mask = 1;
  float environment_collision_bounce_damping = 0.8f;

protected:
  static void _bind_methods();

public:
  VRMSpringBoneSimulation();
  ~VRMSpringBoneSimulation();

  void setup(Array p_spring_bones, Array p_collider_groups);
  void update_parameters(float p_gravity_multiplier,
                         Quaternion p_gravity_rotation, Vector3 p_add_force,
                         float p_stiffness_multiplier = 1.0f,
                         float p_drag_multiplier = 1.0f,
                         float p_hit_radius_multiplier = 1.0f);
  void step_simulation();
  void _process_modification() override;

  int get_chain_count() const;
  int get_joint_count(int p_chain_idx) const;
  Vector3 get_joint_current_tail(int p_chain_idx, int p_joint_idx) const;

  void draw_gizmo(Object *p_mesh_obj, Transform3D p_skel_to_gizmo,
                  Color p_color, bool p_draw_spring_bones,
                  bool p_draw_colliders);

  // Getters/Setters for Multipliers
  void set_stiffness_multiplier(float p_multiplier) {
    stiffness_multiplier = p_multiplier;
  }
  float get_stiffness_multiplier() const { return stiffness_multiplier; }
  void set_drag_multiplier(float p_multiplier) {
    drag_multiplier = p_multiplier;
  }
  float get_drag_multiplier() const { return drag_multiplier; }
  void set_hit_radius_multiplier(float p_multiplier) {
    hit_radius_multiplier = p_multiplier;
  }
  float get_hit_radius_multiplier() const { return hit_radius_multiplier; }

  void set_simulate_in_local_space(bool p_enabled) {
    simulate_in_local_space = p_enabled;
  }
  bool get_simulate_in_local_space() const { return simulate_in_local_space; }

  // Getters/Setters for Wind parameters
  void set_wind_direction(Vector3 p_dir);
  Vector3 get_wind_direction() const;

  void set_wind_strength(float p_strength);
  float get_wind_strength() const;

  void set_wind_turbulence(float p_turbulence);
  float get_wind_turbulence() const;

  void set_wind_frequency(float p_frequency);
  float get_wind_frequency() const;

  // Getters/Setters for Environment Collision parameters
  void set_environment_collision_enabled(bool p_enabled);
  bool is_environment_collision_enabled() const;

  void set_environment_collision_mask(uint32_t p_mask);
  uint32_t get_environment_collision_mask() const;

  void set_environment_collision_bounce_damping(float p_damping);
  float get_environment_collision_bounce_damping() const;

private:
  void _update_colliders(Skeleton3D *skel);
  void _reset_chains(Skeleton3D *skel, const Transform3D &skel_global_inv);
  void _simulate_chains(Skeleton3D *skel, const Transform3D &skel_global_inv,
                        float delta);
  void _query_game_object_collisions(Skeleton3D *skel,
                                     const Vector3 &origin_world,
                                     const Vector3 &tail_world, float radius,
                                     uint32_t mask, Vector3 &out_push);
};

} // namespace godot

#endif // VRM_SPRING_BONE_SIMULATION_H
