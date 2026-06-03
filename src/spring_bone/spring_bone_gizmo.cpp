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

static void draw_wireframe_capsule(ImmediateMesh *mesh, const Vector3 &a,
                                   const Vector3 &b, float radius,
                                   Color color) {
  draw_wireframe_sphere(mesh, a, radius, color);
  draw_wireframe_sphere(mesh, b, radius, color);

  Vector3 dir = b - a;
  if (dir.length_squared() > 0.0001f) {
    dir.normalize();
    Vector3 up = Vector3(0, 1, 0);
    if (Math::abs(dir.dot(up)) > 0.99f) {
      up = Vector3(1, 0, 0);
    }
    Vector3 right = dir.cross(up).normalized();
    up = right.cross(dir).normalized();

    for (int i = 0; i < 4; ++i) {
      float angle = i * Math_PI / 2.0f;
      Vector3 offset =
          (right * Math::cos(angle) + up * Math::sin(angle)) * radius;
      draw_line(mesh, a + offset, b + offset, color);
    }
  } else {
    draw_line(mesh, a, b, color);
  }
}

static float joint_param(const std::vector<float> &arr, size_t idx,
                         float default_val = 1.0f) {
  if (arr.empty()) {
    return default_val;
  }
  return (idx < arr.size()) ? arr[idx] : arr.back();
}

void draw_gizmo(
    ImmediateMesh *mesh, Skeleton3D *skel, const Transform3D &skel_to_gizmo,
    const std::vector<VRMSpringBoneSimulation::CPPSpringBoneChain> &chains,
    const std::vector<VRMSpringBoneSimulation::CPPSpringBoneCollider>
        &colliders,
    const std::vector<VRMSpringBoneSimulation::CPPCollisionImpact> &impacts,
    Color default_color, bool draw_spring_bones, bool draw_colliders,
    VRMSpringBoneSimulation::GizmoDisplayMode gizmo_display_mode,
    bool p_simulate_in_local_space, float hit_radius_multiplier,
    float body_collider_radius_multiplier) {
  if (!mesh || !skel) {
    return;
  }

  mesh->clear_surfaces();

  Transform3D skel_global_inv = skel->get_global_transform().affine_inverse();

  if (draw_spring_bones && !chains.empty()) {
    mesh->surface_begin(Mesh::PRIMITIVE_LINES);
    for (const auto &chain : chains) {
      Transform3D center_transform;
      if (!p_simulate_in_local_space) {
        center_transform = skel_global_inv;
      } else if (chain.center_bone != -1) {
        center_transform = skel->get_bone_global_pose(chain.center_bone);
      } else if (chain.center_node) {
        center_transform =
            skel_global_inv * chain.center_node->get_global_transform();
      } else {
        center_transform = Transform3D();
      }

      for (size_t i = 0; i < chain.joints.size(); ++i) {
        const auto &joint = chain.joints[i];
        Vector3 start_gizmo = skel_to_gizmo.xform(joint.global_pose.origin);
        Vector3 end_gizmo =
            skel_to_gizmo.xform(center_transform.xform(joint.current_tail));

        float radius = hit_radius_multiplier * chain.hit_radius_scale *
                       joint_param(chain.hit_radius, i);

        if (gizmo_display_mode == VRMSpringBoneSimulation::GIZMO_CAPSULE) {
            draw_wireframe_capsule(mesh, start_gizmo, end_gizmo, radius,
                                   default_color);
        } else {
            draw_wireframe_sphere(mesh, start_gizmo, radius, default_color);
            draw_wireframe_sphere(mesh, end_gizmo, radius, default_color);
            draw_line(mesh, start_gizmo, end_gizmo, default_color);
        }
      }
    }
    mesh->surface_end();
  }

  if (draw_colliders && !colliders.empty()) {
    mesh->surface_begin(Mesh::PRIMITIVE_LINES);
    for (const auto &c : colliders) {
      Vector3 pos_gizmo = skel_to_gizmo.xform(c.position);
      float coll_radius = c.radius * body_collider_radius_multiplier;
      if (c.is_capsule) {
        Vector3 tail_gizmo = skel_to_gizmo.xform(c.tail_position);
        draw_wireframe_capsule(mesh, pos_gizmo, tail_gizmo, coll_radius,
                               c.gizmo_color);
      } else {
        draw_wireframe_sphere(mesh, pos_gizmo, coll_radius, c.gizmo_color);
      }
    }
    mesh->surface_end();
  }

  // Draw Impact Debug
  if (!impacts.empty()) {
    mesh->surface_begin(Mesh::PRIMITIVE_LINES);
    for (const auto &impact : impacts) {
      float alpha = 1.0f - (impact.age / 1.0f); // 1-second fade
      if (alpha <= 0) continue;
      
      Color impact_color = Color(1, 0, 0, alpha); // Red for impact
      Vector3 pos_skel = skel_global_inv.xform(impact.position);
      Vector3 pos_gizmo = skel_to_gizmo.xform(pos_skel);
      Vector3 norm_gizmo = skel_to_gizmo.basis.xform(skel_global_inv.basis.xform(impact.normal));
      
      // Draw a cross at impact point
      float size = 0.05f;
      draw_line(mesh, pos_gizmo + Vector3(size, 0, 0), pos_gizmo - Vector3(size, 0, 0), impact_color);
      draw_line(mesh, pos_gizmo + Vector3(0, size, 0), pos_gizmo - Vector3(0, size, 0), impact_color);
      draw_line(mesh, pos_gizmo + Vector3(0, 0, size), pos_gizmo - Vector3(0, 0, size), impact_color);
      
      // Draw normal vector
      draw_line(mesh, pos_gizmo, pos_gizmo + norm_gizmo * 0.2f, Color(1, 1, 0, alpha)); // Yellow normal
    }
    mesh->surface_end();
  }
}

} // namespace SpringBoneGizmo

} // namespace godot
