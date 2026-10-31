extends SceneTree
## Visual cohesion of creatures with the heroes (D-055). Heroes (Caz's character generator) are the
## reference and are never touched (D-023). Audit: average colour and brightness of the outer contour
## (opaque pixels touching transparency) of the hero and of every creature sheet used by the game.
## --write: saves COPIES of the creature sheets with the outer contour darkened toward the hero's
## contour colour (hue kept a little) under assets/processed/outline/<same path>; originals untouched.
##   godot --headless --path . --script res://tools/art_cohesion.gd [-- --write]
##   then: godot --headless --path . --import

const OUT_ROOT := "res://assets/processed/outline/"
const KEEP_HUE := 0.25            # how much of the creature's own contour colour survives


static func contour_stats(img: Image) -> Dictionary:
    var sum := Color(0, 0, 0, 0)
    var n := 0
    for y in img.get_height():
        for x in img.get_width():
            if img.get_pixel(x, y).a < 0.5:
                continue
            if _edge(img, x, y):
                sum += img.get_pixel(x, y)
                n += 1
    if n == 0:
        return {"n": 0, "lum": 0.0, "color": Color.BLACK}
    var c := Color(sum.r / n, sum.g / n, sum.b / n)
    return {"n": n, "lum": c.get_luminance(), "color": c}


static func _edge(img: Image, x: int, y: int) -> bool:
    for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        var q: Vector2i = Vector2i(x, y) + d
        if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height() or img.get_pixel(q.x, q.y).a < 0.5:
            return true
    return false


## The contour, darkened toward `ink` (the heroes' contour colour), keeping a bit of its own hue.
static func outlined(src: Image, ink: Color) -> Image:
    var img := src.duplicate() as Image
    for y in src.get_height():
        for x in src.get_width():
            var c := src.get_pixel(x, y)
            if c.a < 0.5 or not _edge(src, x, y):
                continue
            var dark := ink.lerp(c * 0.45, KEEP_HUE)
            img.set_pixel(x, y, Color(dark.r, dark.g, dark.b, c.a))
    return img


static func sheets() -> Array:
    var out: Array = []
    var ids: Array = []
    for f in TowerExpedition.FLOORS.values():
        for id in f["foes"]:
            ids.append(String(EnemySprites.VOXEL_ALIAS.get(id, id)))
    var dir := DirAccess.open(EnemySprites.VOXEL_ROOT)
    if dir != null:
        for file in dir.get_files():
            if not file.ends_with(".png"):
                continue
            for id in ids:
                if file.begins_with(String(id) + "_side_") and not out.has(EnemySprites.VOXEL_ROOT + file):
                    out.append(EnemySprites.VOXEL_ROOT + file)
    for id in EnemySprites.IDS:
        for n in ["idle", "run", "death"]:
            var p: String = EnemySprites.ROOT + id + "/" + n + ".png"
            if ResourceLoader.exists(p):
                out.append(p)
    return out


func _initialize() -> void:
    var write := OS.get_cmdline_user_args().has("--write")
    var hf := SpriteComposer.build_frames(HeroGenerator.generate(101, 3))
    var hero := contour_stats(hf.get_frame_texture("idle_down", 0).get_image())
    print("HERO contour: lum %.2f colour %s (reference)" % [hero["lum"], (hero["color"] as Color).to_html(false)])
    var written := 0
    for path in sheets():
        var img := (load(path) as Texture2D).get_image()
        if img.is_compressed():
            img.decompress()
        img.convert(Image.FORMAT_RGBA8)
        var st := contour_stats(img)
        var line := "%-70s contour lum %.2f %s" % [String(path).get_file(), st["lum"], (st["color"] as Color).to_html(false)]
        if write:
            var out := outlined(img, hero["color"])
            var dest := OUT_ROOT + String(path).trim_prefix("res://assets/")
            DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest.get_base_dir()))
            out.save_png(ProjectSettings.globalize_path(dest))
            line += "  -> lum %.2f" % contour_stats(out)["lum"]
            written += 1
        print(line)
    print("COHESION done, %d copies written" % written)
    quit()
