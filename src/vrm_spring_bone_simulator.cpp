#include "vrm_spring_bone_simulator.h"
#include "spring_bone_collision.h"
#include "spring_bone_gizmo.h"
#include "spring_bone_physics.h"
#include "spring_bone_setup.h"
#include "spring_bone_wind.h"

#include <godot_cpp/classes/collision_object3d.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/physics_shape_query_parameters3d.hpp>
#include <godot_cpp/classes/sphere_shape3d.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>

namespace godot {

// ---------------------------------------------------------------------------
// Per-joint parameter lookup: returns per-joint value if available, else the
// last entry, else 1.0 (or default_val).
// ---------------------------------------------------------------------------
static float joint_param(const std::vector<float> &arr, size_t idx,
                         float default_val = 1.0f) {
  if (arr.empty()) {
    return default_val;
  }
  return (idx < arr.size()) ? arr[idx] : arr.back();
}

static Vector3 joint_param_vec(const std::vector<Vector3> &arr, size_t idx,
                               const Vector3 &default_val) {
  if (arr.empty()) {
    return default_val;
  }
  return (idx < arr.size()) ? arr[idx] : arr.back();
}

// ---------------------------------------------------------------------------
// Compute the center_transform in skeleton-local space for a given chain.
// ---------------------------------------------------------------------------
static Transform3D
get_center_transform(const VRMSpringBoneSimulator::CPPSpringBoneChain &chain,
                     Skeleton3D *skel, const Transform3D &skel_global_inv) {
  if (chain.center_bone != -1) {
    return skel->get_bone_global_pose(chain.center_bone);
  } else if (chain.center_node) {
    return skel_global_inv * chain.center_node->get_global_transform();
  }
  return Transform3D();
}

// ---------------------------------------------------------------------------
// Build a flat list of ColliderViews in center space for the given chain.
// ---------------------------------------------------------------------------
static std::vector<SpringBoneCollision::ColliderView> gather_collider_views(
    const VRMSpringBoneSimulator::CPPSpringBoneChain &chain,
    const std::vector<VRMSpringBoneSimulator::CPPSpringBoneCollider>
        &all_colliders,
    const std::vector<VRMSpringBoneSimulator::CPPSpringBoneColliderGroup>
        &all_groups,
    const Transform3D &center_inv) {

  std::vector<SpringBoneCollision::ColliderView> views;
  for (int group_idx : chain.collider_group_indices) {
    if (group_idx < 0 || group_idx >= (int)all_groups.size()) {
      continue;
    }
    for (int coll_idx : all_groups[group_idx].collider_indices) {
      const auto &coll = all_colliders[coll_idx];
      SpringBoneCollision::ColliderView cv;
      cv.position = center_inv.xform(coll.position);
      cv.radius = coll.radius;
      cv.is_capsule = coll.is_capsule;
      if (coll.is_capsule) {
        cv.tail_position = center_inv.xform(coll.tail_position);
      }
      views.push_back(cv);
    }
  }
  return views;
}

// ---------------------------------------------------------------------------
// Binding
// ---------------------------------------------------------------------------
void VRMSpringBoneSimulator::_bind_methods() {
  ClassDB::bind_method(D_METHOD("setup", "spring_bones", "collider_groups"),
                       &VRMSpringBoneSimulator::setup);
  ClassDB::bind_method(D_METHOD("update_parameters", "gravity_multiplier",
                                "gravity_rotation", "add_force",
                                "stiffness_multiplier", "drag_multiplier",
                                "hit_radius_multiplier"),
                       &VRMSpringBoneSimulator::update_parameters, DEFVAL(1.0f),
                       DEFVAL(1.0f), DEFVAL(1.0f));
  ClassDB::bind_method(D_METHOD("step_simulation"),
                       &VRMSpringBoneSimulator::step_simulation);

  ClassDB::bind_method(D_METHOD("set_stiffness_multiplier", "multiplier"),
                       &VRMSpringBoneSimulator::set_stiffness_multiplier);
  ClassDB::bind_method(D_METHOD("get_stiffness_multiplier"),
                       &VRMSpringBoneSimulator::get_stiffness_multiplier);
  ClassDB::bind_method(D_METHOD("set_drag_multiplier", "multiplier"),
                       &VRMSpringBoneSimulator::set_drag_multiplier);
  ClassDB::bind_method(D_METHOD("get_drag_multiplier"),
                       &VRMSpringBoneSimulator::get_drag_multiplier);
  ClassDB::bind_method(D_METHOD("set_hit_radius_multiplier", "multiplier"),
                       &VRMSpringBoneSimulator::set_hit_radius_multiplier);
  ClassDB::bind_method(D_METHOD("get_hit_radius_multiplier"),
                       &VRMSpringBoneSimulator::get_hit_radius_multiplier);

  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "stiffness_multiplier"),
               "set_stiffness_multiplier", "get_stiffness_multiplier");
  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "drag_multiplier"),
               "set_drag_multiplier", "get_drag_multiplier");
  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "hit_radius_multiplier"),
               "set_hit_radius_multiplier", "get_hit_radius_multiplier");
  ClassDB::bind_method(D_METHOD("get_chain_count"),
                       &VRMSpringBoneSimulator::get_chain_count);
  ClassDB::bind_method(D_METHOD("get_joint_count", "chain_idx"),
                       &VRMSpringBoneSimulator::get_joint_count);
  ClassDB::bind_method(
      D_METHOD("get_joint_current_tail", "chain_idx", "joint_idx"),
      &VRMSpringBoneSimulator::get_joint_current_tail);
  ClassDB::bind_method(D_METHOD("draw_gizmo", "mesh", "skel_to_gizmo", "color",
                                "draw_spring_bones", "draw_colliders"),
                       &VRMSpringBoneSimulator::draw_gizmo);

  // Wind
  ClassDB::bind_method(D_METHOD("set_wind_direction", "direction"),
                       &VRMSpringBoneSimulator::set_wind_direction);
  ClassDB::bind_method(D_METHOD("get_wind_direction"),
                       &VRMSpringBoneSimulator::get_wind_direction);
  ClassDB::bind_method(D_METHOD("set_wind_strength", "strength"),
                       &VRMSpringBoneSimulator::set_wind_strength);
  ClassDB::bind_method(D_METHOD("get_wind_strength"),
                       &VRMSpringBoneSimulator::get_wind_strength);
  ClassDB::bind_method(D_METHOD("set_wind_turbulence", "turbulence"),
                       &VRMSpringBoneSimulator::set_wind_turbulence);
  ClassDB::bind_method(D_METHOD("get_wind_turbulence"),
                       &VRMSpringBoneSimulator::get_wind_turbulence);
  ClassDB::bind_method(D_METHOD("set_wind_frequency", "frequency"),
                       &VRMSpringBoneSimulator::set_wind_frequency);
  ClassDB::bind_method(D_METHOD("get_wind_frequency"),
                       &VRMSpringBoneSimulator::get_wind_frequency);

  // Environment Collision
  ClassDB::bind_method(
      D_METHOD("set_environment_collision_enabled", "enabled"),
      &VRMSpringBoneSimulator::set_environment_collision_enabled);
  ClassDB::bind_method(
      D_METHOD("is_environment_collision_enabled"),
      &VRMSpringBoneSimulator::is_environment_collision_enabled);
  ClassDB::bind_method(D_METHOD("set_environment_collision_mask", "mask"),
                       &VRMSpringBoneSimulator::set_environment_collision_mask);
  ClassDB::bind_method(D_METHOD("get_environment_collision_mask"),
                       &VRMSpringBoneSimulator::get_environment_collision_mask);

  ADD_GROUP("Wind Settings", "wind_");
  ADD_PROPERTY(PropertyInfo(Variant::VECTOR3, "wind_direction"),
               "set_wind_direction", "get_wind_direction");
  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "wind_strength"),
               "set_wind_strength", "get_wind_strength");
  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "wind_turbulence"),
               "set_wind_turbulence", "get_wind_turbulence");
  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "wind_frequency"),
               "set_wind_frequency", "get_wind_frequency");

  ADD_GROUP("Environment Collision Settings", "environment_collision_");
  ADD_PROPERTY(PropertyInfo(Variant::BOOL, "environment_collision_enabled"),
               "set_environment_collision_enabled",
               "is_environment_collision_enabled");
  ADD_PROPERTY(PropertyInfo(Variant::INT, "environment_collision_mask"),
               "set_environment_collision_mask",
               "get_environment_collision_mask");
}

