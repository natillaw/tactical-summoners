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
var strike_seq: int = 0              # increments at every wind-up (heroes roll once per strike, D-052)
var _pending_strike: float = -1.0    # D-054: a ranged strike in flight lands when this reaches 0
var _pending_heroes: Array = []
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
# Body size (CombatRules.SIZE, game feel report): presence, knock-back resistance and how it moves.
var size_class: String = "standard"
var body_radius: float = 12.0
var mass: float = 1.0
var is_boss: bool = false
var velocity: Vector2 = Vector2.ZERO
var _accel: float = 0.10
var _turn: float = 16.0
var _cur_speed: float = 0.0
var _heading: Vector2 = Vector2.ZERO
const RUN_ANIM_SPEED := 62.0        # move speed at which the run cycle plays at its authored rate
# Role and encounter (EnemyDefs, D-056): how this creature fights and with whom.
var role: String = "melee"
var home: Vector2 = Vector2.INF     # guard post / patrol start (set when placed)
var group_mates: Array = []         # the rest of its encounter: one spotted or hurt = all alerted
var alerted: bool = false
var dormant: bool = false           # ambusher: hidden and still until a hero comes close or it is hurt
var patrol: Array[Vector2] = []     # patrol route (walked while nothing is perceived)
var _patrol_i: int = 0
var _support_cd: float = 0.0
var _back_cd: float = 0.0
var on_hit_status: Dictionary = {}
var _allies: Array = []             # living creatures (supports heal them), set each tick by the screen


func _init() -> void:
    setup_combat(60, 3, 2, 0.05, 0.0, 1)


func _ready() -> void:
    combat_rng.seed = hash(position) ^ get_instance_id()


## T-024: swaps the placeholder circle for a Pixel Crawler mob. Falls back to the circle when
## the art is not installed (tests/headless without assets keep working).
func setup_type(id: String, floor_num: int = 0) -> void:
    type_id = id
    _apply_def(id, floor_num)
    var f := EnemySprites.build_frames(id)
    if f == null or _sprite != null:
        return
    enemy_name = id.capitalize() if EnemySprites.is_voxel(id) else enemy_name
    apply_size(CombatRules.size_class_of(id))
    _sprite = AnimatedSprite2D.new()
    _sprite.sprite_frames = f
    _sprite.centered = false
    _sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # lunge/slide tweens run in idle
    _sprite.scale = Vector2.ONE * EnemySprites.scale_for(id)
    add_child(_sprite)
    _sprite.play("idle")
    _fit("idle")


## Stats and role from EnemyDefs, scaled a little per floor (more health and damage deeper).
func _apply_def(id: String, floor_num: int) -> void:
    var d := EnemyDefs.info(id)
    var k := 1.0 + EnemyDefs.FLOOR_SCALE * float(maxi(0, floor_num - 1))
    setup_combat(roundi(float(d["hp"]) * k), int(d["armor"]), int(d["mres"]), crit_chance, status_resist, int(combat_rng.seed))
    atk = roundi(float(d["atk"]) * k)
    speed = float(d["speed"])
    role = String(d["role"])
    windup_time = float(d.get("windup", windup_time))
    recover_time = float(d.get("recover", recover_time))
    on_hit_status = d.get("status", {})
    if role == "ranged":
        strike_range = EnemyDefs.RANGED_RANGE
        strike_radius = EnemyDefs.RANGED_RADIUS
    elif role == "support":
        strike_range = 34.0


## Wakes this creature and its whole encounter (spotted a hero, or one of them was hurt).
func alert() -> void:
    if alerted and not dormant:
        return
    alerted = true
    dormant = false
    visible = true
    for m in group_mates:
        if is_instance_valid(m) and m != self and m.alive and not m.alerted:
            m.alert()


## Size class from the measured art (CombatRules.SIZE): bigger creatures reach further, telegraph
## longer, resist knock-back and accelerate/turn slower. Standard leaves every number as it was.
func apply_size(cls: String) -> void:
    var d: Dictionary = CombatRules.SIZE.get(cls, CombatRules.SIZE["standard"])
    size_class = cls
    body_radius = float(d["body"])
    mass = float(d["mass"])
    strike_range *= float(d["reach"])
    strike_radius *= float(d["reach"])
    windup_time *= float(d["windup"])
    _accel = float(d["accel"])
    _turn = float(d["turn"])


## <= 0 when a click at `p` lands on this creature: distance to a vertical capsule from its feet to
## its head, minus a margin that never goes below the old 26 px click radius.
func pick_distance(p: Vector2) -> float:
    var top := position + Vector2(0, -maxf(14.0, _art_height() - 10.0))
    var bottom := position + Vector2(0, -8)
    var q := Geometry2D.get_closest_point_to_segment(p, top, bottom)
    return q.distance_to(p) - maxf(26.0, body_radius * 1.4)


