# godot-vrm

> [!IMPORTANT]
> This is a fork of [V-Sekai/godot-vrm](https://github.com/V-Sekai/godot-vrm), now maintained by **[AzPepoze](https://github.com/AzPepoze)**.

VRM importer, exporter, and runtime spring bone physics for **Godot Engine 4.3+**. Includes a standalone MToon shader.

![Two example VRM characters](vrm_samples/screenshot/vrm_sample_screenshot.png)

---

## Contents

- [godot-vrm](#godot-vrm)
	- [Contents](#contents)
	- [Installation](#installation)
	- [Features](#features)
	- [Import Options](#import-options)
	- [Credits](#credits)

---

## Installation

1. Copy `addons/vrm` into your project's `addons/` — **do not rename**
2. Copy `addons/mtoon` into `addons/mtoon` — **do not rename**
3. Enable both in **Project Settings → Plugins → VRM** and **mtoon**

---

## Features

| Feature | Status |
|---|---|
| VRM 0.0 Import | ✅ Converts to VRM 1.0 naming |
| VRM 1.0 Import | ✅ |
| VRM 1.0 Export (`.vrm`) | ✅ |
| `VRMC_springBone` | ✅ C++ GDExtension physics |
| Spring Bone Wind | ✅ Direction, strength, turbulence, frequency |
| Spring Bone Environment Collision | ✅ Capsule queries against physics bodies |
| `VRMC_materials_mtoon` | ✅ |
| `VRMC_materials_hdr_emissive` | ✅ |
| `VRMC_vrm` | ✅ |
| `VRMC_node_constraint` | ⚠️ Issues with retargeting |
| glTF Export with VRM 1.0 extensions | ✅ `VRMC_node_constraint`, `VRMC_materials_mtoon` |
| `VRMC_springBone` in standalone `.gltf` | ⚠️ Not supported |
| `humanoid` | ✅ `SkeletonProfileHumanoid` via `%GeneralSkeleton` |
| `firstPerson` | ⚠️ Head hiding via import options |
| `lookAt` | ⚠️ Animation tracks (app must use `BlendSpace2D`) |
| `expressions` | ✅ Blend shape / material animation tracks |
| Metadata | ✅ License, screenshot |

---

## Import Options

Available in the Import dock when selecting a `.vrm` file:

- **Head Hiding Method** — `ThirdPersonOnly` / `FirstPersonOnly` / `FirstWithShadow` / `Layers` / `LayersWithShadow` / `IgnoreHeadHiding`
- **First/Third Person Layers** — render layer masks for `Layers` mode
- **Remove End Bones** — strips empty end-bone nodes from the skeleton

---

## Credits

Originally created by [V-Sekai](https://v-sekai.org/about). Fork maintained by [AzPepoze](https://github.com/AzPepoze).

Contributors:
- [aaronfranke](https://github.com/aaronfranke) and [The Mirror team](https://www.themirror.space/)
- [fire](https://github.com/fire)
- [TokageItLab](https://github.com/TokageItLab)
- [lyuma](https://github.com/lyuma)
- [SaracenOne](https://github.com/SaracenOne)
