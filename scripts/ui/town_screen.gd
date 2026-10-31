class_name TownScreen
extends Control
## The town is the first screen of the game (D-030). Everything starts from a building:
## click it to enter (summon, roster, party, tower, memorial, town hall) or to build / upgrade it.
## Drag to pan, mouse wheel to zoom. Heroes walk around on their own.

signal navigate(screen: String, arg: int)

const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEPS := [0.5, 1.0, 2.0]       # D-063: whole pixel steps only (the first fit view may be in between)

var map: TownMap
var view: TownView
var camera: Camera2D
var heroes: Array[TownHero] = []
var selected: String = ""
var hero_panel: HeroInfoPanel = null
var selected_hero_id: String = ""

var _viewport: SubViewport
var _world: Node2D
var _res: Label
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _drag_from: Vector2 = Vector2.ZERO
var _cam_from: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _moved: bool = false
var moving: String = ""            # D-050: building being placed ("" = not in move mode)
var placing_new: bool = false      # the building being placed is a NEW construction (free placement)
var _move_msg: Label


func _ready() -> void:
    clip_contents = true
    var container := SubViewportContainer.new()
    container.stretch = true
    container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(container)
    UIKit.fill(container)
    _viewport = SubViewport.new()
    _viewport.handle_input_locally = false
    _viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    container.add_child(_viewport)
    _world = Node2D.new()
    _viewport.add_child(_world)
    camera = Camera2D.new()
    _viewport.add_child(camera)
    camera.make_current()
    camera.zoom = Vector2.ONE
    _build_ui()
    rebuild()
    Game.changed.connect(_on_changed)


## (Re)builds the map and heroes from the current save (called again after a building changes).
func rebuild() -> void:
    for c in _world.get_children():
        c.queue_free()
    heroes.clear()
    map = TownMap.new(Game.town_buildings, Game.town_layout.duplicate())
    view = TownView.new(map)
    view.selected = selected
    _world.add_child(view)
    var i := 0
    for id in Game.heroes:
        var th := TownHero.new(Game.heroes[id], map)
        th.position = map.center_of(map.spawn_cells[i % map.spawn_cells.size()]) + Vector2((i / map.spawn_cells.size()) * 7, 0)
        _world.add_child(th)
        heroes.append(th)
        i += 1
    for th in heroes:
        th.town_heroes = heroes
    if camera.position == Vector2.ZERO:
        # first view: the whole town fits on screen
        var ws := map.world_size()
        var vs := Vector2(_viewport.size) if _viewport.size.x > 0 else Vector2(1280, 670)
        camera.zoom = Vector2.ONE                 # D-063: start at x1 (crisp, readable); wheel = 0.5 / 1 / 2
        camera.position = _clamp_cam(map.center_of(Vector2i(17, 10)))
    _refresh()


func _on_changed() -> void:
    var count_changed := heroes.size() != Game.heroes.size()
    if count_changed or map == null or _levels_changed():
        rebuild()
    else:
        _refresh()


func _levels_changed() -> bool:
    if map.layout != Game.town_layout:
        return true
    for id in TownTables.ids():
        var built := Game.building_level(id) > 0
        if built != map.is_blocked_cell(map.plot_of(id).position):
            return true
    return false


## D-047: the town clock runs while the player is here.
var _occ_t: float = 0.0


func _process(delta: float) -> void:
    Game.town_tick(delta)
    _occ_t -= delta
    if _occ_t <= 0.0 and view != null:
        _occ_t = 0.5
        var occ := {}
        for th in heroes:
            if th.visible or th.activity == "away" or th.activity_target == "":
                continue
            var key := "sleep" if th.activity == "sim_sleep" else "busy"
            var o: Dictionary = occ.get(th.activity_target, {})
            o[key] = int(o.get(key, 0)) + 1
            occ[th.activity_target] = o
        view.occupancy = occ
        view.empty_hint = "Nobody lives here yet: summon your first heroes (Summoner's Hall)" if Game.heroes.is_empty() else ""
        view.queue_redraw()


