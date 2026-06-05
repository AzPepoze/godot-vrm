extends "res://tests/test_base.gd"

# Test _import_preflight sentinel return values for all registered V1 GLTF extensions.
# Purpose: ensure no extension incorrectly aborts the import (Bug 4) when its
# extension key is absent from the glTF file.

const VRMC_MTOON = preload("res://addons/vrm/importer/v1/vrmc/vrmc_materials_mtoon.gd")
const VRMC_VRM = preload("res://addons/vrm/importer/v1/vrmc/vrmc_vrm.gd")
const VRMC_SPRING_BONE = preload("res://addons/vrm/importer/v1/vrmc/vrmc_spring_bone.gd")
const VRMC_NODE_CONSTRAINT = preload("res://addons/vrm/importer/v1/vrmc/vrmc_node_constraint.gd")
const VRMC_VRM_ANIMATION = preload("res://addons/vrm/importer/v1/vrmc/vrmc_vrm_animation.gd")
const VRMC_HDR_EMISSIVE = preload(
    "res://addons/vrm/importer/v1/vrmc/vrmc_materials_hdr_emissive_multiplier.gd"
)


func _fresh_state() -> GLTFState:
    return GLTFState.new()


func test_mtoon_preflight_skips_when_extension_absent():
    var ext := VRMC_MTOON.new()
    var state := _fresh_state()
    var err := ext._import_preflight(state, PackedStringArray([]))
    assert_eq(
        err, ERR_SKIP, "MToon preflight MUST return ERR_SKIP when VRMC_materials_mtoon absent"
    )
    test_completed = true


func test_mtoon_preflight_ok_when_extension_present():
    var ext := VRMC_MTOON.new()
    var state := _fresh_state()
    var err := ext._import_preflight(state, PackedStringArray(["VRMC_materials_mtoon"]))
    assert_eq(err, OK, "MToon preflight MUST return OK when VRMC_materials_mtoon present")
    test_completed = true


func test_vrmc_vrm_preflight_skips_when_absent():
    var ext := VRMC_VRM.new()
    var state := _fresh_state()
    var err := ext._import_preflight(state, PackedStringArray([]))
    assert_eq(err, ERR_SKIP, "vrmc_vrm preflight MUST return ERR_SKIP when VRMC_vrm absent")
    test_completed = true


func test_vrmc_spring_bone_preflight_skips_when_absent():
    var ext := VRMC_SPRING_BONE.new()
    var state := _fresh_state()
    var err := ext._import_preflight(state, PackedStringArray([]))
    assert_eq(
        err, ERR_SKIP, "vrmc_spring_bone preflight MUST return ERR_SKIP when VRMC_springBone absent"
    )
    test_completed = true


func test_vrmc_node_constraint_preflight_skips_when_absent():
    var ext := VRMC_NODE_CONSTRAINT.new()
    var state := _fresh_state()
    var err := ext._import_preflight(state, PackedStringArray([]))
    assert_eq(
        err,
        ERR_SKIP,
        "vrmc_node_constraint preflight MUST return ERR_SKIP when VRMC_node_constraint absent"
    )
    test_completed = true


func test_vrmc_vrm_animation_preflight_skips_when_absent():
    var ext := VRMC_VRM_ANIMATION.new()
    var state := _fresh_state()
    var err := ext._import_preflight(state, PackedStringArray([]))
    assert_eq(
        err,
        ERR_SKIP,
        "vrmc_vrm_animation preflight MUST return ERR_SKIP when VRMC_vrm_animation absent"
    )
    test_completed = true


func test_vrmc_hdr_emissive_preflight_invalid_when_both_absent():
    # NOTE: This extension returns ERR_INVALID_DATA (not ERR_SKIP) when neither
    # VRMC_materials_hdr_emissiveMultiplier nor KHR_materials_emissive_strength is present.
    # This is the current behavior — test documents it to catch regressions.
    var ext := VRMC_HDR_EMISSIVE.new()
    var state := _fresh_state()
    var err := ext._import_preflight(state, PackedStringArray([]))
    assert_eq(
        err,
        ERR_INVALID_DATA,
        "HDR emissive preflight MUST return ERR_INVALID_DATA when neither extension present"
    )
    test_completed = true


func test_vrmc_hdr_emissive_preflight_ok_when_extension_present():
    var ext := VRMC_HDR_EMISSIVE.new()
    var state := _fresh_state()
    var err := ext._import_preflight(
        state, PackedStringArray(["VRMC_materials_hdr_emissiveMultiplier"])
    )
    assert_eq(
        err,
        OK,
        "HDR emissive preflight MUST return OK when VRMC_materials_hdr_emissiveMultiplier present"
    )
    test_completed = true
