## ItemIcons — icono por id de material / consumible / receta / objeto (assets/ui/items/<id>.png).
class_name HeroItemIcons
extends RefCounted

static var _cache: Dictionary = {}


static func get_icon(id: String) -> Texture2D:
	var path := "res://assets/ui/items/%s.png" % id
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]
