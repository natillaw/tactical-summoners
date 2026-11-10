## FloorController — une la misión del piso (MissionRuntime) con el juego: eventos, interactuables, HUD,
## brújula, recompensas y guardado. `main_3d` solo le avisa de lo que ocurre (muertes, recolección, F...).
class_name FloorController
extends Node

signal completed(result: Dictionary)

const INTERACT_RANGE := 95.0

var main: Node
var arena: Arena3D
var world: CombatWorld
var data: Dictionary
var save: Dictionary
var runtime: MissionRuntime
var _alerted: Dictionary = {}
var _marked: bool = false
var _rng := RandomNumberGenerator.new()


func setup(p_main: Node, p_arena: Arena3D, p_world: CombatWorld, p_data: Dictionary, p_save: Dictionary) -> void:
	main = p_main
	arena = p_arena
	world = p_world
	data = p_data
	save = p_save
	_rng.seed = int(save["seed"]) + 99
	arena.build_interacts(data["interacts"])
	var host := {
		"toast": func(text: String) -> void: main._toast(text),
		"spawn": func(arch: String, pos: Vector2, level: int) -> WarriorSim: return arena.spawn_dynamic(arch, pos, level),
		"spawn_ally": func(pos: Vector2, level: int) -> WarriorSim: return arena.spawn_ally(pos, level),
		"alert_group": func(camp: int) -> void: _alert_group(camp),
		"interact_state": func(id: String, props: Dictionary) -> void: arena.set_interact(id, props),
	}
	runtime = MissionRuntime.new(data["mission"], int(data["floor"]), save.get("mission_state", {}), save["dead"], host)
	_restore_interacts()
	world.warrior.died.connect(func() -> void: runtime.on_player_died())
	arena.fighter_spawned.connect(func(f: WarriorSim) -> void: f.died.connect(func() -> void: main._on_enemy_died(f)))
	if runtime.complete:
		_open_exit()
	_mark_targets()


## Marca como objetivo (barra resaltada) a los enemigos que la misión pide derrotar.
func _mark_targets() -> void:
	var eff := runtime.effective()
	var target := -1
	if eff["type"] in ["hunt", "duel", "guardian", "boss"]:
		target = int(eff["layout"]["target"])
	for fighter: WarriorSim in arena.enemy_index:
		fighter.quest_target = int(arena.enemy_index[fighter]) == target
	_marked = true


func _restore_interacts() -> void:
	var state := runtime.state
	for id: String in state["banners"]:
		arena.set_interact(id, {"visible": false})
	for id: String in state["beacons"]:
		arena.set_interact(id, {"done": true, "label": "Baliza encendida"})
	if bool(state["delivered"]):
		arena.set_interact("pickup", {"visible": false})
		arena.set_interact("dropoff", {"done": true, "label": "Entregada"})
	if runtime.complete and data["mission"]["type"] == "rescue":
		arena.set_interact("cage", {"visible": false})


func _alert_group(camp: int) -> void:
	for fighter: WarriorSim in world.fighters:
		if fighter.brain != null and fighter.brain.group == camp and fighter.team == 1:
			fighter.brain.alerted = true
			fighter.brain.wake = 0.0


func _camp_of(index: int) -> int:
	var ranges: Array = data["mission"]["ranges"]
	for i in range(ranges.size()):
		if index >= int(ranges[i][0]) and index < int(ranges[i][1]):
			return i
	return -1


# --- eventos desde el juego -----------------------------------------------------------------------


func on_enemy_died(fighter: WarriorSim) -> void:
	var tier := String(EnemyArchetypes.data(fighter.archetype_id).get("tier", "minion"))
	world.warrior.gain_xp(FloorRewards.kill_xp(tier, int(data["floor"])))
	if arena.enemy_index.has(fighter):
		runtime.on_kill(int(arena.enemy_index[fighter]))


func on_gather(kind: String, amount: int) -> void:
	runtime.on_gather(kind, amount)


func on_chest(entry_data: Dictionary) -> void:
	runtime.on_chest(entry_data)


