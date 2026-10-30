class_name TownHero
extends Node2D
## A hero living in the town: walks between random spots (or its workplace door), pauses, repeats.
## Purely visual; never changes hero data.

const SPEED := 55.0

var hero: HeroData
var map: TownMap
var hovered: bool = false
var _sprite: AnimatedSprite2D
var _path: Array[Vector2] = []
var _wait: float = 0.0
var _rng := RandomNumberGenerator.new()
var _facing := "down"


func _init(h: HeroData = null, m: TownMap = null) -> void:
    hero = h
    map = m


func _ready() -> void:
    if hero == null:
        return
    _rng.seed = hero.hero_seed
    _sprite = AnimatedSprite2D.new()
    _sprite.sprite_frames = SpriteComposer.build_frames(hero)
    _sprite.offset = Vector2(0, -16)
    add_child(_sprite)
    _sprite.play("idle_down")
    _wait = _rng.randf_range(0.2, 2.5)


## Where this hero wants to go next: its workplace door half of the time, otherwise anywhere.
func _pick_target() -> Vector2:
    if hero.hq_assignment != "" and Game.building_level(hero.hq_assignment) > 0 and _rng.randf() < 0.5:
        return map.center_of(TownTables.door_cell(hero.hq_assignment)) + Vector2(_rng.randf_range(-14, 14), 6)
    return map.center_of(map.random_walkable(_rng))


func _process(delta: float) -> void:
    if hero == null or map == null:
        return
    if _path.is_empty():
        _wait -= delta
        _play("idle_" + _facing)
        if _wait <= 0.0:
            _path = map.find_path(position, _pick_target())
            _wait = _rng.randf_range(1.5, 4.0)
        return
    var to := _path[0] - position
    var step := SPEED * delta
    if to.length() <= step:
        position = _path[0]
        _path.remove_at(0)
    else:
        var dir := to.normalized()
        position += dir * step
        if absf(dir.x) >= absf(dir.y):
            _facing = "right" if dir.x > 0.0 else "left"
        else:
            _facing = "down" if dir.y > 0.0 else "up"
        _play("walk_" + _facing)
    queue_redraw()


func _play(anim: String) -> void:
    if _sprite != null and _sprite.animation != anim:
        _sprite.play(anim)


func _draw() -> void:
    if hero == null:
        return
    draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.55))
    draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, Color(hero.star_color(), 0.6), 2.0)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    if hovered:
        var font := ThemeDB.fallback_font
        var txt := hero.display_name()
        var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
        draw_rect(Rect2(-w * 0.5 - 4, -58, w + 8, 16), Color(0.08, 0.07, 0.12, 0.85))
        draw_string(font, Vector2(-w * 0.5, -46), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, hero.star_color())
