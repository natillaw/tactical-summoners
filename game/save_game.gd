## SaveGame — guardado en disco (user://savegame.json): personaje, nivel, equipo, mochila,
## materiales y los pisos ya generados (semilla, enemigos muertos y nodos recogidos).
## Se guarda al cambiar de zona y al cerrar el juego; se carga al abrir el creador.
class_name SaveGame
extends RefCounted

const PATH := "user://savegame.json"
const VERSION := 1
const ITEM_FIELDS := ["id", "item_name", "slot", "rarity", "item_level", "weapon_type", "weapon_min", "weapon_max", "weapon_speed", "stats", "trait_id", "set_id", "model_id", "legendary_effect"]


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func item_to_dict(item: Item) -> Dictionary:
	var d := {}
	for field: String in ITEM_FIELDS:
		d[field] = item.get(field)
	return d


static func item_from_dict(d: Dictionary) -> Item:
	var item := Item.new()
	for field: String in ITEM_FIELDS:
		if d.has(field):
			item.set(field, d[field])
	return item


## Estado actual de CharacterProfile + inventario como diccionario (testeable sin tocar disco).
static func snapshot() -> Dictionary:
	var armor := {}
	for slot: String in CharacterProfile.armor:
		armor[slot] = item_to_dict(CharacterProfile.armor[slot])
	var bag := []
	for item: Item in CharacterProfile.bag:
		bag.append(item_to_dict(item))
	var floors := {}
	for key in CharacterProfile.floor_saves:
		floors[str(key)] = CharacterProfile.floor_saves[key]
	return {
		"version": VERSION,
		"player_name": CharacterProfile.player_name, "class_id": String(CharacterProfile.class_id),
		"appearance": CharacterProfile.appearance, "level": CharacterProfile.level, "xp": CharacterProfile.xp,
		"materials": Materials.inventory, "bag": bag, "armor": armor,
		"weapon": item_to_dict(CharacterProfile.weapon) if CharacterProfile.weapon != null else {},
		"floors": floors, "current_floor": CharacterProfile.current_floor, "max_floor": CharacterProfile.max_floor,
		"started": CharacterProfile.started,
	}


static func apply(data: Dictionary) -> void:
	CharacterProfile.player_name = String(data.get("player_name", "Héroe"))
	CharacterProfile.class_id = StringName(String(data.get("class_id", "warrior")))
	CharacterProfile.appearance = data.get("appearance", {})
	CharacterProfile.level = int(data.get("level", 1))
	CharacterProfile.xp = int(data.get("xp", 0))
	Materials.inventory = {}
	var mats: Dictionary = data.get("materials", {})
	for id: String in mats:
		Materials.inventory[id] = int(mats[id])
	CharacterProfile.bag = []
	for d: Dictionary in data.get("bag", []):
		CharacterProfile.bag.append(item_from_dict(d))
	CharacterProfile.armor = {}
	var armor: Dictionary = data.get("armor", {})
	for slot: String in armor:
		CharacterProfile.armor[slot] = item_from_dict(armor[slot])
	var weapon: Dictionary = data.get("weapon", {})
	CharacterProfile.weapon = item_from_dict(weapon) if not weapon.is_empty() else null
	CharacterProfile.floor_saves = {}
	var floors: Dictionary = data.get("floors", {})
	for key: String in floors:
		var f: Dictionary = floors[key]
		CharacterProfile.floor_saves[int(key)] = {
			"seed": int(f.get("seed", 1)), "dead": _ints(f.get("dead", [])), "gathered": _ints(f.get("gathered", [])), "done": bool(f.get("done", false)),
			"mission_state": f.get("mission_state", {}), "rewarded": bool(f.get("rewarded", false)),
		}
	CharacterProfile.current_floor = int(data.get("current_floor", 1))
	CharacterProfile.max_floor = int(data.get("max_floor", 1))
	CharacterProfile.started = bool(data.get("started", false))
	CharacterProfile.chosen = true


static func _ints(values: Array) -> Array:
	var out: Array = []
	for v in values:
		out.append(int(v))
	return out


static func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(snapshot(), "\t"))


## Devuelve true si había partida y se cargó.
static func load_game() -> bool:
	if not exists():
		return false
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return false
	apply(parsed)
	return true


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	CharacterProfile.reset()
	Materials.inventory = {}
