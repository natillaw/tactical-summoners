class_name SandboxEnemy
extends Combatant
## Placeholder enemy (T-010): perceives the nearest hero, chases, then winds up a telegraphed
## strike. The strike lands only on heroes still inside the marked circle when the wind-up ends,
## so the player can dodge by ordering a move.

enum State { IDLE, CHASE, WINDUP, RECOVER }

var enemy_name: String = "Grunt"
var atk: int = 12
var defense: int:                   # legacy alias of Combatant.armor
    get:
        return armor
var speed: float = 62.0
var perception: float = 230.0
var strike_range: float = 40.0
var strike_radius: float = 44.0
var windup_time: float = 0.7
var recover_time: float = 0.8
var state: State = State.IDLE
var _timer: float = 0.0
var _aim: Vector2 = Vector2.ZERO
var _flash: float = 0.0
var type_id: String = ""            # T-024: visual type (EnemySprites.IDS); stats unchanged for now
var _sprite: AnimatedSprite2D = null
var _path: Array[Vector2] = []
var _repath: float = 0.0
const REPATH_EVERY := 0.4
var _anim_lock: float = 0.0        # attack / hurt animation playing (look only)
var focus: SandboxHero = null       # hero it is currently going for (rogue Backstab reads it)
var taunted_by: SandboxHero = null  # Warrior War Cry: forced target while taunt_t > 0
var taunt_t: float = 0.0


func _init() -> void:
    setup_combat(60, 3, 2, 0.05, 0.0, 1)


func _ready() -> void:
    combat_rng.seed = hash(position) ^ get_instance_id()


## T-024: swaps the placeholder circle for a Pixel Crawler mob. Falls back to the circle when
## the art is not installed (tests/headless without assets keep working).
func setup_type(id: String) -> void:
    type_id = id
    var f := EnemySprites.build_frames(id)
    if f == null or _sprite != null:
        return
    enemy_name = id.capitalize() if EnemySprites.is_voxel(id) else enemy_name
    _sprite = AnimatedSprite2D.new()
    _sprite.sprite_frames = f
    _sprite.centered = false
    _sprite.scale = Vector2.ONE * EnemySprites.scale_for(id)
    add_child(_sprite)
    _sprite.play("idle")
    _fit("idle")


func _fit(anim: String) -> void:
    var sz := _sprite.sprite_frames.get_frame_texture(anim, 0).get_size()
    _sprite.offset = Vector2(-sz.x * 0.5, -sz.y)         # feet at the node origin


func _play(anim: String) -> void:
    if _sprite == null or _anim_lock > 0.0 or _sprite.animation == anim:
        return
    _sprite.speed_scale = 1.0
    _sprite.play(anim)
    _fit(anim)


## Plays a one-shot creature animation lasting `duration` seconds (stretched to fit), if it has one.
func _play_once(anim: String, duration: float) -> void:
    if _sprite == null or not _sprite.sprite_frames.has_animation(anim):
        return
    var n := _sprite.sprite_frames.get_frame_count(anim)
    var natural := float(n) / maxf(1.0, _sprite.sprite_frames.get_animation_speed(anim))
    _sprite.speed_scale = natural / maxf(0.05, duration)
    _sprite.stop()
    _sprite.play(anim)
    _fit(anim)
    _anim_lock = duration


func _look_at_x(x: float) -> void:
    if _sprite != null and absf(x - position.x) > 1.0:
        _sprite.flip_h = x < position.x                 # the art faces right


func _update_sprite() -> void:
    if _sprite == null:
        return
    _play("run" if state == State.CHASE else "idle")
    if state == State.WINDUP:
        _look_at_x(_aim.x)
    var k := 1.0 - clampf(_timer / windup_time, 0.0, 1.0)
    if _flash > 0.0:
        _sprite.modulate = Color(2.5, 2.5, 2.5)
    elif state == State.WINDUP:
        _sprite.modulate = Color(1.0, 1.0 - 0.45 * k, 1.0 - 0.45 * k)
    else:
        _sprite.modulate = Color.WHITE


func _do_lunge() -> void:
    if _sprite == null or not _sprite.is_inside_tree():
        return
    var t := _sprite.create_tween()
    t.tween_property(_sprite, "position", (_aim - position).normalized() * 8.0, 0.08)
    t.tween_property(_sprite, "position", Vector2.ZERO, 0.15)


## Floor 10 boss (D-014 principles; numbers are tuning placeholders): much tougher, bigger strike,
## longer and clearer wind-up so the player can read and dodge it.
func make_boss() -> void:
    enemy_name = "Orc Chieftain"
    base_max_hp *= 8
    max_hp = base_max_hp
    hp = max_hp
    atk = roundi(float(atk) * 1.6)
    armor += 4
    strike_radius *= 1.5
    strike_range *= 1.3
    windup_time = 1.1
    if _sprite != null:
        _sprite.scale *= 1.5


func aim_point() -> Vector2:
    return _aim


func windup_left() -> float:
    return _timer if state == State.WINDUP else 0.0


func is_telegraphing() -> bool:
    return state == State.WINDUP