func is_heavy() -> bool:
    return is_boss or size_class == "large" or size_class == "huge"


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
func make_boss(boss_name: String = "Orc Chieftain") -> void:
    enemy_name = boss_name
    base_max_hp *= 8
    max_hp = base_max_hp
    hp = max_hp
    atk = roundi(float(atk) * 1.6)
    armor += 4
    strike_radius *= 1.5
    strike_range *= 1.3
    windup_time = 1.1 * float(CombatRules.SIZE[size_class]["windup"])
    is_boss = true
    mass *= CombatRules.BOSS_MASS_MULT
    body_radius *= 1.5
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
    _support_cd = maxf(0.0, _support_cd - delta)
    _back_cd = maxf(0.0, _back_cd - delta)
    if _pending_strike >= 0.0:
        _pending_strike -= delta
        if _pending_strike < 0.0:
            _land_strike(_pending_heroes)
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
            if dormant:
                for h in heroes:                  # ambush: still and hidden until a hero walks in
                    if h.alive and position.distance_to(h.position) <= EnemyDefs.AMBUSH_WAKE:
                        alert()
                        FloatingText.spawn(self, "ambush!", Color(1.0, 0.45, 0.35), true)
                        break
                if dormant:
                    _update_sprite()
                    return
            var t := _nearest_hero(heroes)
            if t != null and not alerted:
                alert()                           # it saw you: so does its group
            if t != null and role == "guard" and home != Vector2.INF and t.position.distance_to(home) > EnemyDefs.GUARD_LEASH:
                t = null                          # a guard does not leave its post
            focus = t
            if role == "support" and _support_tick():
                pass                              # healed an ally this tick
            elif t == null:
                state = State.IDLE
                _wander(delta, map)
            elif (role == "ranged" or role == "support") and position.distance_to(t.position) < EnemyDefs.BACK_OFF and _back_cd <= 0.0:
                _back_cd = 2.0                    # keep the distance its role wants, but not every tick
                var away := position + (position - t.position).normalized() * 90.0
                if not map.is_blocked(away):
                    _path = map.find_path(position, away)
                    _repath = 1.0
                state = State.CHASE
            elif state == State.CHASE and not _path.is_empty() and _repath > 0.6 and (role == "ranged" or role == "support"):
                _step_toward(_path[_path.size() - 1], delta, map)     # finishing the step back
            elif role == "support" and position.distance_to(t.position) > strike_range:
                state = State.IDLE                # healers stay behind the fight
            elif position.distance_to(t.position) <= strike_range and (role != "ranged" or map.has_line_of_sight(position + Vector2(0, -12), t.position + Vector2(0, -12))):
                state = State.WINDUP
                strike_seq += 1
                _cur_speed = 0.0
                velocity = Vector2.ZERO
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
    # weight: speed builds up over the size's accel time and the heading turns at a limited rate
    # (a golem swings round, a rat darts); top speed itself is unchanged.
    var want := to.normalized()
    if _heading == Vector2.ZERO:
        _heading = want
    var ang := _heading.angle_to(want)
    _heading = _heading.rotated(clampf(ang, -_turn * delta, _turn * delta))
    var top := speed * move_mult()
    _cur_speed = move_toward(_cur_speed, top, top / maxf(0.01, _accel) * delta)
    var np := position + _heading * _cur_speed * delta
    if map.is_blocked(np):
        _heading = want                              # never let the turn rate push it into a wall
        np = position + want * _cur_speed * delta
    if not map.is_blocked(np):
        velocity = (np - position) / maxf(0.0001, delta)
        position = np
        if _sprite != null and _anim_lock <= 0.0:
            _sprite.speed_scale = clampf(_cur_speed / RUN_ANIM_SPEED, 0.6, 1.4)


## Support: heals the most hurt creature in reach every SUPPORT_EVERY seconds (visible, interruptible
## by killing it first: that is the decision the player has to make).
func _support_tick() -> bool:
    if _support_cd > 0.0:
        return false
    var best: SandboxEnemy = null
    var best_k := 0.85
    for a in _allies:
        if not is_instance_valid(a) or not a.alive or a.position.distance_to(position) > EnemyDefs.SUPPORT_REACH:
            continue
        var k := float(a.hp) / float(maxi(1, a.max_hp))
        if k < best_k:
            best_k = k
            best = a
    if best == null:
        return false
    _support_cd = EnemyDefs.SUPPORT_EVERY
    best.heal(roundi(float(best.max_hp) * EnemyDefs.SUPPORT_HEAL))
    CombatVFX.play(get_parent(), best.position + Vector2(0, -14), "heal_toxic", 1.0)
    _play_once("attack", 0.4)
    return true


## Nothing perceived: patrols walk their route, guards drift back to their post, the rest stay put.
func _wander(delta: float, map: NavMap) -> void:
    if not patrol.is_empty():
        var goal: Vector2 = patrol[_patrol_i % patrol.size()]
        if position.distance_to(goal) < 20.0:
            _patrol_i += 1
        else:
            state = State.CHASE
            _step_toward(goal, delta * 0.6, map)         # patrols walk, they do not run
    elif home != Vector2.INF and position.distance_to(home) > 40.0 and (role == "guard" or alerted):
        state = State.CHASE
        _step_toward(home, delta, map)


