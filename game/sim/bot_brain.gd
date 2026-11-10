## BotBrain — IA que juega una clase como lo haría un jugador.
##
## Produce el mismo input que el jugador (movimiento, puntería, teclas) para un WarriorSim, así que
## enemigos de clase y bots del simulador usan las mismas skills, costes, cooldowns y barras de cast.
## Comportamientos (según `difficulty` 0..1 y los `traits` del arquetipo):
##  - Lee tus ataques: calcula cuánto falta para el impacto y reacciona con su defensa (bloqueo con
##    Perfect Parry si es bueno, roll/paso evasivo, escudo de maná) con un tiempo de reacción.
##  - Bait: si bloqueas, deja de golpear y usa control (stun, empuje, atracción) en vez de gastar daño.
##  - Punish: si estás aturdido o en stagger, suelta su ráfaga fuerte sin dudar.
##  - Flanqueo: con un aliado ya peleando contigo, el melee rodea hasta tu espalda.
##  - Kiting: los de rango mantienen la distancia, escapan con su movilidad y se retiran con poca vida.
##  - Búsqueda: si te vuelves invisible, va a donde te vio por última vez.
class_name BotBrain
extends RefCounted

const RANGED_CLASSES := [&"mage", &"ranger"]

var rng := RandomNumberGenerator.new()
var difficulty: float = 0.6
var aggression: float = 0.8
var traits: Array = []

var _think_timer: float = 0.0
var _strafe: float = 1.0
var _strafe_timer: float = 0.0
var _pressed: Dictionary = {}
var _hold_guard: float = 0.0
var _reaction: float = 0.0
var _handled_threat: bool = false
var _bait_timer: float = 0.0
var _last_seen: Vector2 = Vector2.ZERO
var _has_seen: bool = false
var _shield_clock: float = 0.0
## Piso de la torre: solo ataca dentro de `aggro_range` (0 = siempre); `group` alerta a todo el campamento.
var aggro_range: float = 0.0
var group: int = -1
var alerted: bool = false
## Reacción escalonada al alertarse por un compañero: se queda quieto este tiempo antes de atacar.
var wake: float = 0.0


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value


func configure(data: Dictionary) -> void:
	difficulty = float(data.get("difficulty", difficulty))
	aggression = float(data.get("aggression", aggression))
	traits = data.get("traits", [])


func think(sim: WarriorSim, world: Object, delta: float) -> Dictionary:
	var out := {"move_dir": Vector2.ZERO, "aim_dir": sim.aim_dir, "aim_point": sim.position, "actions": {}}
	if not sim.alive:
		return out
	if wake > 0.0:
		wake -= delta
		return out
	var target := _pick_target(sim, world)
	if target == null:
		return _search(sim, out, delta)
	_has_seen = true
	_last_seen = target.position
	var to_target: Vector2 = target.position - sim.position
	var distance := maxf(to_target.length(), 0.001)
	var dir := to_target / distance
	out["aim_dir"] = dir
	out["aim_point"] = target.position
	var ranged: bool = sim.class_id in RANGED_CLASSES
	var hp := sim.health / maxf(sim.max_health, 1.0)
	var casting := sim.cast_progress() >= 0.0
	var target_guarding: bool = _flag(target, "guarding") and String(target.get("guard_kind")) == "block"
	var target_down: bool = _num(target, "stun_timer") > 0.0

	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = rng.randf_range(0.6, 1.6)
		_strafe = -_strafe
	var side := dir.orthogonal() * _strafe

	# --- Movimiento ---
	var move := Vector2.ZERO
	var reach := float(sim.ability_for_slot("M1").get("range", 80.0))
	if ranged:
		var ideal := 270.0 if sim.class_id == &"ranger" else 250.0
		if hp < 0.3 or distance < ideal * 0.55:
			move = -dir + side * 0.5          # se retira / mantiene distancia
		elif distance > ideal * 1.35:
			move = dir
		else:
			move = side * 0.45
	elif _bait_timer > 0.0:
		move = side * 0.8 - dir * 0.15        # rodea esperando a que baje la guardia
	elif "flank" in traits and _ally_engaged(sim, world, target) and distance > 40.0:
		var behind: Vector2 = target.position - (target.facing as Vector2) * 55.0
		move = (behind - sim.position).normalized()
	elif distance > reach * 0.8:
		move = dir + side * 0.25
	else:
		move = side * 0.5
	if casting:
		move = Vector2.ZERO  # moverse cancelaría la barra de cast
	out["move_dir"] = move.limit_length(1.0)

	# --- Defensa: leer el ataque del rival y reaccionar ---
	_bait_timer = maxf(0.0, _bait_timer - delta)
	_hold_guard = maxf(0.0, _hold_guard - delta)
	var actions: Dictionary = out["actions"]
	var m2 := sim.ability_for_slot("M2")
	var m2_cast := String(m2.get("cast", ""))
	var time_to_hit := _time_to_hit(target, distance)
	if time_to_hit < 0.0:
		_handled_threat = false
		_reaction = 0.0
	else:
		_reaction += delta
		var react_after := lerpf(0.45, 0.08, difficulty)
		if not _handled_threat and _reaction >= react_after:
			_handled_threat = true
			if rng.randf() < 0.35 + 0.65 * difficulty:
				_react(sim, m2_cast, time_to_hit)
	if m2_cast in ["guard", "mana_shield"]:
		actions["m2"] = _hold_guard > 0.0 and sim.rage() > 3.0

	if "shield" in traits and distance < 300.0 and m2_cast == "guard":
		_shield_clock = fmod(_shield_clock + delta, 2.6)
		if _shield_clock < 1.7:
			_hold_guard = maxf(_hold_guard, 0.2)  # escudo en alto; 0.9 s de cada 2.6 s baja la guardia para atacar

	# --- Skills ---
	_think_timer -= delta
	if _think_timer <= 0.0 and not casting:
		_think_timer = rng.randf_range(0.08, 0.22)
		var chosen := _choose_skill(sim, target, dir, distance, ranged, out, target_guarding, target_down)
		if chosen != "":
			_pressed[String(sim.kit.ACTION_KEYS[chosen])] = 4
	for key: String in _pressed.keys():
		actions[key] = true
		_pressed[key] = int(_pressed[key]) - 1
		if int(_pressed[key]) <= 0:
			_pressed.erase(key)
	# M1 mantenido mientras haya blanco a tiro; no se golpea contra una guardia (bait)
	var m1: Dictionary = sim.ability_for_slot("M1")
	var wants_m1 := _in_range(m1, distance, target) and not (float(m1.get("cost", 0.0)) > sim.rage() + 0.001)
	if target_guarding and "bait" in traits and not ranged:
		_bait_timer = 0.7
	if _bait_timer > 0.0 or (_hold_guard > 0.0 and m2_cast == "guard"):
		wants_m1 = false
	actions["m1"] = wants_m1 and rng.randf() < 0.5 + 0.5 * aggression
	return out