func _build_ui() -> void:
    var top := HBoxContainer.new()
    top.position = Vector2(6, 4)  # px
    top.add_theme_constant_override("separation", 5)  # px
    add_child(top)
    var menu_btn := UIKit.button("Menu", func(): navigate.emit("menu", 0), Vector2(90, 34))
    menu_btn.focus_mode = Control.FOCUS_NONE
    top.add_child(menu_btn)
    var res_panel := PanelContainer.new()
    top.add_child(res_panel)
    _res = UIKit.label("", 14, UIKit.ACCENT)
    res_panel.add_child(_res)
    var build_btn := UIKit.button("Build", show_build_menu, Vector2(90, 34))
    build_btn.focus_mode = Control.FOCUS_NONE
    build_btn.tooltip_text = "Choose a new building and place it anywhere near the town"
    top.add_child(build_btn)
    var day_btn := UIKit.button("Pass a day", func(): Game.pass_time(24), Vector2(110, 34))
    day_btn.focus_mode = Control.FOCUS_NONE
    day_btn.tooltip_text = "Let the town work, eat, sleep and heal for 24 hours"
    top.add_child(day_btn)
    _move_msg = UIKit.label("", 15, UIKit.ACCENT)
    _move_msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    _move_msg.position += Vector2(-100, 26)  # px
    _move_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_move_msg)

    var hint := UIKit.label("Click a building to manage it    Click a hero to see them    Drag to move    Wheel to zoom    Red ! = a building has a problem", 14, UIKit.MUTED)
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    hint.position += Vector2(7, -15)  # px
    add_child(hint)

    _panel = PanelContainer.new()
    _panel.custom_minimum_size = Vector2(175, 0)  # px
    _panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    _panel.position = Vector2(-181, 26)  # px
    _panel.visible = false
    add_child(_panel)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(170, 295)  # px
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _panel.add_child(scroll)
    _panel_box = VBoxContainer.new()
    _panel_box.add_theme_constant_override("separation", 3)  # px
    _panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_panel_box)


func _refresh() -> void:
    var st := Game.hq_outputs
    _res.text = "%s   Mat %d  Food %d  Grain %d  Wood %d  Stone %d  Ore %d  Iron %d  Herb %d  Med %d   Beds %d/%d" % [
        Game.town_time_text(), int(st.get("materials", 0)), int(st.get("food", 0)), int(st.get("grain", 0)), int(st.get("wood", 0)),
        int(st.get("stone", 0)), int(st.get("ore", 0)), int(st.get("ingot", 0)), int(st.get("herb", 0)), int(st.get("medicine", 0)),
        Game.heroes.size(), Game.max_hero_capacity()]
    if selected != "":
        _show_panel(selected)


# --- building panel ---------------------------------------------------------------------

func select_building(id: String) -> void:
    selected = id
    if view != null:
        view.selected = id
    if id == "":
        _panel.visible = false
    else:
        _show_panel(id)


