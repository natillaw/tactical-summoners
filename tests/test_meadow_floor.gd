extends SceneTree
## Piso 1: el generador es determinista, siempre da 10 enemigos y nada bloquea el spawn.
var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", msg)

func _init() -> void:
	var a := MeadowFloor.generate(7)
	var b := MeadowFloor.generate(7)
	var c := MeadowFloor.generate(8)
	_check(a["spawn"] == b["spawn"] and a["decor"].size() == b["decor"].size(), "misma semilla = mismo piso")
	_check(a["spawn"] != c["spawn"] or a["decor"].size() != c["decor"].size(), "otra semilla = otro piso")
	for seed_value in range(1, 25):
		var d := MeadowFloor.generate(seed_value)
		var total := 0
		for camp: Dictionary in d["camps"]:
			total += camp["enemies"].size()
			for e: Dictionary in camp["enemies"]:
				var p: Vector2 = e["pos"]
				_check(Rect2(Vector2.ZERO, MeadowFloor.SIZE).has_point(p), "enemigo dentro del mapa (semilla %d)" % seed_value)
				for o: Dictionary in d["obstacles"]:
					_check(p.distance_to(o["position"]) > float(o["radius"]) + 12.0, "enemigo no dentro de un obstáculo (semilla %d)" % seed_value)
		_check(total == MeadowFloor.KILL_GOAL, "10 enemigos (semilla %d, hay %d)" % [seed_value, total])
		for o: Dictionary in d["obstacles"]:
			_check(d["spawn"].distance_to(o["position"]) > float(o["radius"]) + 30.0, "spawn libre (semilla %d)" % seed_value)
	# Pisos 1-10: enemigos dentro del mapa y libres de obstáculos, más enemigos y nivel al subir, salida libre.
	var prev_total := 0
	for fl in range(1, 11):
		var d := MeadowFloor.generate(500 + fl, fl)
		var total := 0
		for camp: Dictionary in d["camps"]:
			for e: Dictionary in camp["enemies"]:
				total += 1
				_check(int(e["level"]) >= fl and int(e["level"]) <= fl + 1, "nivel del enemigo = piso (o +1 si es el duelo/guardián) (%d)" % fl)
				for o: Dictionary in d["obstacles"]:
					_check((e["pos"] as Vector2).distance_to(o["position"]) > float(o["radius"]) + 12.0, "enemigo fuera de obstáculos (piso %d)" % fl)
		_check(int(d["quest"]["kill"]) == total, "la misión cuenta todos los enemigos (piso %d)" % fl)
		_check(Rect2(Vector2.ZERO, MeadowFloor.SIZE).has_point(d["exit"]), "salida dentro del mapa (piso %d)" % fl)
		# Los pisos de jefe (5 y 10) cambian élites por el Coloso y sus esbirros: menos enemigos, pelea más larga.
		if fl % 5 != 0 and (fl - 1) % 5 != 0:
			_check(total >= prev_total - 2, "la dificultad no baja de golpe (piso %d: %d)" % [fl, total])
		var bosses := 0
		for ci in range((d["camps"] as Array).size()):
			var elites := 0
			var minions := 0
			for e: Dictionary in d["camps"][ci]["enemies"]:
				var tier := EnemyArchetypes.tier_of(String(e["arch"]))
				elites += 1 if tier == "elite" else 0
				minions += 1 if tier == "minion" else 0
				bosses += 1 if tier == "boss" else 0
			if fl == 1:
				_check(elites == 0 and minions <= 4, "piso 1 (tutorial): solo esbirros, como mucho 4 por campamento")
			if ci == 0:
				_check(elites == 0, "el primer campamento nunca tiene élite (piso %d)" % fl)
			_check(elites <= 2, "como mucho 2 élites por campamento (piso %d)" % fl)
		_check(bosses == (1 if fl % 5 == 0 else 0), "jefe solo en los pisos 5 y 10 (piso %d)" % fl)
		prev_total = total
	_check(MeadowFloor.generate(9, 1)["quest"]["kill"] == 10, "piso 1 mantiene los 10 enemigos")
	# Esbirros: solo ataque básico + 1 o 2 skills como máximo, en todos los pisos; no reaccionan (rasgo dumb).
	for id: String in EnemyArchetypes.ids():
		var data := EnemyArchetypes.data(id)
		if String(data.get("tier", "")) == "minion":
			_check(data.has("skills") and (data["skills"] as Array).size() <= EnemyArchetypes.MINION_MAX_SKILLS and "dumb" in data["traits"], "esbirro limitado: " + id)
	# Fórmula por piso: el esbirro es débil frente a un élite y todo crece suave con el piso.
	var m1 := EnemyArchetypes.floor_scale("esbirro", 1)
	var m10 := EnemyArchetypes.floor_scale("esbirro", 10)
	var e1 := EnemyArchetypes.floor_scale("soldado", 1)
	_check(float(m1["health_mult"]) < float(e1["health_mult"]) * 0.5 and float(m1["damage_mult"]) < float(e1["damage_mult"]), "esbirro mucho más débil que un élite")
	_check(float(m10["damage_mult"]) > float(m1["damage_mult"]) and float(m10["damage_mult"]) < float(m1["damage_mult"]) * 2.0, "el daño crece con el piso sin dispararse")
	_check(float(m1["windup_mult"]) >= 1.5, "los enemigos avisan sus golpes (windup x%.1f)" % float(m1["windup_mult"]))
	print("meadow floor: ", "OK" if fails == 0 else "%d fallos" % fails)
	quit(1 if fails > 0 else 0)
