extends Control
## Root of the game. Builds the background, the currency bar and swaps screens.

var _content: Control
var _currency: Label


func _ready() -> void:
    theme = UIKit.make_theme()
    ThemeDB.fallback_font = UIKit.body_font()          # world text (bars, names, floating numbers) in m5x7 too
    ThemeDB.fallback_font_size = UIKit.BODY

    var bg := ColorRect.new()
    bg.color = UIKit.BG
    add_child(bg)
    UIKit.fill(bg)

    var bar := PanelContainer.new()
    bar.custom_minimum_size = Vector2(0, 20)       # 640x360 base (D-063)
    add_child(bar)
    bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    var hb := HBoxContainer.new()
    bar.add_child(hb)
    hb.add_child(UIKit.label("Tactical Summoners", 14, UIKit.MUTED))
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hb.add_child(spacer)
    _currency = UIKit.label("", 14, UIKit.ACCENT)
    hb.add_child(_currency)

    _content = Control.new()
    add_child(_content)
    _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _content.offset_top = 22

    Game.changed.connect(_refresh_currency)
    _refresh_currency()
    # a new account starts with the welcome and its first summons; everyone else lands in the town (D-030)
    show_screen("welcome" if Game.heroes.is_empty() and not Game.onboarded else "town")


func _refresh_currency() -> void:
    _currency.text = "Gems %d     Stones %d     Books %d" % [Game.gems, Game.stones, Game.books]


func show_screen(screen: String, arg: int = 0) -> void:
    for c in _content.get_children():
        c.queue_free()
    var back := show_screen.bind("town", 0)
    var s: Control
    match screen:
        "summon":
            s = SummonScreen.new()
            s.back_requested.connect(back)
        "roster":
            s = RosterScreen.new()
            s.back_requested.connect(back)
        "party":
            s = PartyScreen.new()
            s.back_requested.connect(back)
        "memorial":
            s = MemorialScreen.new()
            s.back_requested.connect(back)
        "sandbox":
            s = SandboxScreen.new(arg)          # 0 = training ground, 1-10 = tower floors
            s.back_requested.connect(back)
        "hq":
            var hq_screen := HQScreen.new()
            hq_screen.back_requested.connect(back)
            hq_screen.explore_requested.connect(back)
            s = hq_screen
        "welcome":
            var w := WelcomeScreen.new()
            w.finished.connect(back)
            s = w
        "menu":
            var menu := MainMenu.new()
            menu.navigate.connect(func(to: String): show_screen(to, 0))
            s = menu
        _:
            var town := TownScreen.new()
            town.navigate.connect(show_screen)
            s = town
    _content.add_child(s)
    UIKit.fill(s)