func _show_panel(id: String) -> void:
    for c in _panel_box.get_children():
        c.queue_free()
    var b := TownTables.info(id)
    var level := Game.building_level(id)
    var head := HBoxContainer.new()
    head.add_child(UIKit.label(String(b["name"]), 20, UIKit.ACCENT))
    var sp := Control.new()
    sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(sp)
    var close := UIKit.button("x", func(): select_building(""), Vector2(32, 30))
    close.focus_mode = Control.FOCUS_NONE
    head.add_child(close)
    _panel_box.add_child(head)
    _panel_box.add_child(UIKit.label("Level %d / %d" % [level, int(b["max"])] if level > 0 else "Not built yet", 15, UIKit.TEXT))
    var desc := UIKit.label(String(b["desc"]), 14, UIKit.MUTED)
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.custom_minimum_size = Vector2(150, 0)  # px
    _panel_box.add_child(desc)
    _panel_construction(id, level)
    if TownTables.is_dorm(id) and level > 0:
        _panel_dorm(id, level)
    if id == "infirmary" and level > 0:
        _panel_hospital(level)
    if id == "warehouse" and level > 0:
        _panel_storage()
    if id == "town_hall":
        _panel_hall()
    if not (b.get("jobs", []) as Array).is_empty() and level > 0:
        _panel_jobs(id)
    if level > 0 and (TownTables.worker_slots(id, level) > 0):
        _panel_workers(id, TownTables.worker_slots(id, level))
    if level > 0 and id == "library":
        var books := 0
        for k in Game.skill_books:
            books += int(Game.skill_books[k])
        _panel_box.add_child(UIKit.label("Skill books in the archive: %d (heroes read them from their panel)" % books, 13, UIKit.MUTED))
        _panel_box.add_child(UIKit.label("Transcribe a book (%d materials) for class:" % Game.library_cost(), 13, UIKit.TEXT))
        var grid := GridContainer.new()
        grid.columns = 3
        _panel_box.add_child(grid)
        for cls in Game.roster_classes():
            var trans_btn := UIKit.button(String(HeroTables.CLASSES[cls]["name"]), _on_transcribe.bind(id, String(cls)), Vector2(96, 32))
            trans_btn.focus_mode = Control.FOCUS_NONE
            trans_btn.disabled = int(Game.hq_outputs.get("materials", 0)) < Game.library_cost()
            grid.add_child(trans_btn)
    if level > 0 and String(b["open"]) == "tower":
        _add_tower_buttons()
    elif level > 0 and String(b["open"]) != "":
        var open_screen := String(b["open"])
        var enter := UIKit.button("Enter", func(): navigate.emit(open_screen, 0), Vector2(300, 40))
        enter.focus_mode = Control.FOCUS_NONE
        _panel_box.add_child(enter)
    var cost := Game.next_building_cost(id)
    if cost >= 0 and Game.under_construction(id).is_empty():
        var label := ("Build (%d materials)" if level == 0 else "Upgrade to Lv %d (%%d materials)" % (level + 1)) % cost
        var up := UIKit.button(label, func(): Game.build_or_upgrade(id), Vector2(320, 38))
        up.focus_mode = Control.FOCUS_NONE
        var why := Game.construction_block(id)
        up.disabled = why != ""
        _panel_box.add_child(up)
        if why != "":
            _panel_box.add_child(_wrap("Cannot start: " + why, 13, Color(1.0, 0.6, 0.5)))
        elif Game.builders().is_empty():
            _panel_box.add_child(_wrap("No builder assigned yet: the work waits until someone builds (Summoner's Hall).", 13, Color(1.0, 0.8, 0.5)))
    var mv := UIKit.button("Move building", func(): start_move(id), Vector2(320, 32))
    mv.focus_mode = Control.FOCUS_NONE
    _panel_box.add_child(mv)
    _panel.visible = true


