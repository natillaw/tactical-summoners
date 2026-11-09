## BalanceSim — motor de simulación headless para balancear las clases.
##
## Corre combates completos entre bots (BotBrain) sin escenas ni render:
##  - dps_race: una clase contra un muñeco inmóvil durante N segundos.
##  - team_match: 1v1, 2v2, 1v2... hasta que un equipo cae o se acaba el tiempo.
##  - matrix: todas las clases contra todas (tasa de victoria).
## Cada combatiente puede llevar multiplicadores propios (`mods`) y nivel. Los números por skill
## se cambian con BalanceData.set_skill_value (o editando res://data/balance.json).
##
## Una configuración de combatiente es {class: &"mage", level: 10, mods: {damage_mult: 1.2}}.
class_name BalanceSim
extends RefCounted

const DT := 1.0 / 60.0
const CLASS_IDS: Array = [&"warrior", &"rogue", &"mage", &"ranger"]


static func _world(seed_value: int) -> CombatWorld:
	var world := CombatWorld.new(seed_value)
	world.setup_arena(Rect2(0, 0, 1000, 600))
	return world


static func _apply(sim: WarriorSim, cfg: Dictionary) -> void:
	sim.progression.set_level(int(cfg.get("level", 1)))
	var mods: Dictionary = cfg.get("mods", {})
	if not mods.is_empty():
		for key: String in mods:
			sim.mods[key] = mods[key]
		sim.recompute_stats(true)


static func _new_record(sim: WarriorSim, side: String, label: String) -> Dictionary:
	return {
		"label": label, "class": String(sim.class_id), "side": side, "sim": sim,
		"skills": {}, "damage": 0.0, "damage_taken": 0.0, "bins": [],
	}


static func _skill_entry(record: Dictionary, skill_id: String, name: String) -> Dictionary:
	var skills: Dictionary = record["skills"]
	if not skills.has(skill_id):
		skills[skill_id] = {"id": skill_id, "name": name, "casts": 0, "hits": 0, "crits": 0, "damage": 0.0}
	return skills[skill_id]


static func _record_damage(record: Dictionary, amount: float, time_now: float) -> void:
	record["damage"] = float(record["damage"]) + amount
	var bins: Array = record["bins"]
	var index := int(time_now / 10.0)
	while bins.size() <= index:
		bins.append(0.0)
	bins[index] = float(bins[index]) + amount


## Conecta señales del combatiente para contar casteos, golpes, crits y daño (incl. DoT).
static func _track(record: Dictionary, clock: Array, all_records: Dictionary) -> void:
	var sim: WarriorSim = record["sim"]
	sim.attack_started.connect(func(skill: Dictionary, _dir: Vector2) -> void:
		var entry := _skill_entry(record, String(skill.get("id", "")), String(skill.get("name", "")))
		entry["casts"] = int(entry["casts"]) + 1)
	sim.attack_hit.connect(func(skill: Dictionary, _target: Object, dealt: float, critical: bool, _pos: Vector2) -> void:
		var entry := _skill_entry(record, String(skill.get("id", "")), String(skill.get("name", "")))
		entry["hits"] = int(entry["hits"]) + 1
		entry["damage"] = float(entry["damage"]) + dealt
		if critical:
			entry["crits"] = int(entry["crits"]) + 1
		_record_damage(record, dealt, float(clock[0])))
	sim.damage_taken.connect(func(amount: float, _from: Vector2, _is_dot: bool) -> void:
		record["damage_taken"] = float(record["damage_taken"]) + amount)


static func _track_dots(victim: Object, all_records: Dictionary, clock: Array) -> void:
	victim.dot_damage.connect(func(amount: float, meta: Dictionary) -> void:
		var source: Variant = meta.get("src", null)
		if source != null and all_records.has(source):
			var record: Dictionary = all_records[source]
			var skill_id := String(meta.get("skill_id", "")) + "_dot"
			var entry := _skill_entry(record, skill_id, "%s (DoT)" % _skill_name(record, String(meta.get("skill_id", ""))))
			entry["hits"] = int(entry["hits"]) + 1
			entry["damage"] = float(entry["damage"]) + amount
			_record_damage(record, amount, float(clock[0])))


