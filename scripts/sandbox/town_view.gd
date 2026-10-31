class_name TownView
extends Node2D
## Draws the town (D-030): ground baked once from Pixel Crawler tiles (grass, cobble, dirt, wall),
## buildings drawn live from wall tiles tinted per building, voxel props at the doors, names and levels.
## Every texture is optional: without the art it falls back to flat colours.

const TILE_DIR := AssetCatalog.PIXEL_CRAWLER_TILES
const PROP_DIR := AssetCatalog.VOXEL_PROPS
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
var ghost_id: String = ""            # D-050 placement preview: building being moved
var ghost_cell: Vector2i = Vector2i.ZERO
var ghost_ok: bool = false
var hovered: String = ""
## Heroes out of sight inside each building (set by TownScreen): {building id: {"sleep": n, "busy": n}}.
## Without it, at night or during indoor work the town looked empty although everyone was home.
var occupancy: Dictionary = {}
var empty_hint: String = ""
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


func _load_prop(key: String) -> void:
    if _props.has(key):
        return
    var frames: Array = []
    if key.begins_with("caz:"):
        var ct := CazArt.texture(key.trim_prefix("caz:"))
        if ct != null:
            frames.append(ct)
        _props[key] = frames
        return
    var id := key.trim_prefix("voxel:")
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
    _props[key] = frames


func _bake_ground() -> Texture2D:
    if CazArt.available() and map != null:
        return _bake_ground_caz()
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


## Town ground with Caz tiles: grass, cobbled roads, stone plaza with a fountain, dirt plots,
## flowers/bushes/rocks on the grass, lamp posts at the crossroads and a ring of Caz trees.
func _bake_ground_caz() -> Texture2D:
    var cell := NavMap.CELL
    var out := Image.create(map.width * cell, map.height * cell, false, Image.FORMAT_RGBA8)
    var r := RandomNumberGenerator.new()
    r.seed = 7331
    for y in map.height:
        var row: String = map.ground[y]
        for x in map.width:
            var area := Rect2i(Vector2i(x, y) * cell, Vector2i(cell, cell))
            var in_plaza := x >= 15 and x <= 19 and y >= 9 and y <= 11
            match row[x]:
                "p", "B":
                    CazArt.fill_tiles(out, area, CazArt.PLAZA if in_plaza else CazArt.COBBLE, r)
                "w":
                    CazArt.fill_tiles(out, area, CazArt.PLAZA, r)
                "d":
                    CazArt.fill_tiles(out, area, CazArt.DIRT, r)
                _:
                    CazArt.fill_tiles(out, area, CazArt.GRASS, r)
    for y in map.height:
        var row2: String = map.ground[y]
        for x in map.width:
            var o := Vector2i(x, y) * cell
            if row2[x] == ".":
                var feet := o + Vector2i(r.randi_range(10, 38), r.randi_range(20, 44))
                var roll := r.randf()
                if roll < 0.22:
                    CazArt.blit_feet(out, CazArt.image(CazArt.FLOWER), feet)
                elif roll < 0.30:
                    CazArt.blit_feet(out, CazArt.pick(CazArt.BUSHES, r), feet)
                elif roll < 0.33:
                    CazArt.blit_feet(out, CazArt.pick(CazArt.ROCKS, r), feet)
                elif roll < 0.36:
                    CazArt.blit_feet(out, CazArt.pick(CazArt.SMALL_TREES, r), feet)
            elif row2[x] == "w":
                CazArt.blit_feet(out, CazArt.image("ExteriorFeatures/ExteriorFeatures_7_2"), o + Vector2i(24, 46))
    # lamp posts where the avenues cross
    for c in [Vector2i(9, 8), Vector2i(18, 8), Vector2i(24, 8), Vector2i(9, 12), Vector2i(18, 12), Vector2i(24, 12)]:
        if map.ground[c.y][c.x] == ".":
            CazArt.blit_feet(out, CazArt.image("ExteriorFeatures/ExteriorFeatures_1_1"), c * cell + Vector2i(24, 30))
    # forest ring around the town
    for y in range(-1, map.height + 1):
        for x in range(-1, map.width + 1):
            var edge := x <= 0 or y <= 0 or x >= map.width - 1 or y >= map.height - 1
            if not edge:
                continue
            for k in 2:
                var tree := CazArt.pick(CazArt.BIG_TREES if r.randf() < 0.7 else CazArt.SMALL_TREES, r)
                CazArt.blit_feet(out, tree, Vector2i(x, y) * cell + Vector2i(r.randi_range(4, 44), r.randi_range(20, 46) - k * 16))
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
        if not map.is_placed(id):
            continue                        # not built and never placed: no plot on the ground
        var b: Dictionary = TownTables.info(id)
        var plot: Rect2i = map.plot_of(id)
        var r := Rect2(Vector2(plot.position) * cell, Vector2(plot.size) * cell)
        var level := Game.building_level(id)
        if level > 0:
            var look: Dictionary = b.get("look", {})
            var img: Image = null
            if CazArt.available():
                img = CazArt.house(plot.size.x * NavMap.CELL, plot.size.y * NavMap.CELL, String(look.get("roof", "thatch")), String(look.get("wall", "plaster")), look.get("tint", Color.WHITE))
            if img == null:
                img = ProcArt.house(plot.size.x * NavMap.CELL, plot.size.y * NavMap.CELL, b["roof"], String(STYLES.get(id, "plaster")), true)
            draw_texture(ProcArt.texture(img), r.position)
            if id == "tower_gate" and CazArt.texture(CazArt.ARCH) != null:
                draw_texture(CazArt.texture(CazArt.ARCH), Vector2(r.get_center().x - 24, r.end.y - 48))
            var props: Array = b["props"]
            var front := Vector2(map.door_of(id)) * cell + Vector2(cell * 0.5, cell * 0.85)
            for i in props.size():
                var side := -1.0 if i % 2 == 0 else 1.0
                _draw_prop(String(props[i]), -1, front + Vector2(side * cell * (1.0 + i / 2), 0))
        else:
            # construction site: fenced dirt plot with rubble
            draw_rect(r.grow(-6), Color(0.0, 0.0, 0.0, 0.12))
            for fx in range(int(r.position.x) + 4, int(r.end.x) - 4, 12):
                draw_rect(Rect2(fx, r.position.y + 4, 3, 8), Color8(110, 74, 42))
                draw_rect(Rect2(fx, r.end.y - 12, 3, 8), Color8(110, 74, 42))
            draw_rect(Rect2(r.position.x + 4, r.position.y + 6, r.size.x - 8, 2), Color8(140, 96, 56))
            draw_rect(Rect2(r.position.x + 4, r.end.y - 10, r.size.x - 8, 2), Color8(140, 96, 56))
            _draw_prop("rubble", 0, r.get_center() + Vector2(0, cell * 0.4))
        var ring := Color(1.0, 0.9, 0.5) if id == selected else (Color(1, 1, 1, 0.7) if id == hovered else Color(0, 0, 0, 0))
        if ring.a > 0.0:
            draw_rect(r.grow(3), ring, false, 3.0)
        var proj: Dictionary = Game.under_construction(id)
        if not proj.is_empty():
            var total := EconomyDefs.BUILD_HOURS_PER_LEVEL * float(proj["to"])
            var k := clampf(1.0 - float(proj["work_left"]) / total, 0.0, 1.0)
            draw_rect(Rect2(r.position.x + 6, r.end.y - 8, r.size.x - 12, 6), Color(0.1, 0.1, 0.1, 0.8))
            draw_rect(Rect2(r.position.x + 6, r.end.y - 8, (r.size.x - 12) * k, 6), Color(0.95, 0.75, 0.3))
            _draw_prop("rubble", 0, Vector2(r.end.x - cell * 0.5, r.end.y))
        var problem := String(Game.town_problems.get(id, ""))
        if problem != "" and level > 0:
            draw_circle(Vector2(r.end.x - 8, r.position.y + 8), 8.0, Color(0.9, 0.25, 0.2))
            draw_string(font, Vector2(r.end.x - 11, r.position.y + 13), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
        var title := String(b["name"]) + ("  Lv %d" % level if level > 0 else "  (build)")
        var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
        var tp := Vector2(r.get_center().x - tw * 0.5, r.position.y - 6)
        draw_rect(Rect2(tp + Vector2(-4, -14), Vector2(tw + 8, 18)), Color(0.08, 0.07, 0.12, 0.75))
        draw_string(font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.8) if level > 0 else Color(0.8, 0.8, 0.8))
    _draw_ghost(cell)
    _draw_occupancy(cell)
    if empty_hint != "":
        var f := ThemeDB.fallback_font
        var ws := map.world_size()
        draw_string_outline(f, Vector2(0, ws.y * 0.5), empty_hint, HORIZONTAL_ALIGNMENT_CENTER, ws.x, 28, 6, Color(0, 0, 0, 0.85))
        draw_string(f, Vector2(0, ws.y * 0.5), empty_hint, HORIZONTAL_ALIGNMENT_CENTER, ws.x, 28, Color(1.0, 0.92, 0.7))


