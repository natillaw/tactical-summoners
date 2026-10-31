class_name EconomyDefs
extends RefCounted
## Town economy as data: resources, recipes (gathering and crafting), diseases, needs and time.
## The simulation that uses it is TownSim; the state lives in Game. Numbers are tuning placeholders.

# --- time (D-047) -----------------------------------------------------------------------------
const REAL_SECONDS_PER_HOUR := 30.0    # while the player is in the town
const HOURS_PER_EXPEDITION := 24       # every floor attempt moves the town one day
const NIGHT_START := 22
const NIGHT_END := 6

# --- needs (0 = fine, 100 = critical) -----------------------------------------------------------
const HUNGER_EAT := 55                 # goes to eat at or above this
const FATIGUE_SLEEP := 85              # goes to bed at or above this, even by day
const STRESS_SOCIAL := 55              # seeks the tavern at or above this
const NEED_DELTA := {                  # per hour: [hunger, fatigue, stress]
    "working": [3, 4, 0], "idle": [2, -3, -1], "sleeping": [1, -12, -1], "eating": [-60, 0, -2],
    "socializing": [2, 0, -10], "in_treatment": [1, -6, -1], "deployed": [0, 0, 0],
}
const ROUGH_SLEEP_FATIGUE := -6        # no bed: sleeps on the floor
const ROUGH_SLEEP_STRESS := 2
const STARVING_STRESS := 3

# --- storage -------------------------------------------------------------------------------------
const STORAGE_BASE := 150              # per resource, + STORAGE_PER_LEVEL per warehouse level
const STORAGE_PER_LEVEL := 150
const STASH_BASE := 12                 # equipment slots in the stash, + per warehouse level
const STASH_PER_LEVEL := 8
const RESOURCES := {
    "materials": {"name": "Building materials", "cat": "processed"},
    "food": {"name": "Meals", "cat": "consumable"},
    "grain": {"name": "Grain", "cat": "basic"},
    "herb": {"name": "Herbs", "cat": "basic"},
    "wood": {"name": "Wood", "cat": "basic"},
    "stone": {"name": "Stone", "cat": "basic"},
    "ore": {"name": "Ore", "cat": "basic"},
    "ingot": {"name": "Iron ingots", "cat": "processed"},
    "medicine": {"name": "Medicine", "cat": "consumable"},
    "potion": {"name": "Healing potions", "cat": "consumable"},
    "antidote": {"name": "Antidotes", "cat": "consumable"},
    # creature drops (EnemyDefs "drops"): crafting and ascension materials from the tower
    "hide": {"name": "Beast hide", "cat": "drop"},
    "fang": {"name": "Fangs", "cat": "drop"},
    "gel": {"name": "Slime gel", "cat": "drop"},
    "spore": {"name": "Spores", "cat": "drop"},
    "silk": {"name": "Spider silk", "cat": "drop"},
    "venom": {"name": "Venom sacs", "cat": "drop"},
    "bone": {"name": "Bones", "cat": "drop"},
    "core": {"name": "Golem core", "cat": "drop"},
}

## Gathering spots in tower floors (ProceduralMap v2 "nodes"): what a hero collects in GATHER_TIME.
const GATHER_TIME := 1.5
const NODES := {
    "ore": {"name": "Ore vein", "res": {"ore": [2, 4], "stone": [1, 2]}, "color": Color(0.55, 0.6, 0.75)},
    "wood": {"name": "Fallen timber", "res": {"wood": [3, 5]}, "color": Color(0.6, 0.42, 0.25)},
    "herb": {"name": "Herb patch", "res": {"herb": [2, 4]}, "color": Color(0.45, 0.85, 0.4)},
}

