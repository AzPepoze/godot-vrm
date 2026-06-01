#ifndef SPRING_BONE_SETUP_H
#define SPRING_BONE_SETUP_H

#include "vrm_spring_bone_simulation.h"

#include <godot_cpp/variant/array.hpp>

namespace godot {

namespace SpringBoneSetup {

// Parse VRM collider group resources into CPP collider data.
void parse_collider_groups(
    const Array &p_collider_groups, Skeleton3D *skel, Node *resolver_root,
    std::vector<VRMSpringBoneSimulation::CPPSpringBoneCollider> &out_colliders,
    std::vector<VRMSpringBoneSimulation::CPPSpringBoneColliderGroup>
        &out_groups);

// Parse VRM spring bone resources into CPP chain data.
void parse_spring_bones(
    const Array &p_spring_bones, const Array &p_collider_groups,
    Skeleton3D *skel, Node *resolver_root,
    std::vector<VRMSpringBoneSimulation::CPPSpringBoneChain> &out_chains);

} // namespace SpringBoneSetup

} // namespace godot

#endif // SPRING_BONE_SETUP_H