func _wrap(text: String, size_px: int, color: Color) -> Label:
    var l := UIKit.label(text, size_px, color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(160, 0)  # px
    return l


func _small_btn(text: String, cb: Callable, w: float = 70.0) -> Button:
    var b := UIKit.button(text, cb, Vector2(w, 26))
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", UIKit.fpx(12))  # px
    return b


func _panel_construction(id: String, level: int) -> void:
    var p := Game.under_construction(id)
    if p.is_empty():
        return
    var total := EconomyDefs.BUILD_HOURS_PER_LEVEL * float(p["to"])
    _panel_box.add_child(_wrap("Under construction → Lv %d: %.0f of %.0f work-hours left. Builders on site: %d" % [int(p["to"]), float(p["work_left"]), total, Game.builders().size()], 14, Color(0.95, 0.8, 0.4)))


func _panel_dorm(id: String, level: int) -> void:
    var beds := TownTables.beds_at(id, level)
    var used := Game.beds_used(id)
    _panel_box.add_child(UIKit.label("Beds: %d used / %d  (%d free)" % [used, beds, beds - used], 15, UIKit.TEXT))
    _panel_box.add_child(UIKit.label("Rest quality: x%.1f" % (0.8 + 0.1 * float(level)), 13, UIKit.MUTED))
    var names: Array = []
    for hid in Game.heroes:
        var h: HeroData = Game.heroes[hid]
        if h.bed == id:
            names.append("%s (%s)" % [h.hero_name.split(" ")[0], h.activity_state])
    if not names.is_empty():
        _panel_box.add_child(_wrap("Residents: " + ", ".join(names), 13, UIKit.TEXT))
    var rough := Game.heroes.values().filter(func(h): return (h as HeroData).bed == "").size()
    if rough > 0:
        _panel_box.add_child(_wrap("%d hero(es) sleep rough: build or upgrade a dormitory." % rough, 13, Color(1.0, 0.6, 0.5)))


func _panel_hospital(level: int) -> void:
    var beds: int = TownTables.info("infirmary")["sick_beds"][clampi(level, 0, 5)]
    _panel_box.add_child(UIKit.label("Sick beds: %d / %d   Medicine %d   Antidotes %d" % [Game.patients.size(), beds,
        int(Game.hq_outputs.get("medicine", 0)), int(Game.hq_outputs.get("antidote", 0))], 14, UIKit.TEXT))
    var docs: Array = Game.workers_at("infirmary").filter(func(h): return (h as HeroData).knows_prof("doctor")).map(func(h): return "%s (Lv %d)" % [h.hero_name.split(" ")[0], h.prof_level("doctor")])
    _panel_box.add_child(_wrap("Doctors: " + (", ".join(docs) if not docs.is_empty() else "none — patients only rest"), 13, UIKit.TEXT if not docs.is_empty() else Color(1.0, 0.6, 0.5)))
    for hid in Game.patients:
        var h: HeroData = Game.heroes[hid]
        for dz in h.diseases:
            _panel_box.add_child(_wrap("• %s — %s, ~%.0f h left (%s)" % [h.hero_name.split(" ")[0], EconomyDefs.DISEASES[String(dz["id"])]["name"], float(dz["hours"]), dz["cause"]], 13, UIKit.TEXT))
    var waiting := Game.heroes.values().filter(func(h): return not (h as HeroData).diseases.is_empty() and not Game.patients.has(h.id)).size()
    if waiting > 0:
        _panel_box.add_child(_wrap("%d sick hero(es) waiting for a bed." % waiting, 13, Color(1.0, 0.6, 0.5)))


func _panel_storage() -> void:
    _panel_box.add_child(UIKit.label("Capacity per resource: %d" % Game.storage_cap(), 14, UIKit.TEXT))
    for res in EconomyDefs.RESOURCES:
        _panel_box.add_child(UIKit.label("%s: %d" % [EconomyDefs.RESOURCES[res]["name"], int(Game.hq_outputs.get(res, 0))], 13, UIKit.TEXT))
    _panel_box.add_child(UIKit.label("Equipment stash: %d / %d items (open a hero to equip)" % [Game.stash.size(), Game.stash_cap()], 14, UIKit.TEXT))


func _panel_hall() -> void:
    _panel_box.add_child(_wrap("Every other building can reach at most this level. Some buildings need a higher Hall to be built.", 13, UIKit.MUTED))
    var queue: Array = Game.construction.map(func(p): return "%s → Lv %d (%.0f h)" % [TownTables.info(String(p["bid"]))["name"], int(p["to"]), float(p["work_left"])])
    _panel_box.add_child(_wrap("Construction queue: " + (", ".join(queue) if not queue.is_empty() else "empty"), 13, UIKit.TEXT))
    _panel_workers("construction", 99)
    _panel_box.add_child(UIKit.label("Town log", 15, UIKit.ACCENT))
    var n := Game.town_log.size()
    for i in range(maxi(0, n - 8), n):
        _panel_box.add_child(_wrap(String(Game.town_log[i]), 12, UIKit.MUTED))


func _panel_jobs(id: String) -> void:
    var current := Game.job_of(id)
    var row := HFlowContainer.new()
    for rid in TownTables.info(id)["jobs"]:
        var r: Dictionary = EconomyDefs.RECIPES[rid]
        if r.get("service", false):
            continue
        var recipe := String(rid)
        var btn := _small_btn(("● " if recipe == current else "") + String(r["name"]), func(): Game.set_job(id, recipe), 150.0)
        btn.tooltip_text = "%s → %s. %s level %d+, %.0f work-hours." % [_res_text(r["in"]), (_res_text(r["out"]) if not r.has("item") else "a %s" % r["item"]),
            ProfessionDefs.info(String(r["prof"]))["name"], int(r["min"]), float(r["work"])]
        row.add_child(btn)
    if row.get_child_count() > 0:
        _panel_box.add_child(UIKit.label("Job", 15, UIKit.ACCENT))
        _panel_box.add_child(row)
        var cr: Dictionary = EconomyDefs.RECIPES[current]
        _panel_box.add_child(_wrap("%s: %s → %s" % [cr["name"], _res_text(cr["in"]), (_res_text(cr["out"]) if not cr.has("item") else "a %s (quality from smith and forge level)" % cr["item"])], 13, UIKit.TEXT))
        var bt: Dictionary = Game.town_batches.get(id, {})
        if not bt.is_empty():
            _panel_box.add_child(UIKit.label("In progress: %.1f / %.0f work-hours" % [float(bt["progress"]), float(EconomyDefs.RECIPES[String(bt["recipe"])]["work"])], 13, UIKit.TEXT))
    var problem := String(Game.town_problems.get(id, ""))
    if problem != "":
        _panel_box.add_child(_wrap("Problem: " + problem, 13, Color(1.0, 0.6, 0.5)))


func _res_text(d: Dictionary) -> String:
    if d.is_empty():
        return "nothing"
    var parts: Array = []
    for k in d:
        parts.append("%d %s" % [int(d[k]), String(EconomyDefs.RESOURCES[k]["name"]).to_lower()])
    return ", ".join(parts)


## Workers of a workplace (or the construction crew) with remove buttons, then candidates to assign.
func _panel_workers(id: String, slots: int) -> void:
    var prof := Game.workplace_prof(id)
    var here := Game.workers_at(id)
    _panel_box.add_child(UIKit.label(("Builders" if id == "construction" else "Workers") + (" %d / %d" % [here.size(), slots] if slots < 99 else " %d" % here.size()), 15, UIKit.ACCENT))
    for h in here:
        var hd := h as HeroData
        var row := HBoxContainer.new()
        row.add_child(_wrap("%s — %s Lv %d · %s" % [hd.hero_name.split(" ")[0], ProfessionDefs.info(prof).get("name", prof), hd.prof_level(prof), hd.activity_state], 13, UIKit.TEXT))
        (row.get_child(0) as Label).custom_minimum_size = Vector2(125, 0)  # px
        row.add_child(_small_btn("Remove", func(): Game.assign_work(hd, "")))
        _panel_box.add_child(row)
    if here.size() >= slots:
        return
    var cands: Array = Game.heroes.values().filter(func(h): return (h as HeroData).hq_assignment != id)
    cands.sort_custom(func(a, b): return a.prof_level(prof) > b.prof_level(prof))
    for i in mini(5, cands.size()):
        var hd := cands[i] as HeroData
        var lvl := hd.prof_level(prof)
        var note := ("%s Lv %d" % [ProfessionDefs.info(prof).get("name", prof), lvl]) if lvl >= 0 else ("can learn it" if hd.professions.size() < ProfessionDefs.MAX_KNOWN else "knows 2 professions")
        var row := HBoxContainer.new()
        row.add_child(_wrap("%s (%s)%s" % [hd.hero_name.split(" ")[0], note, " · now: " + hd.hq_assignment if hd.hq_assignment != "" else ""], 13, UIKit.MUTED))
        (row.get_child(0) as Label).custom_minimum_size = Vector2(125, 0)  # px
        var b := _small_btn("Assign", func(): Game.assign_work(hd, id))
        b.disabled = lvl < 0 and hd.professions.size() >= ProfessionDefs.MAX_KNOWN
        row.add_child(b)
        _panel_box.add_child(row)


# --- build menu: new buildings go wherever the player places them (owner, 2026-10-31) -----------

## Buildings that are not built yet, each with its price and whatever stops it right now.
func show_build_menu() -> void:
    select_building("")
    for c in _panel_box.get_children():
        c.queue_free()
    var head := HBoxContainer.new()
    head.add_child(UIKit.label("Build", 20, UIKit.ACCENT))
    var sp := Control.new()
    sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(sp)
    var close := UIKit.button("x", func(): _panel.visible = false, Vector2(32, 30))
    close.focus_mode = Control.FOCUS_NONE
    head.add_child(close)
    _panel_box.add_child(head)
    _panel_box.add_child(_wrap("Pick a building, then click where it goes (near the town). Builders raise it over time.", 13, UIKit.MUTED))
    if Game.builders().is_empty():
        _panel_box.add_child(_wrap("No builder at work: assign one at the Summoner's Hall.", 13, Color(1.0, 0.8, 0.5)))
    for id in TownTables.ids():
        if Game.is_placed(id):
            continue
        var b := TownTables.info(id)
        var why := Game.construction_block(id)
        var btn := UIKit.button("%s  (%d materials)" % [String(b["name"]), Game.next_building_cost(id)], start_place.bind(id), Vector2(320, 34))
        btn.focus_mode = Control.FOCUS_NONE
        btn.disabled = why != ""
        btn.tooltip_text = String(b["desc"]) + ("" if why == "" else "\nCannot start: " + why)
        _panel_box.add_child(btn)
        if why != "":
            _panel_box.add_child(_wrap("   " + why, 12, Color(1.0, 0.6, 0.5)))
    _panel.visible = true


func start_place(id: String) -> void:
    _panel.visible = false
    placing_new = true
    moving = id
    view.ghost_id = id
    _move_msg.text = "Building the %s: click a spot near the town (green = valid). Right-click or Esc to cancel." % TownTables.info(id)["name"]


# --- move mode (D-050) ------------------------------------------------------------------------

func start_move(id: String) -> void:
    moving = id
    select_building("")
    view.ghost_id = id
    _move_msg.text = "Placing the %s: click a spot (green = valid). Right-click or Esc to cancel." % TownTables.info(id)["name"]


func cancel_move() -> void:
    moving = ""
    placing_new = false
    if view != null:
        view.ghost_id = ""
    _move_msg.text = ""


## Places the building being moved with its top-left at the cell under `world`. Returns the reason
## when it cannot go there ("" = moved).
func place_at(world: Vector2) -> String:
    var cell := _ghost_cell(world)
    var why := Game.place_and_build(moving, cell) if placing_new else Game.move_building(moving, cell)
    if why == "":
        cancel_move()
        rebuild()
    else:
        _move_msg.text = "Cannot place it there: " + why
    return why


func _ghost_cell(world: Vector2) -> Vector2i:
    var p := map.plot_of(moving)
    return map.cell_of(world) - Vector2i(p.size.x / 2, p.size.y / 2)


func _on_transcribe(id: String, class_id: String) -> void:
    Game.library_transcribe(class_id)
    _show_panel(id)


func _add_tower_buttons() -> void:
    var train := UIKit.button("Training ground (fixed map)", func(): navigate.emit("sandbox", 0), Vector2(300, 38))
    train.focus_mode = Control.FOCUS_NONE
    _panel_box.add_child(train)
    # vertical slice: floors 1-5, each known before entering (mission, difficulty, squad size, what it is)
    for f in range(1, TowerExpedition.SLICE_FLOORS + 1):
        var floor_num := f
        var cfg := TowerExpedition.get_floor_config(f)
        var done := int(Game.tower_cleared.get(str(f), 0))
        var btn := UIKit.button("%s  ·  %s  ·  %s%s" % [String(cfg["name"]), String(cfg["mission"]).capitalize(), String(cfg["difficulty"]),
            "  ✓" if done > 0 else ""], func(): navigate.emit("sandbox", floor_num), Vector2(320, 32))
        btn.focus_mode = Control.FOCUS_NONE
        btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
        btn.tooltip_text = "%s
Recommended: %d heroes. Explored: %s" % [String(cfg.get("intro", "")), TowerExpedition.RECOMMENDED_HEROES,
            "yes" if Game.floor_explored(f) != "" else "not yet"]
        _panel_box.add_child(btn)
    var grid := GridContainer.new()
    grid.columns = 5
    _panel_box.add_child(grid)
    for f in range(TowerExpedition.SLICE_FLOORS + 1, 11):
        var floor_num := f
        var btn := UIKit.button("F%d" % f, func(): navigate.emit("sandbox", floor_num), Vector2(56, 30))
        btn.focus_mode = Control.FOCUS_NONE
        btn.tooltip_text = String(TowerExpedition.get_floor_config(f)["name"]) + " (beyond the demo: not tuned yet)"
        grid.add_child(btn)
    if Game.party_heroes().size() < Game.PARTY_SIZE:
        var warn := UIKit.label("Party not full: a test squad will go instead and nothing is kept (Menu -> Party, or the War Room).", 13, Color(1.0, 0.7, 0.5))
        warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        warn.custom_minimum_size = Vector2(150, 0)  # px
        _panel_box.add_child(warn)


