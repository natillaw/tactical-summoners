class_name MasterDefs
extends RefCounted
## D-080: the Master, the player's own character. A HeroData with is_master = true, made once in the
## character creator (MasterCreator) and the only hero the player drives in an expedition. The other
## heroes of the party act on their own. Every number here is a tuning placeholder.

## Debug only: brings back 1-5 to switch the driven hero (D-053) when the squad has a Master.
const DEBUG_HERO_SWITCH := false

## Rank of a mid rarity summon (HeroTables.STAR_DATA): same stats, level cap and promotions as any 3-star.
const STARS := 3
const NAME_MAX := 16
## Background: fixed, shown as text (the Spanish lives in StringsEs).
const BACKGROUND_ID := "bg.old_master"
const BACKGROUND_TITLE := "Former Master"
const BACKGROUND_TEXT := "Once the circle answered only to you. You lost it all, and now you begin again."
## The Master leads, so Trust and Obedience are full (D-051 never refuses the Master).
const TRUST := 100
const OBEDIENCE := 100

## Races the creator offers (LpcWardrobe looks; elves add elven ears). LpcRaces stays for enemies.
const RACES := ["human", "elf"]
const BODIES := ["male", "female"]
const BEARDS := ["", "beard_trimmed"]          # male bodies only, like the summoned
## Classes the creator offers, with the role shown (tank / damage / support / scout).
const CLASSES := {
    "class.warrior": {"role": "Tank", "text": "Holds the front line and takes the blows meant for the others."},
    "class.rogue": {"role": "Scout", "text": "Fast and light: finds the way, strikes first and gets out."},
    "class.ranger": {"role": "Damage", "text": "Fights from a distance and picks off what threatens the squad."},
    "class.mage": {"role": "Damage", "text": "Fragile, but its spells hit the hardest of all."},
    "class.cleric": {"role": "Support", "text": "Keeps the squad standing with healing and protection."},
    "class.commoner": {"role": "Damage", "text": "No training, no limits: a bit of everything, eager to learn."},
}

## Wounded Master (D-080): the Master never dies. If the agony runs out or the squad leaves without them,
## the expedition fails and the Master comes home with this disease (EconomyDefs.DISEASES).
const WOUND_DISEASE := "master_wounded"
