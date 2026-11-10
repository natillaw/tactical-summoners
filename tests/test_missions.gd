extends SceneTree
## Misiones por piso: diseño válido para todos los tipos, lógica de cada tipo con un host simulado,
## ritmo de nivel y materiales por grado. godot --headless --path . -s tests/test_missions.gd
var fails := 0
var checks := 0
var world: CombatWorld
var calls: Array = []
var spawned: Array = []


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", msg)


func _host() -> Dictionary:
	return {
		"toast": func(text: String) -> void: calls.append("toast:" + text),
		"spawn": func(arch: String, pos: Vector2, level: int) -> WarriorSim:
			var f := world.add_archetype(arch, 1, pos, level)
			spawned.append(f)
			return f,
		"spawn_ally": func(pos: Vector2, level: int) -> WarriorSim:
			return world.add_fighter(&"warrior", 0, pos, level, "Aldeano"),
		"alert_group": func(camp: int) -> void: calls.append("alert:%d" % camp),
		"interact_state": func(id: String, props: Dictionary) -> void: calls.append("state:%s" % id),
	}


func _runtime(data: Dictionary, saved: Dictionary = {}, dead: Array = []) -> MissionRuntime:
	return MissionRuntime.new(data["mission"], int(data["floor"]), saved, dead, _host())


func _init() -> void:
	world = CombatWorld.new(5)
	_test_catalog()
	_test_layouts()
	_test_runtime_types()
	_test_rescue_and_choice()
	_test_optionals_and_save()
	_test_rewards_and_materials()
	print("misiones: ", checks, " comprobaciones, ", "OK" if fails == 0 else "%d fallos" % fails)
	quit(1 if fails > 0 else 0)


func _test_catalog() -> void:
	_check(MissionCatalog.pick_type(1, 1) == "clear", "piso 1 = clear")
	_check(MissionCatalog.pick_type(3, 5) == "boss" and MissionCatalog.pick_type(9, 10) == "boss", "pisos 5 y 10 = boss")
	var seen := {}
	for seed_value in range(1, 80):
		for fl in [2, 3, 4, 6, 7, 8, 9]:
			seen[MissionCatalog.pick_type(seed_value, fl)] = true
	_check(seen.size() == MissionCatalog.POOL.size(), "el sorteo alcanza todos los tipos (%d de %d)" % [seen.size(), MissionCatalog.POOL.size()])
	for type: String in MissionCatalog.TYPES:
		_check(MissionCatalog.TYPES[type].has("title") and MissionCatalog.TYPES[type].has("text"), "tipo con textos: " + type)


func _test_layouts() -> void:
	var rect := Rect2(Vector2.ZERO, MeadowFloor.SIZE)
	for type: String in MissionCatalog.TYPES:
		for fl in [2, 4, 7, 9]:
			for seed_value in [3, 17, 40]:
				var d := MeadowFloor.generate(seed_value, fl, type)
				var spec: Dictionary = d["mission"]
				var tag := "%s/piso %d/semilla %d" % [type, fl, seed_value]
				var total := 0
				for camp: Dictionary in d["camps"]:
					for e: Dictionary in camp["enemies"]:
						total += 1
						_check(rect.has_point(e["pos"]), "enemigo dentro del mapa " + tag)
						for o: Dictionary in d["obstacles"]:
							if (e["pos"] as Vector2).distance_to(o["position"]) <= float(o["radius"]) + 10.0:
								_check(false, "enemigo sobre un obstáculo " + tag)
								break
				_check(total == int(spec["total"]), "total de enemigos coherente " + tag)
				var ids := {}
				for it: Dictionary in d["interacts"]:
					_check(rect.has_point(it["pos"]), "interactuable dentro del mapa " + tag)
					_check(not ids.has(it["id"]), "id único " + tag)
					ids[it["id"]] = true
				var eff_type: String = spec["type"]
				var layout: Dictionary = spec["layout"]
				if eff_type in ["hunt", "duel", "guardian", "boss"]:
					_check(int(layout["target"]) >= 0 and int(layout["target"]) < total, "objetivo válido " + tag)
				if eff_type == "stealth":
					_check(int(layout["camp"]) < (spec["ranges"] as Array).size(), "campamento válido " + tag)
				if eff_type in ["treasure", "ambush"]:
					_check(int(layout["count"]) <= int(spec["chests_total"]), "hay cofres para la misión " + tag)
				if eff_type == "hidden":
					_check(rect.has_point(layout["chest_pos"]), "cofre oculto en el mapa " + tag)
					var hidden_chests := 0
					for g: Dictionary in d["gather"]:
						if g.get("secret", false):
							hidden_chests += 1
					_check(hidden_chests == 1, "un único cofre oculto " + tag)
				if eff_type == "explore":
					_check(int(layout["count"]) <= (spec["clearing_centers"] as Array).size(), "claros suficientes " + tag)
				if eff_type in ["banners", "beacons"]:
					_check((layout["ids"] as Array).size() == 3 and d["interacts"].size() >= 3, "3 interactuables " + tag)
				if eff_type == "delivery":
					_check(layout["pickup"] != layout["dropoff"], "recogida y entrega distintas " + tag)
				_check(spec["optional"] in MissionCatalog.OPTIONALS, "opcional válido " + tag)
				_check(MissionCatalog.text_for(spec) != "", "texto descriptivo " + tag)


