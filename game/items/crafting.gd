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
	{"id": "guantes_cuero", "station": "blacksmith", "name": "Guantes de Cuero", "cost": {"cuero_basto": 2, "fibra": 2}, "armor": "hands", "stats": {"strength": 1.0, "armor": 3.0, "attack_power_bonus": 2.0}},
	{"id": "botas_cuero", "station": "blacksmith", "name": "Botas de Cuero", "cost": {"cuero_basto": 2, "fibra": 2}, "armor": "boots", "stats": {"stamina": 2.0, "armor": 3.0, "crit_chance": 0.01}},
	# Alquimia
	{"id": "pocion_vida", "station": "alchemy", "name": "Poción de Vida", "cost": {"hierba_curativa": 2, "flor_silvestre": 1}, "gives": "pocion_vida", "amount": 1},
	{"id": "elixir_fuerza", "station": "alchemy", "name": "Elixir de Fuerza", "cost": {"hongo": 2, "hierba_curativa": 1}, "gives": "elixir_fuerza", "amount": 1},
	{"id": "pocion_arcana", "station": "alchemy", "name": "Poción Arcana", "cost": {"polvo_arcano": 1, "flor_silvestre": 1}, "gives": "pocion_arcana", "amount": 1},
]
## Calidad al forjar (se revela al terminar): único y legendario no se pueden fabricar.
const ODDS := [[ItemRarity.Tier.POCO_COMUN, 0.85], [ItemRarity.Tier.RARO, 0.13], [ItemRarity.Tier.EPICO, 0.02]]
## Calidad del último objeto forjado (para sonidos/avisos de la UI).
static var last_quality: int = 0
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


static func roll_quality(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	var acc := 0.0
	for odd: Array in ODDS:
		acc += float(odd[1])
		if r < acc:
			return int(odd[0])
	return ItemRarity.Tier.POCO_COMUN


## Fabrica la receta: gasta materiales y entrega el resultado (la calidad se sortea al forjar).
## Devuelve el mensaje para el jugador. `rng` opcional para tests.
static func craft(recipe: Dictionary, warrior: WarriorSim, rng: RandomNumberGenerator = null) -> String:
	if not can_craft(recipe):
		return "Faltan materiales"
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for id: String in recipe["cost"]:
		Materials.inventory[id] = int(Materials.inventory.get(id, 0)) - int(recipe["cost"][id])
	last_quality = 0
	if recipe.has("gives"):
		Materials.add(String(recipe["gives"]), int(recipe["amount"]))
		return "Creaste: %s" % recipe["name"]
	var quality := roll_quality(rng)
	last_quality = quality
	var item: Item
	if recipe.has("weapon"):
		item = ItemFactory.roll_weapon(rng, ITEM_LEVEL, quality, String(recipe["weapon"]))
		item.item_name = String(recipe["name"])
		item.id = String(recipe["id"])
	else:
		item = Item.new()
		item.id = String(recipe["id"])
		item.item_name = String(recipe["name"])
		item.slot = String(recipe["armor"])
		item.rarity = quality
		item.item_level = ITEM_LEVEL
		var power := float(ItemRarity.POWER[quality])
		for k: String in recipe["stats"]:
			item.stats[k] = float(recipe["stats"][k]) * (power if k != "crit_chance" else 1.0)
		for i in int(ItemRarity.AFFIXES[quality]) - 1:  # extras de las calidades altas
			var stat: String = ItemFactory.AFFIX_STATS[rng.randi() % ItemFactory.AFFIX_STATS.size()]
			item.stats[stat] = float(item.stats.get(stat, 0.0)) + (0.01 if stat == "crit_chance" else float(1 + rng.randi() % 3))
	var equipped := Gear.give(item, warrior)
	return "Forjaste %s [%s]%s" % [item.item_name, ItemRarity.display(item.rarity), " y lo equipaste" if equipped else " (va a tu mochila)"]


static func category_of(recipe: Dictionary) -> String:
	if recipe.has("weapon"):
		return "Armas"
	if recipe.has("armor"):
		return "Armadura"
	return "Pociones"


static func describe_result(recipe: Dictionary) -> String:
	if recipe.has("weapon"):
		var base: Dictionary = ItemFactory.WEAPON_TYPES[recipe["weapon"]]
		var dps := (2.0 + 0.7 * ITEM_LEVEL)
		return "%s  ·  Nv.%d
~%.1f DPS  ·  vel %.1f
[color=#aaaaaa]La calidad se revela al forjar.[/color]" % [base["name"], ITEM_LEVEL, dps, float(base["speed"])]
	if recipe.has("armor"):
		var lines: Array = ["%s  ·  Nv.%d" % [Gear.SLOT_NAMES[recipe["armor"]], ITEM_LEVEL]]
		for k: String in recipe["stats"]:
			lines.append("+%s %s" % [("%d%%" % int(recipe["stats"][k] * 100.0)) if k == "crit_chance" else str(int(recipe["stats"][k])), k])
		lines.append("[color=#aaaaaa]La calidad se revela al forjar.[/color]")
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