# --- recipes -------------------------------------------------------------------------------------
## work = hours of a 1.0-efficiency worker per batch. Inputs are taken when a batch STARTS (so the same
## material can never be used twice) and outputs land when it ends. item = crafted equipment kind.
const RECIPES := {
    "grow_grain": {"name": "Grow grain", "building": "farm", "prof": "farmer", "min": 0, "work": 2.0, "in": {}, "out": {"grain": 3}},
    "grow_herbs": {"name": "Grow herbs", "building": "farm", "prof": "farmer", "min": 1, "work": 3.0, "in": {}, "out": {"herb": 2}},
    "fell_wood": {"name": "Fell trees", "building": "lumber_camp", "prof": "lumberjack", "min": 0, "work": 2.0, "in": {}, "out": {"wood": 3}},
    "dig_stone": {"name": "Quarry stone", "building": "mine", "prof": "miner", "min": 0, "work": 2.0, "in": {}, "out": {"stone": 3}},
    "dig_ore": {"name": "Dig ore", "building": "mine", "prof": "miner", "min": 0, "work": 3.0, "in": {}, "out": {"ore": 2}},
    "cook_meal": {"name": "Cook meals", "building": "kitchen", "prof": "cook", "min": 0, "work": 2.0, "in": {"grain": 2}, "out": {"food": 4}},
    "make_materials": {"name": "Shape materials", "building": "workshop", "prof": "carpenter", "min": 0, "work": 3.0, "in": {"wood": 2, "stone": 1}, "out": {"materials": 6}},
    "smelt_iron": {"name": "Smelt iron", "building": "blacksmith", "prof": "blacksmith", "min": 0, "work": 3.0, "in": {"ore": 2}, "out": {"ingot": 1}},
    "forge_weapon": {"name": "Forge a weapon", "building": "blacksmith", "prof": "blacksmith", "min": 1, "work": 8.0, "in": {"ingot": 3, "wood": 1}, "out": {}, "item": "weapon"},
    "forge_armor": {"name": "Forge armor", "building": "blacksmith", "prof": "blacksmith", "min": 2, "work": 8.0, "in": {"ingot": 4}, "out": {}, "item": "armor"},
    "brew_medicine": {"name": "Brew medicine", "building": "alchemy", "prof": "alchemist", "min": 0, "work": 3.0, "in": {"herb": 2}, "out": {"medicine": 1}},
    "brew_potion": {"name": "Brew healing potions", "building": "alchemy", "prof": "alchemist", "min": 1, "work": 4.0, "in": {"herb": 2, "grain": 1}, "out": {"potion": 1}},
    "brew_antidote": {"name": "Brew antidotes", "building": "alchemy", "prof": "alchemist", "min": 1, "work": 4.0, "in": {"herb": 3}, "out": {"antidote": 1}},
    "treat": {"name": "Treat patients", "building": "infirmary", "prof": "doctor", "min": 0, "work": 0.0, "in": {}, "out": {}, "service": true},
    "serve": {"name": "Run the tavern", "building": "common", "prof": "tavernkeeper", "min": 0, "work": 0.0, "in": {}, "out": {}, "service": true},
}

# --- construction (D-048) ------------------------------------------------------------------------
const BUILD_HOURS_PER_LEVEL := 6.0    # hours of a 1.0-efficiency builder per target level

# --- diseases (persistent; affect attributes, so they reach combat) --------------------------------
## hours = natural course; natural = heals with rest alone; treat_rate = hours removed per treated hour
## (x doctor efficiency); medicine = units used per 24 h of treatment (resource id); mods = attribute
## multipliers; work = work efficiency multiplier; contagion = daily chance per dorm mate.
const DISEASES := {
    "infected_wound": {"name": "Infected wound", "severity": 2, "hours": 96, "natural": false, "treat_rate": 4.0, "medicine": "medicine",
        "mods": {"vit": 0.85, "fue": 0.9}, "work": 0.7, "contagion": 0.0,
        "desc": "From being downed in the tower. Does not heal on its own: needs a doctor and medicine."},
    "marsh_fever": {"name": "Marsh fever", "severity": 1, "hours": 72, "natural": true, "treat_rate": 3.0, "medicine": "medicine",
        "mods": {"agi": 0.9, "tem": 0.9}, "work": 0.8, "contagion": 0.0,
        "desc": "Caught in the wet forest floors. Passes with rest; a doctor shortens it."},
    "toxin": {"name": "Lingering toxin", "severity": 1, "hours": 60, "natural": true, "treat_rate": 6.0, "medicine": "antidote",
        "mods": {"fue": 0.9, "vit": 0.9}, "work": 0.85, "contagion": 0.0,
        "desc": "Poison that stayed in the blood. An antidote clears it fast."},
    "cave_cough": {"name": "Cave cough", "severity": 1, "hours": 120, "natural": true, "treat_rate": 3.0, "medicine": "medicine",
        "mods": {"tem": 0.85}, "work": 0.8, "contagion": 0.06,
        "desc": "Damp air of the deeper floors. Spreads to dorm mates."},
    "exhaustion": {"name": "Exhaustion", "severity": 1, "hours": 36, "natural": true, "treat_rate": 1.0, "medicine": "",
        "mods": {"fue": 0.9, "agi": 0.9}, "work": 0.6, "contagion": 0.0,
        "desc": "Worked to the bone. Only sleep cures it."},
}
## Chances when a hero comes back from the tower (deterministic rolls on Game.rng).
const DISEASE_CHANCE := {"downed": 0.6, "poisoned": 0.35, "forest": 0.06, "deep": 0.05}
const EXHAUSTION_HOURS := 12          # hours at fatigue 100 before exhaustion sets in

# --- expeditions -----------------------------------------------------------------------------------
const AFTER_MISSION := {"hunger": 25, "fatigue": 35, "stress": 10, "stress_death": 25}