func on_potion() -> void:
	runtime.on_potion()


## Interactuable más cercano y usable (visible y no terminado), o {}.
func nearest_interact() -> Dictionary:
	var best: Dictionary = {}
	var best_d := INTERACT_RANGE
	for id: String in arena.interacts:
		var item: Dictionary = arena.interacts[id]
		if not bool(item["visible"]) or (bool(item["done"]) and id != "altar"):
			continue
		var d := world.warrior.position.distance_to(item["data"]["pos"])
		if d < best_d:
			best_d = d
			best = {"id": id, "label": item["data"]["label"]}
	return best


## F: usa el interactuable cercano. Devuelve true si lo gestionó.
func try_interact() -> bool:
	var near := nearest_interact()
	if near.is_empty():
		return false
	var handled := runtime.on_interact(String(near["id"]))
	if handled:
		main.arena.play_sfx(&"ui_confirm", -6.0)
	return handled


# --- bucle ------------------------------------------------------------------------------------------


func _process(delta: float) -> void:
	if runtime == null:
		return
	_detect_alerts()
	var w := world.warrior
	runtime.tick(delta, w.position, w.alive, w.health / maxf(w.max_health, 1.0))
	if runtime.complete and not bool(save.get("rewarded", false)):
		_finish()


func _detect_alerts() -> void:
	for fighter: WarriorSim in arena.enemy_index:
		if fighter.alive and fighter.brain != null and fighter.brain.alerted:
			var camp := _camp_of(int(arena.enemy_index[fighter]))
			if camp >= 0 and not _alerted.has(camp):
				_alerted[camp] = true
				runtime.on_alert(camp)


func _finish() -> void:
	save["rewarded"] = true
	var floor_number := int(data["floor"])
	var kills := 0
	for i in runtime.dead:
		kills += 1
	var result := FloorRewards.compute(floor_number, world.warrior.progression.level, runtime, kills, int(data["mission"]["total"]), _rng)
	world.warrior.gain_xp(int(result["xp"]))
	for id: String in result["loot"]:
		Materials.add(id, int(result["loot"][id]))
	CharacterProfile.max_floor = maxi(CharacterProfile.max_floor, mini(floor_number + 1, MeadowFloor.MAX_FLOOR))
	_open_exit()
	arena.play_sfx(&"quest_done", -4.0)
	result["title"] = runtime.title()
	result["level_after"] = world.warrior.progression.level
	completed.emit(result)


func _open_exit() -> void:
	if arena.exit_portal != null:
		arena.exit_portal.visible = int(data["floor"]) < MeadowFloor.MAX_FLOOR


## Guarda el estado de la misión dentro del guardado del piso.
func save_into(floor_save: Dictionary) -> void:
	if runtime != null:
		floor_save["mission_state"] = runtime.state.duplicate(true)
		floor_save["done"] = runtime.complete


# --- HUD ----------------------------------------------------------------------------------------------


func hud_text() -> String:
	var lines: Array = ["PISO %d · %s" % [int(data["floor"]), String(data["name"])], runtime.title()]
	lines.append_array(runtime.lines())
	if runtime.complete:
		lines.append("¡Misión cumplida!  %s" % ("Portal verde abierto: F cerca para subir  ·  Enter: pueblo" if int(data["floor"]) < MeadowFloor.MAX_FLOOR else "¡Praderas completadas!  ·  Enter: pueblo"))
	else:
		var target: Variant = runtime.compass_target()
		if target != null:
			lines.append(compass_text(world.warrior.position, target))
	return "\n".join(lines)


## "↗ 42 m" hacia un punto del mapa (0° = este, en el plano de la simulación; arriba de la pantalla = norte).
static func compass_text(from: Vector2, to: Vector2) -> String:
	var delta := to - from
	var arrows := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var index := int(round(delta.angle() / (TAU / 8.0))) % 8
	if index < 0:
		index += 8
	return "Destino %s %d m" % [arrows[index], int(delta.length() / 40.0)]
