extends RefCounted

enum HeadHidingSetting {
    ThirdPersonOnly = 0,
    FirstPersonOnly = 1,
    FirstPersonOnlyWithShadow = 2,
    BothLayers = 3,
    BothLayersWithShadow = 4,
    IgnoreHeadHiding = 5,
}

enum OutlineColorMode {
    FixedColor = 0,
    MixedLight3Ding = 1,
}

enum OutlineWidthMode {
    None = 0,
    WorldCoordinates = 1,
    ScreenCoordinates = 2,
}

enum RenderMode {
    Opaque = 0,
    Cutout = 1,
    Transparent = 2,
    TransparentWithZWrite = 3,
}

enum CullMode {
    Off = 0,
    Front = 1,
    Back = 2,
}