VRMSpringBoneSimulator::VRMSpringBoneSimulator() {}
VRMSpringBoneSimulator::~VRMSpringBoneSimulator() {}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------
void VRMSpringBoneSimulator::update_parameters(float p_gravity_multiplier,
                                               Quaternion p_gravity_rotation,
                                               Vector3 p_add_force,
                                               float p_stiffness_multiplier,
                                               float p_drag_multiplier,
                                               float p_hit_radius_multiplier) {
  gravity_multiplier = p_gravity_multiplier;
  gravity_rotation = p_gravity_rotation;
  add_force = p_add_force;
  stiffness_multiplier = p_stiffness_multiplier;
  drag_multiplier = p_drag_multiplier;
  hit_radius_multiplier = p_hit_radius_multiplier;
}

void VRMSpringBoneSimulator::step_simulation() { _process_modification(); }

void VRMSpringBoneSimulator::setup(Array p_spring_bones,
                                   Array p_collider_groups) {
  chains.clear();
  all_colliders.clear();
  all_collider_groups.clear();
  is_setup = false;

  Skeleton3D *skel = get_skeleton();
  if (!skel) {
    return;
  }

  SpringBoneSetup::parse_collider_groups(p_collider_groups, skel, this,
                                         all_colliders, all_collider_groups);
  SpringBoneSetup::parse_spring_bones(p_spring_bones, p_collider_groups, skel,
                                      this, chains);

  is_setup = true;
  need_reset = true;
}