# --- input -----------------------------------------------------------------------------

func screen_to_world(p: Vector2) -> Vector2:
    var vsize := Vector2(_viewport.size)
    return camera.position + (p - vsize * 0.5) / camera.zoom.x


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT:
            if mb.pressed:
                _dragging = true
                _moved = false
                _drag_from = mb.position
                _cam_from = camera.position
            else:
                _dragging = false
                if not _moved:
                    if moving != "":
                        place_at(screen_to_world(mb.position))
                    else:
                        click_at(screen_to_world(mb.position))
        elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and moving != "":
            cancel_move()
        elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom(1.1)
        elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom(1.0 / 1.1)
    elif event is InputEventMouseMotion:
        var mm := event as InputEventMouseMotion
        if _dragging and (mm.position - _drag_from).length() > 6.0:
            _moved = true
            camera.position = _clamp_cam(_cam_from - (mm.position - _drag_from) / camera.zoom.x)
        _update_hover(screen_to_world(mm.position))
        if moving != "" and view != null:
            view.ghost_cell = _ghost_cell(screen_to_world(mm.position))
            view.ghost_ok = Game.placement_block(moving, view.ghost_cell) == "" and (not placing_new or Game.construction_block(moving) == "")


func click_at(world: Vector2) -> void:
    if map == null:
        return
    var th := hero_at(world)
    if th != null:
        open_hero(th)
        return
    select_building(map.building_at(map.cell_of(world)))


