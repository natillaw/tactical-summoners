class_name EnemySprites
extends RefCounted
## T-024: Pixel Crawler mobs (Anokolisa, see assets/CREDITS.md). Sheets are installed by
## tools/prepare_crawler.py into ROOT/<id>/{idle,run,death}.png. All art faces right.
## Idle = 32x32 frames, run = 64x64, death = per-mob frame width (table). Feet sit at the bottom
## of every frame, so a bottom-center anchor keeps the mob on its cell.

const ROOT := "res://assets/pixel/enemies/pixel-crawler/"
const IDS := ["orc", "orc_rogue", "orc_shaman", "orc_warrior", "skeleton_base", "skeleton_mage", "skeleton_rogue", "skeleton_warrior"]
const IDLE_W := 32
const RUN_W := 64
const DEATH_W := {"orc_warrior": 96, "skeleton_base": 96}     # every other mob: 64

static var _cache: Dictionary = {}


static func available(id: String) -> bool:
    for n in ["idle", "run", "death"]:
        if not ResourceLoader.exists(ROOT + id + "/" + n + ".png"):
            return false
    return true


static func _add(sf: SpriteFrames, anim: String, tex: Texture2D, fw: int, fps: float, loop: bool) -> void:
    sf.add_animation(anim)
    sf.set_animation_speed(anim, fps)
    sf.set_animation_loop(anim, loop)
    var n := floori(float(tex.get_width()) / float(fw))
    for i in n:
        var at := AtlasTexture.new()
        at.atlas = tex
        at.region = Rect2(i * fw, 0, fw, tex.get_height())
        sf.add_frame(anim, at)


## Null when the art is not installed.
static func build_frames(id: String) -> SpriteFrames:
    if _cache.has(id):
        return _cache[id]
    var sf: SpriteFrames = null
    if available(id):
        var idle := load(ROOT + id + "/idle.png") as Texture2D
        var run := load(ROOT + id + "/run.png") as Texture2D
        var death := load(ROOT + id + "/death.png") as Texture2D
        if idle != null and run != null and death != null:
            sf = SpriteFrames.new()
            sf.remove_animation("default")
            _add(sf, "idle", idle, IDLE_W, 6.0, true)
            _add(sf, "run", run, RUN_W, 10.0, true)
            _add(sf, "death", death, int(DEATH_W.get(id, 64)), 10.0, false)
    _cache[id] = sf
    return sf


## The enemy node stays hidden after death (combat code unchanged); this leaves a corpse that
## plays the death animation, holds, fades and frees itself.
static func spawn_death(e: Node2D, sprite: AnimatedSprite2D) -> void:
    if e == null or sprite == null or not e.is_inside_tree():
        return
    var parent := e.get_parent()
    if parent == null:
        return
    var ghost := Node2D.new()
    ghost.position = e.position
    var s := AnimatedSprite2D.new()
    s.sprite_frames = sprite.sprite_frames
    s.centered = false
    s.flip_h = sprite.flip_h
    var sz := s.sprite_frames.get_frame_texture("death", 0).get_size()
    s.offset = Vector2(-sz.x * 0.5, -sz.y)
    ghost.add_child(s)
    s.play("death")
    parent.add_child.call_deferred(ghost)
    var t := e.get_tree().create_tween()
    t.tween_interval(1.4)
    t.tween_property(s, "modulate:a", 0.0, 0.6)
    t.tween_callback(ghost.queue_free)
