extends SceneTree
## Balance del piso 1: cada clase (bot) contra cada campamento, nivel 1 (campamento 3: nivel 1 con enemigos nivel 2).
## godot --headless --path . -s tools/balance/floor_balance.gd -- [seeds=10] [level=1]
func _init() -> void:
	var seeds := 10
	var level := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seeds="): seeds = int(arg.substr(6))
		if arg.begins_with("level="): level = int(arg.substr(6))
	var floor_data := MeadowFloor.generate(11)
	for klass in ["warrior", "rogue", "mage", "ranger"]:
		var row: String = String(klass).rpad(8)
		for ci in range(3):
			var wins := 0
			var hp_left := 0.0
			var secs := 0.0
			for sd in range(seeds):
				var world := CombatWorld.new(1000 + sd)
				world.setup_arena(Rect2(0, 0, 3200, 2200), [])
				var w := world.warrior
				w.set_class(StringName(klass))
				w.progression.set_level(level)
				w.reset(Vector2(400, 400))
				w.health = w.max_health
				world.warrior_bot = BotBrain.new(sd + 5)
				var camp: Dictionary = floor_data["camps"][ci]
				var offset: Vector2 = Vector2(400, 400) - (camp["center"] as Vector2)
				for e: Dictionary in camp["enemies"]:
					var f := world.add_archetype(String(e["arch"]), 1, e["pos"] + offset, int(e["level"]))
					f.brain.group = ci
					f.brain.aggro_range = 260.0
				var t := 0
				while t < 60 * 90:
					world.step(1.0 / 60.0)
					t += 1
					var alive := false
					for f: WarriorSim in world.fighters:
						alive = alive or f.alive
					if not alive or not w.alive:
						break
				var any := false
				for f: WarriorSim in world.fighters:
					any = any or f.alive
				if w.alive and not any:
					wins += 1
					hp_left += w.health / w.max_health
				secs += float(t) / 60.0
			row += "  camp%d: win %3d%% hp %3d%% %4.0fs" % [ci + 1, wins * 100 / seeds, int(100.0 * hp_left / maxf(wins, 1)), secs / seeds]
		print(row)
	quit()
