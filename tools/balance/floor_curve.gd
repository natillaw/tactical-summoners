extends SceneTree
## Curva de balance por piso y clase (headless, sin abrir el juego).
##
##   godot --headless --path . -s tools/balance/floor_curve.gd -- [floors=1-10] [seeds=4] [out=docs/BALANCE.md]
##
## Para cada piso crea al jugador "esperado" (nivel según FloorRewards, arma y armadura del grado que toca)
## controlado por un bot, y lo enfrenta a cada campamento del piso generado. Imprime:
##   - vida, golpe medio y reducción física del jugador; vida y golpe de esbirro / élite / jefe (fórmula por piso)
##   - golpes del jugador para matar (TTK) y golpes que aguanta el jugador
##   - % de victorias del bot, vida restante y duración por campamento
## El bot juega peor que una persona (no kitea ni esquiva bien): sus victorias son una cota baja.

const CLASSES := ["warrior", "rogue", "mage", "ranger"]
const WEAPON := {"warrior": "sword", "rogue": "dagger", "mage": "staff", "ranger": "bow"}
const ARMOR_PER_PIECE := {"warrior": 7.0, "rogue": 4.0, "mage": 2.5, "ranger": 4.5}
const SLOTS := ["chest", "legs", "head", "hands", "boots"]


func _init() -> void:
	var lo := 1
	var hi := 10
	var seeds := 4
	var out_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("floors="):
			var bits := String(arg.substr(7)).split("-")
			lo = int(bits[0])
			hi = int(bits[bits.size() - 1])
		if arg.begins_with("seeds="): seeds = int(arg.substr(6))
		if arg.begins_with("out="): out_path = arg.substr(4)
	var lines: Array = []
	lines.append("# Curva de balance por piso (generado por tools/balance/floor_curve.gd)")
	lines.append("")
	lines.append("Bot de cada clase con el nivel y el equipo esperados, %d semillas por campamento. `gk` = golpes básicos del jugador para matar; `ga` = golpes del enemigo que aguanta el jugador." % seeds)
	lines.append("")
	lines.append("| Piso | Clase | Nv | Vida | Golpe | Red.fís | Esbirro vida/golpe (gk/ga) | Élite vida/golpe (gk/ga) | Jefe vida/golpe (gk/ga) | Victorias | Vida restante | s/camp |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
	for floor_number in range(lo, hi + 1):
		for klass: String in CLASSES:
			lines.append(_row(floor_number, klass, seeds))
			print(lines[lines.size() - 1])
	if out_path != "":
		var file := FileAccess.open("res://" + out_path, FileAccess.WRITE)
		file.store_string("\n".join(lines) + "\n")
		file.close()
	quit()


## Nivel con el que el jugador llega al piso (1 nivel por piso en los 3 primeros, luego fracciones).
static func expected_level(floor_number: int) -> int:
	var level := 1.0
	for k in range(1, floor_number):
		level += FloorRewards.level_fraction(k)
	return int(level)


## Equipa al jugador con lo que se espera a esa altura: arma de su clase del grado del piso y armadura fabricada.
static func equip_expected(w: WarriorSim, klass: String, floor_number: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99 + floor_number
	var grade2 := floor_number >= Materials.GRADE2_FLOOR + 1
	if floor_number >= 2:
		w.equip_weapon(ItemFactory.roll_weapon(rng, Crafting.GRADE2_LEVEL if grade2 else Crafting.ITEM_LEVEL, ItemRarity.Tier.POCO_COMUN, WEAPON[klass]))
	var pieces := clampi(floor_number - 1, 0, SLOTS.size())
	for i in range(pieces):
		var item := Item.new()
		item.slot = SLOTS[i]
		item.id = "sim_" + item.slot
		var mult := Crafting.GRADE2_STATS if grade2 else 1.0
		item.stats = {"stamina": 3.0 * mult, "armor": float(ARMOR_PER_PIECE[klass]) * mult}
		w.equip_armor(item)


func _player(world: CombatWorld, klass: String, floor_number: int) -> WarriorSim:
	var w := world.warrior
	w.set_class(StringName(klass))
	w.progression.set_level(expected_level(floor_number))
	equip_expected(w, klass, floor_number)
	w.recompute_stats(true)
	return w


func _row(floor_number: int, klass: String, seeds: int) -> String:
	# --- números analíticos ---
	var probe := CombatWorld.new(1)
	probe.setup_arena(Rect2(0, 0, 3200, 2200), [])
	var p := _player(probe, klass, floor_number)
	var hit := p.average_hit() * float(p.mods.get("damage_mult", 1.0))
	var cells: Array = []
	for arch: String in ["esbirro", "soldado", "coloso"]:
		if arch == "coloso" and floor_number % 5 != 0:
			cells.append("—")
			continue
		var e := probe.add_archetype(arch, 1, Vector2(100, 100), floor_number)
		var e_hit := e.average_hit() * float(e.mods.get("damage_mult", 1.0)) * (1.0 - p.physical_reduction())
		var p_hit := hit * (1.0 - e.physical_reduction() if klass != "mage" else 1.0)
		cells.append("%d / %d (%.1f / %.0f)" % [int(e.max_health), int(e_hit), e.max_health / maxf(p_hit, 0.01), p.max_health / maxf(e_hit, 0.01)])
	# --- combates simulados ---
	var data := MeadowFloor.generate(500 + floor_number * 13, floor_number, "boss" if floor_number % 5 == 0 else "clear")
	var camps: Array = data["camps"]
	var wins := 0
	var fights := 0
	var hp_left := 0.0
	var secs := 0.0
	for ci in range(camps.size()):
		for sd in range(seeds):
			var world := CombatWorld.new(2000 + sd * 7 + ci)
			world.setup_arena(Rect2(0, 0, 3200, 2200), [])
			var w := _player(world, klass, floor_number)
			w.reset(Vector2(1000, 1000))
			w.health = w.max_health
			world.warrior_bot = BotBrain.new(sd + 5)
			var camp: Dictionary = camps[ci]
			var offset: Vector2 = Vector2(1240, 1000) - (camp["center"] as Vector2)
			for e: Dictionary in camp["enemies"]:
				var f := world.add_archetype(String(e["arch"]), 1, e["pos"] + offset, int(e["level"]))
				f.brain.group = ci
				f.brain.aggro_range = 260.0
			var t := 0
			var limit := 60 * (240 if floor_number % 5 == 0 else 120)
			while t < limit:
				world.step(1.0 / 60.0)
				t += 1
				var any := false
				for f: WarriorSim in world.fighters:
					any = any or f.alive
				if not any or not w.alive:
					break
			var left := false
			for f: WarriorSim in world.fighters:
				left = left or f.alive
			fights += 1
			if w.alive and not left:
				wins += 1
				hp_left += w.health / w.max_health
			secs += float(t) / 60.0
	return "| %d | %s | %d | %d | %d | %d%% | %s | %s | %s | %d%% | %d%% | %.0f |" % [
		floor_number, klass, p.progression.level, int(p.max_health), int(hit), int(p.physical_reduction() * 100.0),
		cells[0], cells[1], cells[2], wins * 100 / maxi(fights, 1), int(100.0 * hp_left / maxf(wins, 1)), secs / maxf(fights, 1)]
