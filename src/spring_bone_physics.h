#ifndef SPRING_BONE_PHYSICS_H
#define SPRING_BONE_PHYSICS_H

#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

namespace SpringBonePhysics {

struct VerletState {
    Vector3 current_tail;   // Current position in center space
    Vector3 prev_tail;      // Previous position in center space
    float length;           // Distance constraint length
    Vector3 bone_axis;      // Rest direction in local space
};

struct ForceParams {
    float stiffness;        // Return-to-rest force scaled by delta
    float drag;             // Velocity damping (0-1)
    Vector3 external_force; // Wind + gravity + add_force combined
};

// Single Verlet step: returns new tail position in center space (before collision)
Vector3 step_verlet(const VerletState &state, const ForceParams &params,
                    const Vector3 &origin, const Quaternion &local_rot_center);

// Length constraint: project tail to fixed distance from origin
Vector3 apply_length_constraint(const Vector3 &tail, const Vector3 &origin,
                                 float length);

// Compute rotation from bone_axis to target direction
Quaternion compute_bone_rotation(const Vector3 &bone_axis,
                                  const Vector3 &target_dir);

} // namespace SpringBonePhysics

} // namespace godot

#endif // SPRING_BONE_PHYSICS_H
