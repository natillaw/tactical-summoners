## MissionLayout — diseña la misión de un piso sobre el mapa ya generado: elige claros, marca enemigos,
## añade campamentos extra (duelo, guardián) e interactuables (altares, balizas, estandartes...).
## Es determinista (misma semilla = mismo diseño) y no toca escenas: solo devuelve datos.
class_name MissionLayout
extends RefCounted

const SIZE := Vector2(3200.0, 2200.0)


## ctx = {clearings, camps, spawn, exit}. `camps` se modifica (campamentos extra). Devuelve
## {spec: {...misión...}, interacts: [...], hidden: {center, radius} o {}}.
static func design(type: String, rng: RandomNumberGenerator, floor_number: int, ctx: Dictionary) -> Dictionary:
	var camps: Array = ctx["camps"]
	var rooms := _rooms(ctx)
	var interacts: Array = []
	var layout: Dictionary = {}
	var hidden: Dictionary = {}
	var total := _count(camps)
	match type:
		"hunt":
			var target := _pick_elite(camps, rng)
			if target < 0:
				type = "clear"
			else:
				layout = {"target": target}
		"duel":
			if rooms.is_empty():
				type = "clear"
			else:
				var room: Dictionary = _take(rooms, rng)
				layout = {"target": _add_camp(camps, "El Claro del Duelo", room["center"], "campeon" if floor_number >= 5 else "duelista", floor_number + 1)}
		"guardian":
			layout = {"target": _add_camp(camps, "El Paso de la Costura", ctx["exit"], "campeon" if floor_number >= 6 else "guardian", floor_number + 1)}
		"boss":
			layout = {"target": _find_arch(camps, "coloso")}
			if int(layout["target"]) < 0:
				layout = {"target": _add_camp(camps, "El Trono del Pliegue", ctx["exit"], "coloso", floor_number)}
		"stealth":
			layout = {"camp": rng.randi() % camps.size()}
		"waves":
			if rooms.is_empty():
				type = "clear"
			else:
				var room: Dictionary = _take(rooms, rng)
				interacts.append({"id": "altar", "kind": "altar", "pos": (room["center"] as Vector2) + Vector2(0.0, -80.0), "label": "Altar de oleadas"})
				layout = {"altar": (room["center"] as Vector2) + Vector2(0.0, -80.0), "waves": [3 + floor_number / 3, 4 + floor_number / 2, 5 + floor_number / 2]}
		"survivor":
			if rooms.is_empty():
				type = "clear"
			else:
				var room: Dictionary = _take(rooms, rng)
				interacts.append({"id": "altar", "kind": "altar", "pos": (room["center"] as Vector2) + Vector2(0.0, -80.0), "label": "Altar del recuerdo"})
				layout = {"altar": (room["center"] as Vector2) + Vector2(0.0, -80.0), "seconds": 70 + floor_number * 2}
		"timed":
			layout = {"seconds": 60 + 12 * total}
		"gather":
			var choice: Array = [["ore", "mineral"], ["wood", "madera"], ["stone", "piedra"]][rng.randi() % 3]
			layout = {"kind": choice[0], "what": choice[1], "count": mini(5 + floor_number / 3, 8)}
		"harvest":
			layout = {"kind": "herb", "count": 5 + floor_number / 3}
		"treasure", "ambush":
			layout = {"count": mini(3, rooms.size()), "trapped": type == "ambush"}
			if int(layout["count"]) <= 0:
				type = "clear"
				layout = {}
		"explore":
			layout = {"count": mini(4 + floor_number / 5, (ctx["clearings"] as Array).size() - 1)}
		"hidden":
			hidden = _hidden_clearing(rng, ctx["clearings"])
			if hidden.is_empty():
				type = "treasure"
				layout = {"count": mini(3, rooms.size()), "trapped": false}
			else:
				layout = {"chest_pos": hidden["center"]}
		"banners":
			var camp_i := rng.randi() % camps.size()
			var center: Vector2 = camps[camp_i]["center"]
			var ids: Array = []
			for i in range(3):
				var angle := TAU * (float(i) + 0.3) / 3.0
				interacts.append({"id": "banner%d" % i, "kind": "banner", "pos": center + Vector2(cos(angle), sin(angle)) * 150.0, "label": "Estandarte"})
				ids.append("banner%d" % i)
			layout = {"camp": camp_i, "ids": ids}
		"beacons":
			var spots: Array = []
			for room: Dictionary in rooms:
				spots.append(room["center"])
			for c: Dictionary in camps:
				spots.append(c["center"])
			spots.shuffle()
			if spots.size() < 3:
				type = "clear"
			else:
				var ids2: Array = []
				for i in range(3):
					interacts.append({"id": "beacon%d" % i, "kind": "beacon", "pos": (spots[i] as Vector2) + Vector2(90.0, 40.0), "label": "Baliza"})
					ids2.append("beacon%d" % i)
				layout = {"ids": ids2}
		"delivery":
			var points: Array = []
			for room: Dictionary in rooms:
				points.append(room["center"])
			if points.size() < 2:
				type = "clear"
			else:
				points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return ctx["spawn"].distance_to(a) < ctx["spawn"].distance_to(b))
				var a: Vector2 = points[0]
				var b: Vector2 = points[0]
				for p: Vector2 in points:
					if p.distance_to(a) > b.distance_to(a):
						b = p
				interacts.append({"id": "pickup", "kind": "relic", "pos": a + Vector2(90.0, 40.0), "label": "Reliquia"})
				interacts.append({"id": "dropoff", "kind": "pedestal", "pos": b + Vector2(90.0, 40.0), "label": "Pedestal"})
				layout = {"pickup": a + Vector2(90.0, 40.0), "dropoff": b + Vector2(90.0, 40.0)}
		"rescue":
			var camp_i2 := 1 + rng.randi() % maxi(camps.size() - 1, 1)
			camp_i2 = mini(camp_i2, camps.size() - 1)
			var cage_pos: Vector2 = (camps[camp_i2]["center"] as Vector2) + Vector2(60.0, -60.0)
			interacts.append({"id": "cage", "kind": "cage", "pos": cage_pos, "label": "Aldeano preso"})
			layout = {"camp": camp_i2, "cage": cage_pos, "destination": ctx["exit"]}
		"choice":
			if rooms.is_empty():
				type = "clear"
			else:
				var room2: Dictionary = _take(rooms, rng)
				interacts.append({"id": "signpost", "kind": "signpost", "pos": (ctx["spawn"] as Vector2) + Vector2(110.0, -40.0), "label": "Cartel: elige camino"})
				layout = {
					"a": {"type": "explore", "layout": {"count": mini(3, (ctx["clearings"] as Array).size() - 1)}},
					"b": {"type": "duel", "layout": {"target": _add_camp(camps, "El Claro del Duelo", room2["center"], "campeon" if floor_number >= 5 else "duelista", floor_number + 1)}},
				}
	total = _count(camps)
	var optional := MissionCatalog.pick_optional(rng, type)
	var centers: Array = []
	for c: Dictionary in ctx["clearings"]:
		if c["center"] != ctx["spawn"] and not c.has("hidden"):
			centers.append(c["center"])
	var ranges: Array = []  # [primer índice, último índice + 1] de cada campamento
	var start := 0
	for c: Dictionary in camps:
		ranges.append([start, start + (c["enemies"] as Array).size()])
		start += (c["enemies"] as Array).size()
	return {
		"spec": {
			"type": type, "layout": layout, "optional": optional, "total": total, "ranges": ranges,
			"par_seconds": 120 + 10 * total, "reward_mult": 1.0, "chests_total": 0, "clearing_centers": centers,
		},
		"interacts": interacts, "hidden": hidden,
	}


