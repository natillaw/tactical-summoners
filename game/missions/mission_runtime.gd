## MissionRuntime — lógica en vivo de la misión de un piso (progreso, eventos, completado, opcional).
##
## No toca escenas: el juego le avisa de eventos (muertes, recolección, cofres, interacciones, tick) y recibe
## de vuelta si la misión está completa. Para actuar sobre el mundo (spawnear oleadas, avisar al jugador...)
## usa las funciones del diccionario `host`:
##   toast(text) · spawn(arch, pos, level) -> WarriorSim · spawn_ally(pos, level) -> WarriorSim
##   alert_group(camp_index) · interact_state(id, {visible, label, done}) · ally_alive_near(pos, radius) -> bool
## `state` es JSON-seguro y se guarda con el piso (floor_saves[piso]["mission_state"]).
class_name MissionRuntime
extends RefCounted

var spec: Dictionary
var floor_number: int = 1
var state: Dictionary = {}
var host: Dictionary = {}
var dead: Dictionary = {}          # índices de enemigos del piso ya muertos
var complete: bool = false
var wave_enemies: Array = []       # WarriorSim de la oleada actual (no se guarda)
var ally: WarriorSim = null
var _announced_done: bool = false


func _init(p_spec: Dictionary, p_floor: int, saved_state: Dictionary, saved_dead: Array, p_host: Dictionary) -> void:
	spec = p_spec
	floor_number = p_floor
	host = p_host
	for i in saved_dead:
		dead[int(i)] = true
	state = {
		"choice": "a", "elapsed": 0.0, "progress": 0, "wave": 0, "started": false, "timer": 0.0, "carry": false, "delivered": false,
		"banners": [], "beacons": [], "visited": [], "chests": 0, "hidden_done": false, "freed": false, "escort_failed": false,
		"escort_done": false, "ticks": 0, "alerts": 0, "stealth_broken": false, "potions": 0, "hp_ok": true, "complete": false,
	}
	for key in saved_state:
		state[key] = saved_state[key]
	complete = bool(state["complete"])
	if not complete:
		# Al recargar el piso se pierde lo que dependía de la sesión (oleada en curso, reliquia en la mano, aliado).
		state["started"] = false
		state["wave"] = 0
		state["timer"] = 0.0
		state["ticks"] = 0
		state["carry"] = false
		if bool(state["freed"]) and not bool(state["escort_done"]):
			state["freed"] = false
			state["escort_failed"] = false


# --- tipo efectivo -----------------------------------------------------------------------------


## Tipo de objetivo que cuenta ahora: "choice" delega en el camino elegido; un rescate fallido pasa a "clear".
func effective() -> Dictionary:
	var type: String = spec["type"]
	var layout: Dictionary = spec["layout"]
	if type == "choice":
		var sub: Dictionary = layout["b" if state["choice"] == "b" else "a"]
		return {"type": sub["type"], "layout": sub["layout"]}
	if type == "rescue" and bool(state["escort_failed"]):
		return {"type": "clear", "layout": {}}
	return {"type": type, "layout": layout}


func title() -> String:
	var type: String = spec["type"]
	if type == "rescue" and bool(state["escort_failed"]):
		return "El aldeano cayó: limpia el Pliegue"
	return String(MissionCatalog.TYPES[type]["title"])


func description() -> String:
	return MissionCatalog.text_for(spec)


func reward_multiplier() -> float:
	return float(spec.get("reward_mult", 1.0)) * (1.5 if (spec["type"] == "choice" and state["choice"] == "b") else 1.0)


# --- eventos -------------------------------------------------------------------------------------


func on_kill(index: int) -> void:
	dead[index] = true


## Un campamento se alertó (lo vio el jugador o lo golpeó). `camp` = índice de campamento.
func on_alert(camp: int) -> void:
	state["alerts"] = int(state["alerts"]) + 1
	var eff := effective()
	if eff["type"] == "stealth" and camp == int(eff["layout"]["camp"]) and not bool(state["stealth_broken"]):
		state["stealth_broken"] = true
		_toast("¡Te vieron! El campamento sigue contando, pero sin bonus de sigilo.")


func on_gather(kind: String, amount: int) -> void:
	var eff := effective()
	if eff["type"] in ["gather", "harvest"] and String(eff["layout"]["kind"]) == kind:
		state["progress"] = int(state["progress"]) + amount


