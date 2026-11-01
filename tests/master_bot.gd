class_name MasterBot
extends RefCounted
## D-082: a scripted player that, like a real one, drives ONLY the Master (right-click moves, Q attacks,
## W E R skills, Space dashes, holds F to lift a fallen ally) and leads the other four with pings
## (SandboxScreen.ping) and Commands (use_command). It never gives orders to the other heroes directly.
##   style "loco": attacks the nearest foe, pings "attack" at it without thinking, never retreats.
##   style "tactical": explores toward the goal, marks and pings the priority targets (casters, healers,
##   the leader, lookouts), uses Commands at good moments, warns of marked areas, retreats when hurt and
##   lifts the fallen.

const ENGAGE := 320.0
const PING_EVERY := {"loco": 1.0, "tactical": 2.5}
const REVIVE_GO := 420.0

var style: String = "tactical"
var stats := {"pings": 0, "commands": 0, "skills": 0, "revives": 0, "retreats": 0, "dashes": 0}
var _ping_cd: float = 0.0
var _move_cd: float = 0.0
var _last_goal: Vector2 = Vector2.INF
var _pinged: Dictionary = {}          # foe -> already marked (tactical)
var _lifting: SandboxHero = null
var _lift_t: float = 0.0
var _given_up: Dictionary = {}        # fallen allies it could not reach in time (gives up after LIFT_GIVE_UP s)
const LIFT_GIVE_UP := 15.0
const RETREAT_EVERY := 4.0
var _retreat_cd: float = 0.0


func _init(p_style: String = "tactical") -> void:
    style = p_style


func tactical() -> bool:
    return style == "tactical"


## The hero the bot plays: the Master, or (a squad without one) the hero in slot 1.
func lead(sb: SandboxScreen) -> SandboxHero:
    if sb.master_hero != null:
        return sb.master_hero
    if sb.controlled() == null and not sb.heroes.is_empty() and sb.heroes[0].alive:
        sb.select_slot(0)
    return sb.controlled()


## One decision (call every few tenths of a second of game time). goal = where the mission wants the squad
## (relic, clue, exit...; INF = nothing). Returns the skills + commands used.
func think(sb: SandboxScreen, goal: Vector2, dt: float) -> int:
    _ping_cd -= dt
    _move_cd -= dt
    var m := lead(sb)
    sb.interact_held = false
    if m == null or not m.alive or sb.mission_state != SandboxScreen.Mission.ACTIVE:
        return 0
    var used := 0
    var foes: Array = sb.visible_enemies()
    var near: SandboxEnemy = _nearest(foes, m.position, ENGAGE)
    # survival of the Master: step out of a marked area (dash on timing)
    if _dodge(sb, m, foes):
        return used
    if tactical():
        used += _tactical_calls(sb, m, foes, near)
        if _revive(sb, m, foes):
            return used
        if near != null and float(m.hp) < float(m.max_hp) * 0.3:
            stats["retreats"] += 1
            _ping(sb, "danger", near.position)
            _move(sb, m.position + (m.position - near.position).normalized() * 160.0, true)
            return used
    if near != null:
        var key := _priority(foes, m.position) if tactical() else near
        if key == null:
            key = near
        if _ping_cd <= 0.0:
            _ping_cd = float(PING_EVERY[style])
            _ping(sb, "attack", key.position, key)
        if sb.use_command(0, key.position) > 0:         # focus fire whenever it is ready
            stats["commands"] += 1
            used += 1
        if m.position.distance_to(key.position) > m.attack_range() * 0.9:
            _move(sb, key.position, false)
        else:
            m.aimed_attack(key.position, sb.living_enemies(), sb.map)   # Q at the foe
        for i in m.slots.size():
            if m.skill_ready(i):
                sb.select_only([m])
                if sb.use_skill_selected(i, key.position) > 0:
                    stats["skills"] += 1
                    used += 1
        return used
    for g in sb.nodes:                                # a gathering spot at the Master's feet: hold F
        if is_instance_valid(g) and not g.taken and g.position.distance_to(m.position) <= GatherNode.RANGE:
            sb.interact_held = true
            m.stop()
            return used
    if goal != Vector2.INF:
        _move(sb, goal, false)
        if tactical() and _ping_cd <= 0.0 and m.position.distance_to(goal) > 300.0:
            _ping_cd = 8.0
            _ping(sb, "explore", m.position + (goal - m.position).normalized() * 200.0)
    return used


## Retreat toward the exit like a player: X (the Master runs, the squad is pinged to come), then escape.
## The tactical player first lifts the fallen it can reach (holding F) and calls the squad together;
## it leaves a fallen ally behind only when nobody can reach them safely.
func retreat(sb: SandboxScreen) -> void:
    stats["retreats"] += 1
    var m := lead(sb)
    sb.interact_held = false
    if m == null or not m.alive:
        return
    if tactical():
        _dodge(sb, m, sb.visible_enemies())
        if _revive(sb, m, sb.visible_enemies()):
            if _ping_cd <= 0.0:
                _ping_cd = 3.0
                _ping(sb, "regroup", m.position)
            return
    if sb.extract_block() == "":
        sb.interact_press()                           # F at the exit escapes
        sb.interact_release()
        if sb.mission_state == SandboxScreen.Mission.ACTIVE:
            sb.extract()
        return
    _retreat_cd -= 0.25
    if _retreat_cd <= 0.0:
        _retreat_cd = RETREAT_EVERY                   # X now and then, not every think (pings have an anti-spam)
        sb.squad_key(KEY_X)


