## EnemyArchetypes — tipos de enemigo basados en las clases, con personalidad propia.
##
## Cada arquetipo es una clase + dificultad + rasgos de comportamiento (ver BotBrain):
##  guard/bait/punish: bloquea, no golpea contra tu guardia y castiga tus aperturas.
##  flank: rodea hasta tu espalda cuando hay un aliado peleando contigo.
## `mods` son multiplicadores de balance propios (vida, armadura...), `level_bonus` suma niveles.
class_name EnemyArchetypes
extends RefCounted

const TYPES := {
	"soldado": {
		"tier": "elite",
		"name": "Soldado de Guardia", "class": &"warrior", "difficulty": 0.45, "aggression": 0.7,
		"level_bonus": 0, "traits": ["guard"], "mods": {},
		"description": "Bloquea cuando ve tu golpe, pero reacciona despacio: castiga sus errores.",
	},
	"campeon": {
		"tier": "elite",
		"name": "Campeón", "class": &"warrior", "difficulty": 0.9, "aggression": 0.8,
		"level_bonus": 1, "traits": ["guard", "bait", "punish"], "mods": {"health_mult": 1.4, "armor_mult": 1.6},
		"description": "Lee tus ataques y los bloquea en el timing perfecto, se queda esperando si bloqueas y castiga cada aturdimiento. Mucha armadura.",
	},
	"duelista": {
		"tier": "elite",
		"name": "Duelista", "class": &"rogue", "difficulty": 0.7, "aggression": 1.0,
		"level_bonus": 1, "traits": ["flank", "punish"], "mods": {"damage_mult": 0.9},
		"description": "Rápido y frágil: rueda para esquivar, te rodea hasta la espalda y te aturde.",
	},
	"hechicero": {
		"tier": "elite",
		"name": "Hechicero", "class": &"mage", "difficulty": 0.65, "aggression": 0.55,
		"level_bonus": 1, "traits": ["kite"], "mods": {"health_mult": 1.1},
		"description": "Se mantiene lejos, te silencia, te arrastra y se protege con su escudo de maná si te acercas.",
	},
	"esbirro": {
		"tier": "minion", "skills": ["SHIFT"],
		"name": "Esbirro", "class": &"warrior", "difficulty": 0.3, "aggression": 0.9,
		"level_bonus": 0, "traits": ["dumb"], "mods": {"armor_mult": 0.5},
		"description": "Débil pero aparece en grupo de 4: obliga a usar skills de área y a no quedarse quieto.",
	},
	"guardian": {
		"tier": "elite",
		"name": "Guardián", "class": &"warrior", "difficulty": 0.6, "aggression": 0.5,
		"level_bonus": 1, "traits": ["guard", "shield"], "mods": {"armor_mult": 1.4},
		"description": "Mantiene el escudo en alto: de frente bloquea el 80% del daño físico. Hay que rodearlo, aturdirlo o usar magia.",
	},
	"coloso": {
		"tier": "boss",
		"name": "Coloso", "class": &"warrior", "difficulty": 0.8, "aggression": 0.7,
		"level_bonus": 1, "traits": ["guard", "punish"], "mods": {"armor_mult": 2.0, "cc_scale": 0.35},
		"description": "Jefe: muchísima vida y armadura, resiste el control (stun/atadura/silencio duran un tercio). La magia ignora su armadura.",
	},
	"esbirro_arquero": {
		"name": "Esbirro Arquero", "class": &"ranger", "difficulty": 0.25, "aggression": 0.7, "tier": "minion", "skills": [],
		"level_bonus": 0, "traits": ["dumb"], "mods": {"health_mult": 0.85, "armor_mult": 0.4},
		"description": "Solo dispara flechas sueltas; no esquiva ni se reposiciona.",
	},
	"esbirro_mago": {
		"name": "Esbirro Aprendiz", "class": &"mage", "difficulty": 0.25, "aggression": 0.6, "tier": "minion", "skills": ["Q"],
		"level_bonus": 0, "traits": ["dumb"], "mods": {"health_mult": 0.85, "armor_mult": 0.4},
		"description": "Lanza un proyectil arcano y poco más; no se protege.",
	},
	"cazador": {
		"tier": "elite",
		"name": "Cazador", "class": &"ranger", "difficulty": 0.65, "aggression": 0.6,
		"level_bonus": 1, "traits": ["kite"], "mods": {},
		"description": "Dispara a distancia, escapa con su salto y te aparta de una patada si te pegas.",
	},
}


