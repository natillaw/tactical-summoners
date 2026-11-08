## Progression — nivel y experiencia (1–60, como WoW Classic) y stats base.
class_name Progression
extends RefCounted

signal leveled_up(new_level: int)

const MAX_LEVEL := 60

var level: int = 1
var xp: int = 0


static func xp_to_next(lvl: int) -> int:
	return 60 + 30 * lvl + 2 * lvl * lvl


## Fuerza base: 20 en nivel 1, ~166 en nivel 60.
static func strength_for(lvl: int) -> float:
	return 20.0 + 2.5 * (lvl - 1)


## Vida base: 300 en nivel 1, ~4500 en nivel 60.
static func health_for(lvl: int) -> float:
	return 300.0 + 71.0 * (lvl - 1)


func add_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		leveled_up.emit(level)
	if level >= MAX_LEVEL:
		xp = 0


func set_level(lvl: int) -> void:
	level = clampi(lvl, 1, MAX_LEVEL)
	xp = 0
	leveled_up.emit(level)
