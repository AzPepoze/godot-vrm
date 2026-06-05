@tool
extends RefCounted

const vrm0_to_vrm1_presets: Dictionary = {
    "joy": "happy",
    "angry": "angry",
    "sorrow": "sad",
    "fun": "relaxed",
    "a": "aa",
    "i": "ih",
    "u": "ou",
    "e": "ee",
    "o": "oh",
    "blink": "blink",
    "blink_l": "blinkLeft",
    "blink_r": "blinkRight",
    "lookup": "lookUp",
    "lookdown": "lookDown",
    "lookleft": "lookLeft",
    "lookright": "lookRight",
    "neutral": "neutral",
}

const vrm_animation_to_look_at: Dictionary = {
    "lookUp": "rangeMapVerticalUp",
    "lookDown": "rangeMapVerticalDown",
    "lookLeft": "rangeMapHorizontalOuter",
    "lookRight": "rangeMapHorizontalInner",
}

const vrm_animation_presets: Dictionary = {
    "happy": true,
    "angry": true,
    "sad": true,
    "relaxed": true,
    "surprised": true,
    "aa": true,
    "ih": true,
    "ou": true,
    "ee": true,
    "oh": true,
    "blink": true,
    "blinkLeft": true,
    "blinkRight": true,
    "lookUp": true,
    "lookDown": true,
    "lookLeft": true,
    "lookRight": true,
    "neutral": true,
}
