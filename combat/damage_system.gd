## DamageSystem — único sitio donde se calcula y mitiga el daño.
##
## Todas las clases y enemigos pasan por aquí: tipo de daño, crítico y
## resistencias. Un kit solo declara `"damage_type"` en su skill (por defecto
## físico); añadir un tipo nuevo es añadir una fila a TYPES.
class_name DamageSystem
extends RefCounted

enum Type { PHYSICAL, MAGIC, FIRE, FROST, POISON, HOLY, SHADOW, ARCANE }

## Nombre visible, color de número flotante y si ignora la armadura (reservado).
const TYPES := {
	Type.PHYSICAL: {"name": "Físico", "color": Color(1.0, 0.72, 0.35)},
	Type.MAGIC: {"name": "Mágico", "color": Color(0.7, 0.55, 1.0)},
	Type.FIRE: {"name": "Fuego", "color": Color(1.0, 0.45, 0.15)},
	Type.FROST: {"name": "Hielo", "color": Color(0.6, 0.85, 1.0)},
	Type.POISON: {"name": "Veneno", "color": Color(0.5, 0.9, 0.3)},
	Type.HOLY: {"name": "Sagrado", "color": Color(1.0, 0.95, 0.6)},
	Type.SHADOW: {"name": "Sombra", "color": Color(0.55, 0.3, 0.7)},
	Type.ARCANE: {"name": "Arcano", "color": Color(0.78, 0.5, 1.0)},
}
const KEY := "damage_type"
const CRIT_MULTIPLIER := 2.0  # como WoW Classic


## Tipo de una skill o de un diccionario de efectos (físico si no lo dice).
static func type_of(data: Dictionary) -> int:
	return int(data.get(KEY, Type.PHYSICAL))


static func color_of(type: int) -> Color:
	return TYPES.get(type, TYPES[Type.PHYSICAL])["color"]


## Tirada de un golpe: base · multiplicador, con crítico. Devuelve {amount, critical, type}.
static func roll(base: float, mult: float, crit_chance: float, type: int, rng: RandomNumberGenerator) -> Dictionary:
	var amount := base * mult
	var critical := rng.randf() < crit_chance
	if critical:
		amount *= CRIT_MULTIPLIER
	return {"amount": amount, "critical": critical, "type": type}


## Aplica las resistencias del objetivo (`resist`: tipo → fracción, 0.25 = -25 %;
## negativo = vulnerable). Tope 90 % para que nada sea inmune por accidente.
static func mitigate(amount: float, type: int, resist: Dictionary) -> float:
	var r := clampf(float(resist.get(type, 0.0)), -1.0, 0.9)
	return amount * (1.0 - r)
