@tool
extends RefCounted

const vrm_meta_class = preload("../../core/vrm_meta.gd")


static func create_meta_v1(
    vrm_extension: Dictionary, gstate: GLTFState, humanBones: BoneMap
) -> Resource:
    var vrm_meta = vrm_meta_class.new()
    vrm_meta.resource_name = "CLICK TO SEE METADATA"
    vrm_meta.spec_version = vrm_extension.get("specVersion", "1.0")
    var vrm_extension_meta = vrm_extension.get("meta")
    if vrm_extension_meta:
        vrm_meta.title = vrm_extension_meta.get("name", "")
        vrm_meta.version = vrm_extension_meta.get("version", "")
        vrm_meta.authors = PackedStringArray(vrm_extension_meta.get("authors", []))
        vrm_meta.contact_information = vrm_extension_meta.get("contactInformation", "")
        vrm_meta.references = PackedStringArray(vrm_extension_meta.get("references", []))
        var tex: int = vrm_extension_meta.get("thumbnailImage", -1)
        if tex >= 0:
            vrm_meta.thumbnail_image = gstate.get_images()[tex]
        var avatar_permission_map = {
            "": "",
            "onlyAuthor": "OnlyAuthor",
            "onlySeparatelyLicensedPerson": "ExplicitlyLicensedPerson",
            "everyone": "Everyone"
        }
        vrm_meta.allowed_user_name = avatar_permission_map.get(
            vrm_extension_meta.get("avatarPermission", ""), ""
        )
        vrm_meta.violent_usage = (
            "Allow" if vrm_extension_meta.get("allowExcessivelyViolentUsage", false) else "Disallow"
        )
        vrm_meta.sexual_usage = (
            "Allow" if vrm_extension_meta.get("allowExcessivelySexualUsage", false) else "Disallow"
        )
        var commercial_usage_map = {
            "": "",
            "personalNonProfit": "PersonalNonProfit",
            "personalProfit": "PersonalProfit",
            "corporation": "AllowCorporation"
        }
        vrm_meta.commercial_usage_type = commercial_usage_map.get(
            vrm_extension_meta.get("commercialUsage", ""), ""
        )
        vrm_meta.political_religious_usage = (
            "Allow"
            if vrm_extension_meta.get("allowPoliticalOrReligiousUsage", false)
            else "Disallow"
        )
        vrm_meta.antisocial_hate_usage = (
            "Allow" if vrm_extension_meta.get("allowAntisocialOrHateUsage", false) else "Disallow"
        )
        var credit_notation_map = {"": "", "required": "Required", "unnecessary": "Unnecessary"}
        vrm_meta.credit_notation = credit_notation_map.get(
            vrm_extension_meta.get("creditNotation", ""), ""
        )
        vrm_meta.allow_redistribution = (
            "Allow" if vrm_extension_meta.get("allowRedistribution", false) else "Disallow"
        )
        var modification_map = {
            "prohibited": "Prohibited",
            "allowModification": "AllowModification",
            "allowModificationRedistribution": "AllowModificationRedistribution"
        }
        vrm_meta.modification = modification_map.get(vrm_extension_meta.get("modification", ""), "")
        vrm_meta.license_name = vrm_extension_meta.get("licenseName", "")
        vrm_meta.license_url = vrm_extension_meta.get("licenseUrl", "")
        vrm_meta.third_party_licenses = vrm_extension_meta.get("thirdPartyLicenses", "")
        vrm_meta.other_license_url = vrm_extension_meta.get("otherLicenseUrl", "")

    vrm_meta.humanoid_bone_mapping = humanBones
    return vrm_meta


static func export_meta_v1(vrm_meta: Resource, vrm_extension: Dictionary):
    var meta_obj: Dictionary = {}
    meta_obj["specVersion"] = vrm_meta.spec_version
    meta_obj["name"] = vrm_meta.title
    meta_obj["version"] = vrm_meta.version
    meta_obj["authors"] = Array(vrm_meta.authors)
    meta_obj["contactInformation"] = vrm_meta.contact_information
    meta_obj["references"] = Array(vrm_meta.references)
    var avatar_permission_map_rev = {
        "OnlyAuthor": "onlyAuthor",
        "ExplicitlyLicensedPerson": "onlySeparatelyLicensedPerson",
        "Everyone": "everyone"
    }
    var commercial_usage_map_rev = {
        "PersonalNonProfit": "personalNonProfit",
        "PersonalProfit": "personalProfit",
        "AllowCorporation": "corporation"
    }
    var credit_notation_map_rev = {"Required": "required", "Unnecessary": "unnecessary"}
    var modification_map_rev = {
        "Prohibited": "prohibited",
        "AllowModification": "allowModification",
        "AllowModificationRedistribution": "allowModificationRedistribution"
    }
    meta_obj["avatarPermission"] = avatar_permission_map_rev.get(vrm_meta.allowed_user_name, "")
    meta_obj["allowExcessivelyViolentUsage"] = vrm_meta.violent_usage == "Allow"
    meta_obj["allowExcessivelySexualUsage"] = vrm_meta.sexual_usage == "Allow"
    meta_obj["commercialUsage"] = commercial_usage_map_rev.get(vrm_meta.commercial_usage_type, "")
    meta_obj["allowPoliticalOrReligiousUsage"] = vrm_meta.political_religious_usage == "Allow"
    meta_obj["allowAntisocialOrHateUsage"] = vrm_meta.antisocial_hate_usage == "Allow"
    meta_obj["creditNotation"] = credit_notation_map_rev.get(vrm_meta.credit_notation, "")
    meta_obj["allowRedistribution"] = vrm_meta.allow_redistribution == "Allow"
    meta_obj["modification"] = modification_map_rev.get(vrm_meta.modification, "")
    meta_obj["licenseName"] = vrm_meta.license_name
    meta_obj["licenseUrl"] = vrm_meta.license_url
    meta_obj["thirdPartyLicenses"] = vrm_meta.third_party_licenses
    meta_obj["otherLicenseUrl"] = vrm_meta.other_license_url
    vrm_extension["meta"] = meta_obj


