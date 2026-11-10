## EnemyArchetypes — tipos de enemigo basados en las clases, con personalidad propia.
##
## Cada arquetipo es una clase + dificultad + rasgos de comportamiento (ver BotBrain):
##  guard/bait/punish: bloquea, no golpea contra tu guardia y castiga tus aperturas.
##  flank: rodea hasta tu espalda cuando hay un aliado peleando contigo.
## `mods` son multiplicadores de balance propios (vida, poise...), `level_bonus` suma niveles.
class_name EnemyArchetypes
extends RefCounted

const TYPES := {
	"soldado": {
		"name": "Soldado de Guardia", "class": &"warrior", "difficulty": 0.45, "aggression": 0.7,
		"level_bonus": 0, "traits": ["guard"], "mods": {},
		"description": "Bloquea cuando ve tu golpe, pero reacciona despacio: castiga sus errores.",
	},
	"campeon": {
		"name": "Campeón", "class": &"warrior", "difficulty": 0.9, "aggression": 0.8,
		"level_bonus": 2, "traits": ["guard", "bait", "punish"], "mods": {"health_mult": 1.5, "armor_mult": 1.6},
		"description": "Lee tus ataques y los bloquea en el timing perfecto, se queda esperando si bloqueas y aprovecha cada stagger. Mucho poise.",
	},
	"duelista": {
		"name": "Duelista", "class": &"rogue", "difficulty": 0.7, "aggression": 1.0,
		"level_bonus": 1, "traits": ["flank", "punish"], "mods": {"damage_mult": 0.9},
		"description": "Rápido y frágil: rueda para esquivar, te rodea hasta la espalda y te aturde.",
	},
	"hechicero": {
		"name": "Hechicero", "class": &"mage", "difficulty": 0.65, "aggression": 0.55,
		"level_bonus": 1, "traits": ["kite"], "mods": {"health_mult": 1.1},
		"description": "Se mantiene lejos, te silencia, te arrastra y se protege con su escudo de maná si te acercas.",
	},
	"cazador": {
		"name": "Cazador", "class": &"ranger", "difficulty": 0.65, "aggression": 0.6,
		"level_bonus": 1, "traits": ["kite"], "mods": {},
		"description": "Dispara a distancia, escapa con su salto y te aparta de una patada si te pegas.",
	},
}


static func ids() -> Array:
	return TYPES.keys()


static func random_id(rng: RandomNumberGenerator) -> String:
	var all := ids()
	return String(all[rng.randi() % all.size()])


static func data(id: String) -> Dictionary:
	return TYPES.get(id, {})
