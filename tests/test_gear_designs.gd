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
	for r: Dictionary in Crafting.RECIPES:
		if not r.has("model"):
			continue
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
		_check(item.model_id == String(r["model"]) and WeaponCatalog.CUSTOM.has(item.model_id), "modelo propio " + item.id)
		_check(is_equal_approx(item.weapon_speed, float(r["speed"])), "velocidad de " + item.id)
		_check(item.dps() < base_dps * 2.2, "DPS acotado (no OP) " + item.id)
		w.weapon = item
		var spec := WeaponCatalog.spec_for(w, false)
		_check(String(spec["model"]) == item.model_id, "el actor usa el diseño " + item.id)
		var built: Dictionary = WeaponCatalog.build(spec)
		_check(float(built["tip"]) > 0.5 and (built["node"] as Node3D).get_child_count() == 1, "carga el modelo " + item.id)
		(built["node"] as Node3D).free()
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