func _kill_all(rt: MissionRuntime, from_index: int, to_index: int) -> void:
	for i in range(from_index, to_index):
		rt.on_kill(i)


func _test_runtime_types() -> void:
	var rect_center := MeadowFloor.SIZE * 0.5
	# clear / timed: matar a todos
	for type in ["clear", "timed"]:
		var d := MeadowFloor.generate(5, 3, type)
		var rt := _runtime(d)
		_check(not rt.complete, type + ": no empieza completa")
		_kill_all(rt, 0, int(d["mission"]["total"]) - 1)
		rt.tick(0.1, rect_center, true, 1.0)
		_check(not rt.complete, type + ": falta uno")
		rt.on_kill(int(d["mission"]["total"]) - 1)
		rt.tick(0.1, rect_center, true, 1.0)
		_check(rt.complete, type + ": completa al matar a todos")
	# objetivo único
	for type in ["hunt", "duel", "guardian", "boss"]:
		var fl := 5 if type == "boss" else 3
		var d := MeadowFloor.generate(8, fl, type)
		var spec: Dictionary = d["mission"]
		var rt := _runtime(d)
		var target := int(spec["layout"]["target"])
		rt.on_kill((target + 1) % int(spec["total"]))
		rt.tick(0.1, rect_center, true, 1.0)
		_check(not rt.complete, type + ": otro enemigo no cuenta")
		rt.on_kill(target)
		rt.tick(0.1, rect_center, true, 1.0)
		_check(rt.complete, type + ": completa al derrotar al objetivo")
	# sigilo
	var ds := MeadowFloor.generate(11, 4, "stealth")
	var rts := _runtime(ds)
	var camp := int(ds["mission"]["layout"]["camp"])
	rts.on_alert(camp)
	_check(rts.state["stealth_broken"] == true, "sigilo: la alarma rompe el bonus")
	var r: Array = ds["mission"]["ranges"][camp]
	_kill_all(rts, int(r[0]), int(r[1]))
	rts.tick(0.1, rect_center, true, 1.0)
	_check(rts.complete, "sigilo: sigue contando al limpiar el campamento")
	# oleadas
	var dw := MeadowFloor.generate(12, 6, "waves")
	spawned.clear()
	var rtw := _runtime(dw)
	_check(rtw.on_interact("altar"), "oleadas: el altar responde")
	var waves: Array = dw["mission"]["layout"]["waves"]
	for wave in range(waves.size()):
		_check(spawned.size() > 0 and rtw.wave_enemies.size() == int(waves[wave]), "oleadas: la oleada %d trae %d enemigos" % [wave + 1, int(waves[wave])])
		for f in rtw.wave_enemies:
			(f as WarriorSim).alive = false
		rtw.tick(0.1, rect_center, true, 1.0)
	_check(rtw.complete, "oleadas: completa tras la última")
	# muerte en mitad de las oleadas: se reinicia
	var rtw2 := _runtime(dw)
	rtw2.on_interact("altar")
	rtw2.on_player_died()
	_check(rtw2.state["started"] == false and rtw2.state["wave"] == 0, "oleadas: morir reinicia el altar")
	# supervivencia
	var dv := MeadowFloor.generate(13, 4, "survivor")
	spawned.clear()
	var rtv := _runtime(dv)
	rtv.tick(5.0, rect_center, true, 1.0)
	_check(not rtv.complete and spawned.is_empty(), "supervivencia: sin altar no corre el tiempo")
	rtv.on_interact("altar")
	var seconds := float(dv["mission"]["layout"]["seconds"])
	var t := 0.0
	while t < seconds + 1.0:
		rtv.tick(0.5, rect_center, true, 1.0)
		t += 0.5
	_check(rtv.complete and spawned.size() > 5, "supervivencia: completa al aguantar y aparecen enemigos (%d)" % spawned.size())
	# recolección y cosecha
	for type in ["gather", "harvest"]:
		var dg := MeadowFloor.generate(14, 3, type)
		var layout: Dictionary = dg["mission"]["layout"]
		var rtg := _runtime(dg)
		rtg.on_gather("fiber", 50)
		_check(not rtg.complete, type + ": otro tipo de nodo no cuenta")
		rtg.on_gather(String(layout["kind"]), int(layout["count"]))
		rtg.tick(0.1, rect_center, true, 1.0)
		_check(rtg.complete, type + ": completa al reunir la cantidad")
	# cofres
	for type in ["treasure", "ambush"]:
		var dt := MeadowFloor.generate(15, 7, type)
		var count := int(dt["mission"]["layout"]["count"])
		spawned.clear()
		var rtt := _runtime(dt)
		for i in range(count):
			_check(not rtt.complete, type + ": aún faltan cofres")
			rtt.on_chest({"pos": Vector2(500, 500), "secret": false, "trapped": type == "ambush"})
			rtt.tick(0.1, rect_center, true, 1.0)
		_check(rtt.complete, type + ": completa con %d cofres" % count)
		_check((type == "ambush") == (spawned.size() == 3 * count), type + ": las trampas sueltan enemigos")
	# explorar
	var de := MeadowFloor.generate(16, 2, "explore")
	var rte := _runtime(de)
	var centers: Array = de["mission"]["clearing_centers"]
	for i in range(int(de["mission"]["layout"]["count"])):
		rte.tick(0.1, centers[i], true, 1.0)
	_check(rte.complete, "explorar: completa al visitar los claros")
	var rte2 := _runtime(de)
	rte2.tick(0.1, centers[0], true, 1.0)
	rte2.tick(0.1, centers[0], true, 1.0)
	_check((rte2.state["visited"] as Array).size() == 1, "explorar: un claro no cuenta dos veces")
	# oculto
	var dh := MeadowFloor.generate(17, 8, "hidden")
	_check(dh["mission"]["type"] == "hidden", "oculto: el claro oculto cabe en el mapa del piso 8")
	var rth := _runtime(dh)
	_check(rth.compass_target() != null, "oculto: la brújula apunta al cofre")
	rth.on_chest({"pos": dh["mission"]["layout"]["chest_pos"], "secret": true, "trapped": false})
	rth.tick(0.1, rect_center, true, 1.0)
	_check(rth.complete and rth.compass_target() == null, "oculto: completa al abrir el cofre secreto")
	# estandartes y balizas
	for type in ["banners", "beacons"]:
		var db := MeadowFloor.generate(18, 4, type)
		var rtb := _runtime(db)
		calls.clear()
		for id: String in db["mission"]["layout"]["ids"]:
			_check(rtb.on_interact(id), type + ": " + id + " responde")
			_check(rtb.on_interact(id), type + ": repetir no rompe")
		rtb.tick(0.1, rect_center, true, 1.0)
		_check(rtb.complete, type + ": completa con los 3")
		if type == "banners":
			_check("alert:%d" % int(db["mission"]["layout"]["camp"]) in calls, "estandartes: alertan al campamento")
	# entrega
	var dd := MeadowFloor.generate(19, 5 + 1, "delivery")
	var rtd := _runtime(dd)
	_check(not rtd.on_interact("dropoff") or not rtd.state["delivered"], "entrega: sin reliquia no se entrega")
	rtd.on_interact("pickup")
	_check(rtd.state["carry"] == true, "entrega: recoge la reliquia")
	rtd.on_player_died()
	_check(rtd.state["carry"] == false, "entrega: morir suelta la reliquia")
	rtd.on_interact("pickup")
	rtd.on_interact("dropoff")
	rtd.tick(0.1, rect_center, true, 1.0)
	_check(rtd.complete, "entrega: completa al entregar")


