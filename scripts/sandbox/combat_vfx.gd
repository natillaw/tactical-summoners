class_name CombatVFX
extends RefCounted
## Helper to generate SpriteFrames and play animated combat VFX from SpritePilot packs.
## Packs are unpacked as assets/packs/<pack>/<pack>/<size>/<file> (F-012: the folder is nested).

const BASE_DIR := "res://assets/packs/"
static var _cache: Dictionary = {}


static func create_strip_frames(pack_name: String, subfolder: String, filename: String, frame_width: int, frame_height: int, frame_count: int, fps: int = 12) -> SpriteFrames:
    var path := BASE_DIR + "%s/%s/%s/%s" % [pack_name, pack_name, subfolder, filename]
    if _cache.has(path):
        return _cache[path]
    if not ResourceLoader.exists(path):
        _cache[path] = null
        return null
    var tex := load(path) as Texture2D
    if tex == null:
        return null
    var sf := SpriteFrames.new()
    sf.remove_animation("default")
    sf.add_animation("fx")
    sf.set_animation_speed("fx", float(fps))
    sf.set_animation_loop("fx", false)

    for i in range(frame_count):
        var atlas := AtlasTexture.new()
        atlas.atlas = tex
        atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
        sf.add_frame("fx", atlas)
    _cache[path] = sf
    return sf


## Strip of square 16 px frames: the frame count is in the file name ("..._strip8.png").
static func spawn_strip16(parent: Node2D, pos: Vector2, pack: String, fname: String, scale_factor: float = 2.5) -> void:
    var count := int(fname.get_basename().get_slice("_strip", 1))
    if count <= 0:
        return
    spawn_effect(parent, pos, pack, "16px", fname, 16, 16, count, scale_factor)


static func spawn_effect(parent: Node2D, pos: Vector2, pack: String, folder: String, fname: String, fw: int, fh: int, count: int, scale_factor: float = 2.0) -> void:
    if parent == null:
        return
    var sf := create_strip_frames(pack, folder, fname, fw, fh, count, 14)
    if sf == null:
        return
    var anim := AnimatedSprite2D.new()
    anim.sprite_frames = sf
    anim.position = pos
    anim.scale = Vector2(scale_factor, scale_factor)
    parent.add_child(anim)
    anim.play("fx")
    anim.animation_finished.connect(func(): anim.queue_free())
