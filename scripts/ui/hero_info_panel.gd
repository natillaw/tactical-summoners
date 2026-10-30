class_name HeroInfoPanel
extends PanelContainer
## Everything about one hero, opened by clicking the hero in the town: portrait, identity, stats,
## social state, personality, equipment slots, appearance colours, what they are doing now,
## relationships and recent memories. Read-only.

signal open_barracks
signal closed

const LAYER_NAMES := {"body": "Skin", "eyes": "Eyes", "rear_hair": "Hair (back)", "front_hair": "Hair",
    "facial_hair": "Beard", "top": "Top", "bottom": "Bottom", "shoes": "Shoes", "hat": "Hat", "held": "Held item"}

var hero: HeroData
var activity: String = ""


func _init(h: HeroData = null, current_activity: String = "") -> void:
    hero = h
    activity = current_activity


func _ready() -> void:
    custom_minimum_size = Vector2(380, 0)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(370, 560)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var vb := VBoxContainer.new()
    vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vb.add_theme_constant_override("separation", 6)
    scroll.add_child(vb)
    if hero == null:
        return
    var h := hero

    var head := HBoxContainer.new()
    var portrait := TextureRect.new()
    portrait.texture = SpriteComposer.pose_texture(h)
    portrait.custom_minimum_size = Vector2(96, 96)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    head.add_child(portrait)
    var id_box := VBoxContainer.new()
    id_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var name_lbl := UIKit.label(h.display_name(), 18, h.star_color())
    name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    id_box.add_child(name_lbl)
    id_box.add_child(UIKit.label("%d-star %s  ·  Lv %d / %d" % [h.stars, h.class_title(), h.level, h.level_cap()], 14, UIKit.TEXT))
    id_box.add_child(UIKit.label("Power %d   ·   XP %d / %d" % [h.power(), h.xp, h.xp_to_next()], 13, UIKit.MUTED))
    var prof: Dictionary = HeroTables.PROFESSIONS.get(h.profession, {})
    if not prof.is_empty():
        id_box.add_child(UIKit.label("Past life: " + String(prof["name"]), 13, UIKit.MUTED))
        var best: Array = TownTables.best_workplaces(h.profession).map(func(b): return String(TownTables.info(b)["name"]))
        if not best.is_empty():
            id_box.add_child(UIKit.label("Expert at: " + ", ".join(best), 13, UIKit.ACCENT))
    head.add_child(id_box)
    var close := UIKit.button("x", func(): closed.emit(), Vector2(32, 30))
    close.focus_mode = Control.FOCUS_NONE
    head.add_child(close)
    vb.add_child(head)

    if activity != "":
        vb.add_child(_wrap("Now: " + activity, 14, UIKit.ACCENT))
    if h.hq_assignment != "":
        vb.add_child(_wrap("Works at: " + String(TownTables.info(h.hq_assignment).get("name", h.hq_assignment)), 13, UIKit.TEXT))

    vb.add_child(_section("Stats"))
    var st := h.get_stats()
    var at := h.attributes()
    vb.add_child(UIKit.label("FUE %d   AGI %d   VIT %d   INT %d   TEM %d" % [at["fue"], at["agi"], at["vit"], at["int"], at["tem"]], 14, UIKit.ACCENT))
    vb.add_child(UIKit.label("HP %d   P.ATK %d   M.ATK %d   ARMOR %d   M.RES %d" % [st["hp"], st["atk"], st["mag"], st["def"], st["mres"]], 14, UIKit.TEXT))
    vb.add_child(UIKit.label("Crit %d%%   Attack every %.2fs   %s basic attacks" % [roundi(float(st["crit"]) * 100.0), float(st["interval"]), String(st["kind"]).capitalize()], 13, UIKit.MUTED))
    for pair in [["Trust", h.trust], ["Obedience", h.obedience], ["Composure", h.composure]]:
        vb.add_child(_bar(String(pair[0]), int(pair[1])))

    vb.add_child(_section("Personality"))
    for t in h.traits:
        var td: Dictionary = HeroTables.TRAITS.get(t, {})
        vb.add_child(_wrap("%s — %s" % [td.get("name", t), td.get("desc", "")], 13, UIKit.TEXT))
    for p in h.passives:
        var pd: Dictionary = HeroTables.PASSIVES.get(p, {})
        vb.add_child(_wrap("Passive: %s — %s" % [pd.get("name", p), pd.get("desc", "")], 12, UIKit.MUTED))
    if h.background_text != "":
        vb.add_child(_wrap(h.background_text, 12, UIKit.MUTED))

    vb.add_child(_section("Equipment"))
    var held := String(h.appearance.get("held", ""))
    vb.add_child(UIKit.label("Weapon: " + ("held item #%s (cosmetic)" % held.get_slice("/", 1) if held != "" else "—"), 13, UIKit.TEXT))
    for slot in ["Armor", "Helmet", "Accessory"]:
        vb.add_child(UIKit.label("%s: —" % slot, 13, UIKit.TEXT))
    vb.add_child(_wrap("Gear with stats arrives with the equipment system (D-021, P-19).", 12, UIKit.MUTED))

    vb.add_child(_section("Appearance & colours"))
    for key in SpriteComposer.LAYER_ORDER:
        var rel := String(h.appearance.get(key, ""))
        if rel == "":
            continue
        var row := HBoxContainer.new()
        var sw := ColorRect.new()
        sw.color = dominant_color(rel)
        sw.custom_minimum_size = Vector2(18, 18)
        row.add_child(sw)
        row.add_child(UIKit.label("  %s  (%s)" % [LAYER_NAMES.get(key, key), rel.get_file()], 13, UIKit.TEXT))
        vb.add_child(row)

    vb.add_child(_section("Relationships"))
    var rels: Array = []
    for other_id in h.relationships:
        rels.append([other_id, int((h.relationships[other_id] as Dictionary).get("level", 0))])
    rels.sort_custom(func(a, b): return absi(a[1]) > absi(b[1]))
    if rels.is_empty():
        vb.add_child(UIKit.label("No bonds yet.", 13, UIKit.MUTED))
    for i in mini(4, rels.size()):
        var oid: String = rels[i][0]
        var other: HeroData = Game.heroes.get(oid)
        var nm := other.display_name() if other != null else "(fallen)"
        vb.add_child(UIKit.label("%s — %s (%d)" % [nm, h.get_relationship(oid)["status"], rels[i][1]], 13, UIKit.TEXT))

    vb.add_child(_section("Recent memories"))
    if h.memories.is_empty():
        vb.add_child(UIKit.label("Nothing remembered yet.", 13, UIKit.MUTED))
    for m in h.memories.slice(-4):
        vb.add_child(_wrap("• " + String((m as Dictionary).get("text", "")), 12, UIKit.TEXT))

    var btn := UIKit.button("Open in Barracks", func(): open_barracks.emit(), Vector2(340, 38))
    btn.focus_mode = Control.FOCUS_NONE
    vb.add_child(btn)


