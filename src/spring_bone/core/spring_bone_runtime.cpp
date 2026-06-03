#include "spring_bone_runtime.h"

#include "spring_bone_constants.h"

namespace godot {
namespace SpringBoneRuntime {
std::vector<SpringBoneCollision::ColliderView> gather_collider_views(
    const SpringBoneTypes::Chain &chain,
    const std::vector<SpringBoneTypes::Collider> &all_colliders,
    const std::vector<SpringBoneTypes::ColliderGroup> &all_groups,
    const Transform3D &center_inv, float body_collider_radius_multiplier) {
  std::vector<SpringBoneCollision::ColliderView> views;
  for (int group_idx : chain.collider_group_indices) {
    if (group_idx < 0 || group_idx >= (int)all_groups.size()) {
      continue;
    }

    for (int collider_idx : all_groups[group_idx].collider_indices) {
      const SpringBoneTypes::Collider &collider = all_colliders[collider_idx];
      SpringBoneCollision::ColliderView view;
      view.position = center_inv.xform(collider.position);
      view.radius = collider.radius * body_collider_radius_multiplier;
      view.is_capsule = collider.is_capsule;
      if (collider.is_capsule) {
        view.tail_position = center_inv.xform(collider.tail_position);
      }
      views.push_back(view);
    }
  }
  return views;
}

void age_impacts(std::vector<SpringBoneTypes::CollisionImpact> &impacts,
                 float delta) {
  for (auto it = impacts.begin(); it != impacts.end();) {
    it->age += delta;
    if (it->age > SpringBoneConstants::IMPACT_FADE_DURATION) {
      it = impacts.erase(it);
    } else {
      ++it;
    }
  }
}

void add_impact(std::vector<SpringBoneTypes::CollisionImpact> &impacts,
                const Vector3 &position, const Vector3 &normal) {
  SpringBoneTypes::CollisionImpact impact;
  impact.position = position;
  impact.normal = normal;
  impact.age = 0.0f;
  impacts.push_back(impact);

  if (impacts.size() > SpringBoneConstants::MAX_IMPACT_HISTORY) {
    impacts.erase(impacts.begin());
  }
}
} // namespace SpringBoneRuntime
} // namespace godot
