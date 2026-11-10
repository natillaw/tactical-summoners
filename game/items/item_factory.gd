## ItemFactory — genera armas de forma determinista (el RNG lo aporta quien llama).
##
## Presupuesto de daño: DPS = (2 + 0.7·nivel) · poder(rareza). Con nivel 60 y un
## arma épica de 3.0 de velocidad son ~200 de daño medio; con Fuerza y AP las
## habilidades más fuertes rondan los 3k con crítico, sin números gigantes.
class_name ItemFactory
extends RefCounted

const WEAPON_TYPES := {
	"sword": {"name": "Espada", "speed": 2.6, "spread": 0.25, "trait": "crítico +3%"},
	"axe": {"name": "Hacha", "speed": 3.2, "spread": 0.32, "trait": "sangrado"},
	"mace": {"name": "Maza", "speed": 3.0, "spread": 0.20, "trait": "aturdimiento"},
	"spear": {"name": "Lanza", "speed": 3.4, "spread": 0.15, "trait": "alcance +"},
	"dagger": {"name": "Daga", "speed": 1.8, "spread": 0.30, "trait": "golpes rápidos"},
	"bow": {"name": "Arco", "speed": 2.8, "spread": 0.22, "trait": "disparo preciso"},
	"staff": {"name": "Bastón", "speed": 3.0, "spread": 0.18, "trait": "canaliza magia"},
}
const PREFIXES := ["Oxidada", "Sólida", "Afilada", "Forjada", "Rúnica", "Ancestral"]
const AFFIX_STATS := ["strength", "stamina", "crit_chance", "attack_power_bonus"]
const LEGENDARY_EFFECTS := ["seismic_burning_ground", "thrust_pierces_all", "charge_resets_on_kill"]


static func starter_sword() -> Item:
	var item := Item.new()
	item.id = "starter_sword"
	item.item_name = "Espada de recluta"
	item.weapon_type = "sword"
	item.weapon_speed = 2.6
	item.weapon_min = 7.0
	item.weapon_max = 11.0
	return item


## Armadura genérica (drop): stats por nivel de objeto y ranura, × poder de la rareza, + afijos.
##   aguante = (1.2 + 0.45·nivel) × ranura · armadura = (2 + 0.9·nivel) × ranura
const ARMOR_SLOT_WEIGHT := {"chest": 1.0, "legs": 0.75, "head": 0.6, "hands": 0.4, "boots": 0.4}
const ARMOR_SLOT_NAMES := {"chest": "Peto", "legs": "Grebas", "head": "Casco", "hands": "Guantes", "boots": "Botas"}
const ARMOR_SUFFIXES := ["del Eco", "del Pliegue", "de la Costura", "del Recuerdo", "del Umbral", "de la Torre"]


static func roll_armor(rng: RandomNumberGenerator, level: int, rarity: int = -1, slot: String = "") -> Item:
	if rarity < 0:
		rarity = ItemRarity.roll(rng)
	if not ARMOR_SLOT_WEIGHT.has(slot):
		var slots := ARMOR_SLOT_WEIGHT.keys()
		slot = slots[rng.randi() % slots.size()]
	var item := Item.new()
	item.slot = slot
	item.rarity = rarity
	item.item_level = clampi(level, 1, Progression.MAX_LEVEL)
	var weight := float(ARMOR_SLOT_WEIGHT[slot])
	var power := float(ItemRarity.POWER[rarity])
	item.stats["stamina"] = roundf((1.2 + 0.45 * item.item_level) * weight * power * 10.0) / 10.0
	item.stats["armor"] = roundf((2.0 + 0.9 * item.item_level) * weight * power * 10.0) / 10.0
	for i in int(ItemRarity.AFFIXES[rarity]):
		var stat: String = AFFIX_STATS[rng.randi() % AFFIX_STATS.size()]
		var amount := 0.01 if stat == "crit_chance" else roundf(1.0 + item.item_level * rng.randf_range(0.2, 0.4) * weight)
		item.stats[stat] = float(item.stats.get(stat, 0.0)) + amount
	item.item_name = "%s %s" % [ARMOR_SLOT_NAMES[slot], ARMOR_SUFFIXES[rng.randi() % ARMOR_SUFFIXES.size()]]
	item.id = "drop_%s_%d_%d" % [slot, item.item_level, rng.randi() % 100000]
	return item


static func roll_weapon(rng: RandomNumberGenerator, level: int, rarity: int = -1, type: String = "") -> Item:
	if rarity < 0:
		rarity = ItemRarity.roll(rng)
	if type == "" or not WEAPON_TYPES.has(type):
		var keys := WEAPON_TYPES.keys()
		type = keys[rng.randi() % keys.size()]
	var base: Dictionary = WEAPON_TYPES[type]
	var item := Item.new()
	item.weapon_type = type
	item.rarity = rarity
	item.item_level = clampi(level, 1, Progression.MAX_LEVEL)
	item.weapon_speed = float(base["speed"])
	var dps := (2.0 + 0.7 * item.item_level) * float(ItemRarity.POWER[rarity])
	var avg := dps * item.weapon_speed
	var spread := float(base["spread"])
	item.weapon_min = roundf(avg * (1.0 - spread))
	item.weapon_max = roundf(avg * (1.0 + spread))
	item.trait_id = String(base["trait"])
	item.item_name = "%s %s" % [base["name"], PREFIXES[rng.randi() % PREFIXES.size()]]
	item.id = "%s_%d_%d" % [type, item.item_level, rng.randi() % 100000]
	for i in int(ItemRarity.AFFIXES[rarity]):
		var stat: String = AFFIX_STATS[rng.randi() % AFFIX_STATS.size()]
		var amount := 0.0
		match stat:
			"strength": amount = roundf(item.item_level * rng.randf_range(0.35, 0.6)) + 1.0
			"stamina": amount = roundf(item.item_level * rng.randf_range(0.5, 0.9)) + 2.0
			"crit_chance": amount = rng.randf_range(0.01, 0.03)
			"attack_power_bonus": amount = roundf(item.item_level * rng.randf_range(0.8, 1.4)) + 2.0
		item.stats[stat] = float(item.stats.get(stat, 0.0)) + amount
	if rarity == ItemRarity.Tier.LEGENDARIO:
		item.legendary_effect = LEGENDARY_EFFECTS[rng.randi() % LEGENDARY_EFFECTS.size()]
	return item