## D-042: only control effects (stun, knock-back, "interrupt") break a wind-up. Returns true if one broke.
func interrupt() -> bool:
    if state != State.WINDUP:
        return false
    state = State.RECOVER
    _timer = recover_time
    _anim_lock = 0.0
    _play_once("hurt", 0.4)
    FloatingText.spawn(self, "interrupted", Color(1.0, 0.85, 0.4), false)
    return true


func taunt(by: SandboxHero, duration: float) -> void:
    taunted_by = by
    taunt_t = maxf(taunt_t, duration)


## heroes = every hero that is not permanently dead (downed ones can still be hit by a strike).
func tick(delta: float, heroes: Array, map: NavMap) -> void:
    tick_combat(delta)
    if not alive:
        return
    _repath = maxf(0.0, _repath - delta)
    taunt_t = maxf(0.0, taunt_t - delta)
    if _flash > 0.0:
        _flash = maxf(0.0, _flash - delta)
    _anim_lock = maxf(0.0, _anim_lock - delta)
    if not can_act():
        interrupt()                       # a stun breaks the wind-up (D-042)
        _update_sprite()
        queue_redraw()
        return
    match state:
        State.WINDUP:
            _timer -= delta
            if _timer <= 0.0:
                _strike(heroes)
                state = State.RECOVER
                _timer = recover_time
        State.RECOVER:
            _timer -= delta
            if _timer <= 0.0:
                state = State.IDLE
        _:
            var t := _nearest_hero(heroes)
            focus = t
            if t == null:
                state = State.IDLE
            elif position.distance_to(t.position) <= strike_range:
                state = State.WINDUP
                _timer = windup_time
                _play_once("attack", windup_time + 0.15)    # the blow lands when the wind-up ends
                _aim = t.position
            else:
                state = State.CHASE
                _step_toward(t.position, delta, map)
    _update_sprite()
    queue_redraw()


## Follows a cached path, recomputed every REPATH_EVERY seconds (not every frame: performance).
func _step_toward(goal: Vector2, delta: float, map: NavMap) -> void:
    if not can_move():
        return
    if _repath <= 0.0 or _path.is_empty():
        _repath = REPATH_EVERY
        _path = map.find_path(position, goal)
    if _path.is_empty():
        return
    var to: Vector2 = _path[0] - position
    if to.length() < 4.0:
        _path.remove_at(0)
        return
    _look_at_x(_path[0].x)
    var np := position + to.normalized() * speed * move_mult() * delta
    if not map.is_blocked(np):
        position = np


func _nearest_hero(heroes: Array) -> SandboxHero:
    if taunt_t > 0.0 and taunted_by != null and is_instance_valid(taunted_by) and taunted_by.alive:
        return taunted_by
    var best: SandboxHero = null
    var best_d := perception
    for h in heroes:
        if not h.alive:
            continue                          # downed heroes are not chased (no executions, D-036)
        var d: float = position.distance_to(h.position)
        if d < best_d:
            best_d = d
            best = h
    return best


func _strike(heroes: Array) -> void:
    _do_lunge()
    # look per creature (CombatVFX.ENEMY_FX): claws, slime splashes, spores, slams, spells; sized to the strike
    var fx := CombatVFX.enemy_fx(type_id)
    var sc := strike_radius / 44.0
    var at := _aim + Vector2(0, -12)
    if fx.has("proj"):
        CombatVFX.projectile(get_parent(), position + Vector2(0, -20), at, String(fx["proj"]), String(fx["hit"]), 900.0, 1.0, sc)
    else:
        CombatVFX.play(get_parent(), at, String(fx.get("hit", "claw")), sc, _aim.x < position.x)
    if fx.has("extra"):
        CombatVFX.play(get_parent(), _aim, String(fx["extra"]), sc)
    for h in heroes:
        if not h.dead and h.position.distance_to(_aim) <= strike_radius:
            h.take_hit(DamageInfo.make(float(atk), "physical", self, crit_chance, combat_rng))


func _on_hit(_info: DamageInfo, dmg: int) -> void:
    _flash = 0.12
    if dmg > 0 and state != State.WINDUP and hp > 0:
        _play_once("hurt", 0.3)


func _on_die() -> void:
    EnemySprites.spawn_death(self, _sprite)
    visible = false


func _draw() -> void:
    if not alive:
        return
    var body := Color(0.85, 0.30, 0.30) if _flash <= 0.0 else Color.WHITE
    var bar_y := -34.0
    if _sprite == null:
        draw_circle(Vector2(0, -12), 12.0, body)
    else:
        bar_y = -40.0
    draw_rect(Rect2(-15, bar_y, 30, 4), Color(0.1, 0.1, 0.1, 0.8))
    draw_rect(Rect2(-15, bar_y, 30.0 * float(hp) / float(maxi(1, max_hp)), 4), Color(0.9, 0.35, 0.35))
    if state == State.WINDUP:
        var k := 1.0 - clampf(_timer / windup_time, 0.0, 1.0)
        draw_set_transform(_aim - position, 0.0, Vector2(1.0, 0.55))
        draw_circle(Vector2.ZERO, strike_radius, Color(1.0, 0.2, 0.2, 0.15 + 0.25 * k))
        draw_arc(Vector2.ZERO, strike_radius, 0.0, TAU, 32, Color(1.0, 0.3, 0.3), 2.0)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