# --- utilidades -----------------------------------------------------------------------------


static func _count(camps: Array) -> int:
	var n := 0
	for c: Dictionary in camps:
		n += (c["enemies"] as Array).size()
	return n


## Claros sin campamento ni spawn (candidatos a altares, duelos, cofres...).
static func _rooms(ctx: Dictionary) -> Array:
	var out: Array = []
	for c: Dictionary in ctx["clearings"]:
		if c["center"] == ctx["spawn"]:
			continue
		var taken := false
		for camp: Dictionary in ctx["camps"]:
			if camp["center"] == c["center"]:
				taken = true
		if not taken:
			out.append(c)
	return out


static func _take(rooms: Array, rng: RandomNumberGenerator) -> Dictionary:
	var i := rng.randi() % rooms.size()
	var room: Dictionary = rooms[i]
	rooms.remove_at(i)
	return room


## Añade un campamento de un solo enemigo; devuelve el índice global de ese enemigo.
static func _add_camp(camps: Array, camp_name: String, center: Vector2, arch: String, level: int) -> int:
	var index := _count(camps)
	camps.append({"name": camp_name, "center": center, "enemies": [{"arch": arch, "pos": center + Vector2(0.0, 40.0), "level": level}]})
	return index


static func _pick_elite(camps: Array, rng: RandomNumberGenerator) -> int:
	var found: Array = []
	var index := 0
	for ci in range(camps.size()):
		for e: Dictionary in camps[ci]["enemies"]:
			var tier := String(EnemyArchetypes.data(String(e["arch"])).get("tier", "minion"))
			if ci > 0 and tier == "elite":
				found.append(index)
			index += 1
	return int(found[rng.randi() % found.size()]) if not found.is_empty() else -1


static func _find_arch(camps: Array, arch: String) -> int:
	var index := 0
	for c: Dictionary in camps:
		for e: Dictionary in c["enemies"]:
			if String(e["arch"]) == arch:
				return index
			index += 1
	return -1


static func _hidden_clearing(rng: RandomNumberGenerator, clearings: Array) -> Dictionary:
	# Distancia mínima al resto de claros (muros de árboles incluidos): se relaja si el mapa está lleno.
	for margin in [330.0, 260.0, 200.0]:
		for attempt in range(600):
			var center := Vector2(rng.randf_range(380.0, SIZE.x - 380.0), rng.randf_range(380.0, SIZE.y - 380.0))
			var ok := true
			for c: Dictionary in clearings:
				if center.distance_to(c["center"]) < float(c["radius"]) + 160.0 + margin:
					ok = false
					break
			if ok:
				return {"center": center, "radius": 160.0, "hidden": true}
	return {}
