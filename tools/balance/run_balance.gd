## Simulador de balance por línea de comandos (headless).
##
## godot --headless --path . -s res://tools/balance/run_balance.gd -- mode=dps class=mage seconds=60
## godot --headless --path . -s res://tools/balance/run_balance.gd -- mode=duel class=warrior vs=rogue runs=20
## godot --headless --path . -s res://tools/balance/run_balance.gd -- mode=2v2 class=warrior,mage vs=rogue,ranger runs=10
## godot --headless --path . -s res://tools/balance/run_balance.gd -- mode=1v2 class=mage vs=warrior,rogue
## godot --headless --path . -s res://tools/balance/run_balance.gd -- mode=matrix runs=10 level=5
## Cambios de balance temporales: cmod.rogue.damage_mult=0.85  skill.death_sentence.damage_mult=3.5
## Extras: level=N  seconds=N  runs=N  mod.damage_mult=1.2 (para el equipo A)  vsmod.health_mult=1.5 (equipo B)
extends SceneTree


func _init() -> void:
	var args := {}
	for raw in OS.get_cmdline_user_args():
		var parts := String(raw).split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	for key: String in args:
		var bits := key.split(".")
		if bits.size() == 3 and bits[0] == "cmod":
			BalanceData.set_class_mod(StringName(bits[1]), bits[2], float(args[key]))
		elif bits.size() == 3 and bits[0] == "skill":
			BalanceData.set_skill_value(bits[1], bits[2], float(args[key]))
	var mode := String(args.get("mode", "dps"))
	var level := int(args.get("level", 1))
	var runs := int(args.get("runs", 10))
	var seconds := float(args.get("seconds", 60.0))
	var mods_a := _mods(args, "mod.")
	var mods_b := _mods(args, "vsmod.")
	match mode:
		"dps":
			var result := BalanceSim.dps_race({"class": String(args.get("class", "warrior")), "level": level, "seconds": seconds, "mods": mods_a})
			print(BalanceSim.format_dps(result))
		"matrix":
			print(BalanceSim.format_matrix(BalanceSim.matrix(level, runs, seconds)))
		_:
			var a := _team(String(args.get("class", "warrior")), level, mods_a)
			var b := _team(String(args.get("vs", "rogue")), level, mods_b)
			var result := BalanceSim.run_many({"a": a, "b": b, "max_seconds": seconds if seconds > 0.0 else 120.0}, runs)
			print(BalanceSim.format_match(result))
	quit()


func _team(csv: String, level: int, mods: Dictionary) -> Array:
	var team: Array = []
	for id in csv.split(","):
		team.append({"class": id.strip_edges(), "level": level, "mods": mods})
	return team


func _mods(args: Dictionary, prefix: String) -> Dictionary:
	var mods := {}
	for key: String in args:
		if key.begins_with(prefix):
			mods[key.trim_prefix(prefix)] = float(args[key])
	return mods