# --- Percepción -------------------------------------------------------------------------


func _pick_target(sim: WarriorSim, world: Object) -> Object:
	var best: Object = null
	var best_score := INF
	for target: Object in world.targets_for(sim):
		if target.has_method("is_invisible") and target.is_invisible() and sim.position.distance_to(target.position) > 40.0:
			continue
		var d := sim.position.distance_to(target.position)
		var score := d * (0.6 if target.health < target.max_health * 0.35 else 1.0)  # remata al débil
		if score < best_score:
			best_score = score
			best = target
	if best != null and aggro_range > 0.0 and not alerted:
		if sim.health < sim.max_health or sim.position.distance_to(best.position) <= aggro_range:
			alerted = true
		else:
			return null
	return best


## Segundos hasta que el golpe del rival conecta (-1 si no hay amenaza cercana).
func _time_to_hit(target: Object, distance: float) -> float:
	if distance > 190.0:
		return -1.0
	if target is WarriorSim:
		var warrior := target as WarriorSim
		if warrior.state == WarriorSim.AttackState.WINDUP and not warrior.current_skill.is_empty():
			return maxf(float(warrior.current_skill.get("windup", 0.2)) - warrior.state_time, 0.0)
		return -1.0
	if target.has_method("is_telegraphing") and target.is_telegraphing():
		return maxf(float(target.telegraph_seconds) - float(target.state_time), 0.0)
	if target.has_method("is_swinging") and target.is_swinging():
		return 0.1
	return -1.0


func _react(sim: WarriorSim, m2_cast: String, time_to_hit: float) -> void:
	match m2_cast:
		"guard":
			# Un buen jugador empieza a bloquear justo antes del impacto (Perfect Parry).
			_hold_guard = 0.7 if time_to_hit < 0.3 or rng.randf() < difficulty else 0.5
		"mana_shield":
			if sim.rage() > 15.0:
				_hold_guard = 0.6
		_:
			if sim._can_start("M2"):
				_pressed["m2"] = 3


func _ally_engaged(sim: WarriorSim, world: Object, target: Object) -> bool:
	for other: WarriorSim in world.all_fighters():
		if other != sim and other.alive and other.team == sim.team and other.position.distance_to(target.position) < 170.0:
			return true
	return false


## Sin objetivo visible: va a donde lo vio por última vez y se queda alerta.
func _search(sim: WarriorSim, out: Dictionary, _delta: float) -> Dictionary:
	if _has_seen and sim.position.distance_to(_last_seen) > 40.0:
		out["move_dir"] = (_last_seen - sim.position).normalized() * 0.7
		out["aim_dir"] = (_last_seen - sim.position).normalized()
	else:
		_has_seen = false
	return out


