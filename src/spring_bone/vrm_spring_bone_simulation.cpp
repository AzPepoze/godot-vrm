#include "vrm_spring_bone_simulation.h"
#include "spring_bone_collision.h"
#include "spring_bone_gizmo.h"
#include "spring_bone_physics.h"
#include "spring_bone_setup.h"
#include "spring_bone_wind.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

// Binding
void VRMSpringBoneSimulation::_bind_methods() {
  ClassDB::bind_method(D_METHOD("setup", "spring_bones", "collider_groups"),
                       &VRMSpringBoneSimulation::setup);
  ClassDB::bind_method(
      D_METHOD("update_parameters", "gravity_multiplier", "gravity_rotation",
               "add_force", "stiffness_multiplier", "drag_multiplier",
               "hit_radius_multiplier", "body_collider_radius_multiplier"),
      &VRMSpringBoneSimulation::update_parameters, DEFVAL(1.0f), DEFVAL(1.0f),
      DEFVAL(1.0f), DEFVAL(1.0f));
  ClassDB::bind_method(D_METHOD("step_simulation"),
                       &VRMSpringBoneSimulation::step_simulation);

  ClassDB::bind_method(D_METHOD("set_stiffness_multiplier", "multiplier"),
                       &VRMSpringBoneSimulation::set_stiffness_multiplier);
  ClassDB::bind_method(D_METHOD("get_stiffness_multiplier"),
                       &VRMSpringBoneSimulation::get_stiffness_multiplier);
  ClassDB::bind_method(D_METHOD("set_drag_multiplier", "multiplier"),
                       &VRMSpringBoneSimulation::set_drag_multiplier);
  ClassDB::bind_method(D_METHOD("get_drag_multiplier"),
                       &VRMSpringBoneSimulation::get_drag_multiplier);
  ClassDB::bind_method(D_METHOD("set_hit_radius_multiplier", "multiplier"),
                       &VRMSpringBoneSimulation::set_hit_radius_multiplier);
  ClassDB::bind_method(D_METHOD("get_hit_radius_multiplier"),
                       &VRMSpringBoneSimulation::get_hit_radius_multiplier);

  ClassDB::bind_method(D_METHOD("set_simulate_in_local_space", "enabled"),
                       &VRMSpringBoneSimulation::set_simulate_in_local_space);
  ClassDB::bind_method(D_METHOD("get_simulate_in_local_space"),
                       &VRMSpringBoneSimulation::get_simulate_in_local_space);
  ClassDB::bind_method(
      D_METHOD("set_body_collider_radius_multiplier", "multiplier"),
      &VRMSpringBoneSimulation::set_body_collider_radius_multiplier);
  ClassDB::bind_method(
      D_METHOD("get_body_collider_radius_multiplier"),
      &VRMSpringBoneSimulation::get_body_collider_radius_multiplier);
  ClassDB::bind_method(D_METHOD("set_enable_body_collisions", "enabled"),
                       &VRMSpringBoneSimulation::set_enable_body_collisions);
  ClassDB::bind_method(D_METHOD("get_enable_body_collisions"),
                       &VRMSpringBoneSimulation::get_enable_body_collisions);

  ClassDB::bind_method(D_METHOD("set_gizmo_display_mode", "mode"),
                       &VRMSpringBoneSimulation::set_gizmo_display_mode);
  ClassDB::bind_method(D_METHOD("get_gizmo_display_mode"),
                       &VRMSpringBoneSimulation::get_gizmo_display_mode);

  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "stiffness_multiplier",
                            PROPERTY_HINT_RANGE, "0.0,10.0,0.01"),
               "set_stiffness_multiplier", "get_stiffness_multiplier");
  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "drag_multiplier",
                            PROPERTY_HINT_RANGE, "0.0,10.0,0.01"),
               "set_drag_multiplier", "get_drag_multiplier");
  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "hit_radius_multiplier",
                            PROPERTY_HINT_RANGE, "0.0,10.0,0.01"),
               "set_hit_radius_multiplier", "get_hit_radius_multiplier");
  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "body_collider_radius_multiplier",
                            PROPERTY_HINT_RANGE, "0.0,10.0,0.01"),
               "set_body_collider_radius_multiplier",
               "get_body_collider_radius_multiplier");
  ADD_PROPERTY(PropertyInfo(Variant::BOOL, "enable_body_collisions"),
               "set_enable_body_collisions", "get_enable_body_collisions");
  ADD_PROPERTY(PropertyInfo(Variant::BOOL, "simulate_in_local_space"),
               "set_simulate_in_local_space", "get_simulate_in_local_space");

  ADD_PROPERTY(PropertyInfo(Variant::INT, "gizmo_display_mode", PROPERTY_HINT_ENUM,
                            "Line Circle,Capsule"),
               "set_gizmo_display_mode", "get_gizmo_display_mode");

  ClassDB::bind_method(D_METHOD("get_chain_count"),
                       &VRMSpringBoneSimulation::get_chain_count);
  ClassDB::bind_method(D_METHOD("get_joint_count", "chain_idx"),
                       &VRMSpringBoneSimulation::get_joint_count);
  ClassDB::bind_method(D_METHOD("get_joint_current_tail", "chain_idx", "joint_idx"),
                       &VRMSpringBoneSimulation::get_joint_current_tail);
  ClassDB::bind_method(D_METHOD("get_joint_prev_tail", "chain_idx", "joint_idx"),
                       &VRMSpringBoneSimulation::get_joint_prev_tail);
  ClassDB::bind_method(D_METHOD("draw_gizmo", "mesh", "skel_to_gizmo", "color",
                                "draw_spring_bones", "draw_colliders"),
                       &VRMSpringBoneSimulation::draw_gizmo);

  // Wind
  ClassDB::bind_method(D_METHOD("set_wind_direction", "direction"),
                       &VRMSpringBoneSimulation::set_wind_direction);
  ClassDB::bind_method(D_METHOD("get_wind_direction"),
                       &VRMSpringBoneSimulation::get_wind_direction);
  ClassDB::bind_method(D_METHOD("set_wind_strength", "strength"),
                       &VRMSpringBoneSimulation::set_wind_strength);
  ClassDB::bind_method(D_METHOD("get_wind_strength"),
                       &VRMSpringBoneSimulation::get_wind_strength);
  ClassDB::bind_method(D_METHOD("set_wind_turbulence", "turbulence"),
                       &VRMSpringBoneSimulation::set_wind_turbulence);
  ClassDB::bind_method(D_METHOD("get_wind_turbulence"),
                       &VRMSpringBoneSimulation::get_wind_turbulence);
  ClassDB::bind_method(D_METHOD("set_wind_frequency", "frequency"),
                       &VRMSpringBoneSimulation::set_wind_frequency);
  ClassDB::bind_method(D_METHOD("get_wind_frequency"),
                       &VRMSpringBoneSimulation::get_wind_frequency);

  // Environment Collision
  ClassDB::bind_method(
      D_METHOD("set_environment_collision_enabled", "enabled"),
      &VRMSpringBoneSimulation::set_environment_collision_enabled);
  ClassDB::bind_method(
      D_METHOD("is_environment_collision_enabled"),
      &VRMSpringBoneSimulation::is_environment_collision_enabled);
  ClassDB::bind_method(
      D_METHOD("set_environment_collision_mask", "mask"),
      &VRMSpringBoneSimulation::set_environment_collision_mask);
  ClassDB::bind_method(
      D_METHOD("get_environment_collision_mask"),
      &VRMSpringBoneSimulation::get_environment_collision_mask);
  ClassDB::bind_method(
      D_METHOD("set_environment_collision_bounce_damping", "damping"),
      &VRMSpringBoneSimulation::set_environment_collision_bounce_damping);

  ClassDB::bind_method(
      D_METHOD("get_environment_collision_bounce_damping"),
      &VRMSpringBoneSimulation::get_environment_collision_bounce_damping);

  ClassDB::bind_method(D_METHOD("set_debug_collision", "enabled"),
                       &VRMSpringBoneSimulation::set_debug_collision);
  ClassDB::bind_method(D_METHOD("is_debug_collision_enabled"),
                       &VRMSpringBoneSimulation::is_debug_collision_enabled);

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
  ADD_PROPERTY(PropertyInfo(Variant::FLOAT,
                            "environment_collision_bounce_damping",
                            PROPERTY_HINT_RANGE, "0.0,1.0,0.01"),
               "set_environment_collision_bounce_damping",
               "get_environment_collision_bounce_damping");

  ADD_PROPERTY(PropertyInfo(Variant::BOOL, "debug_collision"),
               "set_debug_collision", "is_debug_collision_enabled");

  BIND_ENUM_CONSTANT(GIZMO_LINE_CIRCLE);
  BIND_ENUM_CONSTANT(GIZMO_CAPSULE);
}

