class_name PartyScreen
extends Control
## Formation editor: 3 front-row slots, 2 back-row slots. Pick a slot, then click a hero.

signal back_requested

var _slot_box: HBoxContainer
var _grid: GridContainer
var _power: Label
var _hint: Label
var _selected_slot: int = 0
var _group := ButtonGroup.new()


func _ready() -> void:
    var margin := UIKit.margin(20)
    add_child(margin)
    UIKit.fill(margin)
    var root := VBoxContainer.new()
    margin.add_child(root)

    var header := HBoxContainer.new()
    header.add_child(UIKit.button("< Back", func(): back_requested.emit(), Vector2(110, 40)))
    header.add_child(UIKit.label("Party Formation", 32, UIKit.ACCENT))
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(spacer)
    _power = UIKit.label("", 20, UIKit.TEXT)
    header.add_child(_power)
    header.add_child(UIKit.button("Clear all", func(): Game.clear_party(), Vector2(110, 40)))
    root.add_child(header)

    _hint = UIKit.label("Pick a slot, then click a hero from the list. Right-click a slot to empty it.", 15, UIKit.MUTED)
    root.add_child(_hint)

    var body := HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(body)

    var left := PanelContainer.new()
    left.custom_minimum_size = Vector2(430, 0)
    body.add_child(left)
    _slot_box = HBoxContainer.new()
    _slot_box.alignment = BoxContainer.ALIGNMENT_CENTER
    _slot_box.add_theme_constant_override("separation", 24)
    left.add_child(_slot_box)

    var scroll := ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(scroll)
    _grid = GridContainer.new()
    _grid.columns = 4
    _grid.add_theme_constant_override("h_separation", 10)
    _grid.add_theme_constant_override("v_separation", 10)
    scroll.add_child(_grid)

    Game.changed.connect(_rebuild)
    _rebuild()


func _rebuild() -> void:
    for c in _slot_box.get_children():
        c.queue_free()
    for c in _grid.get_children():
        c.queue_free()

    # Back row on the left, front row on the right (enemies would be further right).
    var back := _column("BACK ROW", [3, 4])
    var front := _column("FRONT ROW", [0, 1, 2])
    _slot_box.add_child(back)
    _slot_box.add_child(front)

    var power := 0
    for h in Game.party_heroes():
        power += h.power()
    _power.text = "Party power: %d    (%d / %d)" % [power, Game.party_heroes().size(), Game.PARTY_SIZE]

    var list: Array = Game.heroes.values()
    list.sort_custom(func(a, b): return a.stars > b.stars or (a.stars == b.stars and a.level > b.level))
    for h in list:
        var card := HeroCard.new(h)
        if Game.party_slot_of(h.id) >= 0:
            card.modulate = Color(1, 1, 1, 0.45)
        card.card_pressed.connect(_on_hero)
        _grid.add_child(card)


func _column(title: String, slots: Array) -> VBoxContainer:
    var col := VBoxContainer.new()
    col.alignment = BoxContainer.ALIGNMENT_CENTER
    col.add_child(UIKit.label(title, 15, UIKit.MUTED))
    for i in slots:
        var id: String = Game.party[i]
        var h: HeroData = Game.heroes[id] if Game.heroes.has(id) else null
        var slot := PartySlot.new(i, h, title.capitalize())
        slot.button_group = _group
        slot.button_pressed = (i == _selected_slot)
        slot.pressed.connect(func(): _selected_slot = i)
        slot.clear_requested.connect(func(idx): Game.clear_slot(idx))
        col.add_child(slot)
    return col


func _on_hero(h: HeroData) -> void:
    Game.assign_party(_selected_slot, h.id)
    # move on to the next empty slot, if any
    for step in range(1, Game.PARTY_SIZE + 1):
        var nxt := (_selected_slot + step) % Game.PARTY_SIZE
        if Game.party[nxt] == "":
            _selected_slot = nxt
            break
    _rebuild()
