class_name MainMenu
extends Control
## Title screen with navigation and a few debug buttons for testing.

signal navigate(screen: String)

var _summary: Label


func _ready() -> void:
    var center := CenterContainer.new()
    add_child(center)
    UIKit.fill(center)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 12)
    center.add_child(vb)

    var title := UIKit.label("TACTICAL SUMMONERS", 52, UIKit.ACCENT)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vb.add_child(title)
    var sub := UIKit.label("Drop C  -  Summoning, real-time missions, permanent death", 18, UIKit.MUTED)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vb.add_child(sub)
    vb.add_child(Control.new())

    vb.add_child(UIKit.button("Summon", func(): navigate.emit("summon"), Vector2(360, 56)))
    vb.add_child(UIKit.button("Roster", func(): navigate.emit("roster"), Vector2(360, 56)))
    vb.add_child(UIKit.button("Party", func(): navigate.emit("party"), Vector2(360, 56)))
    vb.add_child(UIKit.button("Memorial  (fallen heroes)", func(): navigate.emit("memorial"), Vector2(360, 56)))
    vb.add_child(UIKit.button("Sandbox  (real-time control test)", func(): navigate.emit("sandbox"), Vector2(360, 56)))
    vb.add_child(UIKit.button("Living Headquarters", func(): navigate.emit("hq"), Vector2(360, 56)))

    _summary = UIKit.label("", 16, UIKit.MUTED)
    _summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vb.add_child(_summary)

    var dbg := HBoxContainer.new()
    dbg.alignment = BoxContainer.ALIGNMENT_CENTER
    dbg.add_child(UIKit.label("Debug:", 14, UIKit.MUTED))
    dbg.add_child(UIKit.button("+1000 gems", func(): Game.grant(1000, 0, 0)))
    dbg.add_child(UIKit.button("+10 stones", func(): Game.grant(0, 10, 0)))
    dbg.add_child(UIKit.button("+10 books", func(): Game.grant(0, 0, 10)))
    dbg.add_child(UIKit.button("Reset save", _ask_reset))
    vb.add_child(dbg)

    Game.changed.connect(_refresh)
    _refresh()


func _refresh() -> void:
    _summary.text = "%d heroes   |   party %d / %d" % [Game.heroes.size(), Game.party_heroes().size(), Game.PARTY_SIZE]


func _ask_reset() -> void:
    var dlg := ConfirmationDialog.new()
    dlg.dialog_text = "Delete all heroes and progress?"
    dlg.confirmed.connect(func(): Game.new_game())
    add_child(dlg)
    dlg.popup_centered()
