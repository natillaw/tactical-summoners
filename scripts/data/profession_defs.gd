class_name ProfessionDefs
extends RefCounted
## Town professions (D-049): every hero knows at most MAX_KNOWN professions, each with a level
## (0 = apprentice .. MAX_LEVEL) and experience. The past-life occupation becomes the first one, at
## PAST_LIFE_LEVEL and with "passion" (faster learning). Numbers are tuning placeholders.

const MAX_KNOWN := 2              # D-049: main + secondary
const MAX_LEVEL := 10
const PAST_LIFE_LEVEL := 2
const PASSION_XP := 1.5           # experience multiplier on the past-life profession
const APPRENTICE_EFF := 0.3       # level-0 efficiency

## attr = attribute that helps (+2% efficiency per point above 5).
const PROFESSIONS := {
    "builder": {"name": "Builder", "family": "craft", "attr": "fue", "desc": "Raises and upgrades buildings (D-048)."},
    "blacksmith": {"name": "Blacksmith", "family": "craft", "attr": "fue", "desc": "Smelts ore and forges weapons and armor."},
    "carpenter": {"name": "Carpenter", "family": "craft", "attr": "agi", "desc": "Turns wood and stone into building materials."},
    "miner": {"name": "Miner", "family": "gather", "attr": "fue", "desc": "Digs ore and stone."},
    "lumberjack": {"name": "Lumberjack", "family": "gather", "attr": "fue", "desc": "Fells trees for wood."},
    "farmer": {"name": "Farmer", "family": "gather", "attr": "vit", "desc": "Grows grain and herbs."},
    "cook": {"name": "Cook", "family": "service", "attr": "tem", "desc": "Turns grain into meals."},
    "alchemist": {"name": "Alchemist", "family": "medicine", "attr": "int", "desc": "Brews medicine, potions and antidotes."},
    "doctor": {"name": "Doctor", "family": "medicine", "attr": "int", "desc": "Treats diseases and wounds in the hospital."},
    "scholar": {"name": "Scholar", "family": "knowledge", "attr": "int", "desc": "Working in the Library makes skill-book transcription cheaper."},
    "tavernkeeper": {"name": "Tavern keeper", "family": "service", "attr": "tem", "desc": "Makes the tavern more relaxing."},
}

## Past-life occupation (HeroTables.PROFESSIONS) -> town profession it starts with.
const FROM_PAST_LIFE := {
    "occupation.builder": "builder", "occupation.mason": "builder", "occupation.engineer": "builder",
    "occupation.blacksmith": "blacksmith", "occupation.lumberjack": "lumberjack", "occupation.miner": "miner",
    "occupation.farmer": "farmer", "occupation.stablehand": "farmer", "occupation.chef": "cook",
    "occupation.fisher": "cook", "occupation.hunter": "cook", "occupation.alchemist": "alchemist",
    "occupation.medic": "doctor", "occupation.priest": "doctor", "occupation.scholar": "scholar",
    "occupation.entertainer": "tavernkeeper", "occupation.merchant": "tavernkeeper", "occupation.tailor": "carpenter",
    "occupation.guard": "builder", "occupation.scout": "lumberjack",
}


static func info(id: String) -> Dictionary:
    return PROFESSIONS.get(id, {})


static func xp_to_next(level: int) -> int:
    return 10 + 6 * level


## Work done per hour by a worker of this level (before health/fatigue).
static func efficiency(level: int) -> float:
    return APPRENTICE_EFF if level <= 0 else 0.5 + 0.1 * float(level)