## Small tag over each building with how many heroes are inside (sleeping / busy).
func _draw_occupancy(cell: float) -> void:
    var font := ThemeDB.fallback_font
    for id in occupancy:
        if not TownTables.BUILDINGS.has(id):
            continue
        var o: Dictionary = occupancy[id]
        var parts: Array = []
        if int(o.get("sleep", 0)) > 0:
            parts.append("Zz %d" % int(o["sleep"]))
        if int(o.get("busy", 0)) > 0:
            parts.append("inside %d" % int(o["busy"]))
        if parts.is_empty():
            continue
        var plot: Rect2i = map.plot_of(id)
        var text := "  ".join(parts)
        var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10
        var at := Vector2(plot.position.x + plot.size.x * 0.5, plot.position.y) * cell + Vector2(-w * 0.5, -4)
        draw_rect(Rect2(at, Vector2(w, 17)), Color(0.08, 0.08, 0.12, 0.8))
        draw_string(font, at + Vector2(5, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.92, 0.75))


## D-050 placement preview (green = valid, red = invalid).
func _draw_ghost(cell: float) -> void:
    if ghost_id == "":
        return
    var p: Rect2i = map.plot_of(ghost_id)
    var r := Rect2(Vector2(ghost_cell) * cell, Vector2(p.size) * cell)
    var c := Color(0.3, 1.0, 0.4) if ghost_ok else Color(1.0, 0.3, 0.3)
    draw_rect(r, Color(c, 0.3))
    draw_rect(r, c, false, 3.0)


## Draws a prop with its feet at `feet`. Caz props at native size, voxel props (64 px) at 0.75.
## frame -1 = animate with time.
func _draw_prop(key: String, frame: int, feet: Vector2) -> void:
    var frames: Array = _props.get(key, [])
    if frames.is_empty():
        return
    var f := frame if frame >= 0 else int(_time * 8.0) % frames.size()
    var tex: Texture2D = frames[f]
    var s := 1.0 if key.begins_with("caz:") else 0.75
    var size := tex.get_size() * s
    draw_texture_rect(tex, Rect2(feet - Vector2(size.x * 0.5, size.y), size), false)
