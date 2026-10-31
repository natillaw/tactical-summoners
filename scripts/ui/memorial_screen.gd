class_name MemorialScreen
extends Control
## Read-only list of fallen heroes (T-013). Entries come from Game.memorial and are never edited.

signal back_requested


static func entry_text(m: Dictionary) -> String:
    var cls: String = String(HeroTables.CLASSES.get(String(m.get("class", "class.none")), HeroTables.CLASSES["class.none"])["name"])
    var lines: Array = []
    lines.append("#%d  %s  -  %d-star %s, Lv %d" % [int(m.get("n", 0)), m.get("name", "?"), int(m.get("stars", 1)), cls, int(m.get("level", 1))])
    var cause := String(m.get("cause", ""))
    var mission := String(m.get("mission", ""))
    if cause != "" or mission != "":
        lines.append("    %s%s" % [cause, "  (%s)" % mission if mission != "" else ""])
    var bg := String(m.get("background", ""))
    if bg != "":
        lines.append("    %s" % bg)
    return "\n".join(lines)


func _ready() -> void:
    var m := UIKit.margin(16)
    add_child(m)
    UIKit.fill(m)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 5)  # px
    m.add_child(vb)
    var top := HBoxContainer.new()
    vb.add_child(top)
    top.add_child(UIKit.button("< Back", func(): back_requested.emit(), Vector2(100, 36)))
    top.add_child(UIKit.label("   Memorial - %d fallen" % Game.memorial.size(), 22, UIKit.ACCENT))
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vb.add_child(scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 6)  # px
    scroll.add_child(list)
    if Game.memorial.is_empty():
        list.add_child(UIKit.label("No hero has fallen yet.", 16, UIKit.MUTED))
        return
    for i in range(Game.memorial.size() - 1, -1, -1):        # newest first
        var l := UIKit.label(entry_text(Game.memorial[i]), 15, UIKit.TEXT)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.custom_minimum_size = Vector2(350, 0)  # px
        list.add_child(l)
