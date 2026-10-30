class_name TownView
extends Node2D
## Draws the town (D-030): ground baked once from Pixel Crawler tiles (grass, cobble, dirt, wall),
## buildings drawn live from wall tiles tinted per building, voxel props at the doors, names and levels.
## Every texture is optional: without the art it falls back to flat colours.

const TILE_DIR := "res://assets/pixel/tilesets/pixel-crawler/"
const PROP_DIR := "res://assets/packs/voxel-dungeon-pack-full/props/frames/"
const T := 16
const GRASS := Vector2i(2, 10)
const COBBLE := Vector2i(7, 10)
const DIRT := Vector2i(12, 10)
const WALL_TOP := Vector2i(9, 3)
const FACE_COL := 9
const FACE_ROW := 6

## Facade style per building (ProcArt.house).
const STYLES := {"town_hall": "stone", "barracks": "stone", "tower_gate": "stone", "memorial": "stone",
    "blacksmith": "stone", "kitchen": "wood", "workshop": "wood", "common": "wood"}

var map: TownMap
var hovered: String = ""
var selected: String = ""
var _ground: Texture2D = null
var _walls: Texture2D = null
var _props: Dictionary = {}      # prop id -> Array[Texture2D] (animation frames)
var _time: float = 0.0


func _init(m: TownMap = null) -> void:
    map = m


func _ready() -> void:
    _walls = _tex(TILE_DIR + "Wall_Tiles.png")
    _ground = _bake_ground()
    for id in TownTables.ids():
        for p in TownTables.info(id)["props"]:
            _load_prop(String(p))
    _load_prop("rubble")


func _process(delta: float) -> void:
    _time += delta
    queue_redraw()


static func _tex(path: String) -> Texture2D:
    if not ResourceLoader.exists(path):
        return null
    return load(path) as Texture2D


func _load_prop(id: String) -> void:
    if _props.has(id):
        return
    var frames: Array = []
    var dir := DirAccess.open(PROP_DIR + id)
    if dir != null:
        var files: Array = []
        for f in dir.get_files():
            var n := String(f).trim_suffix(".import").trim_suffix(".remap")
            if n.ends_with(".png") and not files.has(n):
                files.append(n)
        files.sort()
        for f in files:
            var t := _tex(PROP_DIR + id + "/" + String(f))
            if t != null:
                frames.append(t)
    _props[id] = frames


func _bake_ground() -> Texture2D:
    var floors := _tex(TILE_DIR + "Floors_Tiles.png")
    if floors == null or _walls == null or map == null:
        return null
    var fl := floors.get_image()
    var wl := _walls.get_image()
    fl.convert(Image.FORMAT_RGBA8)
    wl.convert(Image.FORMAT_RGBA8)
    var cell := NavMap.CELL
    var out := Image.create(map.width * cell, map.height * cell, false, Image.FORMAT_RGBA8)
    var sz := Vector2i(T, T)
    for y in map.height:
        var row: String = map.ground[y]
        for x in map.width:
            var kind := row[x]
            for sy in 3:
                for sx in 3:
                    var dst := Vector2i(x * cell + sx * T, y * cell + sy * T)
                    match kind:
                        "#":
                            out.fill_rect(Rect2i(dst, sz), ForestArt.FOREST_FLOOR)
                        "p", "B", "w":
                            out.blend_rect(fl, Rect2i(COBBLE * T, sz), dst)
                        "d":
                            out.blend_rect(fl, Rect2i(DIRT * T, sz), dst)
                        _:
                            out.blend_rect(fl, Rect2i(GRASS * T, sz), dst)
    var r := RandomNumberGenerator.new()
    r.seed = 7331
    for y in map.height:
        var row2: String = map.ground[y]
        for x in map.width:
            var o := Vector2i(x, y) * cell
            if row2[x] == ".":
                ProcArt.stamp_tufts(out, o, r)
                var roll := r.randf()
                if roll < 0.30:
                    ProcArt.stamp_flowers(out, o + Vector2i(r.randi_range(4, 30), r.randi_range(4, 30)), r)
                elif roll < 0.38:
                    out.blend_rect(ProcArt.bush(r.randi() % 2), Rect2i(0, 0, 18, 14), o + Vector2i(r.randi_range(4, 26), r.randi_range(10, 30)))
                elif roll < 0.42:
                    out.blend_rect(ProcArt.rock(0), Rect2i(0, 0, 14, 10), o + Vector2i(r.randi_range(4, 30), r.randi_range(10, 34)))
            elif row2[x] == "w":
                out.blend_rect(ProcArt.well(), Rect2i(0, 0, 24, 26), o + Vector2i(12, 10))
    # forest around the town: trees on the edge ring, drawn top to bottom
    for y in range(-1, map.height + 1):
        for x in range(-1, map.width + 1):
            var edge := x <= 0 or y <= 0 or x >= map.width - 1 or y >= map.height - 1
            if not edge:
                continue
            for k in 2:
                var img := ProcArt.tree([0, 0, 1, 2][r.randi() % 4])
                out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, y) * cell + Vector2i(r.randi_range(-6, 22), r.randi_range(-16, 8) + k * 16))
    return ImageTexture.create_from_image(out)