static func _skill_name(record: Dictionary, skill_id: String) -> String:
	var sim: WarriorSim = record["sim"]
	for slot: String in ["M1", "M2", "SHIFT", "Q", "E", "R", "F"]:
		var ability := sim.ability_for_slot(slot)
		if String(ability.get("id", "")) == skill_id:
			return String(ability.get("name", skill_id))
	return skill_id


static func _finish(record: Dictionary, seconds: float) -> Dictionary:
	var sim: WarriorSim = record["sim"]
	var skills: Array = []
	var total := float(record["damage"])
	for id: String in record["skills"]:
		var entry: Dictionary = (record["skills"] as Dictionary)[id]
		entry["dps"] = float(entry["damage"]) / maxf(seconds, 0.001)
		entry["pct"] = float(entry["damage"]) / maxf(total, 0.001) * 100.0
		entry["avg"] = float(entry["damage"]) / maxf(float(entry["hits"]), 1.0)
		skills.append(entry)
	skills.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["damage"]) > float(b["damage"]))
	return {
		"label": record["label"], "class": record["class"], "side": record["side"],
		"damage": total, "dps": total / maxf(seconds, 0.001), "damage_taken": record["damage_taken"],
		"hp_left": sim.health, "hp_max": sim.max_health, "alive": sim.alive,
		"skills": skills, "bins": record["bins"],
	}


## DPS contra un muñeco inmóvil. cfg = {class, level, seconds, mods, seed}.
static func dps_race(cfg: Dictionary) -> Dictionary:
	var seconds := float(cfg.get("seconds", 60.0))
	var world := _world(int(cfg.get("seed", 1)))
	var sim := world.warrior
	sim.set_class(StringName(String(cfg.get("class", "warrior"))))
	sim.reset(Vector2(300, 300))
	_apply(sim, cfg)
	sim.health = sim.max_health
	sim.position = Vector2(300, 300)
	world.warrior_bot = BotBrain.new(int(cfg.get("seed", 1)))
	var dummy := world.add_dummy(Vector2(460, 300), false)
	dummy.max_health = 1.0e9
	dummy.health = 1.0e9
	var clock := [0.0]
	var records := {}
	var record := _new_record(sim, "A", String(sim.class_id))
	records[sim] = record
	_track(record, clock, records)
	_track_dots(dummy, records, clock)
	var ticks := int(seconds / DT)
	for i in ticks:
		clock[0] = float(i) * DT
		world.step(DT)
	var result := _finish(record, seconds)
	result["seconds"] = seconds
	result["mode"] = "dps"
	return result


