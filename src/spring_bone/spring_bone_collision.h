#ifndef SPRING_BONE_COLLISION_H
#define SPRING_BONE_COLLISION_H

#include <godot_cpp/variant/vector3.hpp>

#include <vector>

namespace godot
{

	namespace SpringBoneCollision
	{

		// Compute closest point on capsule segment (head to tail) to a point Q
		Vector3 closest_point_on_capsule(const Vector3 &head, const Vector3 &tail,
										 const Vector3 &point);

		// Resolve sphere-sphere collision, returns adjusted tail position
		Vector3 resolve_sphere_collision(const Vector3 &tail, const Vector3 &origin,
										 const Vector3 &collider_pos,
										 float joint_radius, float collider_radius,
										 float joint_length);

		// Resolve sphere-capsule collision
		Vector3 resolve_capsule_collision(const Vector3 &tail, const Vector3 &origin,
										  const Vector3 &capsule_head,
										  const Vector3 &capsule_tail,
										  float joint_radius, float collider_radius,
										  float joint_length);

		// Broad-phase check for sphere collider
		inline bool broad_phase_check(const Vector3 &joint_origin, float joint_length,
									  float joint_radius, const Vector3 &collider_pos,
									  float collider_radius)
		{
			float max_dist = joint_length + joint_radius + collider_radius;
			return (joint_origin - collider_pos).length_squared() <= max_dist * max_dist;
		}

		// Broad-phase check for capsule collider
		inline bool broad_phase_capsule_check(const Vector3 &joint_origin,
											  float joint_length, float joint_radius,
											  const Vector3 &capsule_head,
											  const Vector3 &capsule_tail,
											  float collider_radius)
		{
			Vector3 closest_cap_point =
				closest_point_on_capsule(capsule_head, capsule_tail, joint_origin);
			float max_dist = joint_length + joint_radius + collider_radius;
			return (joint_origin - closest_cap_point).length_squared() <=
				   max_dist * max_dist;
		}

		// Forward declare the collider struct to avoid header coupling.
		// The caller passes raw position/radius data instead.
		struct ColliderView
		{
			Vector3 position;	   // Already in center space
			Vector3 tail_position; // Already in center space (capsule only)
			float radius = 0.0f;
			bool is_capsule = false;
		};

		// Run collision against a list of collider views (sphere + capsule).
		// Returns the adjusted tail position after resolving all collisions.
		Vector3 resolve_all_colliders(const Vector3 &tail, const Vector3 &origin,
									  float joint_radius, float joint_length,
									  const std::vector<ColliderView> &colliders);

	} // namespace SpringBoneCollision

} // namespace godot

#endif // SPRING_BONE_COLLISION_H
