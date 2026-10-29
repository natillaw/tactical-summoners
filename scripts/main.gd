extends Control
## Root of the game. Builds the background, the currency bar and swaps screens.

var _content: Control
var _currency: Label


func _ready() -> void:
    theme = UIKit.make_theme()

    var bg := ColorRect.new()
    bg.color = UIKit.BG
    add_child(bg)
    UIKit.fill(bg)

    var bar := PanelContainer.new()
    bar.custom_minimum_size = Vector2(0, 46)
    add_child(bar)
    bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    var hb := HBoxContainer.new()
    bar.add_child(hb)
    hb.add_child(UIKit.label("Tactical Summoners", 18, UIKit.MUTED))
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hb.add_child(spacer)
    _currency = UIKit.label("", 18, UIKit.ACCENT)
    hb.add_child(_currency)

    _content = Control.new()
    add_child(_content)
    _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _content.offset_top = 50

    Game.changed.connect(_refresh_currency)
    _refresh_currency()
    show_screen("menu")


func _refresh_currency() -> void:
    _currency.text = "Gems %d     Stones %d     Books %d" % [Game.gems, Game.stones, Game.books]


func show_screen(screen: String) -> void:
    for c in _content.get_children():
        c.queue_free()
    var s: Control
    match screen:
        "summon":
            s = SummonScreen.new()
            s.back_requested.connect(show_screen.bind("menu"))
        "roster":
            s = RosterScreen.new()
            s.back_requested.connect(show_screen.bind("menu"))
        "party":
            s = PartyScreen.new()
            s.back_requested.connect(show_screen.bind("menu"))
        "memorial":
            s = MemorialScreen.new()
            s.back_requested.connect(show_screen.bind("menu"))
        "sandbox":
            s = SandboxScreen.new()
            s.back_requested.connect(show_screen.bind("menu"))
        _:
            s = MainMenu.new()
            s.navigate.connect(show_screen)
    _content.add_child(s)
    UIKit.fill(s)