## `entry` = datos del cofre abierto: {pos, secret, trapped}.
func on_chest(entry: Dictionary) -> void:
	var eff := effective()
	if bool(entry.get("secret", false)):
		state["hidden_done"] = true
		_toast("¡Has encontrado el cofre oculto!")
	else:
		state["chests"] = int(state["chests"]) + 1
	if bool(entry.get("trapped", false)):
		_toast("¡Trampa! Los Ecos acuden al cofre.")
		for i in range(3):
			_spawn_near(entry["pos"], "esbirro", 260.0 + 20.0 * i)


func on_potion() -> void:
	state["potions"] = int(state["potions"]) + 1


func on_player_died() -> void:
	# Lo que dependía de seguir vivo se reinicia (el altar vuelve a estar disponible).
	var eff := effective()
	state["carry"] = false
	if eff["type"] == "waves" or eff["type"] == "survivor":
		state["started"] = false
		state["wave"] = 0
		state["timer"] = 0.0
		wave_enemies.clear()
		_set_altar(true)
	if state["freed"] and not state["escort_done"] and not complete and spec["type"] == "rescue":
		state["escort_failed"] = true


func on_interact(id: String) -> bool:
	var eff := effective()
	var layout: Dictionary = eff["layout"]
	match id:
		"altar":
			if eff["type"] == "waves" or eff["type"] == "survivor":
				if bool(state["started"]):
					return true
				state["started"] = true
				state["wave"] = 0
				state["timer"] = 0.0
				_set_altar(false)
				_toast("El altar despierta: ¡aguanta!")
				if eff["type"] == "waves":
					_next_wave()
				return true
		"signpost":
			if int(state["progress"]) == 0 and dead.is_empty():
				state["choice"] = "b" if state["choice"] == "a" else "a"
				_toast("Camino %s: %s" % ["difícil (+50 % de recompensa)" if state["choice"] == "b" else "fácil", String(MissionCatalog.TYPES[effective()["type"]]["title"])])
				return true
			_toast("Ya has empezado: no puedes cambiar de camino.")
			return true
		"pickup":
			if eff["type"] == "delivery" and not bool(state["carry"]) and not bool(state["delivered"]):
				state["carry"] = true
				_toast("Llevas la reliquia. No caigas.")
				host["interact_state"].call("pickup", {"visible": false})
				return true
		"dropoff":
			if eff["type"] == "delivery":
				if bool(state["carry"]):
					state["carry"] = false
					state["delivered"] = true
					_toast("Reliquia entregada.")
				else:
					_toast("Necesitas la reliquia del primer claro.")
				return true
		"cage":
			if spec["type"] == "rescue" and not bool(state["freed"]):
				state["freed"] = true
				host["interact_state"].call("cage", {"visible": false})
				host["alert_group"].call(int(layout["camp"]))
				ally = host["spawn_ally"].call(layout["cage"], floor_number)
				_toast("¡Libre! Escolta al aldeano hasta el portal verde.")
				return true
	if id.begins_with("banner") and eff["type"] == "banners":
		if not (id in state["banners"]):
			(state["banners"] as Array).append(id)
			host["interact_state"].call(id, {"visible": false})
			host["alert_group"].call(int(layout["camp"]))
			_toast("Estandarte derribado (%d/3)" % (state["banners"] as Array).size())
		return true
	if id.begins_with("beacon") and eff["type"] == "beacons":
		if not (id in state["beacons"]):
			(state["beacons"] as Array).append(id)
			host["interact_state"].call(id, {"done": true, "label": "Baliza encendida"})
			_toast("Baliza encendida (%d/3)" % (state["beacons"] as Array).size())
		return true
	return false


# --- tick -----------------------------------------------------------------------------------------


