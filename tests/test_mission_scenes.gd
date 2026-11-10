extends Node
## Humo de cada misión con el juego real (escena, actores, interactuables, recompensa).
## godot --headless --path . res://tests/test_mission_scenes.tscn   (necesita los autoloads, por eso es una escena)
var fails := 0
var checks := 0


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", msg)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _ready() -> void:
	CharacterProfile.mode = "floor"
	CharacterProfile.chosen = false  # no tocar la partida guardada
	for type: String in MissionCatalog.TYPES:
		await _run(type)
	print("misiones en escena: ", checks, " comprobaciones, ", "OK" if fails == 0 else "%d fallos" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _run(type: String) -> void:
	CharacterProfile.floor_saves = {}
	CharacterProfile.current_floor = 6 if type != "boss" else 5
	CharacterProfile.max_floor = 1
	CharacterProfile.force_mission = type
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	await _frames(6)
	var ctl: FloorController = main.floor_ctl
	_check(ctl != null and ctl.runtime != null, type + ": el controlador existe")
	if ctl == null:
		main.queue_free()
		return
	var rt: MissionRuntime = ctl.runtime
	var world: CombatWorld = main.world
	var spec: Dictionary = rt.spec
	var eff_type: String = String(rt.effective()["type"])
	var layout: Dictionary = rt.effective()["layout"]
	_check(ctl.hud_text().length() > 20, type + ": el HUD tiene texto")
	# El jugador usa los interactuables con F (junto a ellos).
	var use := func(id: String) -> void:
		world.warrior.position = main.arena.interacts[id]["data"]["pos"]
		main._interact()
	match eff_type:
		"clear", "timed":
			for i in range(int(spec["total"])):
				rt.on_kill(i)
		"hunt", "duel", "guardian", "boss":
			rt.on_kill(int(layout["target"]))
		"stealth":
			var r: Array = spec["ranges"][int(layout["camp"])]
			for i in range(int(r[0]), int(r[1])):
				rt.on_kill(i)
		"waves":
			var before: int = main.arena.enemy_actors.size()
			use.call("altar")
			_check(main.arena.enemy_actors.size() > before, type + ": el altar invoca la primera oleada")
			for w in range((layout["waves"] as Array).size()):
				for f in rt.wave_enemies:
					(f as WarriorSim).alive = false
				rt.tick(0.1, world.warrior.position, true, 1.0)
		"survivor":
			use.call("altar")
			var t := 0.0
			while t < float(layout["seconds"]) + 1.0 and not rt.complete:
				rt.tick(0.5, world.warrior.position, true, 1.0)
				t += 0.5
			_check(main.arena.enemy_actors.size() > 3, type + ": aparecen enemigos durante la supervivencia")
		"gather", "harvest":
			main.floor_ctl.on_gather(String(layout["kind"]), int(layout["count"]))
		"treasure", "ambush":
			var chests: int = 0
			for entry: Dictionary in main.arena.gather_nodes:
				if entry["data"]["kind"] == "chest" and not entry["data"].get("secret", false) and chests < int(layout["count"]):
					world.warrior.position = entry["data"]["pos"]
					main._interact()
					chests += 1
			_check(chests == int(layout["count"]), type + ": se pueden abrir %d cofres con F" % int(layout["count"]))
			if type == "ambush":
				_check(main.arena.enemy_actors.size() >= 3 * chests, type + ": las trampas invocan enemigos")
		"explore":
			for c: Vector2 in spec["clearing_centers"]:
				world.warrior.position = c
				await _frames(2)
		"hidden":
			for entry: Dictionary in main.arena.gather_nodes:
				if entry["data"].get("secret", false):
					world.warrior.position = entry["data"]["pos"]
					main._interact()
			_check(rt.state["hidden_done"] == true, type + ": el cofre oculto se abre con F")
		"banners", "beacons":
			for id: String in layout["ids"]:
				use.call(id)
		"delivery":
			use.call("pickup")
			use.call("dropoff")
		"rescue":
			use.call("cage")
			_check(not main.arena.ally_actors.is_empty(), type + ": aparece el aliado")
			rt.ally.position = layout["destination"]
			world.warrior.position = layout["destination"]
	rt.tick(0.1, world.warrior.position, true, 1.0)
	await _frames(4)
	if type == "choice":
		_check(rt.effective()["type"] == "explore", "choice: por defecto el camino fácil")
		rt.on_interact("signpost")
		_check(rt.effective()["type"] == "duel", "choice: el cartel cambia al camino difícil")
		rt.on_kill(int(rt.effective()["layout"]["target"]))
		rt.tick(0.1, world.warrior.position, true, 1.0)
		await _frames(4)
	_check(rt.complete, type + ": la misión se completa")
	_check(bool(main._floor_save.get("rewarded", false)), type + ": se entrega la recompensa")
	_check(main.reward_panel.visible, type + ": se muestra el resumen")
	_check(CharacterProfile.max_floor >= CharacterProfile.current_floor + 1, type + ": se desbloquea el piso siguiente")
	_check(main.arena.exit_portal.visible == (CharacterProfile.current_floor < MeadowFloor.MAX_FLOOR), type + ": el portal de salida se abre")
	main._save_progress_state()
	_check(bool(main._floor_save["done"]) and main._floor_save.has("mission_state"), type + ": el guardado incluye la misión")
	main.queue_free()
	await _frames(3)
