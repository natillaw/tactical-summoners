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

## Voxel Dungeon creatures (CC0, Cole Foster): side-view strips of SQUARE frames (48 px for bats, rats,
## slimes, mushrooms and eyes; 64 px for most; 96-144 px for the trex and golems), facing right.
## Used by the tower floors (TowerExpedition "foes"). Some creatures hop or fly instead of walking.
## Besides idle/run/death they bring "attack" (attack, bite, cast, slam or roar) and "hurt".
const VOXEL_ROOT := "res://assets/packs/voxel-dungeon-pack-full/creatures/sheets/"
const VOXEL_W := 64
const VOXEL_SCALE := 1.0

## Voxel creatures whose name clashes with a Pixel Crawler mob ("orc" there is the training-ground
## orc): the tower uses the voxel one under its own id, so every floor creature shares one art style.
const VOXEL_ALIAS := {"orc_brute": "orc"}

static var _cache: Dictionary = {}


static func is_voxel(id: String) -> bool:
    return not IDS.has(id)


static func scale_for(id: String) -> float:
    return VOXEL_SCALE if is_voxel(id) else 1.0


static func _voxel_sheet(id: String, names: Array) -> Texture2D:
    id = String(VOXEL_ALIAS.get(id, id))
    for n in names:
        var path := VOXEL_ROOT + "%s_side_%s.png" % [id, n]
        if ResourceLoader.exists(path):
            return load(path) as Texture2D
    return null


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
    if is_voxel(id):
        var idle := _voxel_sheet(id, ["idle", "fly", "hop"])
        var run := _voxel_sheet(id, ["walk", "hop", "fly"])
        var death := _voxel_sheet(id, ["death"])
        if idle != null and run != null and death != null:
            sf = SpriteFrames.new()
            sf.remove_animation("default")
            _add(sf, "idle", idle, idle.get_height(), 8.0, true)
            _add(sf, "run", run, run.get_height(), 10.0, true)
            _add(sf, "death", death, death.get_height(), 10.0, false)
            var attack := _voxel_sheet(id, ["attack", "bite", "cast", "slam", "roar"])
            if attack != null:
                _add(sf, "attack", attack, attack.get_height(), 12.0, false)
            var hurt := _voxel_sheet(id, ["hurt"])
            if hurt != null:
                _add(sf, "hurt", hurt, hurt.get_height(), 14.0, false)
    elif available(id):
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
    s.scale = sprite.scale
    var sz := s.sprite_frames.get_frame_texture("death", 0).get_size()
    s.offset = Vector2(-sz.x * 0.5, -sz.y)
    ghost.add_child(s)
    s.play("death")
    parent.add_child.call_deferred(ghost)
    var t := e.get_tree().create_tween()
    t.tween_interval(1.4)
    t.tween_property(s, "modulate:a", 0.0, 0.6)
    t.tween_callback(ghost.queue_free)