## Combate por equipos. cfg = {a: [fighter...], b: [fighter...], max_seconds, seed}.
static func team_match(cfg: Dictionary) -> Dictionary:
	var world := _world(int(cfg.get("seed", 1)))
	var records := {}
	var order: Array = []
	var clock := [0.0]
	var team_a: Array = cfg.get("a", [])
	var team_b: Array = cfg.get("b", [])
	var sims: Array = []
	for i in team_a.size():
		var member: Dictionary = team_a[i]
		var sim: WarriorSim
		if i == 0:
			sim = world.warrior
			sim.set_class(StringName(String(member["class"])))
			sim.reset(Vector2(250, 300))
			world.warrior_bot = BotBrain.new(int(cfg.get("seed", 1)) + 7)
		else:
			sim = world.add_fighter(StringName(String(member["class"])), 0, Vector2(250, 300 + 90 * i), 1)
		sim.position = Vector2(250, 220 + 160 * i if team_a.size() > 1 else 300)
		_apply(sim, member)
		sim.health = sim.max_health
		sims.append([sim, "A", "A%d %s" % [i + 1, String(sim.class_id)]])
	for j in team_b.size():
		var member_b: Dictionary = team_b[j]
		var sim_b := world.add_fighter(StringName(String(member_b["class"])), 1, Vector2(750, 220 + 160 * j if team_b.size() > 1 else 300), 1)
		_apply(sim_b, member_b)
		sim_b.health = sim_b.max_health
		sims.append([sim_b, "B", "B%d %s" % [j + 1, String(sim_b.class_id)]])
	for entry: Array in sims:
		var record := _new_record(entry[0], entry[1], entry[2])
		records[entry[0]] = record
		order.append(record)
	for record: Dictionary in order:
		_track(record, clock, records)
		_track_dots(record["sim"], records, clock)
	var max_seconds := float(cfg.get("max_seconds", 120.0))
	var elapsed := 0.0
	var winner := "empate"
	while elapsed < max_seconds:
		clock[0] = elapsed
		world.step(DT)
		elapsed += DT
		var a_alive := false
		var b_alive := false
		for record: Dictionary in order:
			if (record["sim"] as WarriorSim).alive:
				if record["side"] == "A":
					a_alive = true
				else:
					b_alive = true
		if not a_alive or not b_alive:
			winner = "B" if not a_alive and b_alive else ("A" if a_alive and not b_alive else "empate")
			break
	var fighters_out: Array = []
	for record: Dictionary in order:
		fighters_out.append(_finish(record, elapsed))
	return {"mode": "match", "winner": winner, "seconds": elapsed, "fighters": fighters_out}


## Repite un combate con distintas semillas y agrega resultados.
static func run_many(cfg: Dictionary, runs: int) -> Dictionary:
	var wins := {"A": 0, "B": 0, "empate": 0}
	var total_time := 0.0
	var agg: Array = []
	for r in runs:
		var one_cfg := cfg.duplicate()
		one_cfg["seed"] = int(cfg.get("seed", 1)) + r * 101
		var result := team_match(one_cfg)
		wins[String(result["winner"])] = int(wins[String(result["winner"])]) + 1
		total_time += float(result["seconds"])
		var fighters: Array = result["fighters"]
		for i in fighters.size():
			if agg.size() <= i:
				agg.append({"label": fighters[i]["label"], "class": fighters[i]["class"], "side": fighters[i]["side"], "damage": 0.0, "damage_taken": 0.0, "skills": {}, "hp_pct": 0.0, "survived": 0})
			var slot: Dictionary = agg[i]
			slot["damage"] = float(slot["damage"]) + float(fighters[i]["damage"])
			slot["damage_taken"] = float(slot["damage_taken"]) + float(fighters[i]["damage_taken"])
			slot["hp_pct"] = float(slot["hp_pct"]) + float(fighters[i]["hp_left"]) / maxf(float(fighters[i]["hp_max"]), 1.0)
			slot["survived"] = int(slot["survived"]) + (1 if fighters[i]["alive"] else 0)
			for skill: Dictionary in fighters[i]["skills"]:
				var table: Dictionary = slot["skills"]
				if not table.has(skill["id"]):
					table[skill["id"]] = {"id": skill["id"], "name": skill["name"], "casts": 0.0, "hits": 0.0, "crits": 0.0, "damage": 0.0}
				var line: Dictionary = table[skill["id"]]
				line["casts"] = float(line["casts"]) + float(skill["casts"])
				line["hits"] = float(line["hits"]) + float(skill["hits"])
				line["crits"] = float(line["crits"]) + float(skill["crits"])
				line["damage"] = float(line["damage"]) + float(skill["damage"])
	var avg_time := total_time / maxf(float(runs), 1.0)
	for slot: Dictionary in agg:
		slot["damage"] = float(slot["damage"]) / runs
		slot["damage_taken"] = float(slot["damage_taken"]) / runs
		slot["hp_pct"] = float(slot["hp_pct"]) / runs
		slot["dps"] = float(slot["damage"]) / maxf(avg_time, 0.001)
		var lines: Array = []
		for id: String in slot["skills"]:
			var line: Dictionary = (slot["skills"] as Dictionary)[id]
			for key: String in ["casts", "hits", "crits", "damage"]:
				line[key] = float(line[key]) / runs
			line["dps"] = float(line["damage"]) / maxf(avg_time, 0.001)
			line["pct"] = float(line["damage"]) / maxf(float(slot["damage"]), 0.001) * 100.0
			line["avg"] = float(line["damage"]) / maxf(float(line["hits"]), 0.001)
			lines.append(line)
		lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["damage"]) > float(b["damage"]))
		slot["skills"] = lines
	return {"mode": "match", "runs": runs, "wins": wins, "avg_seconds": avg_time, "fighters": agg}


