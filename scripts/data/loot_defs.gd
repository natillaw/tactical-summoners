class_name LootDefs
extends RefCounted
## Master prompt A (2026-10-31): loot of tower floors 1-10, in ONE table so it can be rebalanced here.
## Owner's answer on the prompt: floors drop only a few materials (rare ones), procedural gear (already
## Game.complete_floor) and rare things; the town's basic materials stay in the Wilds (D-066). Gems stay
## the summon currency. Prompt IDs mapped to the repo's where they clash (kept the repo id):
##   cur_mana_shard -> gems · mat_wild_herb -> herb · mat_old_bone -> bone · mat_worn_leather -> hide
##   mat_copper_ore -> ore · mat_weak_essence -> essence · key_guardian_core -> core
##   con_potion_minor -> potion. New ids keep the prompt's names (mat_*, key_*, con_*).
## Tiers: T1 floors 1-4, T2 floors 5-9, T3 floor 10.

## Per floor. drops = per creature killed {id: [chance, min, max]}; chest = mission chest (always
## something); boss = the miniboss/boss {id: [chance, min, max]}; first = only on the first clear.
## "first_chance" overrides a boss chance on the first clear (legendary fragment 2% -> 10%).
const FLOORS := {
    1: {"drops": {"essence": [0.04, 1, 1]}, "chest": {"essence": [1, 1], "potion": [1, 2]}},
    2: {"drops": {"essence": [0.04, 1, 1]}, "chest": {"essence": [1, 2], "potion": [1, 1]}},
    3: {"drops": {"essence": [0.05, 1, 1]}, "chest": {"essence": [2, 2]}},
    4: {"drops": {"essence": [0.06, 1, 1], "mat_enchanted_cloth": [0.03, 1, 1]}, "chest": {"essence": [2, 2], "mat_enchanted_cloth": [1, 1]}},
    5: {"drops": {"mat_enchanted_cloth": [0.12, 1, 1], "essence": [0.05, 1, 1]}, "chest": {"mat_enchanted_cloth": [3, 3], "essence": [2, 2]},
        "boss": {"core": [1.0, 1, 2]}, "first": {"key_floor5_seal": 1}},
    6: {"drops": {"mat_iron_ore": [0.15, 1, 1], "mat_enchanted_cloth": [0.05, 1, 1]}, "chest": {"mat_iron_ore": [4, 4]}},
    7: {"drops": {"mat_resonant_crystal": [0.10, 1, 1], "mat_iron_ore": [0.05, 1, 1]}, "chest": {"mat_resonant_crystal": [2, 2]}},
    8: {"drops": {"mat_moon_flower": [0.12, 1, 1], "mat_resonant_crystal": [0.03, 1, 1]}, "chest": {"mat_moon_flower": [3, 3]}},
    9: {"drops": {"mat_rune_plate": [0.08, 1, 1], "mat_moon_flower": [0.05, 1, 1]}, "chest": {"mat_rune_plate": [2, 2], "essence": [3, 3]}},
    10: {"drops": {"mat_rune_plate": [0.06, 1, 1]}, "chest": {"essence": [5, 5]},
        "boss": {"key_guardian_heart": [1.0, 1, 1], "key_legendary_fragment": [0.02, 1, 1]}, "first_chance": {"key_legendary_fragment": 0.10}},
}
## A replay's chest pays this fraction (at least 1 of each line): repeating is predictable but smaller.
const REPLAY_CHEST := 0.4

## New items: tier, stack cap and use. Their display names live in EconomyDefs.RESOURCES (cat "tower")
## like every other resource; the greater-potion recipe is in EconomyDefs.RECIPES. No sell prices: the
## owner kept gems and there is no gold yet.
const ITEMS := {
    "mat_enchanted_cloth": {"tier": 2, "stack": 99, "desc": "Accessories with a minor passive."},
    "mat_iron_ore": {"tier": 2, "stack": 99, "desc": "T2 gear."},
    "mat_resonant_crystal": {"tier": 2, "stack": 50, "desc": "Synthesis catalyst; enchanting T2."},
    "mat_moon_flower": {"tier": 2, "stack": 99, "desc": "Greater potions."},
    "mat_rune_plate": {"tier": 2, "stack": 50, "desc": "Portal upgrades."},
    "key_floor5_seal": {"tier": 2, "stack": 1, "desc": "Portal shortcut to floor 5 (never used up)."},
    "key_guardian_heart": {"tier": 3, "stack": 10, "desc": "Promotion 2★→3★ or an epic weapon."},
    "key_legendary_fragment": {"tier": 3, "stack": 10, "desc": "10 = a guaranteed Rare+ summon."},
    "con_potion_major": {"tier": 2, "stack": 20, "desc": "Heals 60% of a hero."},
}
