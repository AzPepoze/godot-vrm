# VRM addon for Godot Engine

This Godot addon fully implements an importer and exporter for models with the [VRM specification](https://github.com/vrm-c/vrm-specification/tree/master/specification).
Compatible with **Godot Engine 4.3 or newer**.

Originally created by the [V-Sekai team](https://v-sekai.org/about). This fork is maintained by [AzPepoze](https://github.com/AzPepoze).

This package also includes a standalone full implementation of the MToon Shader for Godot Engine.

![Example of VRM Addon used to import two example characters](vrm_samples/screenshot/vrm_sample_screenshot.png)

## What is VRM?

See [https://vrm.dev/en/](https://vrm.dev/en/)

"VRM" is a file format for handling 3D humanoid avatar (3D model) data for VR applications.
It is based on [glTF 2.0](https://www.khronos.org/gltf/). Anyone is free to use it.

## Feature Status

Import and export of VRM through version 1.0 is supported. Here is a feature breakdown:

| Feature                                        | Status                                                             |
| ---------------------------------------------- | ------------------------------------------------------------------ |
| VRM 0.0 Import                                 | ✅ Implemented; converts to VRM 1.0 compatible naming              |
| VRM 1.0 Import                                 | ✅ Implemented                                                     |
| VRM Export (`.vrm`)                            | ✅ Implemented; exports all models as VRM 1.0                      |
| glTF Export with VRM 1.0 extensions (`.gltf`)  | ✅ `VRMC_node_constraint`, ✅ `VRMC_materials_mtoon`               |
| `VRMC_springBone` in standalone `.gltf` export | ⚠️ Not supported                                                   |
| `VRMC_materials_mtoon`                         | ✅ Implemented                                                     |
| `VRMC_node_constraint`                         | ⚠️ Known issues when combined with retargeting                     |
| `VRMC_springBone`                              | ✅ Implemented (C++ GDExtension simulation)                         |
| `VRMC_materials_hdr_emissive`                  | ✅ Implemented                                                     |
| `VRMC_vrm`                                     | ✅ Implemented                                                     |
| `firstPerson`                                  | ⚠️ Head hiding via import option (camera layers or runtime script) |
| `eyeOffset`                                    | ✅ `BoneAttachment3D` `"LookOffset"` on `Head`                     |
| `lookAt`                                       | ⚠️ Creates animation tracks (app must create `BlendSpace2D`)       |
| `expressions` (blend shapes / material binds)  | ✅ Animation tracks for `BlendTree` `Add2`                         |
| `humanoid`                                     | ✅ Uses `%GeneralSkeleton` `SkeletonProfileHumanoid` retargeting   |
| Metadata (license, screenshot)                 | ✅ Implemented                                                     |

## Runtime Spring Bone System

Spring bones are driven by a **C++ GDExtension** (`VRMSpringBoneSimulation`) registered as a `SkeletonModifier3D`:

```
VRMInstance (scene root)
  └─ VRMSpringBoneController (Node3D) — holds spring bone chains & collider groups
       └─ VRMSpringBoneAdapter (GDScript bridge)
            └─ VRMSpringBoneSimulation (C++ SkeletonModifier3D, child of skeleton)
```

- **Simulation**: Per-frame physics for joint chains with configurable stiffness, gravity, drag, and sphere/capsule collider collision.
- **Adapter**: Auto-detects if the C++ GDExtension is available; falls back gracefully with a warning if not built.
- **Per-Joint Settings**: Each spring bone chain supports per-joint overrides for stiffness force, gravity power/direction, drag force, and hit radius (optional `PackedFloat64Array` / `PackedVector3Array` exports).
- **Gizmo**: Editor visualization of spring bone chains and colliders (`VRMSpringBoneControllerGizmo`). Spring bones and colliders have independent toggle controls (`gizmo_spring_bone` and `gizmo_show_colliders`).
- **Gravity Control**: Exposed on `VRMSpringBoneController` — multiplier, rotation offset, and additive force vector for wind or directional gravity effects.
- **Collision**: Sphere and capsule colliders with configurable radius and offset; colliders are organized into groups per the VRM spec.

## Import Options (Post-Import Plugin)

When importing a `.vrm` file, the following options are available in the Import dock:

- **Head Hiding Method**: `ThirdPersonOnly`, `FirstPersonOnly`, `FirstWithShadow`, `Layers`, `LayersWithShadow`, or `IgnoreHeadHiding`
- **First/Third Person Layers**: Render layer masks (when using `Layers` mode)
- **Remove End Bones**: `true`/`false` — strips redundant empty end-bone scene nodes from the skeleton after import

## How to use

Install the vrm addon folder into `addons/vrm`. **MUST NOT BE RENAMED**: This path will be referenced by generated VRM meta scripts.

Install mtoon into `addons/mtoon`. **MUST NOT BE RENAMED**: This path is referenced by generated materials.

Enable the VRM and MToon plugins in **Project Settings -> Plugins -> VRM and mtoon**.

## Credits

Thanks to the [V-Sekai team](https://v-sekai.org/about) and contributors:

- https://github.com/aaronfranke and [The Mirror team](https://www.themirror.space/)
- https://github.com/fire
- https://github.com/TokageItLab
- https://github.com/lyuma
- https://github.com/SaracenOne
