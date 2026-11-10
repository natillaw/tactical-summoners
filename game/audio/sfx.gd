## Sfx — biblioteca de efectos de sonido por categoría ("hit", "slash", "ui_click"...).
## Cada categoría tiene 1+ variantes en assets/audio/sfx/game/<categoria>_<n>.wav (ver CATALOG.json).
## `Sfx.get_stream(cat)` elige una variante al azar; Arena3D.play_sfx acepta el nombre directamente.
class_name Sfx
extends RefCounted

const DIR := "res://assets/audio/sfx/game/"
const COUNTS := {
	"slash": 5, "slash_heavy": 3, "hit": 5, "hit_heavy": 4, "hurt": 4, "grunt": 5, "death": 2, "magic": 3,
	"fire": 1, "ice": 1, "thunder": 1, "earth": 1, "wind": 1, "poison": 1, "water": 1, "buff": 2, "heal": 1,
	"absorb": 1, "debuff": 1, "parry": 4, "block": 4, "roll": 2, "evade": 1, "teleport": 1, "charge": 1, "slam": 2,
	"step_grass": 5, "step_wood": 5, "step_stone": 5, "ui_hover": 1, "ui_confirm": 1, "ui_decline": 1,
	"ui_denied": 1, "ui_open": 1, "ui_close": 1, "ui_click": 2, "use_item": 1, "equip": 2, "unequip": 1, "buy": 1,
	"craft_weapon": 2, "craft_potion": 3, "craft_armor": 3, "drink": 1, "gather_ore": 3, "gather_herb": 2,
	"gather_wood": 2, "gather_misc": 2, "coin": 3, "door_open": 2, "door_close": 1, "portal": 1, "levelup": 1,
	"quest_done": 1, "alert": 1, "npc_talk": 3, "ambient_wind": 1, "beast": 4, "shade": 3, "slime": 3, "ogre": 3,
}
static var _cache: Dictionary = {}


static func get_stream(category: StringName) -> AudioStream:
	var count := int(COUNTS.get(String(category), 0))
	if count == 0:
		return null
	var n := randi() % count
	var path := "%s%s_%d.wav" % [DIR, category, n]
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


## Variante en bucle (ambientes).
static func loop_stream(category: StringName) -> AudioStreamWAV:
	var base := load("%s%s_0.wav" % [DIR, category]) as AudioStreamWAV
	if base == null:
		return null
	var looped := base.duplicate() as AudioStreamWAV
	var bytes_per_sample := (2 if looped.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if looped.stereo else 1)
	looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
	looped.loop_begin = 0
	looped.loop_end = looped.data.size() / bytes_per_sample
	return looped


## Sonidos de interfaz para un control (hover y clic) y sus hijos Button.
static func wire_buttons(root: Node, arena_player: Callable) -> void:
	for child in root.find_children("*", "BaseButton", true, false):
		var b := child as BaseButton
		if b.has_meta("sfx_wired"):
			continue
		b.set_meta("sfx_wired", true)
		b.mouse_entered.connect(func() -> void: arena_player.call(&"ui_hover", -16.0))
		b.pressed.connect(func() -> void: arena_player.call(&"ui_click", -8.0))
