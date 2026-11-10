## ItemIcons — icono por id de material / consumible / receta / objeto (assets/ui/items/<id>.png).
class_name HeroItemIcons
extends RefCounted

static var _cache: Dictionary = {}


static func get_icon(id: String, slot: String = "") -> Texture2D:
	var path := "res://assets/ui/items/%s.png" % id
	if not ResourceLoader.exists(path) and id.ends_with("_g2"):
		path = "res://assets/ui/items/%s.png" % id.trim_suffix("_g2")  # sin icono propio: el del grado 1
	if not ResourceLoader.exists(path) and slot != "":
		path = "res://assets/ui/items/slot_%s.png" % slot  # piezas sin icono propio usan el de su ranura
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]