func _draw() -> void:
    if map == null:
        return
    var cell := float(NavMap.CELL)
    if _ground != null:
        draw_texture(_ground, Vector2.ZERO)
    else:
        draw_rect(Rect2(Vector2.ZERO, map.world_size()), Color(0.25, 0.45, 0.20))
    var font := ThemeDB.fallback_font
    for id in TownTables.ids():
        var b: Dictionary = TownTables.info(id)
        var plot: Rect2i = b["plot"]
        var r := Rect2(Vector2(plot.position) * cell, Vector2(plot.size) * cell)
        var level := Game.building_level(id)
        if level > 0:
            var img := ProcArt.house(plot.size.x * NavMap.CELL, plot.size.y * NavMap.CELL, b["roof"], String(STYLES.get(id, "plaster")), true)
            draw_texture(ProcArt.texture(img), r.position)
            var props: Array = b["props"]
            var front := Vector2(TownTables.door_cell(id)) * cell
            for i in props.size():
                var side := -1.0 if i % 2 == 0 else 1.0
                var at := front + Vector2(side * cell * (0.75 + i / 2), -cell * 0.35)
                _draw_prop(String(props[i]), -1, Rect2(at, Vector2(cell, cell) * 0.75))
        else:
            # construction site: fenced dirt plot with rubble
            draw_rect(r.grow(-6), Color(0.0, 0.0, 0.0, 0.12))
            for fx in range(int(r.position.x) + 4, int(r.end.x) - 4, 12):
                draw_rect(Rect2(fx, r.position.y + 4, 3, 8), Color8(110, 74, 42))
                draw_rect(Rect2(fx, r.end.y - 12, 3, 8), Color8(110, 74, 42))
            draw_rect(Rect2(r.position.x + 4, r.position.y + 6, r.size.x - 8, 2), Color8(140, 96, 56))
            draw_rect(Rect2(r.position.x + 4, r.end.y - 10, r.size.x - 8, 2), Color8(140, 96, 56))
            _draw_prop("rubble", 0, Rect2(r.get_center() - Vector2(cell, cell) * 0.5, Vector2(cell, cell)))
        var ring := Color(1.0, 0.9, 0.5) if id == selected else (Color(1, 1, 1, 0.7) if id == hovered else Color(0, 0, 0, 0))
        if ring.a > 0.0:
            draw_rect(r.grow(3), ring, false, 3.0)
        var title := String(b["name"]) + ("  Lv %d" % level if level > 0 else "  (build)")
        var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
        var tp := Vector2(r.get_center().x - tw * 0.5, r.position.y - 6)
        draw_rect(Rect2(tp + Vector2(-4, -14), Vector2(tw + 8, 18)), Color(0.08, 0.07, 0.12, 0.75))
        draw_string(font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.8) if level > 0 else Color(0.8, 0.8, 0.8))


## frame -1 = animate with time.
func _draw_prop(id: String, frame: int, rect: Rect2) -> void:
    var frames: Array = _props.get(id, [])
    if frames.is_empty():
        return
    var f := frame if frame >= 0 else int(_time * 8.0) % frames.size()
    draw_texture_rect(frames[f], rect, false)