func tick(delta: float, player_pos: Vector2, player_alive: bool, hp_ratio: float) -> void:
	if complete:
		return
	state["elapsed"] = float(state["elapsed"]) + delta
	if hp_ratio < 0.5:
		state["hp_ok"] = false
	var eff := effective()
	var layout: Dictionary = eff["layout"]
	match String(eff["type"]):
		"survivor":
			if bool(state["started"]) and player_alive:
				state["timer"] = float(state["timer"]) + delta
				var interval := 6.0
				var due := int(float(state["timer"]) / interval)
				if due > int(state["ticks"]):  # una tanda de esbirros cada 6 s
					state["ticks"] = due
					for i in range(2 + floor_number / 4):
						_spawn_near(player_pos, "esbirro" if i % 3 != 2 else "esbirro_arquero", 360.0)
		"waves":
			if bool(state["started"]) and not wave_enemies.is_empty() and _wave_cleared():
				wave_enemies.clear()
				if int(state["wave"]) < (layout["waves"] as Array).size():
					_toast("Oleada superada. ¡La siguiente se acerca!")
					_next_wave()
		"explore":
			var visited: Array = state["visited"]
			var clearings: Array = spec.get("clearing_centers", [])
			for i in range(clearings.size()):
				if not (i in visited) and player_pos.distance_to(clearings[i]) < 150.0:
					visited.append(i)
					_toast("Claro visitado (%d/%d)" % [visited.size(), int(layout["count"])])
		"rescue":
			pass
	if spec["type"] == "rescue" and bool(state["freed"]) and not bool(state["escort_done"]) and not bool(state["escort_failed"]):
		if ally == null or not ally.alive:
			state["escort_failed"] = true
			_toast("El aldeano ha caído. Limpia el Pliegue para continuar.")
		elif ally.position.distance_to(spec["layout"]["destination"]) < 180.0 and player_pos.distance_to(spec["layout"]["destination"]) < 400.0:
			state["escort_done"] = true
	if _check_complete():
		complete = true
		state["complete"] = true


func _check_complete() -> bool:
	var eff := effective()
	var layout: Dictionary = eff["layout"]
	match String(eff["type"]):
		"clear", "timed":
			return _all_dead(0, int(spec["total"]))
		"hunt", "duel", "guardian", "boss":
			return dead.has(int(layout["target"]))
		"stealth":
			var r: Array = spec["ranges"][int(layout["camp"])]
			return _all_dead(int(r[0]), int(r[1]))
		"waves":
			return bool(state["started"]) and int(state["wave"]) >= (layout["waves"] as Array).size() and wave_enemies.is_empty()
		"survivor":
			return bool(state["started"]) and float(state["timer"]) >= float(layout["seconds"])
		"gather", "harvest":
			return int(state["progress"]) >= int(layout["count"])
		"treasure", "ambush":
			return int(state["chests"]) >= int(layout["count"])
		"explore":
			return (state["visited"] as Array).size() >= int(layout["count"])
		"hidden":
			return bool(state["hidden_done"])
		"banners":
			return (state["banners"] as Array).size() >= 3
		"beacons":
			return (state["beacons"] as Array).size() >= 3
		"delivery":
			return bool(state["delivered"])
		"rescue":
			return bool(state["escort_done"])
	return false


func _all_dead(from_index: int, to_index: int) -> bool:
	for i in range(from_index, to_index):
		if not dead.has(i):
			return false
	return true


# --- oleadas / spawns -----------------------------------------------------------------------------


func _next_wave() -> void:
	var waves: Array = effective()["layout"]["waves"]
	var wave := int(state["wave"])
	var altar: Vector2 = effective()["layout"]["altar"]
	var count := int(waves[wave])
	wave_enemies.clear()
	for i in range(count):
		var arch := "esbirro_arquero" if i % 4 == 3 else ("esbirro_mago" if i % 5 == 4 else "esbirro")
		if wave == waves.size() - 1 and i == 0 and floor_number >= 3:
			arch = "soldado" if floor_number < 6 else "duelista"  # la última oleada trae un élite
		var fighter: WarriorSim = _spawn_near(altar, arch, 300.0)
		if fighter != null:
			wave_enemies.append(fighter)
	state["wave"] = wave + 1
	_toast("Oleada %d/%d" % [int(state["wave"]), waves.size()])


func _wave_cleared() -> bool:
	for f in wave_enemies:
		if f != null and (f as WarriorSim).alive:
			return false
	return true


func _spawn_near(center: Vector2, arch: String, radius: float) -> WarriorSim:
	var angle := randf() * TAU
	var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
	var fighter: WarriorSim = host["spawn"].call(arch, pos, floor_number)
	return fighter


func _set_altar(active: bool) -> void:
	host["interact_state"].call("altar", {"visible": true, "label": "Altar (F)" if active else "Altar activo", "done": not active})


