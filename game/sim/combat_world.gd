## CombatWorld — unidad determinista de simulación del primer corte.
##
## Es el único Tickable registrado en TickManager. Dentro de un tick avanza al
## Warrior y a los muñecos en orden fijo. El mismo objeto se puede crear y
## avanzar en headless (step) sin árbol de escena, y su snapshot() es la base
## para netcode: input por tick -> simulación -> snapshot.
class_name CombatWorld
extends "res://core/tickable.gd"

signal tick_advanced(tick_number: int)

const WarriorSimScript := preload("res://game/sim/warrior_sim.gd")
const DummySimScript := preload("res://game/sim/dummy_sim.gd")
const EnemySimScript := preload("res://game/sim/enemy_sim.gd")

const DEFAULT_BOUNDS := Rect2(0, 0, 960, 640)

var tick: int = 0
var rng: RandomNumberGenerator
var bounds: Rect2 = DEFAULT_BOUNDS
var obstacles: Array = []
var warrior: WarriorSim
var dummies: Array = []
var pending_input: InputMessage = null
## Otros combatientes (enemigos de clase, rivales del simulador); el jugador es `warrior`.
var fighters: Array = []
var warrior_bot: BotBrain = null


func _init(seed_value: int = 1337) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	warrior = WarriorSimScript.new(self)
	warrior.position = Vector2(480, 380)
	warrior.progression.leveled_up.connect(_sync_enemy_levels)


func setup_arena(arena_bounds: Rect2, arena_obstacles: Array = []) -> void:
	bounds = arena_bounds
	obstacles = arena_obstacles.duplicate()
	warrior.position = bounds.get_center()
	warrior.reset(bounds.get_center())


func add_dummy(spawn: Vector2, auto_attack: bool = true) -> DummySim:
	var dummy := DummySimScript.new(self, spawn, auto_attack)
	dummies.append(dummy)
	return dummy


## Enemigo guerrero (EnemySim): vive en `dummies`, así que colisiones, reset y
## actores lo tratan igual que a un muñeco. Su nivel sigue al del jugador.
func add_enemy(spawn: Vector2, level: int = 1) -> EnemySim:
	var enemy := EnemySimScript.new(self, spawn, level)
	dummies.append(enemy)
	enemy.died.connect(func() -> void: warrior.gain_xp(enemy.xp_reward))
	return enemy


func submit_input(input: InputMessage) -> void:
	pending_input = input


func step(delta: float, tick_number: int = -1) -> void:
	if tick_number >= 0:
		tick = tick_number
	else:
		tick += 1

	var player_input: Variant = pending_input.to_dict() if pending_input != null else {}
	if warrior_bot != null:
		player_input = warrior_bot.think(warrior, self, delta)
	warrior.step(tick, delta, player_input)
	_propagate_alerts()
	for fighter: WarriorSim in fighters:
		fighter.step(tick, delta, fighter.brain.think(fighter, self, delta) if fighter.brain != null else {})
	for dummy: DummySim in dummies:
		dummy.step(tick, delta, warrior)

	pending_input = null
	tick_advanced.emit(tick)


func _on_tick(tick_number: int, delta: float) -> void:
	step(delta, tick_number)


func _sync_enemy_levels(level: int) -> void:
	for dummy: DummySim in dummies:
		if dummy is EnemySim:
			(dummy as EnemySim).set_level(level)


func all_fighters() -> Array:
	var all: Array = [warrior]
	all.append_array(fighters)
	return all


## Objetivos de `sim`: muñecos/enemigos clásicos (equipo 1) y combatientes del otro equipo.
func targets_for(sim: Object) -> Array:
	var out: Array = []
	if int(sim.get("team")) == 0:
		for dummy: DummySim in dummies:
			if dummy.alive:
				out.append(dummy)
	for fighter: WarriorSim in all_fighters():
		if fighter != sim and fighter.alive and fighter.team != int(sim.get("team")):
			out.append(fighter)
	return out


## Añade un combatiente que juega una clase con IA (BotBrain).
func add_fighter(class_id: StringName, team: int, spawn: Vector2, level: int = 1, display_name: String = "") -> WarriorSim:
	var fighter: WarriorSim = WarriorSimScript.new(self)
	fighter.set_class(class_id)
	fighter.team = team
	fighter.display_name = display_name if display_name != "" else String(fighter.kit.CLASS_NAME)
	fighter.spawn_position = spawn
	fighter.reset(spawn)
	fighter.progression.set_level(level)
	fighter.brain = BotBrain.new(rng.randi())
	var ult: Dictionary = fighter.ability_for_slot("F")
	if not ult.is_empty():
		fighter.cooldowns[String(ult["id"])] = 25.0  # los bots no abren con su ultimate
	fighters.append(fighter)
	return fighter


