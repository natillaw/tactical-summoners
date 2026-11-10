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
	for id in ["blacksmith", "alchemy", "tavern", "leatherworker", "tailor", "carpenter", "portal"]:
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
	CharacterProfile.bag = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var w := WarriorSim.new(CombatWorld.new(1))
	var recipe: Dictionary = Crafting.recipes_for("blacksmith")[0]
	_check(not Crafting.can_craft(recipe), "sin materiales no se puede fabricar")
	Materials.add("mena_cobre", 4)
	Materials.add("madera", 2)
	var dps_before := w.weapon.dps()
	Crafting.craft(recipe, w, rng)
	_check(int(Materials.inventory["mena_cobre"]) == 0 and int(Materials.inventory["madera"]) == 0, "gasta los materiales")
	_check(w.weapon.item_name == "Espada de Cobre" and w.weapon.dps() > dps_before, "equipa el arma mejor")
	var hp_before := w.max_health
	var armor_recipe: Dictionary = {}
	for r: Dictionary in Crafting.RECIPES:
		if r["id"] == "peto_cobre":
			armor_recipe = r
	Materials.add("mena_cobre", 6)
	Materials.add("cuero_basto", 3)
	Crafting.craft(armor_recipe, w, rng)
	_check(w.max_health > hp_before, "la armadura sube la vida máxima")
	var potion: Dictionary = {}
	for r: Dictionary in Crafting.recipes_for("alchemy"):
		if r["id"] == "pocion_vida":
			potion = r
	Materials.add("hierba_curativa", 2)
	Materials.add("flor_silvestre", 1)
	Crafting.craft(potion, w, rng)
	_check(int(Materials.inventory.get("pocion_vida", 0)) == 1, "la alquimia entrega la poción")
	# Calidad al forjar: 85/13/2 y nunca único/legendario.
	var counts := {}
	var qrng := RandomNumberGenerator.new()
	qrng.seed = 99
	for i in range(20000):
		var q := Crafting.roll_quality(qrng)
		counts[q] = int(counts.get(q, 0)) + 1
	_check(absf(counts[ItemRarity.Tier.POCO_COMUN] / 20000.0 - 0.85) < 0.02, "85% poco común")
	_check(absf(counts[ItemRarity.Tier.RARO] / 20000.0 - 0.13) < 0.015, "13% raro")
	_check(absf(counts[ItemRarity.Tier.EPICO] / 20000.0 - 0.02) < 0.008, "2% épico")
	_check(not counts.has(ItemRarity.Tier.UNICO) and not counts.has(ItemRarity.Tier.LEGENDARIO), "único/legendario no se fabrican")
	# Slots: equipar, desequipar y mochila.
	var boots: Dictionary = {}
	for r: Dictionary in Crafting.RECIPES:
		if r["id"] == "botas_cuero":
			boots = r
	Materials.add("cuero_basto", 4)
	Materials.add("fibra", 4)
	Crafting.craft(boots, w, rng)
	_check(w.armor_items.has("boots"), "las botas ocupan su slot")
	var hp_with := w.max_health
	Gear.unequip("boots", w)
	_check(not w.armor_items.has("boots") and CharacterProfile.bag.size() >= 1 and w.max_health < hp_with, "desequipar quita stats y va a la mochila")
	Gear.equip(CharacterProfile.bag[0], w)
	_check(w.armor_items.has("boots"), "equipar desde la mochila")
	print("town+crafting: ", "OK" if fails == 0 else "%d fallos" % fails)
	quit(1 if fails > 0 else 0)
