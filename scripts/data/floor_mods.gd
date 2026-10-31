class_name FloorMods
extends RefCounted
## Master prompt D (2026-10-31): one modifier per floor from floor 3 (the floor's "modifier" in
## TowerExpedition.FLOORS). Numbers are playtest starting values.
##   fog     = the heroes see less (fog of war closes in)
##   hazard  = poisoned ground patches in some rooms (go around them)
##   enrage  = creatures hit harder once they drop under ENRAGE_BELOW health (finish them fast)
##   no_heal = no healing at all on the floor (spells, potions, regeneration)

const FOG_VISION := 3              # cells of sight lost
const HAZARD_ZONES := 7
const HAZARD_RADIUS := 70.0
const HAZARD_DUR := 2.0            # poison applied while standing in it
const HAZARD_MAG := 3.0
const ENRAGE_BELOW := 0.3
const ENRAGE_ATK := 1.5
