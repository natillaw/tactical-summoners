class_name HeroSheet
extends VBoxContainer
## A hero's sheet in tabs (D-063): Summary, Skills, Equipment, Progression (ascension, synthesis,
## sacrifice with a preview of what is gained and lost before confirming), Profession, Relations.
## Every action calls Game; the sheet rebuilds from the data after it.

signal changed

var hero: HeroData
var _tabs: TabContainer
var _msg: String = ""
var _sources: Array = []              # heroes picked to be absorbed by a synthesis
var _tab_index: int = 0


func _init(h: HeroData = null, tab: int = 0) -> void:
    hero = h
    _tab_index = tab
    add_theme_constant_override("separation", 4)


func _ready() -> void:
    rebuild()


func rebuild() -> void:
    for c in get_children():
        c.queue_free()
    if hero == null or not Game.heroes.has(hero.id):
        add_child(UIKit.label("Choose a hero.", 16, UIKit.MUTED))
        return
    var head := HBoxContainer.new()
    add_child(head)
    head.add_child(HeroPortrait.new(hero, 1.0))
    var info := VBoxContainer.new()
    info.add_theme_constant_override("separation", 1)
    head.add_child(info)
    info.add_child(UIKit.label(hero.display_name(), 24, ArtPalette.rarity_color(ArtPalette.rarity_of_stars(hero.stars))))
    info.add_child(StarRow.new(hero.stars, 9.0))
    info.add_child(UIKit.label("%s · Lv %d/%d · Power %d" % [hero.class_title(), hero.level, hero.level_cap(), hero.power()], 14, UIKit.TEXT))
    if _msg != "":
        add_child(_wrap(_msg, UIKit.ACCENT))
    _tabs = TabContainer.new()
    _tabs.custom_minimum_size = Vector2(300, 220)
    add_child(_tabs)
    _tabs.add_child(_scroll("Summary", _summary()))
    _tabs.add_child(_scroll("Skills", _skills()))
    _tabs.add_child(_scroll("Equipment", _equipment()))
    _tabs.add_child(_scroll("Progression", _progression()))
    _tabs.add_child(_scroll("Profession", _profession()))
    _tabs.add_child(_scroll("Relations", _relations()))
    _tabs.current_tab = clampi(_tab_index, 0, _tabs.get_tab_count() - 1)
    _tabs.tab_changed.connect(func(i): _tab_index = i)


func _scroll(title: String, content: Control) -> ScrollContainer:
    var s := ScrollContainer.new()
    s.name = title
    s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    s.add_child(content)
    return s


