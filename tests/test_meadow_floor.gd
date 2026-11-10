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
	print("meadow floor: ", "OK" if fails == 0 else "%d fallos" % fails)
	quit(1 if fails > 0 else 0)
