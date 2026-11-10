## SkillIcons — icono por habilidad (assets/ui/skills/<clase>_<id>.png), con caché.
class_name HeroSkillIcons
extends RefCounted

static var _cache: Dictionary = {}


static func get_icon(class_id: StringName, ability_id: String) -> Texture2D:
	var path := "res://assets/ui/skills/%s_%s.png" % [class_id, ability_id]
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]