// ---------------------------------------------------------------------------
// Simulation
// ---------------------------------------------------------------------------
void VRMSpringBoneSimulator::_process_modification() {
  Skeleton3D *skel = get_skeleton();
  if (!skel || !is_setup) {
    return;
  }

  float delta = (float)get_process_delta_time();
  if (delta <= 0.0001f) {
    delta = 0.016666f;
  }

  wind_time += delta;
  _update_colliders(skel);

  Transform3D skel_global_inv = skel->get_global_transform().affine_inverse();

  if (need_reset) {
    _reset_chains(skel, skel_global_inv);
    need_reset = false;
  }

  _simulate_chains(skel, skel_global_inv, delta);
}

void VRMSpringBoneSimulator::_reset_chains(Skeleton3D *skel,
                                           const Transform3D &skel_global_inv) {
  static const int PUSH_OUT_PASSES = 4;

  for (auto &chain : chains) {
    Transform3D center = get_center_transform(chain, skel, skel_global_inv);
    Transform3D center_inv = center.affine_inverse();

    // Reset tail positions to rest pose
    for (auto &joint : chain.joints) {
      if (joint.parent_idx == -1) {
        joint.initial_transform = skel->get_bone_pose(joint.bone_idx);
      } else {
        joint.initial_transform = skel->get_bone_global_pose(joint.parent_idx) *
                                  skel->get_bone_pose(joint.bone_idx);
      }
      joint.global_pose = joint.initial_transform;
      Vector3 world_child =
          joint.initial_transform.xform(joint.bone_axis * joint.length);
      joint.current_tail = center_inv.xform(world_child);
      joint.prev_tail = joint.current_tail;
    }

    // Push-out pass: resolve initial collider penetration
    auto collider_views = gather_collider_views(
        chain, all_colliders, all_collider_groups, center_inv);
    for (int pass = 0; pass < PUSH_OUT_PASSES; ++pass) {
      for (size_t i = 0; i < chain.joints.size(); ++i) {
        auto &joint = chain.joints[i];
        Vector3 origin = center_inv.xform(joint.global_pose.origin);
        float radius =
            chain.hit_radius_scale * joint_param(chain.hit_radius, i);
        joint.current_tail = SpringBoneCollision::resolve_all_colliders(
            joint.current_tail, origin, radius, joint.length, collider_views);
        joint.prev_tail = joint.current_tail;
      }
    }
  }
}

