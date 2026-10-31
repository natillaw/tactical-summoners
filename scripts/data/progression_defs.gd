class_name ProgressionDefs
extends RefCounted
## Hero progression of the vertical slice (data, tuning placeholders): expedition experience and MVP,
## ascension (promotion) at the Sanctuary of Ascension, and skill training at the Training Grounds.

# --- expedition experience (ExpeditionResults) ---------------------------------------------------
## Completion XP for every surviving hero: COMPLETE_BASE + COMPLETE_PER_FLOOR x floor (success only).
const COMPLETE_BASE := 80
const COMPLETE_PER_FLOOR := 60
## The creatures' worth (EnemyDefs.XP_PER_HP x max HP, summed) is shared by the survivors: SHARE_FLAT of
## it equally, the rest by contribution. An escape keeps this part (no completion, no MVP).
const SHARE_FLAT := 0.6
## MVP bonus = what the MVP still needs for its next level (one level's worth on the XP curve), capped
## so a high level never gets a huge lump: never more than MVP_CAP_MULT x the completion XP.
const MVP_CAP_MULT := 3.0
## Contribution weights (each category normalised by the squad total, so a healer can top a fighter).
const CONTRIB_WEIGHTS := {"damage": 1.0, "kills": 0.6, "healing": 1.0, "shield": 0.6, "rescues": 0.8,
    "explored": 0.7, "objective": 1.0, "gathered": 0.4, "tanked": 0.5}
const CONTRIB_LABELS := {"damage": "dealt the most damage", "kills": "struck the final blows", "healing": "kept the squad alive",
    "shield": "shielded the squad", "rescues": "carried the fallen back", "explored": "scouted the way",
    "objective": "carried the mission", "gathered": "gathered for the town", "tanked": "took the blows for the others"}

# --- ascension (promotion) -----------------------------------------------------------------------
## Materials per target star (tower drops make the player explore and hunt specific creatures).
const ASCENSION_COST := {
    2: {"materials": 30, "hide": 4, "gel": 3, "silk": 2},
    3: {"materials": 80, "bone": 6, "spore": 4, "venom": 3, "ingot": 2},
    4: {"materials": 160, "core": 2, "bone": 10, "silk": 6, "ingot": 6},
    5: {"materials": 300, "core": 5, "venom": 10, "ingot": 12},
}
const ASCENSION_BASE := 0.5          # base chance
const ASCENSION_PER_LUCK := 0.03     # luck 1..10
const ASCENSION_PER_SANCTUARY := 0.04  # per sanctuary level above 1
const ASCENSION_PITY_STEP := 0.15    # each failure adds this to the next try
const ASCENSION_PITY_HARD := 3       # after this many failures in a row the next try cannot fail
const ASCENSION_FAIL_KEEP := 0.5     # a failure gives back this fraction of the tower materials (never the hero's level)

# --- training (Training Grounds) ------------------------------------------------------------------
## A hero of 2+ stars may train (stars - 1) extra class skills; each time it chooses 1 of up to 3.
const TRAIN_MIN_STARS := 2
const TRAIN_OPTIONS := 3
const TRAIN_COST := {"materials": 25, "ingot": 1}


# --- synthesis and sacrifice (D-061; provisional numbers, G-21 / G-22) --------------------------------
const SYNTH_EFFICIENCY := 0.30        # share of the sources' total experience the target receives
const SYNTH_SAME_CLASS := 0.40        # ... when the source is of the target's class
const SYNTH_MAX_SOURCES := 3
const SYNTH_ATTR_BONUS := 1           # +1 permanent to the source's best attribute (same class only)
## Sacrifice: materials by stars, plus a class flavour.
const SACRIFICE := {
    1: {"materials": 15, "hide": 1},
    2: {"materials": 35, "bone": 2, "silk": 1},
    3: {"materials": 70, "bone": 3, "core": 1},
    4: {"materials": 120, "core": 2, "venom": 3},
    5: {"materials": 200, "core": 3, "ingot": 5},
}
const SACRIFICE_CLASS := {"class.warrior": {"bone": 1}, "class.rogue": {"venom": 1}, "class.ranger": {"silk": 1},
    "class.mage": {"spore": 2}, "class.cleric": {"herb": 2}, "class.commoner": {"materials": 5}, "class.none": {"materials": 5}}
