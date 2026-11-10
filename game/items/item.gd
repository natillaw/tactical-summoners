## Item — un objeto equipable. Para armas: daño min/max y velocidad (estilo WoW
## Classic); `stats` suma al personaje (strength, stamina, crit_chance,
## attack_power_bonus).
class_name Item
extends RefCounted

var id: String = ""
var item_name: String = ""
var slot: String = "weapon"
var rarity: int = ItemRarity.Tier.NORMAL
var item_level: int = 1
var weapon_type: String = ""
var weapon_min: float = 0.0
var weapon_max: float = 0.0
var weapon_speed: float = 2.6
var stats: Dictionary = {}
var model_id: String = ""         ## diseño propio del arma (WeaponCatalog.CUSTOM); "" = modelo según rareza
var set_id: String = ""           ## set de armadura (decide el aspecto del personaje), ver ArmorSets
var trait_id: String = ""         ## rasgo del tipo de arma (sangrado, aturdimiento…), pendiente de implementar
var legendary_effect: String = "" ## efecto especial (solo legendarios), pendiente de implementar


func average_damage() -> float:
	return (weapon_min + weapon_max) * 0.5


func dps() -> float:
	return average_damage() / maxf(weapon_speed, 0.1)


func describe() -> String:
	var lines := PackedStringArray()
	lines.append("%s  [%s]  Nv.%d" % [item_name, ItemRarity.display(rarity), item_level])
	if slot == "weapon":
		lines.append("%d–%d daño · vel %.1f · %.1f DPS" % [weapon_min, weapon_max, weapon_speed, dps()])
	for key: String in stats:
		var v: float = stats[key]
		lines.append("+%s %s" % [("%.0f%%" % (v * 100.0)) if key == "crit_chance" else str(int(v)), key])
	if set_id != "":
		lines.append("Set: " + ArmorSets.set_name(set_id))
	if trait_id != "":
		lines.append("Rasgo: " + trait_id)
	if legendary_effect != "":
		lines.append("Efecto: " + legendary_effect)
	return "\n".join(lines)