## Enemigo de arquetipo (EnemyArchetypes): clase + dificultad + rasgos de comportamiento.
func add_archetype(archetype_id: String, team: int, spawn: Vector2, base_level: int = 1) -> WarriorSim:
	var data := EnemyArchetypes.data(archetype_id)
	if data.is_empty():
		return add_fighter(StringName(archetype_id), team, spawn, base_level)
	var shown := ("Élite " if String(data.get("tier", "")) == "elite" else "") + String(data["name"])
	var fighter := add_fighter(data["class"], team, spawn, base_level + int(data.get("level_bonus", 0)), shown)
	fighter.brain.configure(data)
	var mods: Dictionary = data.get("mods", {})
	for key: String in mods:
		fighter.mods[key] = float(mods[key])
	fighter.recompute_stats(true)
	return fighter


## Grupo de enemigos del mismo arquetipo repartidos en círculo (enjambre).
func add_swarm(archetype_id: String, count: int, center: Vector2, base_level: int = 1, team: int = 1) -> Array:
	var group: Array = []
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1))
		group.append(add_archetype(archetype_id, team, center + Vector2(cos(angle), sin(angle)) * 90.0, base_level))
	return group


func get_living_dummies() -> Array:
	var living: Array = []
	for dummy: DummySim in dummies:
		if dummy.alive:
			living.append(dummy)
	return living


## Como resolve_position(), pero solo tiene en cuenta muros y pilares. Se usa
## para destinos de salto/banner, que deben poder caer sobre un enemigo.
func clamp_to_arena(desired: Vector2, radius: float) -> Vector2:
	var pos := desired
	pos.x = clampf(pos.x, bounds.position.x + radius, bounds.end.x - radius)
	pos.y = clampf(pos.y, bounds.position.y + radius, bounds.end.y - radius)

	for obstacle: Dictionary in obstacles:
		var center: Vector2 = obstacle["position"]
		var obstacle_radius := float(obstacle["radius"])
		var diff := pos - center
		var min_distance := radius + obstacle_radius
		if diff.length_squared() < min_distance * min_distance:
			if diff.length_squared() < 0.0001:
				diff = Vector2.RIGHT
			pos = center + diff.normalized() * min_distance

	return pos


## `ignore`: el propio cuerpo que se mueve (si no, un enemigo choca consigo mismo).
func resolve_position(desired: Vector2, radius: float, ignore: Object = null) -> Vector2:
	var pos := desired
	pos.x = clampf(pos.x, bounds.position.x + radius, bounds.end.x - radius)
	pos.y = clampf(pos.y, bounds.position.y + radius, bounds.end.y - radius)

	for obstacle: Dictionary in obstacles:
		var center: Vector2 = obstacle["position"]
		var obstacle_radius := float(obstacle["radius"])
		var diff := pos - center
		var min_distance := radius + obstacle_radius
		if diff.length_squared() < min_distance * min_distance:
			if diff.length_squared() < 0.0001:
				diff = Vector2.RIGHT
			pos = center + diff.normalized() * min_distance

	for dummy: DummySim in dummies:
		if not dummy.alive or dummy == ignore:
			continue
		var diff := pos - dummy.position
		var min_distance := radius + dummy.radius
		if diff.length_squared() < min_distance * min_distance:
			if diff.length_squared() < 0.0001:
				diff = Vector2.RIGHT
			pos = dummy.position + diff.normalized() * min_distance

	for fighter: WarriorSim in all_fighters():
		if not fighter.alive or fighter == ignore:
			continue
		var gap := pos - fighter.position
		var min_gap := radius + fighter.radius
		if gap.length_squared() < min_gap * min_gap:
			if gap.length_squared() < 0.0001:
				gap = Vector2.RIGHT
			pos = fighter.position + gap.normalized() * min_gap

	return pos


## Un enemigo alertado (te vio o lo golpearon) alerta a todo su campamento.
func _propagate_alerts() -> void:
	var hot := {}
	for fighter: WarriorSim in fighters:
		var b: BotBrain = fighter.brain
		if b != null and b.group >= 0 and (b.alerted or fighter.health < fighter.max_health):
			hot[b.group] = true
	if hot.is_empty():
		return
	for fighter: WarriorSim in fighters:
		var b: BotBrain = fighter.brain
		if b != null and hot.has(b.group) and not b.alerted:
			b.alerted = true
			b.wake = rng.randf_range(0.5, 2.4)


func reset() -> void:
	tick = 0
	pending_input = null
	warrior.reset(bounds.get_center())
	for dummy: DummySim in dummies:
		dummy.position = dummy.spawn_position
		dummy.revive()
	for fighter: WarriorSim in fighters:
		fighter.reset(fighter.spawn_position)


func snapshot() -> Dictionary:
	var dummy_states: Array = []
	for dummy: DummySim in dummies:
		dummy_states.append(dummy.snapshot())
	return {
		"tick": tick,
		"warrior": warrior.snapshot(),
		"dummies": dummy_states,
	}
