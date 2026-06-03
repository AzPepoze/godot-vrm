#include "spring_bone_forces.h"

#include "spring_bone_util.h"
#include "spring_bone_wind.h"

namespace godot {
namespace SpringBoneForces {
JointForces compute_joint_forces(const SpringBoneTypes::Chain &chain,
                                 size_t joint_index,
                                 const SpringBoneTypes::Joint &joint,
                                 const ForceContext &context) {
  JointForces forces;
  forces.stiffness =
      context.stiffness_multiplier * chain.stiffness_scale * context.delta *
      SpringBoneUtil::joint_param(chain.stiffness_force, joint_index);
  forces.drag = context.drag_multiplier * chain.drag_force_scale *
                SpringBoneUtil::joint_param(chain.drag_force, joint_index);

  const float gravity_power =
      SpringBoneUtil::joint_param(chain.gravity_power, joint_index);
  const Vector3 gravity_dir = SpringBoneUtil::joint_param_vec(
      chain.gravity_dir, joint_index, chain.gravity_dir_default);
  forces.radius = context.hit_radius_multiplier * chain.hit_radius_scale *
                  SpringBoneUtil::joint_param(chain.hit_radius, joint_index);

  const Vector3 total_gravity = context.gravity_rotation.xform(
      gravity_dir * gravity_power * context.gravity_multiplier);
  forces.external = context.center_rot_inv.xform(total_gravity * context.delta *
                                                 chain.gravity_scale) +
                    (context.add_force * context.delta);

  if (context.wind_strength > 0.0001f) {
    SpringBoneWind::WindParams wind_params;
    wind_params.direction = context.center_rot_inv.xform(
        context.skel_global_inv.basis.xform(context.wind_direction));
    wind_params.strength = context.wind_strength;
    wind_params.turbulence = context.wind_turbulence;
    wind_params.frequency = context.wind_frequency;

    const Vector3 wind_force = SpringBoneWind::compute_wind_force(
        wind_params, joint.current_tail, context.wind_time,
        joint.bone_idx + (int)joint_index * 100);
    forces.external += wind_force * context.delta;
  }

  return forces;
}
} // namespace SpringBoneForces
} // namespace godot