func _wrap(text: String, color: Color = UIKit.TEXT, size: int = 14) -> Label:
    var l := UIKit.label(text, size, color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(280, 0)
    return l


func _done(msg: String) -> void:
    _msg = msg
    rebuild()
    changed.emit()


# --- Summary --------------------------------------------------------------------------------------

func _summary() -> VBoxContainer:
    var v := VBoxContainer.new()
    var stats := hero.get_stats()
    var grid := GridContainer.new()
    grid.columns = 6
    v.add_child(grid)
    for k in HeroTables.STAT_KEYS:
        grid.add_child(UIKit.label(String(HeroTables.STAT_NAMES[k]), 12, UIKit.MUTED))
        grid.add_child(UIKit.label(str(stats[k]), 14, UIKit.TEXT))
    var social := HBoxContainer.new()
    v.add_child(social)
    for s in [["social_trust", "Trust", hero.trust], ["social_obedience", "Obedience", hero.obedience], ["social_composure", "Composure", hero.composure]]:
        social.add_child(UIKit.icon(AssetCatalog.icon(String(s[0])), String(s[1])))
        social.add_child(UIKit.label("%s %d" % [String(s[1]), int(s[2])], 12, UIKit.TEXT))
    v.add_child(UIKit.label("Personality", 20, UIKit.ACCENT))
    for t in hero.traits:
        var td: Dictionary = HeroTables.TRAITS[t]
        v.add_child(_wrap("%s — %s" % [td["name"], td["desc"]]))
    for p in hero.passives:
        var pd: Dictionary = HeroTables.PASSIVES[p]
        v.add_child(_wrap("Passive %s: %s" % [pd["name"], pd["desc"]], UIKit.MUTED, 12))
    v.add_child(UIKit.label("Background", 20, UIKit.ACCENT))
    v.add_child(_wrap(hero.background_text, UIKit.MUTED, 12))
    return v


# --- Skills ---------------------------------------------------------------------------------------

func _skills() -> VBoxContainer:
    var v := VBoxContainer.new()
    var res := String(SkillDefs.RESOURCES[SkillDefs.resource_of(hero.hero_class)]["name"])
    v.add_child(UIKit.label("Q = basic attack · W E R = skills · resource: %s" % res, 12, UIKit.MUTED))
    for sid in hero.skills:
        var sk := SkillDefs.info(sid)
        var row := HBoxContainer.new()
        var icon := TextureRect.new()
        icon.texture = ItemIcons.skill_texture(String(sid))
        row.add_child(icon)
        var slot_i := hero.loadout.find(sid)
        var col := VBoxContainer.new()
        col.add_theme_constant_override("separation", 0)
        col.add_child(UIKit.label("[%s] %s" % [SandboxScreen.SKILL_KEYS[slot_i] if slot_i >= 0 and slot_i < 3 else "-", String(sk["name"])], 14,
            UIKit.ACCENT if slot_i >= 0 else UIKit.TEXT))
        var d := UIKit.label("%d %s · %.0fs · %s" % [int(sk["cost"]), res.to_lower(), float(sk["cd"]), String(sk["desc"])], 12, UIKit.MUTED)
        d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        d.custom_minimum_size = Vector2(220, 0)
        col.add_child(d)
        row.add_child(col)
        if slot_i != 0:
            var id := String(sid)
            row.add_child(UIKit.button("→W", func():
                hero.equip_skill(0, id)
                Game._commit()
                _done("%s now on W." % String(sk["name"])), Vector2(50, 28)))
        v.add_child(row)
    for i in hero.skill_choices.size():
        var c: Dictionary = hero.skill_choices[i]
        v.add_child(UIKit.label("Level %d: choose one" % int(c["level"]), 14, UIKit.ACCENT))
        var opts := HBoxContainer.new()
        for sid in c["options"]:
            var idx := i
            var id := String(sid)
            var b := UIKit.button(String(SkillDefs.info(id)["name"]), func():
                hero.choose_skill(idx, id)
                Game._commit()
                _done("Learned %s." % String(SkillDefs.info(id)["name"])), Vector2(140, 30))
            b.tooltip_text = String(SkillDefs.info(id)["desc"])
            opts.add_child(b)
        v.add_child(opts)
    var tb := Game.training_block(hero)
    v.add_child(UIKit.label("Training Grounds", 20, UIKit.ACCENT))
    if tb != "":
        v.add_child(_wrap(tb, UIKit.MUTED, 12))
    else:
        v.add_child(_wrap("Choose ONE to learn (%s):" % SandboxScreen._res_line(ProgressionDefs.TRAIN_COST), UIKit.TEXT, 12))
        var row := HBoxContainer.new()
        for sid in Game.training_options(hero):
            var id := String(sid)
            var b := UIKit.button(String(SkillDefs.info(id)["name"]), func():
                var why := Game.train_skill(hero, id)
                _done(why if why != "" else "Trained %s." % String(SkillDefs.info(id)["name"])), Vector2(140, 30))
            b.tooltip_text = String(SkillDefs.info(id)["desc"])
            row.add_child(b)
        v.add_child(row)
    return v


# --- Equipment (8 open slots, D-060) --------------------------------------------------------------

func _equipment() -> VBoxContainer:
    var v := VBoxContainer.new()
    var grid := GridContainer.new()
    grid.columns = 4
    v.add_child(grid)
    for slot in ItemDefs.ACTIVE_SLOTS:
        var item: Dictionary = hero.equipment.get(slot, {})
        var cell := ItemIcons.slot_control(slot, item)
        cell.tooltip_text = "%s\n%s" % [String(ItemDefs.SLOT_NAMES.get(slot, slot)), ItemIcons.tooltip(item) if not item.is_empty() else "empty"]
        cell.mouse_filter = Control.MOUSE_FILTER_STOP
        var s := String(slot)
        cell.gui_input.connect(func(e):
            if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and hero.equipment.has(s):
                var why := Game.unequip(hero, s)
                _done(why if why != "" else "Unequipped: back to the master's stash."))
        grid.add_child(cell)
    v.add_child(UIKit.label("Locked for now: hands, second ring, special (D-060).", 12, UIKit.MUTED))
    v.add_child(UIKit.label("From the master's stash (click to equip):", 14, UIKit.ACCENT))
    var any := false
    for it in Game.stash:
        var slots := ItemDefs.slots_for(String(it["base"]))
        if slots.is_empty():
            continue
        any = true
        var vs: Dictionary = hero.equipment.get(String(slots[0]), {})
        var row := HBoxContainer.new()
        var cell := ItemIcons.slot_control(String(slots[0]), it)
        row.add_child(cell)
        var uid := int(it["uid"])
        var b := UIKit.button(ItemDefs.item_label(it), func():
            var why := Game.equip(hero, uid)
            _done(why if why != "" else "Equipped."), Vector2(380, 30))
        b.tooltip_text = ItemIcons.tooltip(it, vs)
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        row.add_child(b)
        v.add_child(row)
    if not any:
        v.add_child(UIKit.label("The stash is empty: the tower and the forge fill it.", 12, UIKit.MUTED))
    return v


# --- Progression: level, ascension, synthesis, sacrifice -------------------------------------------

func _progression() -> VBoxContainer:
    var v := VBoxContainer.new()
    v.add_child(UIKit.label("Level %d / %d" % [hero.level, hero.level_cap()], 14, UIKit.TEXT))
    v.add_child(UIKit.bar("xp", hero.xp, hero.xp_to_next(), 200, true))
    var row := HBoxContainer.new()
    v.add_child(row)
    var t1 := UIKit.button("Read 1 book (+XP)", func():
        Game.train(hero, 1)
        _done("Studied."), Vector2(200, 30))
    t1.disabled = hero.is_max_level() or Game.books < 1
    row.add_child(t1)
    # ascension
    v.add_child(UIKit.label("Ascension", 20, UIKit.ACCENT))
    var why := Game.promotion_block(hero)
    v.add_child(_wrap("Needs: %s · Luck %d · failures %d (sure after %d)" % [SandboxScreen._res_line(Game.ascension_cost(hero)), hero.luck(),
        hero.ascension_fails, ProgressionDefs.ASCENSION_PITY_HARD], UIKit.MUTED, 12))
    var asc := UIKit.button("Ascend to %d★ (%d%%)" % [hero.stars + 1, roundi(Game.promotion_chance(hero) * 100.0)], func():
        var r := Game.attempt_promotion(hero)
        UIKit.sound("level_up" if bool(r.get("ok", false)) else "error")
        _done(("Ascended to %d stars!" % hero.stars) if bool(r.get("ok", false)) else "%s (next try %d%%)." % [String(r.get("reason", "failed")), roundi(Game.promotion_chance(hero) * 100.0)]), Vector2(300, 32))
    asc.disabled = why != ""
    asc.tooltip_text = why if why != "" else "Gained: +1 star, higher level cap, training. A failure keeps the level and half the tower materials."
    v.add_child(asc)
    if why != "":
        v.add_child(_wrap(why, UIKit.BAD, 12))
    # synthesis
    v.add_child(UIKit.label("Synthesis", 20, UIKit.ACCENT))
    v.add_child(_wrap("Absorb 1-3 heroes: %d%% of their experience (%d%% same class) and +1 to their best attribute if same class. They go to the memorial. Irreversible." % [
        roundi(ProgressionDefs.SYNTH_EFFICIENCY * 100.0), roundi(ProgressionDefs.SYNTH_SAME_CLASS * 100.0)], UIKit.MUTED, 12))
    var pick := GridContainer.new()
    pick.columns = 2
    v.add_child(pick)
    for other in Game.heroes.values():
        var o := other as HeroData
        if o == hero:
            continue
        var cb := CheckBox.new()
        cb.text = "%s %s Lv%d" % ["*".repeat(o.stars), o.display_name(), o.level]
        cb.button_pressed = _sources.has(o)
        cb.disabled = Game.consumable_block(o) != ""
        cb.tooltip_text = Game.consumable_block(o)
        cb.toggled.connect(func(on):
            if on and not _sources.has(o) and _sources.size() < ProgressionDefs.SYNTH_MAX_SOURCES:
                _sources.append(o)
            elif not on:
                _sources.erase(o)
            _done(""))
        pick.add_child(cb)
    if not _sources.is_empty():
        var p := Game.synthesis_preview(hero, _sources)
        if bool(p.get("ok", false)):
            v.add_child(_wrap("Gain: +%d XP (%d level%s)%s · Lose: %s%s" % [int(p["xp"]), int(p["levels"]), "" if int(p["levels"]) == 1 else "s",
                (" · +%s" % str(p["attrs"])) if not (p["attrs"] as Dictionary).is_empty() else "", ", ".join(p["lost"]),
                ("\nWarning: " + String(p["warning"])) if String(p["warning"]) != "" else ""], UIKit.TEXT, 12))
            v.add_child(UIKit.button("Confirm synthesis", func():
                var src := _sources.duplicate()
                _sources.clear()
                var r := Game.synthesize(hero, src)
                _done("Synthesis done: +%d XP." % int(r.get("xp", 0)) if bool(r.get("ok", false)) else String(r.get("reason", ""))), Vector2(300, 32)))
        else:
            v.add_child(_wrap(String(p.get("reason", "")), UIKit.BAD, 12))
    # sacrifice
    v.add_child(UIKit.label("Sacrifice", 20, UIKit.ACCENT))
    var sp := Game.sacrifice_preview(hero)
    if bool(sp.get("ok", false)):
        v.add_child(_wrap("Gain: %s · Lose: %s for good (memorial).%s" % [SandboxScreen._res_line(sp["gain"]), hero.display_name(),
            ("\nWarning: " + String(sp["warning"])) if String(sp["warning"]) != "" else ""], UIKit.TEXT, 12))
        var sac := UIKit.button("Sacrifice %s…" % hero.display_name(), _confirm_sacrifice, Vector2(300, 32))
        v.add_child(sac)
    else:
        v.add_child(_wrap(String(sp.get("reason", "")), UIKit.MUTED, 12))
    return v


func _confirm_sacrifice() -> void:
    var dlg := ConfirmationDialog.new()
    dlg.title = "Sacrifice"
    dlg.dialog_text = "%s will be sacrificed for %s.\nThis cannot be undone." % [hero.display_name(), SandboxScreen._res_line(Game.sacrifice_preview(hero).get("gain", {}))]
    dlg.confirmed.connect(func():
        var name := hero.display_name()
        var r := Game.sacrifice(hero)
        _done("%s was sacrificed: %s." % [name, SandboxScreen._res_line(r.get("gain", {}))] if bool(r.get("ok", false)) else String(r.get("reason", ""))))
    add_child(dlg)
    dlg.popup_centered()


# --- Profession -----------------------------------------------------------------------------------

func _profession() -> VBoxContainer:
    var v := VBoxContainer.new()
    if hero.professions.is_empty():
        v.add_child(UIKit.label("No profession yet (the village teaches one on the job).", 12, UIKit.MUTED))
    for p in hero.professions:
        var info: Dictionary = ProfessionDefs.info(String(p))
        var lv := int(hero.professions[p]["lvl"])
        v.add_child(UIKit.label("%s · level %d / %d" % [String(info.get("name", p)), lv, ProfessionDefs.MAX_LEVEL], 14, UIKit.TEXT))
        v.add_child(UIKit.bar("xp", float(lv), float(ProfessionDefs.MAX_LEVEL), 200))
        v.add_child(_wrap(String(info.get("desc", "")), UIKit.MUTED, 12))
    v.add_child(UIKit.label("Works at: %s" % (hero.hq_assignment if hero.hq_assignment != "" else "nowhere (free time)"), 12, UIKit.MUTED))
    return v


# --- Relations ------------------------------------------------------------------------------------

func _relations() -> VBoxContainer:
    var v := VBoxContainer.new()
    var any := false
    for oid in hero.relationships:
        var rel: Dictionary = hero.relationships[oid]
        var other: HeroData = Game.heroes.get(oid)
        if other == null:
            continue
        any = true
        var lvl := int(rel.get("level", 0))
        var row := HBoxContainer.new()
        row.add_child(UIKit.icon(AssetCatalog.icon("social_bond" if lvl >= 0 else "social_rivalry"), "bond" if lvl >= 0 else "rivalry"))
        row.add_child(UIKit.label("%s · %s (%+d)" % [other.display_name(), String(rel.get("status", "")), lvl], 12, UIKit.TEXT if lvl >= 0 else UIKit.BAD))
        v.add_child(row)
    if not any:
        v.add_child(UIKit.label("No bonds or rivalries yet: they grow from shared missions and village life.", 12, UIKit.MUTED))
    v.add_child(UIKit.label("Memories", 20, UIKit.ACCENT))
    for m in hero.memories.slice(-4):
        v.add_child(_wrap("· %s" % String(m["text"]), UIKit.MUTED, 12))
    return v