## --- Fórmula de escalado por piso (única fuente de verdad; ver docs/DECISIONES.md) ---
## Un enemigo es un combatiente de su clase con nivel = piso (+ `level_bonus`), así que su vida y su daño
## base ya crecen con el nivel igual que los del jugador. Encima se aplica, por tier:
##   vida  = vida_de_clase(nivel)  × TIER[tier].health ÷ (1 + HEALTH_EASE × (piso − 1)) × mods del arquetipo
##           (el nivel del enemigo sube 1 por piso y el del jugador más despacio: sin el divisor, matar a un
##            esbirro pasaba de 4 golpes en el piso 1 a 8 en el 10; con él se queda en 4-5)
##   daño  = daño_de_clase(nivel)  × TIER[tier].damage × (1 + DAMAGE_GROWTH × (piso − 1)) × mods del arquetipo
##   windup de sus ataques × TIER[tier].windup (telegraph legible; el jugador no lo sufre)
## Esbirro = 2-4 golpes del jugador y pega flojo; élite = duelo corto; jefe = pelea larga con fases.
const TIER := {
	"minion": {"health": 0.20, "damage": 0.40, "windup": 2.0},
	"elite": {"health": 0.80, "damage": 0.60, "windup": 1.5},
	"boss": {"health": 2.00, "damage": 0.70, "windup": 1.7},
}
const HEALTH_EASE := 0.05
const DAMAGE_GROWTH := 0.05
## Fases de jefe: al bajar de estos umbrales de vida cambia de fase (2 y 3).
const BOSS_PHASES := [0.66, 0.33]
## Por fase (índice = fase − 1): daño, velocidad, cooldowns y esbirros que invoca al entrar.
const BOSS_PHASE_MODS := [
	{"damage": 1.0, "speed": 1.0, "cooldown": 1.0, "adds": 0},
	{"damage": 1.15, "speed": 1.08, "cooldown": 0.8, "adds": 2},
	{"damage": 1.3, "speed": 1.16, "cooldown": 0.65, "adds": 3},
]
## Aviso antes de que el jefe actúe al cambiar de fase (queda quieto y vulnerable: ventana de daño justa).
const BOSS_PHASE_PAUSE := 1.6


static func tier_of(id: String) -> String:
	return String(TYPES.get(id, {}).get("tier", "elite"))


## Multiplicadores de la fórmula para un arquetipo en un piso: {health_mult, damage_mult, windup_mult}.
static func floor_scale(id: String, floor_number: int) -> Dictionary:
	var base: Dictionary = TIER[tier_of(id)]
	var steps := float(maxi(floor_number, 1) - 1)
	return {
		"health_mult": float(base["health"]) / (1.0 + HEALTH_EASE * steps),
		"damage_mult": float(base["damage"]) * (1.0 + DAMAGE_GROWTH * steps),
		"windup_mult": float(base["windup"]),
	}


## Nº máximo de skills (además del básico) que puede usar un esbirro.
const MINION_MAX_SKILLS := 2


static func ids() -> Array:
	return TYPES.keys()


static func random_id(rng: RandomNumberGenerator) -> String:
	var all := ids()
	return String(all[rng.randi() % all.size()])


static func data(id: String) -> Dictionary:
	return TYPES.get(id, {})
