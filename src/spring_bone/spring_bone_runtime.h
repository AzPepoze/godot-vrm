#ifndef SPRING_BONE_RUNTIME_H
#define SPRING_BONE_RUNTIME_H

#include "spring_bone_collision.h"
#include "spring_bone_types.h"

#include <godot_cpp/variant/transform3d.hpp>

#include <vector>

namespace godot {
namespace SpringBoneRuntime {
std::vector<SpringBoneCollision::ColliderView> gather_collider_views(
    const SpringBoneTypes::Chain &chain,
    const std::vector<SpringBoneTypes::Collider> &all_colliders,
    const std::vector<SpringBoneTypes::ColliderGroup> &all_groups,
    const Transform3D &center_inv, float body_collider_radius_multiplier);

void age_impacts(std::vector<SpringBoneTypes::CollisionImpact> &impacts,
                 float delta);
void add_impact(std::vector<SpringBoneTypes::CollisionImpact> &impacts,
                const Vector3 &position, const Vector3 &normal);
} // namespace SpringBoneRuntime
} // namespace godot

#endif // SPRING_BONE_RUNTIME_H