func _in_range(ability: Dictionary, distance: float, target: Object) -> bool:
	var reach := float(ability.get("range", 80.0)) + float(target.radius)
	match String(ability.get("cast", "melee")):
		"aoe":
			if String(ability.get("target", "")) == "ground":
				return distance <= reach
			return distance <= float(ability.get("radius", 100.0)) + float(target.radius)
		"projectile":
			return distance <= reach * 0.92
		"leap_slam":
			return distance <= reach + float(ability.get("lunge", 0.0)) + 20.0
		_:
			return distance <= reach + 12.0


## Lectura segura de propiedades que no todos los objetivos tienen (muñeco / combatiente).
func _flag(obj: Object, prop: String) -> bool:
	var value: Variant = obj.get(prop)
	return value != null and bool(value)


func _num(obj: Object, prop: String) -> float:
	var value: Variant = obj.get(prop)
	return float(value) if value != null else 0.0


func _is_control(ability: Dictionary) -> bool:
	var effects: Dictionary = ability.get("effects", {})
	return effects.has("stun") or effects.has("knockback") or effects.has("pull") or effects.has("silence") or effects.has("root")


## Elige la mejor skill ahora (puntuación por combos). Devuelve el slot o "".
func _choose_skill(sim: WarriorSim, target: Object, dir: Vector2, distance: float, ranged: bool, out: Dictionary, target_guarding: bool, target_down: bool) -> String:
	var hp_ratio := sim.health / maxf(sim.max_health, 1.0)
	var hesitation := 0.0 if target_down else 0.25 * (1.0 - difficulty)
	var best_slot := ""
	var best_score := -INF
	var best_aim: Variant = null
	for slot: String in ["F", "R", "S2", "E", "Q", "SHIFT"]:
		var ability := sim.ability_for_slot(slot)
		if ability.is_empty() or not sim._can_start(slot):
			continue
		if rng.randf() < hesitation:
			continue
		var cast := String(ability.get("cast", "melee"))
		var kind := String(ability.get("kind", ""))
		if target_guarding and not _is_control(ability) and not cast in ["dash", "teleport", "buff", "team_buff"]:
			continue
		var useful := false
		var aim_override: Variant = null
		match cast:
			"dash":
				if ranged:
					useful = distance < 130.0 or hp_ratio < 0.3
				else:
					useful = distance > 190.0 and distance < float(ability.get("distance", 190.0)) + 90.0
			"teleport":
				if ranged:
					useful = distance < 120.0 or (hp_ratio < 0.3 and distance < 200.0)
					aim_override = sim.position - dir * float(ability.get("range", 200.0))
				else:
					useful = distance > 110.0 and distance < float(ability.get("range", 200.0)) + 60.0
			"counter":
				useful = false
			"buff":
				useful = hp_ratio < 0.5 and distance < 260.0
			"team_buff":
				useful = distance < 340.0 and sim.buff_timer <= 0.0 and sim.absorb_amount <= 0.0
			_:
				useful = _in_range(ability, distance, target)
				if useful and kind == "ultimate" and not target_down and difficulty > 0.5 and rng.randf() < 0.5:
					useful = false
				if useful and String(ability.get("id", "")) == "arcane_silence" and _num(target, "silence_timer") > 0.0:
					useful = false
		if not useful:
			continue
		var score := _combo_score(ability, target, target_down, cast)
		if score > best_score:
			best_score = score
			best_slot = slot
			best_aim = aim_override
	if best_aim != null:
		out["aim_point"] = best_aim
	return best_slot


const STATE_FOR_EFFECT := {"stun": "stunned", "root": "rooted", "slow": "slowed", "silence": "silenced", "mark": "marked"}


## Cuánto conviene lanzar esta skill ahora: remates sobre estados activos, preparación si falta el estado.
func _combo_score(ability: Dictionary, target: Object, target_down: bool, cast: String) -> float:
	var score := 1.0 + rng.randf() * 0.2
	var table: Dictionary = ability.get("bonus_vs", {})
	var ready := 0
	for state: String in table:
		if _target_state(target, state):
			ready += 1
	if not table.is_empty():
		score += 3.0 * float(ready) - (0.8 if ready == 0 else 0.0)  # los remates esperan a su preparación
	var effects: Dictionary = ability.get("effects", {})
	for key: String in STATE_FOR_EFFECT:
		if effects.has(key):
			score += -1.5 if _target_state(target, String(STATE_FOR_EFFECT[key])) else 1.5  # preparar el combo
	if String(ability.get("kind", "")) == "ultimate":
		score += 2.0 if target_down else -0.5
	if cast == "team_buff":
		score += 1.0
	return score


func _target_state(target: Object, state: String) -> bool:
	match state:
		"stunned":
			return _num(target, "stun_timer") > 0.0
		"rooted":
			return _num(target, "root_timer") > 0.0
		"slowed":
			return _num(target, "slow_timer") > 0.0
		"silenced":
			return _num(target, "silence_timer") > 0.0
		"marked":
			return _num(target, "mark_timer") > 0.0 or _num(target, "vulnerable_timer") > 0.0
		"poisoned":
			return target.dots.stacks_of(DamageSystem.Type.POISON) > 0
	return false