## Todas las clases contra todas en 1v1. Devuelve {classes, win_rate[a][b] (0..1), avg_time}.
static func matrix(level: int, runs: int, max_seconds: float = 90.0) -> Dictionary:
	var rates := {}
	for a: StringName in CLASS_IDS:
		rates[String(a)] = {}
		for b: StringName in CLASS_IDS:
			var result := run_many({"a": [{"class": a, "level": level}], "b": [{"class": b, "level": level}], "max_seconds": max_seconds}, runs)
			var wins: Dictionary = result["wins"]
			(rates[String(a)] as Dictionary)[String(b)] = (float(wins["A"]) + 0.5 * float(wins["empate"])) / float(runs)
	return {"classes": CLASS_IDS, "win_rate": rates}


# --- Texto (CLI y copia fácil para pegar en el chat) --------------------------------------


static func format_skills(lines: Array, seconds: float) -> String:
	var out := "  %-22s %6s %6s %9s %6s %8s %7s\n" % ["Skill", "Casts", "Hits", "Daño", "%", "DPS", "Prom."]
	for line: Dictionary in lines:
		out += "  %-22s %6.1f %6.1f %9.0f %5.1f%% %8.1f %7.1f\n" % [str(line["name"]), float(line["casts"]), float(line["hits"]), float(line["damage"]), float(line["pct"]), float(line["dps"]), float(line["avg"])]
	return out


static func format_dps(result: Dictionary) -> String:
	var text := "DPS en muñeco — %s (nivel con stats base) durante %.0f s\n" % [str(result["class"]), float(result["seconds"])]
	text += "  Daño total: %.0f   DPS medio: %.1f\n" % [float(result["damage"]), float(result["dps"])]
	var bins: Array = result["bins"]
	var bin_text := ""
	for i in bins.size():
		bin_text += "%s%.0f" % [" | " if i > 0 else "", float(bins[i]) / 10.0]
	text += "  DPS por tramos de 10 s: %s\n" % bin_text
	text += format_skills(result["skills"], float(result["seconds"]))
	return text


static func format_match(result: Dictionary) -> String:
	var text := "Combate (%d simulaciones): victorias A=%d  B=%d  empates=%d   duración media %.1f s\n" % [int(result["runs"]), int(result["wins"]["A"]), int(result["wins"]["B"]), int(result["wins"]["empate"]), float(result["avg_seconds"])]
	for slot: Dictionary in result["fighters"]:
		text += "%s: daño medio %.0f (DPS %.1f), daño recibido %.0f, vida restante %.0f%%, sobrevive %d/%d\n" % [str(slot["label"]), float(slot["damage"]), float(slot["dps"]), float(slot["damage_taken"]), float(slot["hp_pct"]) * 100.0, int(slot["survived"]), int(result["runs"])]
		text += format_skills(slot["skills"], float(result["avg_seconds"]))
	return text


static func format_matrix(result: Dictionary) -> String:
	var text := "Tasa de victoria (fila vs columna)\n%-10s" % ""
	for b: StringName in result["classes"]:
		text += "%9s" % String(b)
	text += "\n"
	for a: StringName in result["classes"]:
		text += "%-10s" % String(a)
		for b: StringName in result["classes"]:
			text += "%8.0f%%" % (float(result["win_rate"][String(a)][String(b)]) * 100.0)
		text += "\n"
	return text
