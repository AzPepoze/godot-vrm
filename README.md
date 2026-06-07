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

| Improvement | Description |
|---|---|
| **C++ Physics** | Spring bones and node constraints rewritten in C++ (GDExtension) for massive performance gains |
| **Wind Support** | Directional and turbulent wind simulation for spring bones |
| **Environment Collision** | Spring bones can collide with Godot's physics bodies (capsule queries) |
| **Editor Gizmos** | Visualize spring bone colliders and radius directly in the 3D viewport |
| **Group Multipliers** | Per-instance hit radius scaling for specific spring bone groups (e.g. Hair, Skirt) |
| **Shared Settings** | Share a single `VRMSettings` resource across avatars to sync wind, gravity, and collisions — or keep them unique per character |

---

## Installation

| Method | Steps | Best For |
|---|---|---|
| **[Godot Asset Library](https://godotengine.org/asset-library/asset/5222)** | Download and install directly from the AssetLib tab in the Godot editor | Quick setup, one-click install |
| **Git Submodules** | See [submodule commands](#method-2-git-submodules) below | Git-based projects, easy updates |
| **Manual Install** | See [manual steps](#method-3-manual-install) below | Offline setup, full control |

### Method 1: Godot Asset Library

Download and install directly via the [Godot Asset Library](https://godotengine.org/asset-library/asset/5222).

### Method 2: Git Submodules

Map the addon branches cleanly to your `addons/` folder:

```bash
git submodule add -b vrm https://github.com/AzPepoze/godot-vrm addons/vrm
git submodule add -b mtoon https://github.com/AzPepoze/godot-vrm addons/mtoon
```

### Method 3: Manual Install

1. Download the latest `.zip` from the [Releases page](https://github.com/AzPepoze/godot-vrm/releases/latest)
2. Copy `addons/vrm` into your project's `addons/vrm` — **do not rename**
3. Copy `addons/mtoon` into your project's `addons/mtoon` — **do not rename**
4. Enable both plugins in **Project Settings → Plugins**

---

## Updating

| Method | How to Update |
|---|---|
| **Godot Asset Library** | Use the AssetLib tab in the editor to check for and install updates |
| **Git Submodules** | See commands below |
| **Manual Install** | Download the latest release and replace the `addons/vrm` and `addons/mtoon` folders |

**Git Submodule update commands:**

```bash
git submodule update --remote addons/vrm
git submodule update --remote addons/mtoon
```

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

Available in the Import dock when selecting a `.vrm` file:

| Option | Description | Values |
|---|---|---|
| **Head Hiding Method** | Controls first/third-person head visibility | `ThirdPersonOnly`, `FirstPersonOnly`, `FirstWithShadow`, `Layers`, `LayersWithShadow`, `IgnoreHeadHiding` |
| **First/Third Person Layers** | Render layer masks for `Layers` mode | Layer bitmask (default: first=2, third=4) |
| **Bone Rename** | How skeleton bones are renamed on import | See [Bone Rename Modes](#bone-rename-modes) |
| **Skeleton Name** | Skeleton node name after import | `Skeleton3D` (default, for Blender) or `GeneralSkeleton` (for BoneMap profiles) |
| **Remove End Bones** | Strips empty end-bone nodes from the skeleton | `true` / `false` |

### Global Defaults

> [!NOTE]
> Import options are shown under the **Advanced** mode.

Set defaults once in **Project Settings → General → VRM → Import** instead of configuring per-file:

| Setting | Purpose |
|---|---|
| `vrm/import/head_hiding_method` | Default head hiding mode |
| `vrm/import/bone_rename` | Default bone rename mode |
| `vrm/import/skeleton_name` | Default skeleton node name |
| `vrm/import/remove_end_bones` | Default remove end bones |
| `vrm/import/v1_rotate_180` | Rotate VRM 1.0 models 180° on Y axis |

In the import dialog, **Override Global Defaults** (disabled by default) lets you override settings for a specific file.

### Bone Rename Modes

| Mode | Description |
|---|---|
| **None** | Keep original VRM bone names as-is |
| **Humanoid** | Convert to standard Godot humanoid names (`Hips`, `Spine`, etc.) |
| **Symmetrize VRoid** | Mirror VRoid bone names on the X axis |

### Works with Blender

For a smooth Blender ↔ Godot animation workflow:

1. Install the [VRM Add-on for Blender](https://vrm-addon-for-blender.info/en/)
2. Import your `.vrm` into Blender with the addon
3. Animate your model in Blender
4. Import your `.blend` file into Godot
5. In the Import dock for the `.blend` file:
     - Locate the VRM skeleton (may be called **Skeleton3D**)
     - Go to **Skeleton → Retarget → Bone Map**
     - Click **Add Bone Map** (create a new one)
     - Set its profile to **SkeletonProfileHumanoid**
     - Verify each bone is mapped correctly

**Recommended import settings for Blender:**

| Setting | Recommended Value | Why |
|---|---|---|
| **Bone Rename** | `Humanoid` | Works with the skeleton setup above; other modes (`None`, `Symmetrize VRoid`) are optional if you know what you're doing |
| **Skeleton Name** | `Skeleton3D` | Matches skeleton names inside `.blend` imports |

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
