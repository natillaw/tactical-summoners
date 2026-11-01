class_name GatherNode
extends Node2D
## A gathering spot in a tower floor (EconomyDefs.NODES): ore vein, fallen timber or herb patch. A hero
## that stands next to it out of combat collects it in EconomyDefs.GATHER_TIME; what it yields goes to
## the expedition ledger (kept on success or escape). Drawn with simple shapes; hidden in unexplored fog.

const RANGE := 38.0

var kind: String = "herb"
var amounts: Dictionary = {}        # resource -> amount, rolled when the floor is entered
var progress: float = 0.0
var taken: bool = false


func _init(p_kind: String = "herb", p_amounts: Dictionary = {}) -> void:
    kind = p_kind
    amounts = p_amounts
    physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func label() -> String:
    return String(EconomyDefs.NODES.get(kind, {}).get("name", kind))


## Owner 2026-11-01: the packs' ores and herbs. Ore veins are the crystal pack's crystals, herbs are
## mushrooms, chanterelles and flowering bushes, stone the rock pack, timber the owner's fallen logs.
## One variant per spot (from its position), drawn x1 with its own shadow, feet on the node.
const ART := {
    "ore": ["res://assets/pixel/packs/crystals/PNG/Assets_shadow/", "^(Blue|Green|Violet|Red|White|Yellow)_crystal[0-9]"],
    "herb": ["res://assets/pixel/packs/forest_objects/PNG/Assets/", "^(Chanterelles|White-red_mushroom|Beige_green_mushroom)[0-9]"],
    "herb_bush": ["res://assets/pixel/packs/bushes/PNG/Assets_shadow/", "^Bush_(blue|orange|pink|red)_flowers[0-9]"],
    "stone": ["res://assets/pixel/packs/rocks2/PNG/Objects_separately/", "^Rock[0-9]+_[0-9]+[.]png$"],
}
static var _tex_cache := {}


static func _textures(key: String) -> Array:
    if _tex_cache.has(key):
        return _tex_cache[key]
    var out: Array = []
    if ART.has(key):
        for img in BosqueArt.pack_images(ART[key]):
            var used := (img as Image).get_used_rect()
            out.append(ImageTexture.create_from_image((img as Image).get_region(used)))
    elif key == "wood" and BosqueArt.available():
        var d: Dictionary = BosqueArt.defs()["props"]
        var props := BosqueArt._img(BosqueArt.PROPS)
        for n in ["tronco_caido", "tocon"]:
            if d.has(n):
                var rc: Array = d[n]["rect"]
                out.append(ImageTexture.create_from_image(props.get_region(Rect2i(int(rc[0]), int(rc[1]), int(rc[2]), int(rc[3])))))
    _tex_cache[key] = out
    return out


func _art() -> Texture2D:
    var key := kind
    if kind == "herb" and int(absf(position.x + position.y)) % 3 == 0:
        key = "herb_bush"
    var pool := _textures(key)
    if pool.is_empty():
        return null
    return pool[int(absf(position.x * 7.0 + position.y * 13.0)) % pool.size()]


func _draw() -> void:
    var col: Color = EconomyDefs.NODES.get(kind, {}).get("color", Color.WHITE)
    var art := _art()
    if art != null:
        draw_texture(art, Vector2(-art.get_width() * 0.5, -art.get_height() + 4.0).floor())
        if progress > 0.0:
            var kk := clampf(progress / EconomyDefs.GATHER_TIME, 0.0, 1.0)
            draw_arc(Vector2(0, -art.get_height() * 0.5), 20.0, -PI / 2.0, -PI / 2.0 + TAU * kk, 28, col, 3.0)
        return
    draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.45))
    draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.3))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    match kind:
        "ore":
            draw_colored_polygon(PackedVector2Array([Vector2(-13, 0), Vector2(-9, -14), Vector2(2, -19), Vector2(12, -10), Vector2(13, 0)]), Color(0.38, 0.38, 0.42))
            draw_polyline(PackedVector2Array([Vector2(-13, 0), Vector2(-9, -14), Vector2(2, -19), Vector2(12, -10), Vector2(13, 0)]), Color(0.1, 0.07, 0.15), 1.5)
            for p in [Vector2(-5, -9), Vector2(4, -12), Vector2(6, -4)]:
                draw_circle(p, 2.2, col)
        "wood":
            for i in 3:
                var y := -4.0 - 6.0 * float(i)
                draw_rect(Rect2(-14 + i * 3, y - 5, 26 - i * 6, 6), Color(0.48, 0.32, 0.18))
                draw_rect(Rect2(-14 + i * 3, y - 5, 26 - i * 6, 6), Color(0.15, 0.08, 0.05), false, 1.0)
                draw_circle(Vector2(12 - i * 3, y - 2), 2.5, Color(0.75, 0.6, 0.4))
        _:
            draw_circle(Vector2(0, -8), 10.0, Color(0.22, 0.5, 0.2))
            draw_circle(Vector2(-6, -12), 6.0, Color(0.28, 0.6, 0.24))
            draw_circle(Vector2(6, -11), 6.0, Color(0.25, 0.55, 0.22))
            for p in [Vector2(-5, -14), Vector2(3, -16), Vector2(6, -8)]:
                draw_circle(p, 2.0, Color(0.95, 0.85, 0.4))
    if progress > 0.0:
        var k := clampf(progress / EconomyDefs.GATHER_TIME, 0.0, 1.0)
        draw_arc(Vector2(0, -10), 18.0, -PI / 2.0, -PI / 2.0 + TAU * k, 28, col, 3.0)
