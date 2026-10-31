class_name BanditArt
extends RefCounted
## Master prompt H (2026-10-31): every human (heroes, bandits, future NPCs) is built from the Tiny
## Pixel Fantasy layers. Bandits read their layer lists from the owner's presets file; "orig:" is a
## layer of the original pack (SpriteComposer.ROOT), "new:" a bandit layer in tpf_bandidos/Sprite/.
## The Crimson Baron uses the ready-made ×2 sheet (96 px cells, aura included): decision recorded in
## DECISIONS (D-070) so his size, hitbox and aura come from one picture instead of a scaled node.

const ROOT := "res://assets/pixel/tpf_bandidos/"
const PRESETS := ROOT + "presets/bandidos_presets.json"
const BARON_X2 := ROOT + "presets/jefe_baron_carmesi_x2.png"
const BARON_ID := "jefe_baron_carmesi"
## Preset layer name -> SpriteComposer appearance key.
const KEYS := {"Rear_Hair": "rear_hair", "Body": "body", "Eyes": "eyes", "Shoes": "shoes", "Bottom": "bottom",
    "Top": "top", "Accesorio": "accessory", "Facial_Hair": "facial_hair", "Mascara": "mask",
    "Front_Hair": "front_hair", "Hat": "hat", "Held_Item": "held"}
## Creature animations from the TPF sheet (rows/cols as SpriteComposer.ANIMS; all art faces right).
const ANIMS := {
    "idle": {"row": 1, "cols": [4], "fps": 2.0, "loop": true},
    "run": {"row": 1, "cols": [0, 1, 2, 3], "fps": 8.0, "loop": true},
    "attack": {"row": 5, "cols": [2, 3, 4, 5], "fps": 10.0, "loop": false},
    "hurt": {"row": 5, "cols": [0], "fps": 10.0, "loop": false},
    "death": {"row": 5, "cols": [0, 1], "fps": 4.0, "loop": false},
}

static var _presets: Dictionary = {}


static func presets() -> Dictionary:
    if _presets.is_empty():
        var f := FileAccess.open(PRESETS, FileAccess.READ)
        if f != null:
            var d = JSON.parse_string(f.get_as_text())
            if d is Dictionary:
                _presets = (d as Dictionary).get("presets", {})
    return _presets


static func has(id: String) -> bool:
    return presets().has(id)


## SpriteComposer appearance of a bandit ({} if unknown).
static func appearance(id: String) -> Dictionary:
    var out := {}
    var p: Dictionary = presets().get(id, {})
    for layer in p:
        var key := String(KEYS.get(layer, ""))
        var v := String(p[layer])
        if key == "" or v == "":
            continue
        if v.begins_with("orig:"):
            out[key] = v.substr(5).trim_suffix(".png")
        elif v.begins_with("new:"):
            out[key] = ROOT + "Sprite/" + v.substr(4)
    return out


static func build_frames(id: String) -> SpriteFrames:
    var sheet: Texture2D = null
    var cell := SpriteComposer.FRAME
    if id == BARON_ID and ResourceLoader.exists(BARON_X2):
        sheet = load(BARON_X2) as Texture2D
        cell *= 2
    else:
        sheet = ImageTexture.create_from_image(SpriteComposer.compose_sheet(appearance(id)))
    var sf := SpriteFrames.new()
    sf.remove_animation("default")
    for anim in ANIMS:
        var def: Dictionary = ANIMS[anim]
        sf.add_animation(anim)
        sf.set_animation_speed(anim, float(def["fps"]))
        sf.set_animation_loop(anim, bool(def["loop"]))
        for c in def["cols"]:
            var at := AtlasTexture.new()
            at.atlas = sheet
            at.region = Rect2(int(c) * cell, int(def["row"]) * cell, cell, cell)
            sf.add_frame(anim, at)
    return sf
