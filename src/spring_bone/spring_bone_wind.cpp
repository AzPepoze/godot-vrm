#include "spring_bone_wind.h"

#include <godot_cpp/core/math.hpp>

namespace godot
{

	namespace SpringBoneWind
	{

		Vector3 compute_wind_force(const WindParams &params,
								   const Vector3 &joint_position, float time,
								   int joint_seed)
		{
			if (params.strength <= 0.0001f || params.direction.is_zero_approx())
			{
				return Vector3();
			}
			Vector3 wind_dir = params.direction.normalized();

			// Wave phase based on time, joint position projected along wind direction,
			// and seed
			float pos_phase = joint_position.dot(wind_dir) * 2.0f;
			float base_phase = time * params.frequency + pos_phase + (float)joint_seed;

			// Layered sines: Primary slow sway, and spring_bone_controller faster flutter
			float wave1 = Math::sin(base_phase);
			float wave2 = Math::sin(base_phase * 2.3f + 1.5f) * 0.4f;
			float wave3 = Math::sin(base_phase * 5.7f + 0.7f) * 0.2f;

			// Total turbulence wave (-1.0 to 1.0 range-ish)
			float wave = (wave1 + wave2 + wave3) / 1.6f;

			// Wind strength modulated by turbulence
			float current_strength = params.strength * (1.0f + params.turbulence * wave);

			// Add perpendicular variation based on turbulence
			Vector3 perp1;
			if (Math::abs(wind_dir.x) < 0.9f)
			{
				perp1 = Vector3(1.0f, 0.0f, 0.0f).cross(wind_dir).normalized();
			}
			else
			{
				perp1 = Vector3(0.0f, 1.0f, 0.0f).cross(wind_dir).normalized();
			}
			Vector3 perp2 = wind_dir.cross(perp1).normalized();

			float perp_phase = base_phase * 1.5f;
			float perp_wave =
				Math::sin(perp_phase) * params.turbulence * 0.2f * params.strength;

			Vector3 force = wind_dir * current_strength + (perp1 + perp2) * perp_wave;

			// Optional gusts
			if (params.gust_interval > 0.0f && params.gust_strength > 0.0f)
			{
				float gust_time = Math::fmod(time, params.gust_interval);
				if (gust_time < 1.0f)
				{
					float gust_factor = Math::sin(gust_time * (float)Math_PI);
					force += wind_dir * params.gust_strength * gust_factor;
				}
			}

			return force;
		}

	} // namespace SpringBoneWind

} // namespace godot
