class_name LpcComposer
extends RefCounted
## Overhaul LPC (D-A): composes a character from the imported LPC sheets (assets/pixel/lpc/lpc_index.json,
## written by tools/import_lpc.py). Same public API as SpriteComposer (FRAME, pose_texture, build_frames,
## clear_cache) plus visual_layers(); results cached per (layers hash). Frames are 64 px; rows are
## up, left, down, right; "hurt" has one row (used for every direction). A layer that lacks an
## animation (a dagger has no idle) borrows its walk sheet's first frames, so the weapon stays in hand.

const ROOT := "res://assets/pixel/lpc/"
const FRAME := 64
const DIRS := ["up", "left", "down", "right"]
const FPS := {"idle": 3.0, "combat_idle": 3.0, "walk": 10.0, "run": 12.0, "slash": 12.0, "thrust": 12.0,
    "shoot": 14.0, "spellcast": 10.0, "hurt": 10.0}
const LOOP := ["idle", "combat_idle", "walk", "run"]

static var _index: Dictionary = {}
static var _img_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func index() -> Dictionary:
    if _index.is_empty():
        var d = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "lpc_index.json"))
        _index = d if d is Dictionary else {"pieces": {}, "anims": []}
    return _index


static func available() -> bool:
    return FileAccess.file_exists(ROOT + "lpc_index.json")


static func _img(rel: String) -> Image:
    if _img_cache.has(rel):
        return _img_cache[rel]
    var tex := load(ROOT + rel) as Texture2D
    var img: Image = null
    if tex != null:
        img = tex.get_image()
        if img.is_compressed():
            img.decompress()
        img.convert(Image.FORMAT_RGBA8)
    _img_cache[rel] = img
    return img


## The look's layers (piece, variant, z), sorted bottom to top.
static func visual_layers(look: Dictionary, hero_class: String = "", equipment: Dictionary = {}) -> Array:
    var body := String(look.get("body", "male"))
    var out: Array = []
    for pv in LpcWardrobe.layers_for(look, hero_class, equipment):
        var piece: Dictionary = index()["pieces"].get(String(pv[0]), {})
        for layer in piece.get("layers", []):
            var files: Dictionary = (layer["files"] as Dictionary).get(body, {})
            var by_anim: Dictionary = files.get(String(pv[1]), files.get("default", {}))
            if not by_anim.is_empty():
                out.append({"piece": pv[0], "z": int(layer["z"]), "anims": by_anim})
    out.sort_custom(func(a, b): return int(a["z"]) < int(b["z"]))
    return out


## One animation sheet (all directions) of the composed character.
static func compose_anim(layers: Array, anim: String) -> Image:
    var base: Image = null
    for l in layers:
        if (l["anims"] as Dictionary).has(anim):
            base = _img(String(l["anims"][anim]))
            break
    if base == null:
        return null
    var out := Image.create(base.get_width(), base.get_height(), false, Image.FORMAT_RGBA8)
    for l in layers:
        var a: Dictionary = l["anims"]
        var rel := String(a.get(anim, a.get("walk", "")))
        if rel == "":
            continue
        var src := _img(rel)
        if src == null:
            continue
        var w := mini(src.get_width(), out.get_width())
        var h := mini(src.get_height(), out.get_height())
        out.blend_rect(src, Rect2i(0, 0, w, h), Vector2i.ZERO)
    return out


static func _key(layers: Array) -> String:
    return str(layers.map(func(l): return str(l["piece"]) + ":" + str((l["anims"] as Dictionary).get("walk", ""))).hash())


## Full animation set: "<anim>_<dir>" for every anim and direction.
static func build_frames_for(look: Dictionary, hero_class: String = "", equipment: Dictionary = {}) -> SpriteFrames:
    var layers := visual_layers(look, hero_class, equipment)
    var key := _key(layers) + "/frames"
    if _tex_cache.has(key):
        return _tex_cache[key]
    var sf := SpriteFrames.new()
    sf.remove_animation("default")
    for anim in index().get("anims", []):
        var img := compose_anim(layers, String(anim))
        if img == null:
            continue
        var tex := ImageTexture.create_from_image(img)
        var cols := img.get_width() / FRAME
        var rows := img.get_height() / FRAME
        for d in DIRS.size():
            var name := "%s_%s" % [anim, DIRS[d]]
            sf.add_animation(name)
            sf.set_animation_speed(name, float(FPS.get(anim, 10.0)))
            sf.set_animation_loop(name, LOOP.has(anim))
            var row := d if rows > d else 0
            for c in cols:
                var at := AtlasTexture.new()
                at.atlas = tex
                at.region = Rect2(c * FRAME, row * FRAME, FRAME, FRAME)
                sf.add_frame(name, at)
    _tex_cache[key] = sf
    return sf


## One still frame (cards, portraits): the first frame of anim facing down.
static func pose_texture_for(look: Dictionary, hero_class: String = "", anim: String = "idle") -> Texture2D:
    var layers := visual_layers(look, hero_class)
    var key := _key(layers) + "/" + anim
    if _tex_cache.has(key):
        return _tex_cache[key]
    var img := compose_anim(layers, anim)
    if img == null:
        return null
    var row := 2 if img.get_height() >= 3 * FRAME else 0
    var tex := ImageTexture.create_from_image(img.get_region(Rect2i(0, row * FRAME, FRAME, FRAME)))
    _tex_cache[key] = tex
    return tex


static func clear_cache() -> void:
    _tex_cache.clear()
    _img_cache.clear()