func _test_rescue_and_choice() -> void:
	var rect_center := MeadowFloor.SIZE * 0.5
	var dr := MeadowFloor.generate(21, 6, "rescue")
	var rtr := _runtime(dr)
	var dest: Vector2 = dr["mission"]["layout"]["destination"]
	rtr.on_interact("cage")
	_check(rtr.state["freed"] == true and rtr.ally != null, "rescate: el aldeano se libera y aparece")
	rtr.ally.position = dest
	rtr.tick(0.1, dest, true, 1.0)
	_check(rtr.complete, "rescate: completa al llevarlo al portal")
	# el aliado muere: se pasa a limpiar el piso
	var rtr2 := _runtime(dr)
	rtr2.on_interact("cage")
	rtr2.ally.alive = false
	rtr2.tick(0.1, rect_center, true, 1.0)
	_check(rtr2.state["escort_failed"] == true and rtr2.effective()["type"] == "clear" and not rtr2.complete, "rescate: si cae, el objetivo pasa a limpiar el piso")
	_kill_all(rtr2, 0, int(dr["mission"]["total"]))
	rtr2.tick(0.1, rect_center, true, 1.0)
	_check(rtr2.complete, "rescate: se completa limpiando el piso")
	# camino
	var dc := MeadowFloor.generate(22, 6, "choice")
	var rtc := _runtime(dc)
	_check(rtc.effective()["type"] == "explore", "camino: por defecto el fácil")
	rtc.on_interact("signpost")
	_check(rtc.effective()["type"] == "duel" and rtc.reward_multiplier() == 1.5, "camino: el cartel cambia al difícil (+50 %)")
	var target := int(rtc.effective()["layout"]["target"])
	rtc.on_kill(target)
	rtc.tick(0.1, rect_center, true, 1.0)
	_check(rtc.complete, "camino difícil: completa al ganar el duelo")
	var rtc2 := _runtime(dc)
	rtc2.on_kill(0)
	rtc2.on_interact("signpost")
	_check(rtc2.state["choice"] == "a", "camino: no se puede cambiar tras empezar")


