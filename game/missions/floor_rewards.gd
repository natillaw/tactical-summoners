## FloorRewards — experiencia y botín al completar un piso.
##
## Ritmo de nivel (decisión de diseño): los 3 primeros pisos dan **1 nivel cada uno**; a partir del piso 4 cada
## piso da una fracción cada vez menor de un nivel (×0.78 por piso), así subir cuesta más a medida que subes la Torre.
## La experiencia de la misión depende de lo que hiciste (enemigos derrotados, objetivo opcional, rapidez,
## sigilo, camino elegido); matar enemigos suelta además un poco de experiencia directa.
class_name FloorRewards
extends RefCounted

const KILL_XP := {"minion": 5.0, "elite": 16.0, "boss": 160.0}


## Fracción de un nivel que vale completar este piso (1.0 = un nivel entero).
static func level_fraction(floor_number: int) -> float:
	return 1.0 if floor_number <= 3 else pow(0.78, floor_number - 3)


static func kill_xp(tier: String, floor_number: int) -> int:
	return int(round(float(KILL_XP.get(tier, 5.0)) * (1.0 + 0.1 * floor_number)))


## Calcula la recompensa. `runtime` = MissionRuntime ya completada; `kills`/`total` = enemigos del mapa derrotados.
static func compute(floor_number: int, player_level: int, runtime: MissionRuntime, kills: int, total: int, rng: RandomNumberGenerator) -> Dictionary:
	var base := float(Progression.xp_to_next(player_level)) * level_fraction(floor_number)
	var ratio := clampf(float(kills) / maxf(float(total), 1.0), 0.0, 1.0)
	var lines: Array = [["Misión cumplida", 0.85]]
	lines.append(["Enemigos derrotados (%d%%)" % int(ratio * 100.0), 0.25 * ratio])
	var optional: String = runtime.spec["optional"]
	if runtime.optional_met():
		lines.append(["Opcional: " + String(MissionCatalog.OPTIONALS[optional]["text"]).replace(" %s", ""), float(MissionCatalog.OPTIONALS[optional]["bonus"])])
	if optional != "speed" and float(runtime.state["elapsed"]) <= float(runtime.spec["par_seconds"]) * 0.8:
		lines.append(["Rapidez", 0.1])
	if runtime.spec["type"] == "stealth" and not bool(runtime.state["stealth_broken"]):
		lines.append(["Sigilo", 0.15])
	var mult := 0.0
	for line: Array in lines:
		mult += float(line[1])
	var choice := runtime.reward_multiplier()
	if choice > 1.0:
		lines.append(["Camino difícil", mult * (choice - 1.0)])
		mult *= choice
	if floor_number <= 3 and mult < 1.0:
		lines.append(["Primeros pisos: garantizado 1 nivel", 1.0 - mult])
		mult = 1.0
	var xp := int(round(base * mult))
	var loot := Materials.roll_chest(rng, floor_number)
	var boost := 2 if floor_number % 5 == 0 else (1 + (1 if runtime.optional_met() else 0))
	for id: String in loot:
		loot[id] = int(loot[id]) * boost if id != "pocion_vida" and id != "pocion_vida_mayor" else int(loot[id])
	return {
		"floor": floor_number, "xp": xp, "multiplier": mult, "lines": lines, "loot": loot, "kills": kills, "total": total,
		"elapsed": float(runtime.state["elapsed"]), "levels_worth": base * mult / float(Progression.xp_to_next(player_level)),
	}
