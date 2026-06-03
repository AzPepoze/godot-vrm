#include "vrm_spring_bone_simulation.h"
#include "spring_bone_constants.h"

#include <godot_cpp/classes/capsule_shape3d.hpp>
#include <godot_cpp/classes/collision_object3d.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/physics_shape_query_parameters3d.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/core/math.hpp>

namespace godot
{

	// ---------------------------------------------------------------------------
	// Environment collision property accessors
	// ---------------------------------------------------------------------------

	void VRMSpringBoneSimulation::set_environment_collision_enabled(
		bool p_enabled)
	{
		environment_collision_enabled = p_enabled;
	}
	bool VRMSpringBoneSimulation::is_environment_collision_enabled() const
	{
		return environment_collision_enabled;
	}
	void VRMSpringBoneSimulation::set_environment_collision_mask(uint32_t p_mask)
	{
		environment_collision_mask = p_mask;
	}
	uint32_t VRMSpringBoneSimulation::get_environment_collision_mask() const
	{
		return environment_collision_mask;
	}
	void VRMSpringBoneSimulation::set_environment_collision_bounce_damping(
		float p_damping)
	{
		environment_collision_bounce_damping = p_damping;
	}
	float VRMSpringBoneSimulation::get_environment_collision_bounce_damping() const
	{
		return environment_collision_bounce_damping;
	}

	// ---------------------------------------------------------------------------
	// PhysicsServer3D query — capsule shape covering the full bone segment.
	// Returns a world-space push vector that moves the tail out of the collider.
	// ---------------------------------------------------------------------------

	void VRMSpringBoneSimulation::_query_game_object_collisions(
		Skeleton3D *skel, const Vector3 &origin_world, const Vector3 &tail_world,
		float radius, uint32_t mask, Vector3 &out_push, float &out_t)
	{
		out_push = Vector3();
		out_t = 1.0f;
		if (!skel)
			return;

		Ref<World3D> world = skel->get_world_3d();
		if (world.is_null())
			return;

		PhysicsDirectSpaceState3D *space_state = world->get_direct_space_state();
		if (!space_state)
			return;

		// Capsule covers the full bone segment (origin → tail)
		Vector3 bone_dir = tail_world - origin_world;
		float bone_length = bone_dir.length();
		if (bone_length < 0.0001f)
			return;

		// SCALE FIX: Scale radius by skeleton's global scale
		float skel_scale = skel->get_global_transform().basis.get_scale().y;
		float scaled_radius = radius * skel_scale;

		Vector3 mid_point = (origin_world + tail_world) * 0.5f;
		Vector3 axis = bone_dir / bone_length;

		// Align Y-up (capsule axis) with bone direction
		Basis rot_basis;
		if (Math::abs(axis.dot(Vector3(0, 1, 0))) > 0.9999f)
		{
			rot_basis = (axis.dot(Vector3(0, 1, 0)) > 0.0f) ? Basis() : Basis(Vector3(1, 0, 0), Math_PI);
		}
		else
		{
			Vector3 rot_axis = Vector3(0, 1, 0).cross(axis).normalized();
			float rot_angle = Math::acos(Vector3(0, 1, 0).dot(axis));
			rot_basis = Basis(rot_axis, rot_angle);
		}

		// Lazy-initialize the cached shape and parameters
		if (env_query_shape.is_null())
		{
			env_query_shape.instantiate();
		}
		if (env_query_params.is_null())
		{
			env_query_params.instantiate();
			env_query_params->set_shape(env_query_shape);
		}

		env_query_shape->set_radius(scaled_radius);
		// GODOT 4 FIX: height is total height including radius.
		// For a swept sphere of length L, height must be L + 2R.
		env_query_shape->set_height(bone_length + scaled_radius * 2.0f);

		env_query_params->set_transform(Transform3D(rot_basis, mid_point));
		env_query_params->set_collision_mask(mask);

		// Exclude the model's own collision objects
		TypedArray<RID> exclude;
		Node *parent = skel->get_parent();
		if (parent)
		{
			CollisionObject3D *co = Object::cast_to<CollisionObject3D>(parent);
			if (co)
			{
				exclude.push_back(co->get_rid());
			}
		}
		env_query_params->set_exclude(exclude);

		TypedArray<Vector3> contacts = space_state->collide_shape(env_query_params, 32);
		if (contacts.size() < 2)
			return;

		// Deepest penetration → push out to surface
		float max_depth = 0.0f;
		Vector3 deepest_push;
		float bone_length_sq = bone_dir.length_squared();

		for (int i = 0; i < contacts.size() - 1; i += 2)
		{
			// contacts[i]=our shape, contacts[i+1]=collided surface
			Vector3 push = Vector3(contacts[i + 1]) - Vector3(contacts[i]);
			float depth = push.length();
			if (depth > max_depth)
			{
				max_depth = depth;
				deepest_push = push;

				// Calculate t: projection of contact point on shape onto the bone axis
				if (bone_length_sq > 1e-8f)
				{
					Vector3 contact_on_shape = Vector3(contacts[i]);
					float t = (contact_on_shape - origin_world).dot(bone_dir) / bone_length_sq;
					out_t = CLAMP(t, 0.0f, 1.0f);
				}
				else
				{
					out_t = 1.0f;
				}
			}
		}

		if (max_depth > 0.001f)
		{
			Vector3 normal = deepest_push.normalized();
			float margin = scaled_radius * SpringBoneConstants::ENV_SHAPE_MARGIN_FACTOR;
			out_push = normal * (max_depth + margin);
		}
	}

} // namespace godot
