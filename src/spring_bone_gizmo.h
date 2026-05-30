#ifndef SPRING_BONE_GIZMO_H
#define SPRING_BONE_GIZMO_H

#include "vrm_spring_bone_simulation.h"

#include <godot_cpp/classes/immediate_mesh.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/transform3d.hpp>

#include <vector>

namespace godot {

namespace SpringBoneGizmo {

// Draw joint chain lines and collider wireframe spheres.
void draw_gizmo(
    ImmediateMesh *mesh, Skeleton3D *skel, const Transform3D &skel_to_gizmo,
    const std::vector<VRMSpringBoneSimulation::CPPSpringBoneChain> &chains,
    const std::vector<VRMSpringBoneSimulation::CPPSpringBoneCollider>
        &colliders,
    Color default_color, bool draw_spring_bones, bool draw_colliders);

} // namespace SpringBoneGizmo

} // namespace godot

#endif // SPRING_BONE_GIZMO_H