## Visible town hero under a world point (feet at the node origin, body ~30 px above).
func hero_at(world: Vector2) -> TownHero:
    var best: TownHero = null
    var best_d := 22.0
    for th in heroes:
        if not th.visible:
            continue
        var d := (th.position + Vector2(0, -14)).distance_to(world)
        if d < best_d:
            best_d = d
            best = th
    return best


## Opens the hero panel (equipment, colours, stats, personality, bonds, memories).
func open_hero(th: TownHero) -> void:
    close_hero()
    selected_hero_id = th.hero.id
    hero_panel = HeroInfoPanel.new(th.hero, th.activity_text())
    hero_panel.position = Vector2(6, 26)  # px
    hero_panel.closed.connect(close_hero)
    hero_panel.open_barracks.connect(func(): navigate.emit("roster", 0))
    add_child(hero_panel)


func close_hero() -> void:
    if hero_panel != null and is_instance_valid(hero_panel):
        hero_panel.queue_free()
    hero_panel = null
    selected_hero_id = ""


func _update_hover(world: Vector2) -> void:
    if map == null or view == null:
        return
    view.hovered = map.building_at(map.cell_of(world))
    for th in heroes:
        th.hovered = th.position.distance_to(world + Vector2(0, 16)) < 20.0
        th.queue_redraw()


func _zoom(f: float) -> void:
    var z := camera.zoom.x
    var next := z
    if f > 1.0:
        for s in ZOOM_STEPS:
            if float(s) > z + 0.01:
                next = float(s)
                break
    else:
        for i in range(ZOOM_STEPS.size() - 1, -1, -1):
            if float(ZOOM_STEPS[i]) < z - 0.01:
                next = float(ZOOM_STEPS[i])
                break
    camera.zoom = Vector2.ONE * clampf(next, ZOOM_MIN, ZOOM_MAX)
    camera.position = _clamp_cam(camera.position)


func _clamp_cam(p: Vector2) -> Vector2:
    if map == null:
        return p
    var ws := map.world_size()
    return Vector2(clampf(p.x, 0.0, ws.x), clampf(p.y, 0.0, ws.y))


func _unhandled_key_input(event: InputEvent) -> void:
    if moving != "" and event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
        cancel_move()
