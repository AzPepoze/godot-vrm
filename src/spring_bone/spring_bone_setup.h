#ifndef SPRING_BONE_SETUP_H
#define SPRING_BONE_SETUP_H

#include "spring_bone_types.h"

#include <godot_cpp/variant/array.hpp>

namespace godot {
class Node;
class Skeleton3D;

namespace SpringBoneSetup {

// Parse VRM collider group resources into CPP collider data.
void parse_collider_groups(
    const Array &p_collider_groups, Skeleton3D *skel, Node *resolver_root,
    std::vector<SpringBoneTypes::Collider> &out_colliders,
    std::vector<SpringBoneTypes::ColliderGroup> &out_groups);

// Parse VRM spring bone resources into CPP chain data.
void parse_spring_bones(const Array &p_spring_bones,
                        const Array &p_collider_groups, Skeleton3D *skel,
                        Node *resolver_root,
                        std::vector<SpringBoneTypes::Chain> &out_chains);

} // namespace SpringBoneSetup

} // namespace godot

#endif // SPRING_BONE_SETUP_H
