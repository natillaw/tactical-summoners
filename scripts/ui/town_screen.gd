class_name TownScreen
extends Control
## The town is the first screen of the game (D-030). Everything starts from a building:
## click it to enter (summon, roster, party, tower, memorial, town hall) or to build / upgrade it.
## Drag to pan, mouse wheel to zoom. Heroes walk around on their own.

signal navigate(screen: String, arg: int)

const ZOOM_MIN := 0.6
const ZOOM_MAX := 2.0

var map: TownMap
var view: TownView
var camera: Camera2D
var heroes: Array[TownHero] = []
var selected: String = ""

var _viewport: SubViewport
var _world: Node2D
var _res: Label
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _drag_from: Vector2 = Vector2.ZERO
var _cam_from: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _moved: bool = false


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
    map = TownMap.new(Game.town_buildings)
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
    if camera.position == Vector2.ZERO:
        # first view: the whole town fits on screen
        var ws := map.world_size()
        var vs := Vector2(_viewport.size) if _viewport.size.x > 0 else Vector2(1280, 670)
        camera.zoom = Vector2.ONE * clampf(minf(vs.x / ws.x, vs.y / ws.y), ZOOM_MIN, ZOOM_MAX)
        camera.position = ws * 0.5
    _refresh()


func _on_changed() -> void:
    var count_changed := heroes.size() != Game.heroes.size()
    if count_changed or map == null or _levels_changed():
        rebuild()
    else:
        _refresh()


func _levels_changed() -> bool:
    for id in TownTables.ids():
        var built := Game.building_level(id) > 0
        var plot: Rect2i = TownTables.info(id)["plot"]
        if built != map.is_blocked_cell(plot.position):
            return true
    return false


func _build_ui() -> void:
    var top := HBoxContainer.new()
    top.position = Vector2(12, 8)
    top.add_theme_constant_override("separation", 10)
    add_child(top)
    var menu_btn := UIKit.button("Menu", func(): navigate.emit("menu", 0), Vector2(90, 34))
    menu_btn.focus_mode = Control.FOCUS_NONE
    top.add_child(menu_btn)
    var res_panel := PanelContainer.new()
    top.add_child(res_panel)
    _res = UIKit.label("", 15, UIKit.ACCENT)
    res_panel.add_child(_res)

    var hint := UIKit.label("Click a building to enter, build or upgrade it    Drag to move    Wheel to zoom", 14, UIKit.MUTED)
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    hint.position += Vector2(14, -30)
    add_child(hint)

    _panel = PanelContainer.new()
    _panel.custom_minimum_size = Vector2(330, 0)
    _panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    _panel.position = Vector2(-342, 8)
    _panel.visible = false
    add_child(_panel)
    _panel_box = VBoxContainer.new()
    _panel_box.add_theme_constant_override("separation", 8)
    _panel.add_child(_panel_box)


func _refresh() -> void:
    _res.text = "Materials %d   Food %d   Medicine %d   Heroes %d / %d" % [
        int(Game.hq_outputs.get("materials", 0)), int(Game.hq_outputs.get("food", 0)),
        int(Game.hq_outputs.get("medicine", 0)), Game.heroes.size(), Game.max_hero_capacity()]
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
    desc.custom_minimum_size = Vector2(300, 0)
    _panel_box.add_child(desc)
    var produces: Dictionary = b.get("produces", {})
    if not produces.is_empty():
        var parts: Array = []
        for res in produces:
            parts.append("+%d %s" % [int(produces[res]) * maxi(1, level), res])
        _panel_box.add_child(UIKit.label("Per worker each turn: " + ", ".join(parts), 14, UIKit.TEXT))
    var workers: Array = []
    for hid in Game.heroes:
        if (Game.heroes[hid] as HeroData).hq_assignment == id:
            workers.append((Game.heroes[hid] as HeroData).hero_name.split(" ")[0])
    if not workers.is_empty():
        _panel_box.add_child(UIKit.label("Workers: " + ", ".join(workers), 14, UIKit.TEXT))
    if level > 0 and String(b["open"]) == "tower":
        _add_tower_buttons()
    elif level > 0 and String(b["open"]) != "":
        var open_screen := String(b["open"])
        var enter := UIKit.button("Enter", func(): navigate.emit(open_screen, 0), Vector2(300, 40))
        enter.focus_mode = Control.FOCUS_NONE
        _panel_box.add_child(enter)
    var cost := Game.next_building_cost(id)
    if cost >= 0:
        var label := ("Build (%d materials)" if level == 0 else "Upgrade to Lv %d (%%d materials)" % (level + 1)) % cost
        var up := UIKit.button(label, func(): Game.build_or_upgrade(id), Vector2(300, 40))
        up.focus_mode = Control.FOCUS_NONE
        up.disabled = int(Game.hq_outputs.get("materials", 0)) < cost
        _panel_box.add_child(up)
    _panel.visible = true


func _add_tower_buttons() -> void:
    var train := UIKit.button("Training ground (fixed map)", func(): navigate.emit("sandbox", 0), Vector2(300, 38))
    train.focus_mode = Control.FOCUS_NONE
    _panel_box.add_child(train)
    var grid := GridContainer.new()
    grid.columns = 5
    _panel_box.add_child(grid)
    for f in range(1, 11):
        var floor_num := f
        var btn := UIKit.button("F%d" % f, func(): navigate.emit("sandbox", floor_num), Vector2(56, 34))
        btn.focus_mode = Control.FOCUS_NONE
        btn.tooltip_text = String(TowerExpedition.get_floor_config(f)["name"])
        grid.add_child(btn)
    if Game.party_heroes().size() < Game.PARTY_SIZE:
        var warn := UIKit.label("Party not full: a test squad will go instead (War Room).", 13, UIKit.MUTED)
        warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        warn.custom_minimum_size = Vector2(300, 0)
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
                    click_at(screen_to_world(mb.position))
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


func click_at(world: Vector2) -> void:
    if map == null:
        return
    select_building(map.building_at(map.cell_of(world)))


func _update_hover(world: Vector2) -> void:
    if map == null or view == null:
        return
    view.hovered = map.building_at(map.cell_of(world))
    for th in heroes:
        th.hovered = th.position.distance_to(world + Vector2(0, 16)) < 20.0
        th.queue_redraw()


func _zoom(f: float) -> void:
    camera.zoom = Vector2.ONE * clampf(camera.zoom.x * f, ZOOM_MIN, ZOOM_MAX)
    camera.position = _clamp_cam(camera.position)


func _clamp_cam(p: Vector2) -> Vector2:
    if map == null:
        return p
    var ws := map.world_size()
    return Vector2(clampf(p.x, 0.0, ws.x), clampf(p.y, 0.0, ws.y))
