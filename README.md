<h1 align="center">
  <img src="docs/vrm_instance.png" alt="Logo" width="128" height="128" style="border-radius: 20px;"/><br>
  ✦ GODOT VRM ✦
</h1>

<p align="center">
  <strong>◈ VRM importer, exporter, and runtime spring bone physics for Godot Engine 4.3+ ◈</strong>
  <br>
  <strong>◈ Includes a standalone MToon shader ◈</strong>
</p>

<p align="center">
  <a href="https://github.com/AzPepoze/godot-vrm/releases/latest">
    <img src="https://img.shields.io/github/v/release/AzPepoze/godot-vrm?style=for-the-badge&label=%E2%97%88%20RELEASE%20%E2%97%88&labelColor=%23181818&color=%23458dc0" alt="Latest Release">
  </a>
  <a href="https://github.com/AzPepoze/godot-vrm/stargazers">
    <img src="https://img.shields.io/github/stars/AzPepoze/godot-vrm?style=for-the-badge&label=%E2%97%88%20STARS%20%E2%97%88&labelColor=%23181818&color=%23458dc0" alt="Stars">
  </a>
  <a href="https://godotengine.org/asset-library/asset/5222">
    <img src="https://img.shields.io/badge/%E2%97%88%20ASSET%20LIBRARY%20%E2%97%88-DOWNLOAD-458dc0?style=for-the-badge&labelColor=%23181818" alt="Godot Asset Library">
  </a>
</p>