func _toast(text: String) -> void:
	if host.has("toast"):
		host["toast"].call(text)


# --- presentación ---------------------------------------------------------------------------------


## Líneas del HUD: progreso de la misión y objetivo opcional.
func lines() -> Array:
	var out: Array = []
	var eff := effective()
	var layout: Dictionary = eff["layout"]
	var kills := dead.size()
	var total := int(spec["total"])
	match String(eff["type"]):
		"clear", "timed":
			out.append("%s %d/%d" % [MissionCatalog.TYPES[eff["type"]]["short"], kills, total])
			if eff["type"] == "timed":
				out.append("Tiempo: %s / %s" % [MissionCatalog.clock(float(state["elapsed"])), MissionCatalog.clock(float(layout["seconds"]))])
		"hunt", "duel", "guardian", "boss":
			out.append("%s: %s" % [MissionCatalog.TYPES[eff["type"]]["short"], "derrotado" if dead.has(int(layout["target"])) else "en pie"])
		"stealth":
			var r: Array = spec["ranges"][int(layout["camp"])]
			var killed := 0
			for i in range(int(r[0]), int(r[1])):
				if dead.has(i):
					killed += 1
			out.append("Campamento %d/%d%s" % [killed, int(r[1]) - int(r[0]), "  (sin sigilo)" if state["stealth_broken"] else "  (en sigilo)"])
		"waves":
			out.append("Oleada %d/%d%s" % [int(state["wave"]), (layout["waves"] as Array).size(), "" if state["started"] else "  (activa el altar con F)"])
		"survivor":
			out.append("Resistes %d/%d s%s" % [int(float(state["timer"])), int(layout["seconds"]), "" if state["started"] else "  (activa el altar con F)"])
		"gather", "harvest":
			out.append("%s %d/%d" % [MissionCatalog.TYPES[eff["type"]]["short"], int(state["progress"]), int(layout["count"])])
		"treasure", "ambush":
			out.append("Cofres %d/%d" % [int(state["chests"]), int(layout["count"])])
		"explore":
			out.append("Claros %d/%d" % [(state["visited"] as Array).size(), int(layout["count"])])
		"hidden":
			out.append("Cofre oculto: %s" % ("encontrado" if state["hidden_done"] else "sin encontrar"))
		"banners":
			out.append("Estandartes %d/3" % (state["banners"] as Array).size())
		"beacons":
			out.append("Balizas %d/3" % (state["beacons"] as Array).size())
		"delivery":
			out.append("Reliquia: %s" % ("entregada" if state["delivered"] else ("la llevas" if state["carry"] else "sin recoger")))
		"rescue":
			out.append("Aldeano: %s" % ("a salvo" if state["escort_done"] else ("libre, escóltalo" if state["freed"] else "preso")))
	if spec["type"] == "choice":
		out.append("Camino: %s (cartel junto al inicio)" % ("difícil" if state["choice"] == "b" else "fácil"))
	var optional: String = spec["optional"]
	if not complete:
		var text: String = MissionCatalog.OPTIONALS[optional]["text"]
		if optional == "speed":
			text = text % MissionCatalog.clock(float(spec["par_seconds"]))
		out.append("Opcional: %s %s" % [text, "✓" if optional_met() else "✗"])
	return out


## ¿Se cumple (aún) el objetivo opcional?
func optional_met() -> bool:
	match String(spec["optional"]):
		"no_potions":
			return int(state["potions"]) == 0
		"speed":
			return float(state["elapsed"]) <= float(spec["par_seconds"])
		"flawless":
			return bool(state["hp_ok"])
		"all_chests":
			return int(state["chests"]) >= int(spec["chests_total"]) and int(spec["chests_total"]) > 0
		"no_alert":
			return int(state["alerts"]) == 0
	return false


## Punto al que apunta la brújula, o `null`.
func compass_target() -> Variant:
	var eff := effective()
	var layout: Dictionary = eff["layout"]
	match String(eff["type"]):
		"hidden":
			return null if state["hidden_done"] else layout["chest_pos"]
		"waves", "survivor":
			return null if state["started"] else layout["altar"]
		"delivery":
			return layout["dropoff"] if state["carry"] else (null if state["delivered"] else layout["pickup"])
		"rescue":
			return layout["destination"] if state["freed"] else layout["cage"]
	return null
