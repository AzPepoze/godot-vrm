#ifndef SPRING_BONE_CONSTANTS_H
#define SPRING_BONE_CONSTANTS_H

namespace godot {
namespace SpringBoneConstants {

constexpr float DEFAULT_BONE_LENGTH = 0.07f;
constexpr int PUSH_OUT_PASSES = 4;
constexpr int ANGULAR_COLLISION_ITERATIONS = 4;
constexpr int MAX_IMPACT_HISTORY = 50;
constexpr float CONTACT_VELOCITY_DAMPING = 0.95f;
constexpr float EXPANSION_DAMPING = 0.5f;
constexpr float IMPACT_FADE_DURATION = 1.0f;
constexpr float ENV_SHAPE_MARGIN_FACTOR = 0.1f;

} // namespace SpringBoneConstants
} // namespace godot

#endif // SPRING_BONE_CONSTANTS_H