func _nearest_hero(heroes: Array) -> SandboxHero:
    if taunt_t > 0.0 and taunted_by != null and is_instance_valid(taunted_by) and taunted_by.alive:
        return taunted_by
    var best: SandboxHero = null
    var best_d := perception * (EnemyDefs.ALERT_PERCEPTION if alerted else 1.0)
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
    if role == "ranged" and not fx.has("proj"):
        fx = {"proj": "orb", "hit": String(fx.get("hit", "spark_small"))}    # a ranged strike always flies
    var sc := strike_radius / 44.0
    var at := _aim + Vector2(0, -12)
    if fx.has("proj"):
        var from := position + Vector2(0, -20)
        CombatVFX.projectile(get_parent(), from, at, String(fx["proj"]), String(fx["hit"]), STRIKE_PROJECTILE_SPEED, 1.0, sc)
        _pending_strike = from.distance_to(at) / STRIKE_PROJECTILE_SPEED      # D-054: lands on arrival
        _pending_heroes = heroes
    else:
        CombatVFX.play(get_parent(), at, String(fx.get("hit", "claw")), sc, _aim.x < position.x)
        _land_strike(heroes)
    if fx.has("extra"):
        CombatVFX.play(get_parent(), _aim, String(fx["extra"]), sc)


const STRIKE_PROJECTILE_SPEED := 900.0


## Everyone still inside the marked circle when the blow (or the projectile) lands is hit.
func _land_strike(heroes: Array) -> void:
    for h in heroes:
        if is_instance_valid(h) and not h.dead and h.position.distance_to(_aim) <= strike_radius:
            h.take_hit(DamageInfo.make(float(atk), "physical", self, crit_chance, combat_rng))
            if not on_hit_status.is_empty() and h.alive:
                h.apply_status(String(on_hit_status["id"]), float(on_hit_status["dur"]), float(on_hit_status.get("mag", 0.0)), self)
    if is_boss:
        CombatFeel.shake(self, "medium", _aim - position)
        CombatFeel.freeze(_sprite, "boss")
    elif is_heavy():
        CombatFeel.shake(self, "small", _aim - position)


## Light blows only flash a heavy creature; a blow worth STAGGER_PCT of its health makes it flinch.
const STAGGER_PCT := 0.06


func _on_hit(_info: DamageInfo, dmg: int) -> void:
    _flash = 0.12
    alert()                                       # hurting one wakes its whole encounter
    var flinch := not is_heavy() or float(dmg) >= float(max_hp) * STAGGER_PCT * (2.0 if is_boss else 1.0)
    if dmg > 0 and state != State.WINDUP and hp > 0 and flinch:
        _play_once("hurt", 0.3)


func _on_die() -> void:
    if is_heavy() and is_inside_tree():
        CombatVFX.play(get_parent(), position, "dust_puff", body_radius / 14.0)
        CombatFeel.shake(self, "medium" if is_boss else "small")
    EnemySprites.spawn_death(self, _sprite)
    visible = false


func _draw() -> void:
    if not alive:
        return
    var body := Color(0.85, 0.30, 0.30) if _flash <= 0.0 else Color.WHITE
    # contact shadow sized to the body: tells size and where the creature really stands
    draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.45))
    draw_circle(Vector2.ZERO, body_radius * 1.25, Color(0, 0, 0, 0.3))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    var bar_y := -34.0
    var bar_w := 30.0
    if _sprite == null:
        draw_circle(Vector2(0, -12), 12.0, body)
    else:
        bar_y = -minf(_art_height() + 8.0, 150.0)          # above the head, whatever the size
        bar_w = clampf(body_radius * 2.6, 26.0, 70.0)
    draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, 4), Color(0.1, 0.1, 0.1, 0.8))
    draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * float(hp) / float(maxi(1, max_hp)), 4), Color(0.9, 0.35, 0.35))
    if state == State.WINDUP:
        # telegraph = the real strike area; the inner disc fills it as the blow approaches (lands when full)
        var k := 1.0 - clampf(_timer / windup_time, 0.0, 1.0)
        draw_set_transform(_aim - position, 0.0, Vector2(1.0, 0.55))
        draw_circle(Vector2.ZERO, strike_radius, Color(1.0, 0.2, 0.2, 0.10 + 0.12 * k))
        draw_circle(Vector2.ZERO, strike_radius * k, Color(1.0, 0.25, 0.2, 0.25))
        draw_arc(Vector2.ZERO, strike_radius, 0.0, TAU, 40, Color(1.0, 0.3, 0.3), 3.0 if is_heavy() else 2.0)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Height of the creature on screen (opaque frame height x scale), for the health bar.
func _art_height() -> float:
    if _sprite == null or _sprite.sprite_frames == null:
        return 26.0
    return float(EnemySprites.art_height(type_id)) * _sprite.scale.y
