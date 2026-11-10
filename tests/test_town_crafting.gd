extends SceneTree
## Pueblo (estaciones/colisiones) y crafteo (gasta materiales, equipa, pociones).
var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", msg)

func _init() -> void:
	var t := Town.generate(1)
	var ids := []
	for s: Dictionary in t["stations"]:
		ids.append(s["id"])
		_check(Rect2(Vector2.ZERO, Town.SIZE).has_point(s["pos"]), "estación dentro del pueblo: " + String(s["id"]))
	for id in ["blacksmith", "alchemy", "tavern", "portal"]:
		_check(id in ids, "hay estación " + id)
	for o: Dictionary in t["obstacles"]:
		_check(t["spawn"].distance_to(o["position"]) > float(o["radius"]) + 30.0, "spawn libre")
	# La estación (NPC) está dentro del edificio, no en la calle.
	for b: Dictionary in Town.BUILDINGS:
		for s: Dictionary in t["stations"]:
			if s["id"] == b["id"]:
				var local: Vector2 = ((s["pos"] as Vector2) - (b["center"] as Vector2)).rotated(float(b["yaw"])) / 40.0
				_check(absf(local.x) < float(b["nx"]) and absf(local.y) < float(b["nz"]), "NPC dentro de " + String(b["id"]))
	# Crafteo
	Materials.inventory.clear()
	CharacterProfile.armor = {}
	CharacterProfile.weapon = null
	var w := WarriorSim.new(CombatWorld.new(1))
	var recipe: Dictionary = Crafting.recipes_for("blacksmith")[0]
	_check(not Crafting.can_craft(recipe), "sin materiales no se puede fabricar")
	Materials.add("mena_cobre", 4)
	Materials.add("madera", 2)
	var dps_before := w.weapon.dps()
	Crafting.craft(recipe, w)
	_check(int(Materials.inventory["mena_cobre"]) == 0 and int(Materials.inventory["madera"]) == 0, "gasta los materiales")
	_check(w.weapon.item_name == "Espada de Cobre" and w.weapon.dps() > dps_before, "equipa el arma mejor")
	var hp_before := w.max_health
	var armor_recipe: Dictionary = {}
	for r: Dictionary in Crafting.RECIPES:
		if r["id"] == "peto_cobre":
			armor_recipe = r
	Materials.add("mena_cobre", 6)
	Materials.add("cuero_basto", 3)
	Crafting.craft(armor_recipe, w)
	_check(w.max_health > hp_before, "la armadura sube la vida máxima")
	var potion: Dictionary = {}
	for r: Dictionary in Crafting.recipes_for("alchemy"):
		if r["id"] == "pocion_vida":
			potion = r
	Materials.add("hierba_curativa", 2)
	Materials.add("flor_silvestre", 1)
	Crafting.craft(potion, w)
	_check(int(Materials.inventory.get("pocion_vida", 0)) == 1, "la alquimia entrega la poción")
	print("town+crafting: ", "OK" if fails == 0 else "%d fallos" % fails)
	quit(1 if fails > 0 else 0)
