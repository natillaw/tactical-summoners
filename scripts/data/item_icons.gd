class_name ItemIcons
extends RefCounted
## Which Caz MV icon (AssetCatalog.ITEM_ICONS: 16 columns of 32 px, row-major index) each item base and
## consumable shows. Picked by look: 19 sword, 20 round shield, 16 winged helm, 17 tunic, 33 plate,
## 48 wizard hat, 49 robe, 18 boots, 34 iron boots, 35 axe, 51 staff, 52 ring, 67 bow, 80/81 potions.

const BASES := {
    "sword": 19, "greataxe": 35, "dagger": 235, "mace": 51, "bow": 67, "staff": 51, "wand": 84,
    "shield": 20, "helm": 16, "hood": 48, "mail": 33, "robe": 49, "gloves": 66, "greaves": 34,
    "boots": 18, "ring": 52, "amulet": 237, "charm": 240,
}
const CONSUMABLES := {"potion": 80, "antidote": 81, "medicine": 81}


static func texture(base_id: String) -> Texture2D:
    var idx: int = int(BASES.get(base_id, CONSUMABLES.get(base_id, 19)))
    if not ResourceLoader.exists(AssetCatalog.ITEM_ICONS):
        return null
    var at := AtlasTexture.new()
    at.atlas = load(AssetCatalog.ITEM_ICONS)
    at.region = Rect2((idx % 16) * 32, (idx / 16) * 32, 32, 32)
    return at


static func skill_texture(skill_id: String) -> Texture2D:
    if not ResourceLoader.exists(AssetCatalog.SKILL_ICONS):
        return null
    var idx := SkillIcons.index_of(skill_id)
    var at := AtlasTexture.new()
    at.atlas = load(AssetCatalog.SKILL_ICONS)
    at.region = Rect2((idx % 8) * 32, (idx / 8) * 32, 32, 32)
    return at


## An item slot: Dragon Regalia frame for the equipment slot, the item's icon inside (16 px from the
## 32 px icon at x0.5 would blur: the 32 px icon is shown whole on a 32 px frame), rarity tint on the rim.
static func slot_control(slot: String, item: Dictionary) -> Control:
    var c := Control.new()
    c.custom_minimum_size = Vector2(32, 32)
    var frame := TextureRect.new()
    var fpath := String(AssetCatalog.SLOT_FRAMES.get(slot, AssetCatalog.SLOT_FRAMES[""]))
    frame.texture = load(fpath) if ResourceLoader.exists(fpath) else null
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    c.add_child(frame)
    if not item.is_empty():
        var r := ColorRect.new()
        r.color = Color(ArtPalette.rarity_color(String(item.get("rarity", "common"))), 0.35)
        r.position = Vector2(2, 2)
        r.size = Vector2(28, 28)
        r.mouse_filter = Control.MOUSE_FILTER_IGNORE
        c.add_child(r)
        var ic := TextureRect.new()
        ic.texture = texture(String(item.get("base", "")))
        ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
        c.add_child(ic)
    return c


## Tooltip text: name, rarity, stats and affixes; vs = the item now equipped in that slot (▲ / ▼).
static func tooltip(item: Dictionary, vs: Dictionary = {}) -> String:
    if item.is_empty():
        return ""
    var lines: Array = [ItemDefs.item_label(item)]
    var st: Dictionary = item.get("stats", {})
    var other: Dictionary = vs.get("stats", {}) if not vs.is_empty() else {}
    for k in st:
        var v := float(st[k])
        var mark := ""
        if not vs.is_empty():
            var o := float(other.get(k, 0.0))
            mark = "  ▲ +%s" % _num(v - o) if v > o else ("  ▼ %s" % _num(v - o) if v < o else "  =")
        lines.append("%s %s%s" % [String(k).to_upper(), _num(v), mark])
    if not vs.is_empty():
        for k in other:
            if not st.has(k):
                lines.append("%s 0  ▼ -%s" % [String(k).to_upper(), _num(float(other[k]))])
    for a in item.get("affixes", []):
        lines.append("· %s" % str(a.get("name", a)) if a is Dictionary else "· %s" % str(a))
    if String(item.get("set", "")) != "":
        lines.append("Set: %s" % String(ItemDefs.SETS.get(String(item["set"]), {}).get("name", item["set"])))
    return "\n".join(lines)


static func _num(v: float) -> String:
    return str(roundi(v)) if absf(v - roundf(v)) < 0.001 else "%.2f" % v