VRMSpringBoneSimulation::VRMSpringBoneSimulation() {}
VRMSpringBoneSimulation::~VRMSpringBoneSimulation() {}

// Public API
void VRMSpringBoneSimulation::update_parameters(
    float p_gravity_multiplier, Quaternion p_gravity_rotation,
    Vector3 p_add_force, float p_stiffness_multiplier, float p_drag_multiplier,
    float p_hit_radius_multiplier, float p_body_collider_radius_multiplier) {
  gravity_multiplier = p_gravity_multiplier;
  gravity_rotation = p_gravity_rotation;
  add_force = p_add_force;
  stiffness_multiplier = p_stiffness_multiplier;
  drag_multiplier = p_drag_multiplier;
  hit_radius_multiplier = p_hit_radius_multiplier;
  body_collider_radius_multiplier = p_body_collider_radius_multiplier;
}

void VRMSpringBoneSimulation::step_simulation() { _process_modification(); }

void VRMSpringBoneSimulation::setup(Array p_spring_bones,
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

// Simulation Entry Point
void VRMSpringBoneSimulation::_process_modification() {
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

// Accessors
int VRMSpringBoneSimulation::get_chain_count() const {
  return (int)chains.size();
}

int VRMSpringBoneSimulation::get_joint_count(int p_chain_idx) const {
  if (p_chain_idx < 0 || p_chain_idx >= (int)chains.size())
    return 0;
  return (int)chains[p_chain_idx].joints.size();
}

Vector3 VRMSpringBoneSimulation::get_joint_current_tail(int p_chain_idx,
                                                        int p_joint_idx) const {
  if (p_chain_idx < 0 || p_chain_idx >= (int)chains.size())
    return Vector3();
  const auto &chain = chains[p_chain_idx];
  if (p_joint_idx < 0 || p_joint_idx >= (int)chain.joints.size())
    return Vector3();
  return chain.joints[p_joint_idx].current_tail;
}

Vector3 VRMSpringBoneSimulation::get_joint_prev_tail(int p_chain_idx,
                                                     int p_joint_idx) const {
  if (p_chain_idx < 0 || p_chain_idx >= (int)chains.size())
    return Vector3();
  const auto &chain = chains[p_chain_idx];
  if (p_joint_idx < 0 || p_joint_idx >= (int)chain.joints.size())
    return Vector3();
  return chain.joints[p_joint_idx].prev_tail;
}

void VRMSpringBoneSimulation::draw_gizmo(Object *p_mesh_obj,
                                         Transform3D p_skel_to_gizmo,
                                         Color p_color,
                                         bool p_draw_spring_bones,
                                         bool p_draw_colliders) {
  ImmediateMesh *mesh = Object::cast_to<ImmediateMesh>(p_mesh_obj);
  Skeleton3D *skel = get_skeleton();

  SpringBoneGizmo::GizmoDrawParams params;
  params.default_color = p_color;
  params.draw_spring_bones = p_draw_spring_bones;
  params.draw_colliders = p_draw_colliders;
  params.display_mode = gizmo_display_mode;
  params.simulate_in_local_space = simulate_in_local_space;
  params.hit_radius_multiplier = hit_radius_multiplier;
  params.body_collider_radius_multiplier = body_collider_radius_multiplier;

  SpringBoneGizmo::draw_gizmo(
      mesh, skel, p_skel_to_gizmo, chains, all_colliders, recent_impacts, params);
}

// Wind property accessors
void VRMSpringBoneSimulation::set_wind_direction(Vector3 p_dir) {
  wind_direction = p_dir;
}
Vector3 VRMSpringBoneSimulation::get_wind_direction() const {
  return wind_direction;
}
void VRMSpringBoneSimulation::set_wind_strength(float p_strength) {
  wind_strength = p_strength;
}
float VRMSpringBoneSimulation::get_wind_strength() const {
  return wind_strength;
}
void VRMSpringBoneSimulation::set_wind_turbulence(float p_turbulence) {
  wind_turbulence = p_turbulence;
}
float VRMSpringBoneSimulation::get_wind_turbulence() const {
  return wind_turbulence;
}
void VRMSpringBoneSimulation::set_wind_frequency(float p_frequency) {
  wind_frequency = p_frequency;
}
float VRMSpringBoneSimulation::get_wind_frequency() const {
  return wind_frequency;
}

} // namespace godot