> [!IMPORTANT]
> An active fork and continuation of the excellent [V-Sekai/godot-vrm](https://github.com/V-Sekai/godot-vrm), providing ongoing maintenance and major performance upgrades. Maintained by **[AzPepoze](https://github.com/AzPepoze)**.

---

## Contents

- [Contents](#contents)
- [What is VRM?](#what-is-vrm)
- [What this fork mainly improves](#what-this-fork-mainly-improves)
- [Installation](#installation)
     - [Method 1: Godot Asset Library](#method-1-godot-asset-library)
     - [Method 2: Git Submodules](#method-2-git-submodules)
     - [Method 3: Manual Install](#method-3-manual-install)
- [Updating](#updating)
- [Showcase](#showcase)
     - [Spring Bone \& Environment Collision](#spring-bone--environment-collision)
     - [VRM Import \& Spring Bone Gizmos](#vrm-import--spring-bone-gizmos)
- [Features Status](#features-status)
     - [Core VRM Support](#core-vrm-support)
     - [Spring Bones (`VRMC_springBone`)](#spring-bones-vrmc_springbone)
     - [Materials \& Shading](#materials--shading)
     - [Animation \& Retargeting](#animation--retargeting)
- [Import Options](#import-options)
     - [Global Defaults](#global-defaults)
     - [Bone Rename Modes](#bone-rename-modes)
     - [Works with Blender](#works-with-blender)
- [Icons](#icons)
- [Credits](#credits)

---

## What is VRM?

- **[VRM](https://vrm.dev/en/)**: 3D avatar ecosystem created by Pixiv.
- **[VRoid Studio](https://vroid.com/en/studio)**: A free tool to easily create your own custom VRM avatars.

---

## What this fork mainly improves

- **C++ Physics**: Spring bones and node constraints are rewritten in C++ (GDExtension) for massive performance gains.
- **Wind Support**: Added directional and turbulent wind simulation for spring bones.
- **Environment Collision**: Spring bones can now collide with Godot's physics bodies.
- **Editor Gizmos**: Visualize spring bone colliders and radius directly in the editor.
- **Group Multipliers**: Scale hit radius for specific spring bone groups (like Hair or Skirts) per-instance.
- **Shared Settings**: Optionally share a single `VRMSettings` resource across multiple avatars to synchronize global wind, gravity, and collisions, or keep them completely unique per character.

---

## Installation

### Method 1: Godot Asset Library

Download and install directly via the [Godot Asset Library](https://godotengine.org/asset-library/asset/5222).

### Method 2: Git Submodules

If you use Git, you can add the specific branch for the addon as a submodule to map it cleanly to the `addons` folder.

```bash
# vrm
git submodule add -b vrm https://github.com/AzPepoze/godot-vrm addons/vrm
# mtoon
git submodule add -b mtoon https://github.com/AzPepoze/godot-vrm addons/mtoon
```

### Method 3: Manual Install

1. Download the latest `.zip` from the [Releases page](https://github.com/AzPepoze/godot-vrm/releases/latest).
2. Copy `addons/vrm` into your project's `addons/` — **do not rename**
3. Copy `addons/mtoon` into `addons/mtoon` — **do not rename**
4. Enable both in **Project Settings → Plugins → VRM** and **mtoon**

---

## Updating

If you installed via Git Submodules, you can update the addon by pulling the latest changes:

```bash
# vrm
git submodule update --remote addons/vrm
# mtoon
git submodule update --remote addons/mtoon
```

For manual installations, simply download the latest release and replace the files in your `addons` folder.

---

## Showcase

![Overall](docs/overall.png)

### Spring Bone & Environment Collision

|                      VRM 0.0 Collision                       |                      VRM 1.0 Collision                       |
| :----------------------------------------------------------: | :----------------------------------------------------------: |
| ![VRM 0.0 Collision](docs/collision_with_environment_v0.png) | ![VRM 1.0 Collision](docs/collision_with_environment_v1.png) |

Spring bones can collide with two types of objects:

- **Body Colliders**: The character's own internal VRM colliders.
- **Environment Collision**: Godot's external physics bodies (can be toggled in settings).

In the debug images above:

- **White wireframe**: Spring bone collision radius
- **Purple wireframe**: VRM character body colliders
- **Yellow line**: Orthogonal surface normal at the hit point
- **Red X**: The exact point of collision with the environment

> [!WARNING]
> **Known Issue:** Spring bones may occasionally pass through colliders (clipping). I honestly suck at collision algorithms, so if you are a math wizard, PRs to help improve collision stability are very much needed and welcome!

### VRM Import & Spring Bone Gizmos

|     VRM 0.0 Import      |     VRM 1.0 Import      |
| :---------------------: | :---------------------: |
| ![VRM 0.0](docs/v0.png) | ![VRM 1.0](docs/v1.png) |

|                    Capsule Gizmo                    |                      Line Circle Gizmo                      |
| :-------------------------------------------------: | :---------------------------------------------------------: |
| ![Capsule Gizmo](docs/gizmo_springbone_capsule.png) | ![Line Circle Gizmo](docs/gizmo_springbone_line_circle.png) |

---

## Features Status

### Core VRM Support

| Feature                          | Status | Details                                                                               |
| -------------------------------- | :----: | ------------------------------------------------------------------------------------- |
| VRM 0.0 Import                   |   ✅   |                                                                                       |
| VRM 1.0 Import                   |   ✅   |                                                                                       |
| VRM 1.0 Export (`.vrm` / `.glb`) |   ⚠️   | Exports metadata, MToon, and node constraints, but humanoid bones/expressions are WIP |
| Metadata                         |   ✅   | License, screenshot parsing                                                           |

### Spring Bones (`VRMC_springBone`)

| Feature                   | Status | Details                                                                |
| ------------------------- | :----: | ---------------------------------------------------------------------- |
| Core Physics              |   ✅   | High-performance C++ GDExtension physics                               |
| Wind Support              |   ✅   | Direction, strength, turbulence, frequency                             |
| Environment Collision     |   ✅   | Capsule queries against Godot's physics environment. Can be toggled.   |
| Group Multipliers         |   ✅   | Per-instance hit radius scaling for specific groups (e.g. Hair, Skirt) |
| Editor Gizmos             |   ✅   | Visualizes spring bone colliders and radius in the 3D viewport         |
| `.gltf` Standalone Export |   ⚠️   | Spring bones are not currently exported to glTF                        |

### Materials & Shading

| Feature                       | Status | Details                |
| ----------------------------- | :----: | ---------------------- |
| `VRMC_materials_mtoon`        |   ✅   | Standard MToon shading |
| `VRMC_materials_hdr_emissive` |   ✅   | HDR emissive textures  |

### Animation & Retargeting

| Feature                | Status | Details                                                           |
| ---------------------- | :----: | ----------------------------------------------------------------- |
| `humanoid`             |   ✅   | `SkeletonProfileHumanoid` via unique skeleton name                |
| `expressions`          |   ✅   | Blend shape / material animation tracks                           |
| `firstPerson`          |   ⚠️   | Head hiding supported via import options                          |
| `lookAt`               |   ⚠️   | Generates animation tracks (app must use `BlendSpace2D` manually) |
| `VRMC_node_constraint` |   ⚠️   | Has known issues with retargeting                                 |

---

## Import Options

Available in the Import dock when selecting a `.vrm` file (under **Advanced** mode):

| Option | Default | Description |
| ------ | :-----: | ----------- |
| **Head Hiding Method** | `ThirdPersonOnly` | How first-person head meshes are handled: `ThirdPersonOnly`, `FirstPersonOnly`, `FirstWithShadow`, `Layers`, `LayersWithShadow`, `IgnoreHeadHiding` |
| **First/Third Person Layers** | `2` / `4` | Render layer masks used when Head Hiding is set to `Layers` mode |
| **Bone Rename** | `None` | How bones are renamed during import — see [Bone Rename Modes](#bone-rename-modes) |
| **Skeleton Name** | `Skeleton3D` | Skeleton node name. Use `Skeleton3D` for Blender workflows, `GeneralSkeleton` for standard `BoneMap` profiles |
| **Remove End Bones** | `true` | Strips empty `_end` marker nodes from the skeleton |
| **V1 Rotate 180** | `true` | Rotates VRM 1.0 root node 180° around Y |
| **Clear Bone Rotation** | `true` | Sets all bone rest rotations to identity `(0,0,0,1)` — useful when the T-pose has unwanted rotation from retargeting |

### Global Defaults

Set defaults in **Project Settings → VRM → Import** (enable **Advanced** toggle in the top-right to see them) instead of configuring per-file:

| Setting | Default | Description |
| ------- | :-----: | ----------- |
| `vrm/import/head_hiding_method` | `0` | Head hiding mode |
| `vrm/import/bone_rename` | `0` | Bone rename mode |
| `vrm/import/skeleton_name` | `Skeleton3D` | Skeleton node name |
| `vrm/import/remove_end_bones` | `true` | Remove end bones |
| `vrm/import/v1_rotate_180` | `true` | Rotate VRM 1.0 root 180° on Y |
| `vrm/import/clear_bone_rotation` | `true` | Clear bone rest rotations to identity |

In the import dialog, **Override Global Defaults** (disabled by default) reads from these project settings. Enable it to override settings for a specific file.

### Bone Rename Modes

| Mode | Best for |
| :--- | :------- |
| **None (Blender ready)** | Animate in Blender with the VRM addon, import `.blend` files directly into Godot |
| **Humanoid** | Standard Godot humanoid bone names (`Hips`, `Spine`, …). Retarget animations across avatars. ⚠️ Not yet fully tested |
| **Symmetrize VRoid** | VRoid Studio models. Symmetrize bones in Blender first: Armature → Object → VRM → Humanoid → Symmetrize VRoid Bone Names on X-Axis |

### Works with Blender

For a smooth Blender ↔ Godot animation workflow:

1. Install the [VRM Add-on for Blender](https://vrm-addon-for-blender.info/en/)
2. Import your `.vrm` into Blender with the addon
3. Animate your model in Blender
4. Export as `.blend` or `.glb` and import into Godot

**Godot import settings for Blender workflow:**

- **Bone Rename**: `None (Blender ready)` or `Symmetrize VRoid` (for VRoid models)
- **Skeleton Name**: `Skeleton3D` (matches `.blend` imports) or `GeneralSkeleton` (standard `BoneMap` profiles)

> [!TIP]
> For an easier rigging setup, check out **[vrm-control-rig](https://github.com/AzPepoze/vrm-control-rig)** — my Blender addon that auto-generates a control rig with IK, designed to work alongside this importer.

---

## Icons

- <img src="addons/vrm/icons/vrm_instance.svg" width="32" height="32" align="center"> **VRM Instance**
- <img src="addons/vrm/icons/vrm_constraint.svg" width="32" height="32" align="center"> **VRM Constraint**
- <img src="addons/vrm/icons/vrm_constraint_applier.svg" width="32" height="32" align="center"> **VRM Constraint Applier**

---

## Credits

Originally created by [V-Sekai](https://v-sekai.org/about). This fork and continuation is maintained by [AzPepoze](https://github.com/AzPepoze).

**Original Contributors:**

- [aaronfranke](https://github.com/aaronfranke) and [The Mirror team](https://www.themirror.space/)
- [fire](https://github.com/fire)
- [TokageItLab](https://github.com/TokageItLab)
- [lyuma](https://github.com/lyuma)
- [SaracenOne](https://github.com/SaracenOne)
