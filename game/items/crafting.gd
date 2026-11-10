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
	{"id": "grebas_cuero", "station": "leatherworker", "name": "Grebas de Cuero", "cost": {"cuero_basto": 3, "fibra": 3, "hueso": 1}, "armor": "legs", "stats": {"stamina": 3.0, "armor": 5.0}},
	{"id": "guantes_cuero", "station": "leatherworker", "name": "Guantes de Cuero", "cost": {"cuero_basto": 2, "fibra": 2}, "armor": "hands", "stats": {"strength": 1.0, "armor": 3.0, "attack_power_bonus": 2.0}},
	{"id": "botas_cuero", "station": "leatherworker", "name": "Botas de Cuero", "cost": {"cuero_basto": 2, "fibra": 2}, "armor": "boots", "stats": {"stamina": 2.0, "armor": 3.0, "crit_chance": 0.01}},
	# Peletería
	{"id": "casco_cuero", "station": "leatherworker", "name": "Casco de Cuero", "cost": {"cuero_basto": 3, "fibra": 1}, "armor": "head", "stats": {"stamina": 2.0, "armor": 4.0}},
	{"id": "jubon_cuero", "station": "leatherworker", "name": "Jubón de Cuero", "cost": {"cuero_basto": 5, "hueso": 1, "fibra": 2}, "armor": "chest", "stats": {"stamina": 4.0, "armor": 8.0, "attack_power_bonus": 2.0}},
	# Sastrería (tela ligera: menos armadura, más poder)
	{"id": "capucha_tela", "station": "tailor", "name": "Capucha de Tela", "cost": {"fibra": 4, "flor_silvestre": 1}, "armor": "head", "stats": {"stamina": 2.0, "armor": 2.0, "crit_chance": 0.01}},
	{"id": "tunica_tela", "station": "tailor", "name": "Túnica de Tela", "cost": {"fibra": 7, "flor_silvestre": 2, "polvo_arcano": 1}, "armor": "chest", "stats": {"stamina": 4.0, "armor": 4.0, "attack_power_bonus": 4.0}},
	{"id": "pantalon_tela", "station": "tailor", "name": "Pantalones de Tela", "cost": {"fibra": 5, "flor_silvestre": 1}, "armor": "legs", "stats": {"stamina": 3.0, "armor": 2.0, "attack_power_bonus": 2.0}},
	{"id": "guantes_tela", "station": "tailor", "name": "Guantes de Tela", "cost": {"fibra": 3, "hueso": 1}, "armor": "hands", "stats": {"stamina": 1.0, "armor": 1.0, "crit_chance": 0.01, "attack_power_bonus": 2.0}},
	{"id": "sandalias_tela", "station": "tailor", "name": "Sandalias de Tela", "cost": {"fibra": 3, "flor_silvestre": 1}, "armor": "boots", "stats": {"stamina": 2.0, "armor": 1.0, "crit_chance": 0.01}},
	# Carpintería
	{"id": "arco_corto", "station": "carpenter", "name": "Arco Corto", "cost": {"madera": 4, "fibra": 2}, "weapon": "bow"},
	{"id": "arco_largo", "station": "carpenter", "name": "Arco Largo", "cost": {"madera": 5, "fibra": 3, "cuero_basto": 1}, "weapon": "bow"},
	{"id": "baston_roble", "station": "carpenter", "name": "Bastón de Roble", "cost": {"madera": 4, "polvo_arcano": 1}, "weapon": "staff"},
	{"id": "garrote_madera", "station": "carpenter", "name": "Garrote Reforzado", "cost": {"madera": 5, "piedra": 2}, "weapon": "mace"},
	{"id": "lanza_madera", "station": "carpenter", "name": "Lanza de Madera", "cost": {"madera": 4, "piedra": 2}, "weapon": "spear"},
	# Sets de armadura de nivel bajo (visual: CharacterBuilder armor_<set>); ver ArmorSets.
	{"id": "footman_yelmo", "station": "blacksmith", "name": "Yelmo Nasal de Leva", "cost": {"mena_cobre": 3, "fibra": 2}, "armor": "head", "set": "footman", "stats": {"armor": 6.9, "stamina": 3.0}},
	{"id": "footman_peto", "station": "blacksmith", "name": "Cota de Leva", "cost": {"mena_cobre": 5, "fibra": 4, "cuero_basto": 2}, "armor": "chest", "set": "footman", "stats": {"armor": 13.8, "stamina": 6.0}},
	{"id": "footman_grebas", "station": "blacksmith", "name": "Calzas Acolchadas de Leva", "cost": {"mena_cobre": 2, "fibra": 3, "cuero_basto": 2}, "armor": "legs", "set": "footman", "stats": {"armor": 5.8, "stamina": 3.0}},
	{"id": "footman_guantes", "station": "blacksmith", "name": "Manoplas de Malla de Leva", "cost": {"mena_cobre": 2, "fibra": 2}, "armor": "hands", "set": "footman", "stats": {"armor": 3.5, "stamina": 1.0}},
	{"id": "footman_botas", "station": "blacksmith", "name": "Botas Ferradas de Leva", "cost": {"cuero_basto": 2, "fibra": 2, "mena_cobre": 1}, "armor": "boots", "set": "footman", "stats": {"armor": 3.5, "stamina": 2.0}},
	{"id": "knight_yelmo", "station": "blacksmith", "name": "Gran Yelmo de Escudero", "cost": {"mena_cobre": 5, "cuero_basto": 2}, "armor": "head", "set": "knight", "stats": {"armor": 7.8, "stamina": 3.2}},
	{"id": "knight_peto", "station": "blacksmith", "name": "Coraza de Escudero", "cost": {"mena_cobre": 9, "cuero_basto": 3, "piedra": 2}, "armor": "chest", "set": "knight", "stats": {"armor": 15.6, "stamina": 5.3}},
	{"id": "knight_grebas", "station": "blacksmith", "name": "Grebas de Escudero", "cost": {"mena_cobre": 5, "cuero_basto": 2}, "armor": "legs", "set": "knight", "stats": {"armor": 6.5, "stamina": 3.2}},
	{"id": "knight_guantes", "station": "blacksmith", "name": "Guanteletes de Escudero", "cost": {"mena_cobre": 3, "cuero_basto": 2}, "armor": "hands", "set": "knight", "stats": {"armor": 3.9, "stamina": 1.1}},
	{"id": "knight_botas", "station": "blacksmith", "name": "Escarpes de Escudero", "cost": {"mena_cobre": 3, "cuero_basto": 2}, "armor": "boots", "set": "knight", "stats": {"armor": 3.9, "stamina": 2.1}},
	{"id": "hoplite_yelmo", "station": "blacksmith", "name": "Casco Corintio de Bronce", "cost": {"mena_cobre": 4, "cuero_basto": 1}, "armor": "head", "set": "hoplite", "stats": {"armor": 6.0, "stamina": 3.0, "strength": 1.0}},
	{"id": "hoplite_peto", "station": "blacksmith", "name": "Coraza de Bronce", "cost": {"mena_cobre": 7, "cuero_basto": 2}, "armor": "chest", "set": "hoplite", "stats": {"armor": 12.0, "stamina": 5.0, "strength": 1.0}},
	{"id": "hoplite_grebas", "station": "blacksmith", "name": "Grebas de Bronce", "cost": {"mena_cobre": 4, "cuero_basto": 2}, "armor": "legs", "set": "hoplite", "stats": {"armor": 5.0, "stamina": 3.0}},
	{"id": "hoplite_guantes", "station": "blacksmith", "name": "Brazales de Bronce", "cost": {"mena_cobre": 2, "cuero_basto": 2}, "armor": "hands", "set": "hoplite", "stats": {"armor": 3.0, "stamina": 1.0}},
	{"id": "hoplite_botas", "station": "blacksmith", "name": "Sandalias Ferradas de Bronce", "cost": {"cuero_basto": 3, "mena_cobre": 1}, "armor": "boots", "set": "hoplite", "stats": {"armor": 3.0, "stamina": 2.0}},
	{"id": "norse_yelmo", "station": "blacksmith", "name": "Yelmo Astado del Norte", "cost": {"mena_cobre": 3, "hueso": 2, "cuero_basto": 1}, "armor": "head", "set": "norse", "stats": {"armor": 5.7, "stamina": 3.8}},
	{"id": "norse_peto", "station": "blacksmith", "name": "Cota de Escamas del Norte", "cost": {"mena_cobre": 5, "hueso": 2, "cuero_basto": 3}, "armor": "chest", "set": "norse", "stats": {"armor": 11.4, "stamina": 6.3, "strength": 1.0}},
	{"id": "norse_grebas", "station": "blacksmith", "name": "Pantalones Reforzados del Norte", "cost": {"cuero_basto": 3, "fibra": 2, "hueso": 1}, "armor": "legs", "set": "norse", "stats": {"armor": 4.8, "stamina": 3.8}},
	{"id": "norse_guantes", "station": "blacksmith", "name": "Brazales de Cuero del Norte", "cost": {"cuero_basto": 2, "hueso": 1}, "armor": "hands", "set": "norse", "stats": {"armor": 2.8, "stamina": 1.3}},
	{"id": "norse_botas", "station": "blacksmith", "name": "Botas de Piel del Norte", "cost": {"cuero_basto": 2, "hueso": 1, "fibra": 1}, "armor": "boots", "set": "norse", "stats": {"armor": 2.8, "stamina": 2.5, "crit_chance": 0.01}},
	{"id": "dark_yelmo", "station": "blacksmith", "name": "Yelmo Astado Ennegrecido", "cost": {"mena_cobre": 4, "hueso": 1}, "armor": "head", "set": "dark", "stats": {"armor": 4.8, "stamina": 2.7, "crit_chance": 0.01}},
	{"id": "dark_peto", "station": "blacksmith", "name": "Coraza de Púas Ennegrecida", "cost": {"mena_cobre": 7, "hueso": 2, "piedra": 1}, "armor": "chest", "set": "dark", "stats": {"armor": 9.6, "stamina": 4.5, "attack_power_bonus": 3.0, "strength": 1.0}},
	{"id": "dark_grebas", "station": "blacksmith", "name": "Grebas Ennegrecidas", "cost": {"mena_cobre": 4, "hueso": 1}, "armor": "legs", "set": "dark", "stats": {"armor": 4.0, "stamina": 2.7}},
	{"id": "dark_guantes", "station": "blacksmith", "name": "Guanteletes de Púas", "cost": {"mena_cobre": 2, "hueso": 1}, "armor": "hands", "set": "dark", "stats": {"armor": 2.4, "stamina": 0.9, "attack_power_bonus": 1.0}},
	{"id": "dark_botas", "station": "blacksmith", "name": "Botas de Hierro Negro", "cost": {"mena_cobre": 2, "cuero_basto": 2}, "armor": "boots", "set": "dark", "stats": {"armor": 2.4, "stamina": 1.8}},
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
		item.set_id = String(recipe.get("set", ""))
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
