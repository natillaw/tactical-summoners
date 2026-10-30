class_name ForestArt
extends RefCounted
## Bakes a procedural tower floor as a forest (D-031): grass clearings with tufts and flowers,
## dirt trails in the narrow corridors, and the solid cells as a dense wall of trees.
## Ground tiles come from Pixel Crawler; trees, bushes, rocks and flowers from ProcArt.

const TILE_DIR := "res://assets/pixel/tilesets/pixel-crawler/"
const T := 16
const GRASS := [Vector2i(2, 10), Vector2i(3, 10)]
const DIRT := Vector2i(12, 10)
const FOREST_FLOOR := Color(0.110, 0.204, 0.118)


static func _img(path: String) -> Image:
    if not ResourceLoader.exists(path):
        return null
    var tex := load(path) as Texture2D
    if tex == null:
        return null
    var img := tex.get_image()
    img.convert(Image.FORMAT_RGBA8)
    return img


## A walkable cell squeezed between two solid cells (left/right or up/down) is a trail.
static func is_trail(map: NavMap, c: Vector2i) -> bool:
    var lr := map.is_blocked_cell(c + Vector2i.LEFT) and map.is_blocked_cell(c + Vector2i.RIGHT)
    var ud := map.is_blocked_cell(c + Vector2i.UP) and map.is_blocked_cell(c + Vector2i.DOWN)
    return lr or ud


static func bake(map: NavMap, art_seed: int) -> Texture2D:
    var fl := _img(TILE_DIR + "Floors_Tiles.png")
    var cell := NavMap.CELL
    var out := Image.create(map.width * cell, map.height * cell, false, Image.FORMAT_RGBA8)
    var r := RandomNumberGenerator.new()
    r.seed = art_seed
    var sz := Vector2i(T, T)
    # 1. ground
    for y in map.height:
        for x in map.width:
            var c := Vector2i(x, y)
            var o := c * cell
            if map.is_blocked_cell(c):
                out.fill_rect(Rect2i(o, Vector2i(cell, cell)), FOREST_FLOOR)
                continue
            var trail := is_trail(map, c)
            for sy in 3:
                for sx in 3:
                    var dst := o + Vector2i(sx, sy) * T
                    if fl == null:
                        out.fill_rect(Rect2i(dst, sz), Color8(150, 105, 60) if trail else Color8(60, 120, 50))
                    else:
                        var t: Vector2i = DIRT if trail else GRASS[r.randi() % GRASS.size()]
                        out.blend_rect(fl, Rect2i(t * T, sz), dst)
            if not trail:
                ProcArt.stamp_tufts(out, o, r)
                if r.randf() < 0.18:
                    ProcArt.stamp_flowers(out, o + Vector2i(r.randi_range(4, 30), r.randi_range(4, 30)), r)
    # 2. small decor on open ground (never blocks movement)
    for y in map.height:
        for x in map.width:
            var c := Vector2i(x, y)
            if map.is_blocked_cell(c) or is_trail(map, c):
                continue
            var roll := r.randf()
            var o := c * cell + Vector2i(r.randi_range(4, 26), r.randi_range(8, 30))
            if roll < 0.04:
                _blit(out, ProcArt.bush(r.randi() % 2), o)
            elif roll < 0.07:
                _blit(out, ProcArt.rock(0), o)
    # 3. tree wall, top to bottom so lower trees overlap the ones behind
    for y in range(-1, map.height):
        for x in map.width:
            var c := Vector2i(x, y)
            if y >= 0 and not map.is_blocked_cell(c):
                continue
            # trees on the edge of a clearing keep their trunk inside the solid cell
            var open_south := y + 1 < map.height and not map.is_blocked_cell(c + Vector2i.DOWN)
            for k in (1 if open_south else 2):
                var img := ProcArt.tree([0, 0, 1, 2][r.randi() % 4])
                var p := c * cell + Vector2i(r.randi_range(-8, 24), r.randi_range(-14, 10) + k * 18) - Vector2i(0, 8)
                _blit(out, img, p)
    return ImageTexture.create_from_image(out)


static func _blit(dst: Image, src: Image, at: Vector2i) -> void:
    dst.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)
