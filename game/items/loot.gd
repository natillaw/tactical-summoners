## Loot — drops de equipo. Son raros y acordes al piso: lo normal es fabricar; un drop es un premio.
##
## Probabilidad de que caiga una pieza (por evento):
##   esbirro 1.5 % · élite 8 % · jefe 100 % (mínimo Raro) · cofre 6 % · completar piso 15 % (+10 % con el opcional)
## Rareza: `ItemRarity.weights_for_floor(piso)`. Nivel de objeto = piso (un drop del piso 4 es comparable a lo
## fabricado con grado 1; del piso 8, a grado 2). Las armas salen con un diseño propio de su grado.
class_name Loot
extends RefCounted

const CHANCE := {"minion": 0.015, "elite": 0.08, "boss": 1.0, "chest": 0.06, "floor": 0.15, "floor_optional": 0.25}
## Parte de los drops que son armas (el resto, armadura).
const WEAPON_SHARE := 0.4
## De las armas, cuántas son de un tipo que tu clase puede empuñar.
const CLASS_BIAS := 0.6


## Tira un drop para `source` (clave de CHANCE). Devuelve el objeto o null si no cae nada.
static func roll(source: String, floor_number: int, class_id: StringName, rng: RandomNumberGenerator) -> Item:
	if rng.randf() >= float(CHANCE.get(source, 0.0)):
		return null
	var rarity := ItemRarity.roll_for_floor(rng, floor_number)
	if source == "boss":
		rarity = maxi(rarity, ItemRarity.Tier.RARO)
	return make(floor_number, class_id, rarity, rng)


## Fabrica la pieza (arma con diseño del grado del piso, o armadura genérica) de la rareza dada.
static func make(floor_number: int, class_id: StringName, rarity: int, rng: RandomNumberGenerator) -> Item:
	var level := clampi(floor_number, 1, Progression.MAX_LEVEL)
	if rng.randf() >= WEAPON_SHARE:
		return ItemFactory.roll_armor(rng, level, rarity)
	var types: Array = ItemFactory.WEAPON_TYPES.keys()
	var usable: Array = Gear.CLASS_WEAPONS.get(class_id, [])
	var type: String = usable[rng.randi() % usable.size()] if not usable.is_empty() and rng.randf() < CLASS_BIAS else types[rng.randi() % types.size()]
	var item := ItemFactory.roll_weapon(rng, level, rarity, type)
	var grade := 2 if Materials.grade2_unlocked(floor_number) else 1
	var looks := WeaponDesigns.ids_for(type, grade)
	if not looks.is_empty():
		var design_id: String = looks[rng.randi() % looks.size()]
		item.model_id = design_id
		item.item_name = String(WeaponDesigns.get_design(design_id)["name"])
	return item


## Entrega el drop al jugador y devuelve el texto para el aviso.
static func give(item: Item, warrior: WarriorSim) -> String:
	var equipped := Gear.give(item, warrior)
	return "Botín: %s [%s]%s" % [item.item_name, ItemRarity.display(item.rarity), " (equipado)" if equipped else " (mochila)"]
