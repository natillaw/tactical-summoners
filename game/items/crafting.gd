## Crafting — recetas de la herrería y el salón de alquimia. Gastan `Materials.inventory`.
## Armas y armadura se equipan al fabricarse si mejoran lo que llevas.
class_name Crafting
extends RefCounted

const RECIPES := [
	# Herrería: armas
	{"id": "espada_cobre", "station": "blacksmith", "name": "Espada de Cobre", "cost": {"mena_cobre": 4, "madera": 2}, "weapon": "sword"},
	{"id": "hacha_cobre", "station": "blacksmith", "name": "Hacha de Cobre", "cost": {"mena_cobre": 5, "madera": 2, "piedra": 2}, "weapon": "axe"},
	{"id": "maza_cobre", "station": "blacksmith", "name": "Maza de Cobre", "cost": {"mena_cobre": 4, "madera": 3, "piedra": 2}, "weapon": "mace"},
	{"id": "daga_cobre", "station": "blacksmith", "name": "Daga de Cobre", "cost": {"mena_cobre": 3, "cuero_basto": 1}, "weapon": "dagger"},
	{"id": "lanza_cobre", "station": "blacksmith", "name": "Lanza de Cobre", "cost": {"mena_cobre": 3, "madera": 4}, "weapon": "spear"},
	# Herrería: armadura
	{"id": "yelmo_cobre", "station": "blacksmith", "name": "Yelmo de Cobre", "cost": {"mena_cobre": 3, "cuero_basto": 2}, "armor": "head", "stats": {"stamina": 3.0, "armor": 6.0}},
	{"id": "peto_cobre", "station": "blacksmith", "name": "Peto de Cobre", "cost": {"mena_cobre": 6, "cuero_basto": 3}, "armor": "chest", "stats": {"stamina": 5.0, "strength": 1.0, "armor": 12.0}},
	{"id": "grebas_cuero", "station": "blacksmith", "name": "Grebas de Cuero", "cost": {"cuero_basto": 3, "fibra": 3, "hueso": 1}, "armor": "legs", "stats": {"stamina": 3.0, "armor": 5.0}},
	{"id": "botas_cuero", "station": "blacksmith", "name": "Botas de Cuero", "cost": {"cuero_basto": 2, "fibra": 2}, "armor": "boots", "stats": {"stamina": 2.0, "armor": 3.0, "crit_chance": 0.01}},
	# Alquimia
	{"id": "pocion_vida", "station": "alchemy", "name": "Poción de Vida", "cost": {"hierba_curativa": 2, "flor_silvestre": 1}, "gives": "pocion_vida", "amount": 1},
	{"id": "elixir_fuerza", "station": "alchemy", "name": "Elixir de Fuerza", "cost": {"hongo": 2, "hierba_curativa": 1}, "gives": "elixir_fuerza", "amount": 1},
	{"id": "pocion_arcana", "station": "alchemy", "name": "Poción Arcana", "cost": {"polvo_arcano": 1, "flor_silvestre": 1}, "gives": "pocion_arcana", "amount": 1},
]
const ITEM_LEVEL := 3  # todo lo del piso 1 se fabrica como objeto poco común de nivel 3


static func recipes_for(station: String) -> Array:
	return RECIPES.filter(func(r: Dictionary) -> bool: return r["station"] == station)


static func can_craft(recipe: Dictionary) -> bool:
	for id: String in recipe["cost"]:
		if int(Materials.inventory.get(id, 0)) < int(recipe["cost"][id]):
			return false
	return true


static func cost_text(recipe: Dictionary) -> String:
	var parts: Array = []
	for id: String in recipe["cost"]:
		parts.append("%d %s (%d)" % [recipe["cost"][id], Materials.display(id), int(Materials.inventory.get(id, 0))])
	return ", ".join(parts)


## Fabrica la receta: gasta materiales y entrega/equipa el resultado. Devuelve el mensaje para el jugador.
static func craft(recipe: Dictionary, warrior: WarriorSim) -> String:
	if not can_craft(recipe):
		return "Faltan materiales"
	for id: String in recipe["cost"]:
		Materials.inventory[id] = int(Materials.inventory.get(id, 0)) - int(recipe["cost"][id])
	if recipe.has("gives"):
		Materials.add(String(recipe["gives"]), int(recipe["amount"]))
		return "Creaste: %s" % recipe["name"]
	var item: Item
	if recipe.has("weapon"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(recipe["id"]))
		item = ItemFactory.roll_weapon(rng, ITEM_LEVEL, ItemRarity.Tier.POCO_COMUN, String(recipe["weapon"]))
		item.item_name = String(recipe["name"])
		item.id = String(recipe["id"])
		item.stats.clear()
		item.stats["attack_power_bonus"] = 2.0
		if item.dps() > (warrior.weapon.dps() if warrior.weapon != null else 0.0):
			warrior.equip_weapon(item)
			CharacterProfile.weapon = item
			return "Forjaste y equipaste: %s (%.1f DPS)" % [item.item_name, item.dps()]
		return "Forjaste %s, pero tu arma actual es mejor" % item.item_name
	item = Item.new()
	item.id = String(recipe["id"])
	item.item_name = String(recipe["name"])
	item.slot = String(recipe["armor"])
	item.rarity = ItemRarity.Tier.POCO_COMUN
	item.item_level = ITEM_LEVEL
	item.stats = (recipe["stats"] as Dictionary).duplicate()
	warrior.equip_armor(item)
	CharacterProfile.armor[item.slot] = item
	return "Forjaste y equipaste: %s" % item.item_name


static func category_of(recipe: Dictionary) -> String:
	if recipe.has("weapon"):
		return "Armas"
	if recipe.has("armor"):
		return "Armadura"
	return "Pociones"


static func describe_result(recipe: Dictionary) -> String:
	if recipe.has("weapon"):
		var base: Dictionary = ItemFactory.WEAPON_TYPES[recipe["weapon"]]
		var dps := (2.0 + 0.7 * ITEM_LEVEL) * float(ItemRarity.POWER[ItemRarity.Tier.POCO_COMUN])
		return "[color=#59d959]Poco común[/color]  ·  %s  ·  Nv.%d
%.1f DPS  ·  vel %.1f  ·  +2 poder de ataque" % [base["name"], ITEM_LEVEL, dps, float(base["speed"])]
	if recipe.has("armor"):
		var lines: Array = ["[color=#59d959]Poco común[/color]  ·  %s  ·  Nv.%d" % [String(recipe["armor"]).capitalize(), ITEM_LEVEL]]
		for k: String in recipe["stats"]:
			lines.append("+%s %s" % [("%d%%" % int(recipe["stats"][k] * 100.0)) if k == "crit_chance" else str(int(recipe["stats"][k])), k])
		return "
".join(lines)
	match String(recipe["gives"]):
		"pocion_vida": return "Consumible
Restaura 40% de la vida máxima. Tecla H."
		"elixir_fuerza": return "Consumible
+25% de daño durante 60 s. Tecla J."
		"pocion_arcana": return "Consumible
Restaura 60% del recurso (maná, energía, rage). Tecla K."
	return ""