func _test_optionals_and_save() -> void:
	var rect_center := MeadowFloor.SIZE * 0.5
	var d := MeadowFloor.generate(30, 3, "clear")
	for opt in MissionCatalog.OPTIONALS:
		d["mission"]["optional"] = opt
		var rt := _runtime(d)
		match opt:
			"no_potions":
				_check(rt.optional_met(), "opcional sin pociones: empieza cumplido")
				rt.on_potion()
				_check(not rt.optional_met(), "opcional sin pociones: beber lo rompe")
			"speed":
				_check(rt.optional_met(), "opcional rapidez: empieza cumplido")
				rt.tick(float(d["mission"]["par_seconds"]) + 5.0, rect_center, true, 1.0)
				_check(not rt.optional_met(), "opcional rapidez: pasarse del tiempo lo rompe")
			"flawless":
				rt.tick(0.1, rect_center, true, 0.4)
				_check(not rt.optional_met(), "opcional sin bajar del 50 %: bajar lo rompe")
			"no_alert":
				rt.on_alert(0)
				_check(not rt.optional_met(), "opcional sin alerta: una alerta lo rompe")
			"all_chests":
				d["mission"]["chests_total"] = 2
				var rt2 := _runtime(d)
				rt2.on_chest({"pos": Vector2.ZERO})
				rt2.on_chest({"pos": Vector2.ZERO})
				_check(rt2.optional_met(), "opcional todos los cofres: abrir los 2 lo cumple")
	# guardado: el estado sobrevive a JSON y las muertes se conservan
	d["mission"]["optional"] = "no_potions"
	var rt3 := _runtime(d)
	rt3.on_kill(0)
	rt3.on_chest({"pos": Vector2.ZERO})
	rt3.on_potion()
	var restored := JSON.parse_string(JSON.stringify(rt3.state)) as Dictionary
	var rt4 := _runtime(d, restored, [0, 1])
	_check(int(rt4.state["chests"]) == 1 and int(rt4.state["potions"]) == 1 and rt4.dead.size() == 2, "guardado: estado y muertes se restauran")
	var banners := MeadowFloor.generate(31, 4, "banners")
	var rtb := _runtime(banners)
	var first_id: String = banners["mission"]["layout"]["ids"][0]
	rtb.on_interact(first_id)
	var rtb2 := _runtime(banners, JSON.parse_string(JSON.stringify(rtb.state)) as Dictionary, [])
	_check((rtb2.state["banners"] as Array).size() == 1, "guardado: estandartes derribados")
	var surv := MeadowFloor.generate(32, 3, "survivor")
	var rts := _runtime(surv)
	rts.on_interact("altar")
	var rts2 := _runtime(surv, JSON.parse_string(JSON.stringify(rts.state)) as Dictionary, [])
	_check(rts2.state["started"] == false, "guardado: una oleada/supervivencia a medias se reinicia al recargar")


