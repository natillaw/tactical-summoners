class_name ItemVisuals
extends RefCounted
## Overhaul LPC phase 5 (D-D): what an equipped item looks like on the hero. Each ItemDefs base maps to
## an imported LPC piece (tools/lpc_manifest.json); metal pieces take the colour of the item's tier
## material (copper, iron, steel, silver, gold by item level), so a copper mail shirt looks copper.
## The equipped item replaces the layer of its slot; the saved base look never changes. Bases with no
## LPC piece (rings, amulets, trinkets, shields for now) show only their icon.

## base -> [slot used by LpcWardrobe, piece, colour rule] ; rule "metal" = by item level, else a fixed variant.
const BY_BASE := {
    "sword": ["main_hand", "weapon_arming", "default"],
    "greataxe": ["main_hand", "weapon_waraxe", "default"],
    "dagger": ["main_hand", "weapon_dagger", "default"],
    "mace": ["main_hand", "weapon_mace", "default"],
    "bow": ["main_hand", "weapon_bow", "default"],
    "staff": ["main_hand", "weapon_staff", "default"],
    "wand": ["main_hand", "weapon_wand", "default"],
    "helm": ["head", "helmet_barbuta", "metal"],
    "hood": ["head", "hood", "forest"],
    "mail": ["chest", "chainmail", "metal"],
    "robe": ["chest", "shirt_longsleeve", "navy"],
    "gloves": ["hands", "gloves", "metal"],
    "greaves": ["legs", "legs_plate", "metal"],
    "boots": ["feet", "boots_basic", "leather"],
}
## Item level -> metal (tiers of D-077: copper/iron 1-10, steel 11-20, silver 21-30, gold 31+).
const METAL_BY_ILVL := [[5, "copper"], [10, "iron"], [20, "steel"], [30, "silver"], [9999, "gold"]]


static func metal_for(ilvl: int) -> String:
    for m in METAL_BY_ILVL:
        if ilvl <= int(m[0]):
            return String(m[1])
    return "gold"


## [piece, variant] for one item, or [] when it has no LPC look.
static func layer_for(item: Dictionary) -> Array:
    var v: Array = BY_BASE.get(String(item.get("visual_base", item.get("base", ""))), [])
    if v.is_empty():
        return []
    var variant := String(v[2])
    if variant == "metal":
        variant = String(item.get("metal", metal_for(int(item.get("ilvl", 1)))))
    return [v[1], variant]


## LpcWardrobe equipment dict (slot -> [piece, variant]) from a hero's equipped items.
static func equipment_layers(equipment: Dictionary) -> Dictionary:
    var out := {}
    for slot in equipment:
        var it = equipment[slot]
        if not (it is Dictionary):
            continue
        var lay := layer_for(it)
        if not lay.is_empty():
            out[String(BY_BASE[String((it as Dictionary).get("visual_base", it.get("base", "")))][0])] = lay
    return out