void VRMSpringBoneSimulator::_simulate_chains(
    Skeleton3D *skel, const Transform3D &skel_global_inv, float delta) {
  for (auto &chain : chains) {
    Transform3D center = get_center_transform(chain, skel, skel_global_inv);
    Transform3D center_inv = center.affine_inverse();
    Quaternion center_rot = center.basis.get_rotation_quaternion();
    Quaternion center_rot_inv = center_rot.inverse();

    auto collider_views = gather_collider_views(
        chain, all_colliders, all_collider_groups, center_inv);

    for (size_t i = 0; i < chain.joints.size(); ++i) {
      auto &joint = chain.joints[i];

      // Per-joint parameters
      float stiffness = stiffness_multiplier * chain.stiffness_scale * delta *
                        joint_param(chain.stiffness_force, i);
      float drag = drag_multiplier * chain.drag_force_scale *
                   joint_param(chain.drag_force, i);
      float grav_pow = joint_param(chain.gravity_power, i);
      Vector3 grav_dir =
          joint_param_vec(chain.gravity_dir, i, chain.gravity_dir_default);
      float radius = hit_radius_multiplier * chain.hit_radius_scale *
                     joint_param(chain.hit_radius, i);

      // External forces
      Vector3 total_gravity =
          gravity_rotation.xform(grav_dir * grav_pow * gravity_multiplier);
      Vector3 external =
          center_rot_inv.xform(total_gravity * delta * chain.gravity_scale) +
          (add_force * delta);

      // Wind
      if (wind_strength > 0.0001f) {
        SpringBoneWind::WindParams wp;
        wp.direction = wind_direction;
        wp.strength = wind_strength;
        wp.turbulence = wind_turbulence;
        wp.frequency = wind_frequency;
        Vector3 wind_val = SpringBoneWind::compute_wind_force(
            wp, joint.current_tail, wind_time,
            (int)joint.bone_idx + (int)i * 100);
        external += center_rot_inv.xform(wind_val * delta);
      }

      // Update global pose from skeleton
      if (joint.parent_idx == -1) {
        joint.global_pose = skel->get_bone_pose(joint.bone_idx);
      } else {
        joint.global_pose = skel->get_bone_global_pose(joint.parent_idx) *
                            skel->get_bone_pose(joint.bone_idx);
      }

      Vector3 origin = center_inv.xform(joint.global_pose.origin);
      Quaternion local_rot_center =
          center_rot_inv * joint.global_pose.basis.get_rotation_quaternion();

      // Verlet step
      SpringBonePhysics::VerletState vs{joint.current_tail, joint.prev_tail,
                                        joint.length, joint.bone_axis};
      SpringBonePhysics::ForceParams fp{stiffness, drag, external};
      Vector3 next_tail =
          SpringBonePhysics::step_verlet(vs, fp, origin, local_rot_center);
      next_tail = SpringBonePhysics::apply_length_constraint(next_tail, origin,
                                                             joint.length);

      // VRM Colliders
      next_tail = SpringBoneCollision::resolve_all_colliders(
          next_tail, origin, radius, joint.length, collider_views);

      // Environment collision (optional)
      if (environment_collision_enabled && chain.enable_environment_collision) {
        Vector3 env_push;
        _query_game_object_collisions(skel, center.xform(next_tail), radius,
                                      chain.environment_collision_mask,
                                      env_push);
        if (!env_push.is_zero_approx()) {
          next_tail += center_inv.basis.xform(env_push);
          next_tail = SpringBonePhysics::apply_length_constraint(
              next_tail, origin, joint.length);
        }
      }

      joint.prev_tail = joint.current_tail;
      joint.current_tail = next_tail;

      // Apply rotation to skeleton
      Transform3D tf = joint.global_pose;
      Vector3 local_target_dir =
          tf.affine_inverse()
              .basis.xform(center.xform(next_tail) - tf.origin)
              .normalized();
      Quaternion rot_diff = SpringBonePhysics::compute_bone_rotation(
          joint.bone_axis, local_target_dir);
      if (rot_diff != Quaternion()) {
        Quaternion new_rot = tf.basis.get_rotation_quaternion() * rot_diff;
        joint.global_pose.basis = Basis(new_rot).scaled(tf.basis.get_scale());
        skel->set_bone_global_pose(joint.bone_idx, joint.global_pose);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Collider position update
// ---------------------------------------------------------------------------
void VRMSpringBoneSimulator::_update_colliders(Skeleton3D *skel) {
  Transform3D skel_global_inv = skel->get_global_transform().affine_inverse();
  for (auto &c : all_colliders) {
    Transform3D tf;
    if (c.bone_idx != -1) {
      tf = skel->get_bone_global_pose(c.bone_idx);
    } else if (c.node) {
      tf = skel_global_inv * c.node->get_global_transform();
    } else {
      continue;
    }
    c.position = tf.xform(c.offset);
    if (c.is_capsule) {
      c.tail_position = tf.xform(c.tail);
    }
  }
}

// ---------------------------------------------------------------------------
// Accessors
// ---------------------------------------------------------------------------
int VRMSpringBoneSimulator::get_chain_count() const {
  return (int)chains.size();
}

int VRMSpringBoneSimulator::get_joint_count(int p_chain_idx) const {
  if (p_chain_idx < 0 || p_chain_idx >= (int)chains.size())
    return 0;
  return (int)chains[p_chain_idx].joints.size();
}

Vector3 VRMSpringBoneSimulator::get_joint_current_tail(int p_chain_idx,
                                                       int p_joint_idx) const {
  if (p_chain_idx < 0 || p_chain_idx >= (int)chains.size())
    return Vector3();
  const auto &chain = chains[p_chain_idx];
  if (p_joint_idx < 0 || p_joint_idx >= (int)chain.joints.size())
    return Vector3();
  return chain.joints[p_joint_idx].current_tail;
}

void VRMSpringBoneSimulator::draw_gizmo(Object *p_mesh_obj,
                                        Transform3D p_skel_to_gizmo,
                                        Color p_color, bool p_draw_spring_bones,
                                        bool p_draw_colliders) {
  ImmediateMesh *mesh = Object::cast_to<ImmediateMesh>(p_mesh_obj);
  Skeleton3D *skel = get_skeleton();
  SpringBoneGizmo::draw_gizmo(mesh, skel, p_skel_to_gizmo, chains,
                              all_colliders, p_color, p_draw_spring_bones,
                              p_draw_colliders);
}

// ---------------------------------------------------------------------------
// Wind property accessors
// ---------------------------------------------------------------------------
void VRMSpringBoneSimulator::set_wind_direction(Vector3 p_dir) {
  wind_direction = p_dir;
}
Vector3 VRMSpringBoneSimulator::get_wind_direction() const {
  return wind_direction;
}
void VRMSpringBoneSimulator::set_wind_strength(float p_strength) {
  wind_strength = p_strength;
}
float VRMSpringBoneSimulator::get_wind_strength() const {
  return wind_strength;
}
void VRMSpringBoneSimulator::set_wind_turbulence(float p_turbulence) {
  wind_turbulence = p_turbulence;
}
float VRMSpringBoneSimulator::get_wind_turbulence() const {
  return wind_turbulence;
}
void VRMSpringBoneSimulator::set_wind_frequency(float p_frequency) {
  wind_frequency = p_frequency;
}
float VRMSpringBoneSimulator::get_wind_frequency() const {
  return wind_frequency;
}

// ---------------------------------------------------------------------------
// Environment collision property accessors
// ---------------------------------------------------------------------------
void VRMSpringBoneSimulator::set_environment_collision_enabled(bool p_enabled) {
  environment_collision_enabled = p_enabled;
}
bool VRMSpringBoneSimulator::is_environment_collision_enabled() const {
  return environment_collision_enabled;
}
void VRMSpringBoneSimulator::set_environment_collision_mask(uint32_t p_mask) {
  environment_collision_mask = p_mask;
}
uint32_t VRMSpringBoneSimulator::get_environment_collision_mask() const {
  return environment_collision_mask;
}

// ---------------------------------------------------------------------------
// PhysicsServer3D query for game object collision
// ---------------------------------------------------------------------------
void VRMSpringBoneSimulator::_query_game_object_collisions(
    Skeleton3D *skel, const Vector3 &tail_world, float radius, uint32_t mask,
    Vector3 &out_push) {
  out_push = Vector3();
  if (!skel)
    return;

  Ref<World3D> world = skel->get_world_3d();
  if (world.is_null())
    return;

  PhysicsDirectSpaceState3D *space_state = world->get_direct_space_state();
  if (!space_state)
    return;

  Ref<SphereShape3D> shape;
  shape.instantiate();
  shape->set_radius(radius);

  Ref<PhysicsShapeQueryParameters3D> params;
  params.instantiate();
  params->set_shape(shape);
  params->set_transform(Transform3D(Basis(), tail_world));
  params->set_collision_mask(mask);

  // Exclude the model's own collision objects
  TypedArray<RID> exclude;
  Node *parent = skel->get_parent();
  if (parent) {
    CollisionObject3D *co = Object::cast_to<CollisionObject3D>(parent);
    if (co) {
      exclude.push_back(co->get_rid());
    }
  }
  params->set_exclude(exclude);

  TypedArray<Vector3> contacts = space_state->collide_shape(params, 32);
  if (contacts.size() < 2)
    return;

  Vector3 total_push;
  int count = 0;
  for (int i = 0; i < contacts.size() - 1; i += 2) {
    total_push += Vector3(contacts[i]) - Vector3(contacts[i + 1]);
    count++;
  }
  if (count > 0) {
    out_push = total_push / (float)count;
  }
}

} // namespace godot
