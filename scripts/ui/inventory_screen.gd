class_name InventoryScreen
extends Control
## The Master's global inventory (vertical slice, D-063 UI): resources by category, the equipment
## stash (rarity frame, tooltip with affixes and ▲▼ against the chosen hero), equip / salvage, and the
## forge's recipes with what you have and what is missing. One inventory: heroes only wear equipment.

signal back_requested

var _hero_pick: OptionButton
var _hero_ids: Array = []
var _body: HBoxContainer
var _msg: Label


func _ready() -> void:
    var root := VBoxContainer.new()
    add_child(root)
    UIKit.fill(root)
    var top := HBoxContainer.new()
    root.add_child(top)
    top.add_child(UIKit.button("< Back", func(): back_requested.emit(), Vector2(100, 32)))
    top.add_child(UIKit.label("Inventory", 28, UIKit.ACCENT))
    top.add_child(UIKit.label("Compare / equip for:", 12, UIKit.MUTED))
    _hero_pick = OptionButton.new()
    top.add_child(_hero_pick)
    for id in Game.heroes:
        _hero_ids.append(id)
        _hero_pick.add_item((Game.heroes[id] as HeroData).display_name())
    _hero_pick.item_selected.connect(func(_i): refresh())
    _msg = UIKit.label("", 12, UIKit.ACCENT)
    root.add_child(_msg)
    _body = HBoxContainer.new()
    _body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(_body)
    Game.changed.connect(refresh)
    refresh()


func _hero() -> HeroData:
    var i := _hero_pick.selected
    return Game.heroes.get(_hero_ids[i]) if i >= 0 and i < _hero_ids.size() else null


func refresh() -> void:
    if not is_inside_tree():
        return
    for c in _body.get_children():
        c.queue_free()
    _body.add_child(_resources())
    _body.add_child(_stash())
    _body.add_child(_forge())


func _panel(title: String, w: int) -> Array:
    var pc := PanelContainer.new()
    pc.custom_minimum_size = Vector2(w, 0)
    pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    pc.add_child(scroll)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 2)
    scroll.add_child(v)
    v.add_child(UIKit.label(title, 20, UIKit.ACCENT))
    return [pc, v]


func _resources() -> Control:
    var pv := _panel("Resources", 130)
    var v: VBoxContainer = pv[1]
    var cats := {"basic": "Gathered", "processed": "Processed", "drop": "Creature drops", "consumable": "Supplies"}
    for cat in cats:
        v.add_child(UIKit.label(String(cats[cat]), 14, UIKit.MUTED))
        for res in EconomyDefs.RESOURCES:
            if String(EconomyDefs.RESOURCES[res]["cat"]) != cat:
                continue
            var n := int(Game.hq_outputs.get(res, 0))
            var l := UIKit.label("%s  %d" % [String(EconomyDefs.RESOURCES[res]["name"]), n], 12, UIKit.TEXT if n > 0 else UIKit.MUTED)
            v.add_child(l)
    v.add_child(UIKit.label("Storage cap %d each · stash %d/%d" % [Game.storage_cap(), Game.stash.size(), Game.stash_cap()], 12, UIKit.MUTED))
    return pv[0]


func _stash() -> Control:
    var pv := _panel("Equipment stash", 290)
    var v: VBoxContainer = pv[1]
    var h := _hero()
    if Game.stash.is_empty():
        v.add_child(UIKit.label("Empty: the tower and the forge fill it.", 12, UIKit.MUTED))
    var grid := GridContainer.new()
    grid.columns = 8
    v.add_child(grid)
    for it in Game.stash:
        var slots := ItemDefs.slots_for(String(it["base"]))
        var slot := String(slots[0]) if not slots.is_empty() else ""
        var cell := ItemIcons.slot_control(slot, it)
        var vs: Dictionary = h.equipment.get(slot, {}) if h != null and slot != "" else {}
        cell.tooltip_text = ItemIcons.tooltip(it, vs) + ("\nClick: equip on %s · Right click: salvage" % h.display_name() if h != null else "")
        cell.mouse_filter = Control.MOUSE_FILTER_STOP
        var uid := int(it["uid"])
        cell.gui_input.connect(func(e):
            if e is InputEventMouseButton and e.pressed:
                if e.button_index == MOUSE_BUTTON_LEFT and _hero() != null:
                    var why := Game.equip(_hero(), uid)
                    _msg.text = why if why != "" else "Equipped on %s." % _hero().display_name()
                elif e.button_index == MOUSE_BUTTON_RIGHT:
                    var got := Game.salvage(uid)
                    _msg.text = "Salvaged: %s" % SandboxScreen._res_line(got)
                UIKit.sound("click"))
        grid.add_child(cell)
    if h != null:
        v.add_child(UIKit.label("%s wears:" % h.display_name(), 14, UIKit.ACCENT))
        var worn := GridContainer.new()
        worn.columns = 8
        v.add_child(worn)
        for slot in ItemDefs.ACTIVE_SLOTS:
            var item: Dictionary = h.equipment.get(slot, {})
            var c := ItemIcons.slot_control(slot, item)
            c.tooltip_text = "%s\n%s" % [String(ItemDefs.SLOT_NAMES.get(slot, slot)), ItemIcons.tooltip(item) if not item.is_empty() else "empty"]
            c.mouse_filter = Control.MOUSE_FILTER_STOP
            worn.add_child(c)
    return pv[0]


func _forge() -> Control:
    var pv := _panel("Forge & alchemy", 190)
    var v: VBoxContainer = pv[1]
    for rid in EconomyDefs.RECIPES:
        var r: Dictionary = EconomyDefs.RECIPES[rid]
        if not (String(r["building"]) in ["blacksmith", "alchemy"]):
            continue
        var built := Game.building_level(String(r["building"])) > 0
        var who := Game.heroes.values().filter(func(x): return (x as HeroData).prof_level(String(r["prof"])) >= int(r["min"]))
        v.add_child(UIKit.label(String(r["name"]), 14, UIKit.TEXT if built else UIKit.MUTED))
        var parts: Array = []
        for k in r["in"]:
            var have := int(Game.hq_outputs.get(k, 0))
            parts.append("%s %d/%d%s" % [String(EconomyDefs.RESOURCES.get(k, {}).get("name", k)), have, int(r["in"][k]), "" if have >= int(r["in"][k]) else " ✗"])
        var l := UIKit.label(", ".join(parts) if not parts.is_empty() else "no ingredients", 12, UIKit.MUTED)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.custom_minimum_size = Vector2(175, 0)
        v.add_child(l)
        var need := "%s level %d" % [String(ProfessionDefs.info(String(r["prof"])).get("name", r["prof"])), int(r["min"])]
        var st := UIKit.label(("%s · %d able" % [need, who.size()]) if built else "Build the %s first" % String(TownTables.info(String(r["building"]))["name"]), 12,
            UIKit.GOOD if built and not who.is_empty() else UIKit.BAD)
        st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        st.custom_minimum_size = Vector2(175, 0)
        v.add_child(st)
    return pv[0]
