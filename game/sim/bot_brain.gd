## BotBrain — IA que juega una clase como lo haría un jugador.
##
## Produce el mismo input que el jugador (movimiento, puntería, teclas) para un WarriorSim,
## así los enemigos de clase y los bots del simulador usan exactamente las mismas skills,
## costes, cooldowns y barras de cast. Decide cada pocas décimas con algo de azar para que
## no sea una rotación fija.
class_name BotBrain
extends RefCounted

const RANGED_CLASSES := [&"mage", &"ranger"]

var rng := RandomNumberGenerator.new()
## 0..1: probabilidad de saltarse una skill útil (más bajo = más agresivo).
var hesitation: float = 0.12

var _think_timer: float = 0.0
var _strafe: float = 1.0
var _strafe_timer: float = 0.0
var _pressed: Dictionary = {}   # tecla -> ticks restantes
var _keys_for_hold: Array = []


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value


func think(sim: WarriorSim, world: Object, delta: float) -> Dictionary:
	var out := {"move_dir": Vector2.ZERO, "aim_dir": sim.aim_dir, "aim_point": sim.position, "actions": {}}
	if not sim.alive:
		return out
	var target := _pick_target(sim, world)
	if target == null:
		return out
	var to_target: Vector2 = target.position - sim.position
	var distance := maxf(to_target.length(), 0.001)
	var dir := to_target / distance
	out["aim_dir"] = dir
	out["aim_point"] = target.position
	var ranged: bool = sim.class_id in RANGED_CLASSES

	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = rng.randf_range(0.6, 1.6)
		_strafe = -_strafe
	var side := dir.orthogonal() * _strafe

	# --- Movimiento ---
	var reach := _basic_reach(sim)
	var move := Vector2.ZERO
	if ranged:
		var ideal := 240.0
		if distance < ideal * 0.6:
			move = -dir + side * 0.5
		elif distance > ideal * 1.35:
			move = dir
		else:
			move = side * 0.4
	elif distance > reach * 0.8:
		move = dir + side * 0.25
	else:
		move = side * 0.5
	# Quieto mientras llena una barra de cast: moverse la cancelaría.
	if sim.cast_progress() >= 0.0:
		move = Vector2.ZERO
	out["move_dir"] = move.limit_length(1.0)

	# --- Skills ---
	_think_timer -= delta
	var chosen := ""
	if _think_timer <= 0.0 and sim.cast_progress() < 0.0:
		_think_timer = rng.randf_range(0.08, 0.22)
		chosen = _choose_skill(sim, target, dir, distance, ranged, out)

	if chosen != "":
		_pressed[String(sim.kit.ACTION_KEYS[chosen])] = 4
	var actions: Dictionary = out["actions"]
	for key: String in _pressed.keys():
		actions[key] = true
		_pressed[key] = int(_pressed[key]) - 1
		if int(_pressed[key]) <= 0:
			_pressed.erase(key)
	# M2 (defensa): bloquear/escudo mantenido si el rival ataca de cerca; roll/paso con algo de azar.
	var m2 := sim.ability_for_slot("M2")
	var threatened: bool = distance < 150.0 and ((target.has_method("is_attacking") and target.is_attacking()) or (target.has_method("is_telegraphing") and target.is_telegraphing()))
	var m2_cast := String(m2.get("cast", ""))
	if m2_cast in ["guard", "mana_shield"]:
		out["actions"]["m2"] = threatened and sim.rage() > 5.0
	elif threatened and rng.randf() < 0.05 and sim._can_start("M2"):
		_pressed["m2"] = 3
	# M1 mantenido mientras haya blanco a tiro (sin coste en la mayoría de clases).
	var m1: Dictionary = sim.ability_for_slot("M1")
	actions["m1"] = _in_range(m1, distance, target) and not (float(m1.get("cost", 0.0)) > sim.rage() + 0.001)
	return out


func _pick_target(sim: WarriorSim, world: Object) -> Object:
	var best: Object = null
	var best_distance := INF
	for target: Object in world.targets_for(sim):
		if target.has_method("is_invisible") and target.is_invisible() and sim.position.distance_to(target.position) > 40.0:
			continue
		var d := sim.position.distance_to(target.position)
		if d < best_distance:
			best_distance = d
			best = target
	return best


func _basic_reach(sim: WarriorSim) -> float:
	return float(sim.ability_for_slot("M1").get("range", 80.0))


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


## Elige una skill útil ahora (prioridad: ultimate > fuertes > M2 > movilidad). Devuelve el slot.
func _choose_skill(sim: WarriorSim, target: Object, dir: Vector2, distance: float, ranged: bool, out: Dictionary) -> String:
	var hp_ratio := sim.health / maxf(sim.max_health, 1.0)
	for slot: String in ["F", "R", "S2", "E", "Q", "SHIFT"]:
		var ability := sim.ability_for_slot(slot)
		if ability.is_empty() or not sim._can_start(slot):
			continue
		if rng.randf() < hesitation:
			continue
		var cast := String(ability.get("cast", "melee"))
		var kind := String(ability.get("kind", ""))
		var useful := false
		match cast:
			"dash":
				if ranged:
					useful = distance < 130.0  # escapar (la skill suele ir hacia atrás)
				else:
					useful = distance > 190.0 and distance < float(ability.get("distance", 190.0)) + 90.0
			"teleport":
				if ranged:
					useful = distance < 120.0
					out["aim_point"] = sim.position - dir * float(ability.get("range", 200.0))
				else:
					useful = distance > 110.0 and distance < float(ability.get("range", 200.0)) + 60.0
			"counter":
				useful = target.has_method("is_attacking") and target.is_attacking() and distance < 130.0 and rng.randf() < 0.6
			"buff":
				useful = hp_ratio < 0.5 and distance < 260.0
			_:
				useful = _in_range(ability, distance, target)
		if useful:
			return slot
	return ""