func _tactical_calls(sb: SandboxScreen, m: SandboxHero, foes: Array, near: SandboxEnemy) -> int:
    var used := 0
    # mark the priority targets once ("enemy spotted": everybody sees it, DPS focus it)
    for e in foes:
        if not _pinged.has(e) and _is_priority(e) and e.position.distance_to(m.position) < 420.0:
            _pinged[e] = true
            _ping(sb, "spotted", e.position, e)
            break
    # a marked area over the squad: warn them
    for e in foes:
        if e.is_telegraphing() and e.telegraph_radius() >= 60.0:
            var caught := sb.heroes.filter(func(h): return h.alive and h != m and h.position.distance_to(e.aim_point()) <= e.telegraph_radius())
            if caught.size() >= 2:
                _ping(sb, "danger", e.aim_point())
                break
    # Commands: hold fast when someone panics; regroup when the squad is scattered in a fight
    if sb.heroes.any(func(h): return h.alive and h.has_status("panicked")) and sb.use_command(2) > 0:
        stats["commands"] += 1
        used += 1
    if near != null:
        var far := sb.heroes.filter(func(h): return h.alive and h != m and h.position.distance_to(m.position) > 260.0)
        if far.size() >= 2 and sb.use_command(1) > 0:
            stats["commands"] += 1
            used += 1
    return used


func _is_priority(e: SandboxEnemy) -> bool:
    return e.ai_role in ["caster", "leader", "support"] or e.job == "scout" or e.job == "caller" or e.job == "horn" \
        or e.skills.has("mend") or e.skills.has("ward")


func _priority(foes: Array, from: Vector2) -> SandboxEnemy:
    var best: SandboxEnemy = null
    var best_s := INF
    for e in foes:
        if not e.alive or e.position.distance_to(from) > ENGAGE * 1.3:
            continue
        var s: float = e.position.distance_to(from) - (250.0 if _is_priority(e) else 0.0)
        if s < best_s:
            best_s = s
            best = e
    return best


## A fallen ally close by with no foe on top of it: ping "help", walk there and hold F until they are up.
func _revive(sb: SandboxScreen, m: SandboxHero, foes: Array) -> bool:
    if _lifting != null and (not is_instance_valid(_lifting) or not _lifting.downed or _lifting.dead):
        if is_instance_valid(_lifting) and not _lifting.downed and not _lifting.dead:
            stats["revives"] += 1
        _lifting = null
    if _lifting != null:
        _lift_t += 0.25
        if _lift_t > LIFT_GIVE_UP:
            _given_up[_lifting] = true            # could not get to them in time: carry on
            _lifting = null
    if _lifting == null:
        _lift_t = 0.0
        for d in sb.heroes:
            if d.downed and not d.dead and not d.lost and not _given_up.has(d) and d.position.distance_to(m.position) < REVIVE_GO \
                    and _nearest(foes, d.position, 90.0) == null and not sb.heroes.any(func(x): return x.rescue_target == d and x != m):
                _lifting = d
                _ping(sb, "help", d.position)
                break
    if _lifting == null:
        return false
    if m.position.distance_to(_lifting.position) > AiDefs.REVIVE_PROMPT_RANGE * 0.8:
        _move(sb, _lifting.position, false)
    else:
        sb.interact_held = true                      # hold F
    return true


func _dodge(sb: SandboxScreen, m: SandboxHero, foes: Array) -> bool:
    for e in foes:
        if not e.is_telegraphing():
            continue
        var r: float = e.telegraph_radius()
        if r <= 0.0 or m.position.distance_to(e.aim_point()) > r + 6.0:
            continue
        var away: Vector2 = (m.position - e.aim_point()).normalized() if m.position.distance_to(e.aim_point()) > 1.0 else Vector2.RIGHT
        if e.windup_left() < 0.4 and m.dash(away):
            stats["dashes"] += 1
            return true
        _move(sb, e.aim_point() + away * (r + 40.0), true)
        return true
    return false


func _ping(sb: SandboxScreen, kind: String, at: Vector2, foe: SandboxEnemy = null) -> void:
    sb.ping(kind, at, foe)
    stats["pings"] += 1


## Right-click for the Master (it re-paths only when the goal moved or now and then, like a player).
func _move(sb: SandboxScreen, to: Vector2, urgent: bool) -> void:
    var m := lead(sb)
    if m == null:
        return
    if not urgent and _move_cd > 0.0 and _last_goal != Vector2.INF and _last_goal.distance_to(to) < 40.0 and not m.path.is_empty():
        return
    _move_cd = 0.6
    _last_goal = to
    sb.select_only([m])
    sb.order_context(sb.map.nearest_walkable(to))


static func _nearest(foes: Array, from: Vector2, radius: float) -> SandboxEnemy:
    var best: SandboxEnemy = null
    for e in foes:
        if e.alive and e.position.distance_to(from) < radius and (best == null or e.position.distance_to(from) < best.position.distance_to(from)):
            best = e
    return best
