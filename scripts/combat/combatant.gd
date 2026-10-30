class_name Combatant
extends Node2D
## Shared base of every unit in a mission (heroes and enemies): health, defences, the single
## damage path (CombatRules.resolve), status effects, downed/agony/rescue (heroes, D-036) and death.
## Subclasses add movement, AI, drawing and animation through the _on_* hooks.

signal died(unit)
signal went_down(unit)
signal revived(unit)

var base_max_hp: int = 1
var max_hp: int = 1
var hp: int = 1
var armor: int = 0
var mres: int = 0
var crit_chance: float = 0.0
var status_resist: float = 0.0
var alive: bool = true            # can act (false while downed or dead)
var dead: bool = false            # permanent
var downed: bool = false
var can_be_downed: bool = false   # heroes only (D-036)
var agony: float = 0.0            # seconds left while downed
var killed_by: String = ""
var statuses: Dictionary = {}     # id -> {"t": seconds, "mag": float, "stacks": int, "src": Node2D}
var combat_rng := RandomNumberGenerator.new()
var _status_tick: float = 0.0


func setup_combat(p_max_hp: int, p_armor: int, p_mres: int, p_crit: float, p_resist: float, seed_value: int) -> void:
    base_max_hp = maxi(1, p_max_hp)
    max_hp = base_max_hp
    hp = max_hp
    armor = p_armor
    mres = p_mres
    crit_chance = p_crit
    status_resist = p_resist
    combat_rng.seed = seed_value


# --- damage -----------------------------------------------------------------------------

## The one way to hurt a unit. Returns the damage dealt (0 if absorbed, dead or downed).
func take_hit(info: DamageInfo) -> int:
    if dead:
        return 0
    if downed:
        agony = maxf(0.0, agony - CombatRules.AGONY_HIT_PENALTY)
        return 0
    var dmg := CombatRules.resolve(info, self)
    if statuses.has("shield"):
        var s: Dictionary = statuses["shield"]
        var absorbed := mini(dmg, int(s["mag"]))
        s["mag"] = float(s["mag"]) - absorbed
        dmg -= absorbed
        if float(s["mag"]) <= 0.0:
            statuses.erase("shield")
    if info.source != null and is_instance_valid(info.source) and info.source.get("enemy_name") != null:
        killed_by = str(info.source.get("enemy_name"))
    hp = maxi(0, hp - dmg)
    FloatingText.spawn(self, str(dmg) + ("!" if info.crit else ""), Color(1.0, 0.85, 0.2) if info.crit else Color(1, 1, 1), info.crit)
    _on_hit(info, dmg)
    if hp <= 0:
        if can_be_downed:
            go_down()
        else:
            die()
    return dmg


## Legacy entry point: already-mitigated damage, no crit (kept for older callers and tests).
func take_damage(amount: int, source: Node2D = null) -> void:
    var info := DamageInfo.make(float(amount), "true", source)
    take_hit(info)


func heal(amount: int) -> int:
    if not alive:
        return 0
    var before := hp
    hp = mini(max_hp, hp + maxi(0, amount))
    if hp > before:
        FloatingText.spawn(self, "+%d" % (hp - before), Color(0.45, 1.0, 0.5), false)
    return hp - before


# --- downed / rescue / death (D-036) --------------------------------------------------------

func go_down() -> void:
    if dead or downed:
        return
    downed = true
    alive = false
    hp = 0
    agony = CombatRules.AGONY_TIME
    statuses.clear()
    _on_down()
    went_down.emit(self)


func revive(hp_fraction: float) -> void:
    if dead or not downed:
        return
    downed = false
    alive = true
    apply_status("wounded", 99999.0)
    hp = maxi(1, roundi(float(max_hp) * hp_fraction))
    _on_revive()
    revived.emit(self)


func die() -> void:
    if dead:
        return
    dead = true
    downed = false
    alive = false
    hp = 0
    statuses.clear()
    _on_die()
    died.emit(self)


# --- status effects -------------------------------------------------------------------------

## duration is shortened by status resistance (TEM) unless the status says "no_resist".
func apply_status(id: String, duration: float, magnitude: float = 0.0, source: Node2D = null) -> void:
    if dead or not CombatRules.STATUS.has(id):
        return
    var def: Dictionary = CombatRules.STATUS[id]
    var t := duration if def.get("no_resist", false) else duration * (1.0 - status_resist)
    if statuses.has(id):
        var s: Dictionary = statuses[id]
        s["t"] = maxf(float(s["t"]), t)
        s["stacks"] = mini(int(s["stacks"]) + 1, int(def.get("stacks", 1)))
        s["mag"] = maxf(float(s["mag"]), magnitude) if id != "shield" else float(s["mag"]) + magnitude
    else:
        statuses[id] = {"t": t, "mag": magnitude, "stacks": 1, "src": source}
    _recalc_max_hp()


func has_status(id: String) -> bool:
    return statuses.has(id)


func can_move() -> bool:
    return alive and not _blocked("move")


func can_act() -> bool:
    return alive and not _blocked("act")


func move_mult() -> float:
    var m := 1.0
    for id in statuses:
        m *= float(CombatRules.STATUS[id].get("move", 1.0))
    return m


func outgoing_mult() -> float:
    var m := 1.0
    for id in statuses:
        m *= float(CombatRules.STATUS[id].get("out_dmg", 1.0))
    return m


func _blocked(what: String) -> bool:
    for id in statuses:
        if (CombatRules.STATUS[id].get("blocks", []) as Array).has(what):
            return true
    return false


func _recalc_max_hp() -> void:
    var m := 1.0
    for id in statuses:
        m *= float(CombatRules.STATUS[id].get("max_hp", 1.0))
    max_hp = maxi(1, roundi(float(base_max_hp) * m))
    hp = mini(hp, max_hp)


## Call every simulation step: status durations, damage over time, agony countdown.
func tick_combat(delta: float) -> void:
    if dead:
        return
    if downed:
        agony -= delta
        if agony <= 0.0:
            die()
        return
    _status_tick += delta
    var ticks := 0
    while _status_tick >= CombatRules.STATUS_TICK:
        _status_tick -= CombatRules.STATUS_TICK
        ticks += 1
    var expired: Array = []
    var dots: Array = []                  # applied after the loop: a lethal tick clears `statuses`
    for id in statuses:
        var s: Dictionary = statuses[id]
        s["t"] = float(s["t"]) - delta
        var dot := String(CombatRules.STATUS[id].get("dot", ""))
        if dot != "" and ticks > 0:
            var src: Node2D = s["src"] if is_instance_valid(s["src"]) else null
            dots.append(DamageInfo.make(float(s["mag"]) * float(s["stacks"]) * CombatRules.STATUS_TICK * ticks, dot, src))
        if float(s["t"]) <= 0.0:
            expired.append(id)
    for id in expired:
        statuses.erase(id)
    if not expired.is_empty():
        _recalc_max_hp()
    for d in dots:
        if alive:
            take_hit(d)


# --- hooks for subclasses ---------------------------------------------------------------------

func _on_hit(_info: DamageInfo, _dmg: int) -> void:
    pass


func _on_down() -> void:
    pass


func _on_revive() -> void:
    pass


func _on_die() -> void:
    pass
