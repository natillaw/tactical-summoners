extends SceneTree
## Espadas con diseño propio (modelo, velocidad, DPS acotado) y sets de armadura (5 piezas por set, aspecto por ranura).
var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", msg)

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var base_dps := (2.0 + 0.7 * Crafting.ITEM_LEVEL)
	var crafted_models := {}
	for r: Dictionary in Crafting.all_recipes():
		if not r.has("model"):
			continue
		crafted_models[String(r["model"])] = true
		CharacterProfile.max_floor = 10
		Materials.inventory.clear()
		for id: String in r["cost"]:
			Materials.add(id, int(r["cost"][id]))
		CharacterProfile.armor = {}
		CharacterProfile.weapon = null
		CharacterProfile.bag = []
		var w := WarriorSim.new(CombatWorld.new(1))
		Crafting.craft(r, w, rng)
		var item: Item = null
		for it: Item in [w.weapon] + CharacterProfile.bag:
			if it != null and it.id == String(r["id"]):
				item = it
		_check(item != null, "se forja " + String(r["id"]))
		if item == null:
			continue
		_check(item.model_id == String(r["model"]) and WeaponDesigns.has(item.model_id), "modelo propio " + item.id)
		_check(is_equal_approx(item.weapon_speed, float(r["speed"])), "velocidad de " + item.id)
		_check(item.dps() < (2.0 + 0.7 * float(r.get("level", Crafting.ITEM_LEVEL))) * 1.45 * 1.06, "DPS acotado (no OP) " + item.id)
		w.weapon = item
		var spec := WeaponCatalog.spec_for(w, false)
		_check(String(spec["model"]) == item.model_id, "el actor usa el diseño " + item.id)
		var built: Dictionary = WeaponCatalog.build(spec)
		_check(float(built["tip"]) > 0.2 and (built["node"] as Node3D).get_child_count() == 1, "carga el modelo " + item.id)
		(built["node"] as Node3D).free()
	CharacterProfile.max_floor = 1
	# Todas las armas de assets/models/weapons/custom tienen receta, y no hay recetas sin modelo.
	var dir := DirAccess.open("res://assets/models/weapons/custom")
	var on_disk := {}
	for f in dir.get_files():
		if f.ends_with(".glb"):
			on_disk[f.get_basename()] = true
	for id: String in on_disk:
		_check(crafted_models.has(id), "arma con receta: " + id)
	for id: String in crafted_models:
		_check(on_disk.has(id), "receta con modelo en disco: " + id)
	_check(on_disk.size() >= 35, "35 armas con diseño propio (%d)" % on_disk.size())
	# Materiales: todo material recolectable o de botín se usa en alguna receta, y el grado del coste es coherente.
	var used := {}
	for r: Dictionary in Crafting.all_recipes():
		for id: String in r["cost"]:
			used[id] = true
			var grade := int(Materials.DEFS[id]["grade"])
			_check(grade <= int(r.get("grade", 1)), "%s no pide materiales de un grado superior (%s)" % [r["id"], id])
	for id: String in Materials.DEFS:
		var kind := String(Materials.DEFS[id]["kind"])
		if kind != "consumible" and kind != "jefe":
			_check(used.has(id), "material con uso: " + id)
	# Drops de equipo: raros, del nivel del piso y con pesos de rareza por piso.
	var w1 := ItemRarity.weights_for_floor(1)
	var w10 := ItemRarity.weights_for_floor(10)
	_check(is_zero_approx(float(w1[2]) + float(w1[3]) + float(w1[4]) + float(w1[5])) and float(w1[0]) > 80.0, "piso 1: solo normal y poco común")
	_check(float(w10[2]) > 15.0 and float(w10[3]) > 0.0 and is_zero_approx(float(w10[5])), "piso 10: raros y algún épico, sin legendarios")
	var drops := 0
	var drop_rng := RandomNumberGenerator.new()
	drop_rng.seed = 5
	for i in 2000:
		var it := Loot.roll("minion", 3, &"warrior", drop_rng)
		if it != null:
			drops += 1
			_check(it.item_level == 3 and it.rarity <= ItemRarity.Tier.RARO, "drop del piso 3: nivel 3 y como mucho raro")
	_check(drops > 5 and drops < 80, "los esbirros casi nunca sueltan equipo (%d de 2000)" % drops)
	var boss_item := Loot.roll("boss", 5, &"mage", drop_rng)
	_check(boss_item != null and boss_item.rarity >= ItemRarity.Tier.RARO, "el jefe siempre suelta una pieza rara o mejor")
	# sets: 5 piezas cada uno, una por ranura, y el aspecto sale de las piezas equipadas
	var by_set := {}
	for r: Dictionary in Crafting.RECIPES:
		if r.has("set"):
			if not by_set.has(r["set"]):
				by_set[r["set"]] = {}
			by_set[r["set"]][r["armor"]] = true
	_check(by_set.size() == 20, "20 sets de armadura (hay %d)" % by_set.size())
	for id: String in by_set:
		_check((by_set[id] as Dictionary).size() == 5, "5 ranuras en el set " + id)
		_check(ArmorSets.SETS.has(id), "nombre del set " + id)
	var head := Item.new()
	head.slot = "head"
	head.set_id = "knight"
	var boots := Item.new()
	boots.slot = "boots"
	boots.set_id = "dark"
	var look := ArmorSets.gear_for({"head": head, "boots": boots})
	_check(look == {"head": "knight", "boots": "dark"}, "aspecto pieza a pieza")
	print("gear designs: %d fallos" % fails)
	quit(1 if fails > 0 else 0)
