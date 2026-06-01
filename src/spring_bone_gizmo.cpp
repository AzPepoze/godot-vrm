#include "spring_bone_gizmo.h"

#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/core/math.hpp>

namespace godot {

namespace SpringBoneGizmo {

static void draw_line(ImmediateMesh *mesh, const Vector3 &begin,
                      const Vector3 &end, Color color) {
  mesh->surface_set_color(color);
  mesh->surface_add_vertex(begin);
  mesh->surface_set_color(color);
  mesh->surface_add_vertex(end);
}

static void draw_wireframe_sphere(ImmediateMesh *mesh, const Vector3 &center,
                                  float radius, Color color) {
  if (radius <= 0.0f) {
    return;
  }
  const int step = 15;
  const float sppi = 2.0f * (float)Math_PI / step;
  Basis bas;

  for (int axis = 0; axis < 3; ++axis) {
    int col_a = (axis + 1) % 3;
    int col_b = axis;
    for (int i = 1; i <= step; ++i) {
      mesh->surface_set_color(color);
      mesh->surface_add_vertex(
          center + (bas.get_column(col_a) * radius)
                       .rotated(bas.get_column(col_b), sppi * (i - 1)));
      mesh->surface_set_color(color);
      mesh->surface_add_vertex(center +
                               (bas.get_column(col_a) * radius)
                                   .rotated(bas.get_column(col_b), sppi * i));
    }
  }
}

void draw_gizmo(
    ImmediateMesh *mesh, Skeleton3D *skel, const Transform3D &skel_to_gizmo,
    const std::vector<VRMSpringBoneSimulation::CPPSpringBoneChain> &chains,
    const std::vector<VRMSpringBoneSimulation::CPPSpringBoneCollider>
        &colliders,
    Color default_color, bool draw_spring_bones, bool draw_colliders,
    bool p_simulate_in_local_space) {
  if (!mesh || !skel) {
    return;
  }

  mesh->clear_surfaces();

  Transform3D skel_global_inv = skel->get_global_transform().affine_inverse();

  if (draw_spring_bones && !chains.empty()) {
    mesh->surface_begin(Mesh::PRIMITIVE_LINES);
    for (const auto &chain : chains) {
      Transform3D center_transform;
      if (chain.center_bone != -1) {
        center_transform = skel->get_bone_global_pose(chain.center_bone);
      } else if (chain.center_node) {
        center_transform =
            skel_global_inv * chain.center_node->get_global_transform();
      } else {
        center_transform =
            p_simulate_in_local_space ? Transform3D() : skel_global_inv;
      }

      for (const auto &joint : chain.joints) {
        Vector3 start_gizmo = skel_to_gizmo.xform(joint.global_pose.origin);
        Vector3 end_gizmo =
            skel_to_gizmo.xform(center_transform.xform(joint.current_tail));

        draw_line(mesh, start_gizmo, end_gizmo, default_color);
        draw_wireframe_sphere(mesh, start_gizmo, 0.015f, default_color);
      }
      if (!chain.joints.empty()) {
        Vector3 end_gizmo = skel_to_gizmo.xform(
            center_transform.xform(chain.joints.back().current_tail));
        draw_wireframe_sphere(mesh, end_gizmo, 0.015f, default_color);
      }
    }
    mesh->surface_end();
  }

  if (draw_colliders && !colliders.empty()) {
    mesh->surface_begin(Mesh::PRIMITIVE_LINES);
    for (const auto &c : colliders) {
      Vector3 pos_gizmo = skel_to_gizmo.xform(c.position);
      if (c.is_capsule) {
        Vector3 tail_gizmo = skel_to_gizmo.xform(c.tail_position);
        draw_line(mesh, pos_gizmo, tail_gizmo, c.gizmo_color);
        draw_wireframe_sphere(mesh, pos_gizmo, c.radius, c.gizmo_color);
        draw_wireframe_sphere(mesh, tail_gizmo, c.radius, c.gizmo_color);
      } else {
        draw_wireframe_sphere(mesh, pos_gizmo, c.radius, c.gizmo_color);
      }
    }
    mesh->surface_end();
  }
}

} // namespace SpringBoneGizmo

} // namespace godot