## Most common opaque colour of a sprite layer in the standing pose (what the player sees).
static func dominant_color(rel: String) -> Color:
    var img := SpriteComposer._layer_image(rel)
    if img == null:
        return Color(0, 0, 0, 0)
    var counts := {}
    var col := int(SpriteComposer.ANIMS["idle"]["cols"][0])
    for y in SpriteComposer.FRAME:
        for x in SpriteComposer.FRAME:
            var c := img.get_pixel(col * SpriteComposer.FRAME + x, y)
            if c.a < 0.5 or c.v < 0.12:
                continue
            var k := c.to_html(false)
            counts[k] = int(counts.get(k, 0)) + 1
    var best := ""
    var best_n := 0
    for k in counts:
        if int(counts[k]) > best_n:
            best_n = int(counts[k])
            best = String(k)
    return Color.html(best) if best != "" else Color(0, 0, 0, 0)


func _section(title: String) -> Label:
    var l := UIKit.label(title, 16, UIKit.ACCENT)
    return l


func _wrap(text: String, size_px: int, color: Color) -> Label:
    var l := UIKit.label(text, size_px, color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(340, 0)
    return l


func _bar(label_text: String, value: int) -> HBoxContainer:
    var row := HBoxContainer.new()
    var l := UIKit.label(label_text, 13, UIKit.TEXT)
    l.custom_minimum_size = Vector2(90, 0)
    row.add_child(l)
    var pb := ProgressBar.new()
    pb.min_value = 0
    pb.max_value = 100
    pb.value = value
    pb.custom_minimum_size = Vector2(200, 14)
    pb.show_percentage = false
    row.add_child(pb)
    row.add_child(UIKit.label(" %d" % value, 13, UIKit.TEXT))
    return row
