## Gear — equipar/desequipar y mochila. Mantiene sincronizado el equipo del sim con `CharacterProfile`
## (que sobrevive a los cambios de escena).
class_name Gear
extends RefCounted

const ARMOR_SLOTS := ["head", "chest", "legs", "hands", "boots"]
const SLOT_NAMES := {"weapon": "Arma", "head": "Cabeza", "chest": "Pecho", "legs": "Piernas", "hands": "Manos", "boots": "Pies"}


## Armas que puede empuñar cada clase (la armadura es libre).
const CLASS_WEAPONS := {
	&"warrior": ["sword", "axe", "mace", "spear"],
	&"rogue": ["dagger", "sword"],
	&"mage": ["staff"],
	&"ranger": ["bow", "dagger"],
}


static func can_use(item: Item, class_id: StringName) -> bool:
	if item.slot != "weapon" or item.id == "starter_sword":
		return true
	return item.weapon_type in CLASS_WEAPONS.get(class_id, [])


static func score(item: Item) -> float:
	if item.slot == "weapon":
		return item.dps() * 10.0 + _stat_sum(item)
	return _stat_sum(item)


static func _stat_sum(item: Item) -> float:
	var total := 0.0
	for k: String in item.stats:
		total += float(item.stats[k]) * (100.0 if k == "crit_chance" else 1.0)
	return total


static func equipped(warrior: WarriorSim, slot: String) -> Item:
	return warrior.weapon if slot == "weapon" else warrior.armor_items.get(slot)


## Entrega un objeto nuevo: lo equipa si mejora lo que llevas, si no va a la mochila. true = equipado.
static func give(item: Item, warrior: WarriorSim) -> bool:
	var current := equipped(warrior, item.slot)
	if not can_use(item, warrior.class_id):
		CharacterProfile.bag.append(item)
		return false
	if current == null or score(item) > score(current):
		equip(item, warrior)
		return true
	CharacterProfile.bag.append(item)
	return false


## Equipa `item` (que puede venir de la mochila); el anterior vuelve a la mochila.
static func equip(item: Item, warrior: WarriorSim) -> void:
	if not can_use(item, warrior.class_id):
		return
	CharacterProfile.bag.erase(item)
	var old := equipped(warrior, item.slot)
	if old != null and old.id != "starter_sword":
		CharacterProfile.bag.append(old)
	if item.slot == "weapon":
		warrior.equip_weapon(item)
		CharacterProfile.weapon = item
	else:
		warrior.equip_armor(item)
		CharacterProfile.armor[item.slot] = item


static func unequip(slot: String, warrior: WarriorSim) -> void:
	if slot == "weapon" or not warrior.armor_items.has(slot):
		return
	var item: Item = warrior.armor_items[slot]
	warrior.armor_items.erase(slot)
	CharacterProfile.armor.erase(slot)
	CharacterProfile.bag.append(item)
	warrior.recompute_stats(false)
