#ifndef SPRING_BONE_WIND_H
#define SPRING_BONE_WIND_H

#include <godot_cpp/variant/vector3.hpp>

namespace godot {

namespace SpringBoneWind {

struct WindParams {
  Vector3 direction = Vector3(0, 0, 0); // Base wind direction
  float strength = 0.0f;                // Base strength
  float turbulence = 0.0f;              // 0-1, how much random variation
  float frequency = 1.0f;               // Turbulence oscillation speed
  float gust_interval = 0.0f;           // Seconds between gusts (0=none)
  float gust_strength = 0.0f;           // Extra force during gusts
};

// Compute wind force for a joint at the given position and time
Vector3 compute_wind_force(const WindParams &params,
                           const Vector3 &joint_position, float time,
                           int joint_seed);

} // namespace SpringBoneWind

} // namespace godot

#endif // SPRING_BONE_WIND_H