func _test_rewards_and_materials() -> void:
	# Ritmo de nivel: pisos 1-3 = 1 nivel cada uno; después cada vez menos.
	var level := 1
	var rt_data := MeadowFloor.generate(40, 1, "clear")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var previous_fraction := 99.0
	for fl in range(1, 11):
		var rt := _runtime(MeadowFloor.generate(40 + fl, fl, "clear"))
		var total := int(rt.spec["total"])
		var result := FloorRewards.compute(fl, level, rt, total, total, rng)
		var p := Progression.new()
		p.level = level
		p.add_xp(int(result["xp"]))
		if fl <= 3:
			_check(p.level >= level + 1, "piso %d da al menos un nivel (nivel %d -> %d)" % [fl, level, p.level])
		_check(FloorRewards.level_fraction(fl) <= previous_fraction, "la fracción de nivel nunca sube (piso %d)" % fl)
		previous_fraction = FloorRewards.level_fraction(fl)
		_check(not (result["loot"] as Dictionary).is_empty(), "el piso %d da botín" % fl)
		level = p.level
	_check(FloorRewards.level_fraction(10) < 0.25, "el piso 10 vale menos de un cuarto de nivel")
	_check(FloorRewards.kill_xp("boss", 5) > FloorRewards.kill_xp("elite", 5) and FloorRewards.kill_xp("elite", 5) > FloorRewards.kill_xp("minion", 5), "XP por tier de enemigo")
	# Atribuciones: mejor rendimiento, más XP.
	var low := _runtime(MeadowFloor.generate(50, 4, "clear"))
	low.state["elapsed"] = 9999.0
	low.state["potions"] = 5
	var high := _runtime(MeadowFloor.generate(50, 4, "clear"))
	var total_n := int(high.spec["total"])
	var xp_low := int(FloorRewards.compute(4, 4, low, total_n / 2, total_n, rng)["xp"])
	var xp_high := int(FloorRewards.compute(4, 4, high, total_n, total_n, rng)["xp"])
	_check(xp_high > xp_low, "atribuciones: mejor rendimiento da más XP (%d > %d)" % [xp_high, xp_low])
	# Materiales por grado
	var mrng := RandomNumberGenerator.new()
	mrng.seed = 9
	var saw_g2_early := false
	var saw_g2_late := false
	for i in range(200):
		for kind in ["ore", "wood", "fiber", "herb"]:
			if int(Materials.DEFS[Materials.node_material(kind, 3, mrng)]["grade"]) >= 2:
				saw_g2_early = true
			if int(Materials.DEFS[Materials.node_material(kind, 8, mrng)]["grade"]) >= 2:
				saw_g2_late = true
	_check(not saw_g2_early and saw_g2_late, "los materiales de grado 2 solo aparecen desde el piso 6")
	var early_loot := {}
	for i in range(100):
		for id in Materials.roll_chest(mrng, 3):
			early_loot[id] = true
	var has_g2 := false
	for id in early_loot:
		if int(Materials.DEFS[id]["grade"]) >= 2:
			has_g2 = true
	_check(not has_g2, "los cofres de los pisos 1-5 no traen grado 2")
	_check(Materials.drops_for("coloso", mrng, 5).has("colmillo_umbral") and Materials.drops_for("coloso", mrng, 10).has("corazon_pradera"), "los Colosos sueltan su pieza única")
	CharacterProfile.max_floor = 1
	var locked := 0
	for r: Dictionary in Crafting.all_recipes():
		if int(r.get("min_floor", 1)) > 1:
			locked += 1
			_check(not Crafting.can_craft(r), "receta de grado 2 bloqueada al inicio: " + String(r["id"]))
	_check(locked >= 20, "hay recetas de grado 2 (%d)" % locked)
	CharacterProfile.max_floor = 6
	var iron_sword: Dictionary = {}
	for r: Dictionary in Crafting.all_recipes():
		if r["id"] == "espada_cobre_g2":
			iron_sword = r
	_check(not iron_sword.is_empty() and Crafting.is_unlocked(iron_sword) and iron_sword["cost"].has("mena_hierro"), "receta de hierro desbloqueada en el piso 6 y usa hierro")
	CharacterProfile.max_floor = 1