static func create_meta_v0(
    vrm_extension: Dictionary,
    gstate: GLTFState,
    skeleton: Skeleton3D,
    humanBones: BoneMap,
    human_bone_to_idx: Dictionary,
    pose_diffs: Array[Basis]
) -> Resource:
    var firstperson = vrm_extension.get("firstPerson", null)
    if firstperson:
        var fpboneoffsetxyz = firstperson["firstPersonBoneOffset"]
        var eyeOffset = Vector3(fpboneoffsetxyz["x"], fpboneoffsetxyz["y"], fpboneoffsetxyz["z"])
        if human_bone_to_idx["head"] != -1:
            eyeOffset = pose_diffs[human_bone_to_idx["head"]] * eyeOffset
        var head_attach: BoneAttachment3D = null
        for child in skeleton.find_children("*", "BoneAttachment3D"):
            var child_attach: BoneAttachment3D = child as BoneAttachment3D
            if child_attach.bone_name == "Head":
                head_attach = child_attach
                break
        if head_attach == null:
            head_attach = BoneAttachment3D.new()
            head_attach.name = "Head"
            skeleton.add_child(head_attach)
            head_attach.owner = skeleton.owner
            head_attach.bone_name = "Head"
            var head_bone_offset: Node3D = Node3D.new()
            head_bone_offset.name = "LookOffset"
            head_attach.add_child(head_bone_offset)
            head_bone_offset.unique_name_in_owner = true
            head_bone_offset.owner = skeleton.owner
            head_bone_offset.position = eyeOffset

    var vrm_meta = vrm_meta_class.new()
    vrm_meta.resource_name = "CLICK TO SEE METADATA"
    vrm_meta.exporter_version = vrm_extension.get("exporterVersion", "")
    vrm_meta.spec_version = "0.0"
    if vrm_extension.has("meta"):
        var meta = vrm_extension["meta"]
        vrm_meta.title = meta.get("title", "")
        vrm_meta.version = meta.get("version", "")
        vrm_meta.authors = PackedStringArray([meta.get("author", "")])
        vrm_meta.contact_information = meta.get("contactInformation", "")
        vrm_meta.references = PackedStringArray([meta.get("reference", "")])
        var tex: int = meta.get("texture", -1)
        if tex >= 0:
            var gltftex: GLTFTexture = gstate.get_textures()[tex]
            vrm_meta.thumbnail_image = gstate.get_images()[gltftex.src_image]
        var allowed_user_name_map = {
            "OnlyAuthor": "OnlyAuthor",
            "ExplicitlyLicensedPerson": "ExplicitlyLicensedPerson",
            "Everyone": "Everyone"
        }
        vrm_meta.allowed_user_name = allowed_user_name_map.get(meta.get("allowedUserName", ""), "")
        vrm_meta.violent_usage = meta.get("violentUssageName", "")
        vrm_meta.sexual_usage = meta.get("sexualUssageName", "")
        vrm_meta.commercial_usage_type = meta.get("commercialUssageName", "")
        vrm_meta.other_permission_url = meta.get("otherPermissionUrl", "")
        vrm_meta.license_name = meta.get("licenseName", "")
        if vrm_meta.license_name == "CreativeCommons_Attribution_4.0":
            vrm_meta.license_url = "https://creativecommons.org/licenses/by/4.0/"
        elif vrm_meta.license_name == "CreativeCommons_Attribution_NonCommercial_4.0":
            vrm_meta.license_url = "https://creativecommons.org/licenses/by-nc/4.0/"
        elif vrm_meta.license_name == "CreativeCommons_Attribution_NoDerivs_4.0":
            vrm_meta.license_url = "https://creativecommons.org/licenses/by-nd/4.0/"
        elif vrm_meta.license_name == "CreativeCommons_Attribution_ShareAlike_4.0":
            vrm_meta.license_url = "https://creativecommons.org/licenses/by-sa/4.0/"
        elif vrm_meta.license_name == "CreativeCommons_Attribution_NonCommercial_NoDerivs_4.0":
            vrm_meta.license_url = "https://creativecommons.org/licenses/by-nc-nd/4.0/"
        elif vrm_meta.license_name == "CreativeCommons_Attribution_NonCommercial_ShareAlike_4.0":
            vrm_meta.license_url = "https://creativecommons.org/licenses/by-nc-sa/4.0/"
        if vrm_meta.license_name.begins_with("CC"):
            vrm_meta.allow_redistribution = "Allow"
            vrm_meta.modification = "AllowModificationRedistribution"
        if vrm_meta.license_name == "Redistribution_Prohibited":
            vrm_meta.allow_redistribution = "Disallow"
        vrm_meta.other_license_url = meta.get("otherLicenseUrl", "")

    vrm_meta.humanoid_bone_mapping = humanBones
    return vrm_meta
