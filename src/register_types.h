#ifndef VRM_PHYSICS_REGISTER_TYPES_H
#define VRM_PHYSICS_REGISTER_TYPES_H

#include <godot_cpp/core/class_db.hpp>

namespace godot {
void initialize_vrm_physics_module(ModuleInitializationLevel p_level);
void uninitialize_vrm_physics_module(ModuleInitializationLevel p_level);
} // namespace godot

#endif // VRM_PHYSICS_REGISTER_TYPES_H
