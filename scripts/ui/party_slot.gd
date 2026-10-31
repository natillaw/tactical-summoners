class_name PartySlot
extends Button
## One formation slot. Left click selects it, right click empties it.

signal clear_requested(index: int)

var index: int = 0
var hero: HeroData = null
var row_name: String = ""


func _init(i: int = 0, h: HeroData = null, row: String = "") -> void:
    index = i
    hero = h
    row_name = row
    toggle_mode = true
    custom_minimum_size = Vector2(85, 75)  # px


func _ready() -> void:
    gui_input.connect(_on_gui_input)
    var vb := VBoxContainer.new()
    vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vb.alignment = BoxContainer.ALIGNMENT_CENTER
    vb.add_theme_constant_override("separation", 1)  # px
    add_child(vb)
    UIKit.fill(vb)
    if hero == null:
        var e := UIKit.label("Empty", 18, UIKit.MUTED)
        e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        e.mouse_filter = Control.MOUSE_FILTER_IGNORE
        vb.add_child(e)
        var r := UIKit.label(row_name, 13, UIKit.MUTED)
        r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        r.mouse_filter = Control.MOUSE_FILTER_IGNORE
        vb.add_child(r)
        return
    var portrait := HeroPortrait.new(hero, 2.0)
    portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    vb.add_child(portrait)
    var n := UIKit.label(hero.hero_name, 13, hero.star_color())
    n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    n.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vb.add_child(n)
    var s := StarRow.new(hero.stars, 12.0, hero.star_color())
    s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    vb.add_child(s)


func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        clear_requested.emit(index)
