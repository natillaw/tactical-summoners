## BalanceData — datos de balance editables sin tocar código (res://data/balance.json).
##
## - classes: multiplicadores por clase (daño, vida, velocidad, crit, cooldowns, regeneración).
## - skills: sobrescritura de cualquier número de una skill (damage_mult, cooldown, cost...).
## WarriorSim lee esto en vivo, así que el Laboratorio de Balance (tools/balance) puede
## probar cambios al instante y guardarlos para el juego.
class_name BalanceData
extends RefCounted

const PATH := "res://data/balance.json"
const CLASS_DEFAULTS := {
	"damage_mult": 1.0, "health_mult": 1.0, "speed_mult": 1.0,
	"crit_bonus": 0.0, "cooldown_mult": 1.0, "regen_mult": 1.0, "armor_mult": 1.0, "cc_scale": 1.0,
}

static var data: Dictionary = {"classes": {}, "skills": {}}
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if not _loaded:
		_loaded = true
		load_file()


static func load_file() -> void:
	_loaded = true
	data = {"classes": {}, "skills": {}}
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		data["classes"] = (parsed as Dictionary).get("classes", {})
		data["skills"] = (parsed as Dictionary).get("skills", {})


static func save_file() -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


static func clear() -> void:
	_loaded = true
	data = {"classes": {}, "skills": {}}


## Multiplicadores efectivos de una clase (defaults + lo guardado).
static func class_mods(id: StringName) -> Dictionary:
	ensure_loaded()
	var mods := CLASS_DEFAULTS.duplicate()
	var saved: Dictionary = (data["classes"] as Dictionary).get(String(id), {})
	for key: String in saved:
		mods[key] = saved[key]
	return mods


static func skill_override(skill_id: String) -> Dictionary:
	ensure_loaded()
	return (data["skills"] as Dictionary).get(skill_id, {})


static func set_class_mod(id: StringName, key: String, value: float) -> void:
	ensure_loaded()
	var classes: Dictionary = data["classes"]
	var entry: Dictionary = classes.get(String(id), {})
	entry[key] = value
	classes[String(id)] = entry


static func set_skill_value(skill_id: String, key: String, value: float) -> void:
	ensure_loaded()
	var skills: Dictionary = data["skills"]
	var entry: Dictionary = skills.get(skill_id, {})
	entry[key] = value
	skills[skill_id] = entry
