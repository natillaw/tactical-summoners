class_name UIKit
extends RefCounted
## Small helpers so screens stay short: colours, the pixel Theme, labels, buttons (D-063).
## The game renders at a 640x360 base scaled by a whole number (x2 720p, x3 1080p, x4 1440p). Screens
## were laid out in 1280x720 "design units": UIKit converts them (px), and text always uses the pixel
## fonts at their native sizes (m5x7 for body text, m6x11 for titles), never a fractional size.

const BG := ArtPalette.INK
const PANEL := ArtPalette.PANEL
const PANEL_LIGHT := ArtPalette.PANEL_LIGHT
const ACCENT := ArtPalette.TEXT_ACCENT
const TEXT := ArtPalette.TEXT
const MUTED := ArtPalette.TEXT_MUTED
const GOOD := ArtPalette.TEXT_GOOD
const BAD := ArtPalette.TEXT_BAD

const DESIGN_SCALE := 0.5          # 1280x720 design units -> 640x360 base pixels
const BODY := 16                   # m5x7 native size (1 font pixel = 1 base pixel)
const TITLE := 16                  # m6x11 native size
const TITLE_BIG := 32              # m6x11 x2 (screen titles)

static var _body: Font = null
static var _title: Font = null


## The audio autoloads looked up at run time (scripts run with --script have no autoloads): nothing
## happens when they are absent (headless tests, tools).
static func audio(autoload_name: String = "UiSfx") -> Node:
    var tree := Engine.get_main_loop() as SceneTree
    return tree.root.get_node_or_null(autoload_name) if tree != null and tree.root != null else null


static func sound(id: String) -> void:
    var a := audio("UiSfx")
    if a != null:
        a.call("play", id)


static func music(role: String) -> void:
    var a := audio("Music")
    if a != null:
        a.call("play_track", role)


static func get_volume(bus: String) -> float:
    var a := audio("UiSfx")
    return float(a.call("get_volume", bus)) if a != null else 1.0


static func set_volume(bus: String, v: float) -> void:
    var a := audio("UiSfx")
    if a != null:
        a.call("set_volume", bus, v)


## A design-unit length in base pixels (whole pixels only).
static func px(v: float) -> int:
    return roundi(v * DESIGN_SCALE)


static func pv(v: Vector2) -> Vector2:
    return Vector2(px(v.x), px(v.y))


## Pixel font size for a requested design size: small and normal text -> body, headings -> title.
static func fpx(design_size: int) -> int:
    return TITLE_BIG if design_size >= 28 else BODY


static func body_font() -> Font:
    if _body == null:
        _body = _pixel_font(AssetCatalog.FONT_BODY)
    return _body


static func title_font() -> Font:
    if _title == null:
        _title = _pixel_font(AssetCatalog.FONT_TITLE)
    return _title


static func _pixel_font(path: String) -> Font:
    if not ResourceLoader.exists(path):
        return ThemeDB.fallback_font
    var f := load(path) as FontFile
    if f == null:
        return ThemeDB.fallback_font
    f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
    f.hinting = TextServer.HINTING_NONE
    f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
    f.oversampling = 1.0
    return f


static func _tex(path: String) -> Texture2D:
    return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Nine-slice stylebox from a texture (frame `idx` of a horizontal sheet of frames `frame_w` wide).
static func nine(path: String, margin: int, frame_w: int = 0, idx: int = 0, content: int = 4) -> StyleBox:
    var tex := _tex(path)
    if tex == null:
        return box(PANEL, ArtPalette.PANEL_RIM, 1, 0, content)
    var s := StyleBoxTexture.new()
    s.texture = tex
    if frame_w > 0:
        s.region_rect = Rect2(idx * frame_w, 0, frame_w, tex.get_height())
    s.set_texture_margin_all(margin)
    s.set_content_margin_all(content)
    return s


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), border_w: int = 0, radius: int = 0, p_margin: int = 4) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(border_w)
    s.set_corner_radius_all(radius)
    s.set_content_margin_all(p_margin)
    s.anti_aliasing = false
    return s


## The one Theme of the game: kit panels, Dragon Regalia buttons, pixel fonts, palette colours.
static func make_theme() -> Theme:
    var t := Theme.new()
    t.default_font = body_font()
    t.default_font_size = BODY
    var ui: Dictionary = AssetCatalog.UI
    var panel := nine(String(ui["panel"][0]), 4, 0, 0, 6)
    t.set_stylebox("panel", "PanelContainer", panel)
    t.set_stylebox("panel", "Panel", panel)
    t.set_stylebox("panel", "PopupPanel", panel)
    t.set_stylebox("panel", "TooltipPanel", nine(String(ui["panel"][0]), 4, 0, 0, 4))
    t.set_color("font_color", "TooltipLabel", TEXT)
    t.set_font("font", "TooltipLabel", body_font())
    t.set_font_size("font_size", "TooltipLabel", BODY)
    for c in ["Label", "Button", "LineEdit", "CheckBox", "OptionButton", "TabBar"]:
        t.set_color("font_color", c, TEXT)
    t.set_color("font_hover_color", "Button", ArtPalette.GOLD[3])
    t.set_color("font_pressed_color", "Button", ArtPalette.GOLD[3])
    t.set_color("font_focus_color", "Button", TEXT)
    t.set_color("font_disabled_color", "Button", Color(TEXT_DISABLED))
    t.set_color("font_outline_color", "Label", ArtPalette.OUTLINE)
    var b: Array = ui["dragon_button"]
    # Dragon Regalia button sheet: 4 states side by side (rest, hover, pressed, disabled)
    t.set_stylebox("normal", "Button", nine(String(b[0]), 6, int(b[2]), 3, 4))
    t.set_stylebox("hover", "Button", nine(String(b[0]), 6, int(b[2]), 0, 4))
    t.set_stylebox("pressed", "Button", nine(String(b[0]), 6, int(b[2]), 2, 4))
    t.set_stylebox("hover_pressed", "Button", nine(String(b[0]), 6, int(b[2]), 2, 4))
    t.set_stylebox("disabled", "Button", box(Color(ArtPalette.PANEL, 0.9), ArtPalette.PANEL_RIM, 1, 0, 4))
    t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
    t.set_stylebox("background", "ProgressBar", nine(String(ui["bar_frame"][0]), 2, 0, 0, 1))
    t.set_stylebox("fill", "ProgressBar", box(ArtPalette.MANA, Color(0, 0, 0, 0), 0, 0, 0))
    t.set_stylebox("normal", "LineEdit", box(ArtPalette.INK, ArtPalette.PANEL_RIM, 1, 0, 3))
    t.set_stylebox("panel", "TabContainer", panel)
    t.set_stylebox("tab_selected", "TabContainer", box(ArtPalette.PANEL_LIGHT, ArtPalette.GOLD[2], 1, 0, 3))
    t.set_stylebox("tab_unselected", "TabContainer", box(ArtPalette.PANEL, ArtPalette.PANEL_RIM, 1, 0, 3))
    t.set_stylebox("tab_hovered", "TabContainer", box(ArtPalette.PANEL_LIGHT, ArtPalette.PANEL_RIM, 1, 0, 3))
    t.set_constant("separation", "VBoxContainer", 4)
    t.set_constant("separation", "HBoxContainer", 4)
    t.set_constant("h_separation", "GridContainer", 4)
    t.set_constant("v_separation", "GridContainer", 4)
    return t


const TEXT_DISABLED := Color(0.45, 0.43, 0.55)


## A label in the pixel fonts. size is a design size (old 1280x720 sizes): it picks body or title.
static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
    var l := Label.new()
    l.text = text
    var fs := fpx(size)
    if size >= 20:
        l.add_theme_font_override("font", title_font())
    l.add_theme_font_size_override("font_size", fs)
    l.add_theme_color_override("font_color", color)
    return l


## A button; min_size in design units.
static func button(text: String, callback: Callable, min_size: Vector2 = Vector2.ZERO) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = pv(min_size)
    b.pressed.connect(callback)
    b.mouse_entered.connect(func(): UIKit.sound("hover"))
    b.pressed.connect(func(): UIKit.sound("click"))
    return b


## A small square button with a 16 px icon (and a tooltip: icons never go unexplained).
static func icon_button(icon_path: String, tip: String, callback: Callable, size_px: int = 22) -> Button:
    var b := Button.new()
    b.icon = _tex(icon_path)
    b.tooltip_text = tip
    b.custom_minimum_size = Vector2(size_px, size_px)
    b.expand_icon = false
    b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    b.pressed.connect(callback)
    b.mouse_entered.connect(func(): UIKit.sound("hover"))
    b.pressed.connect(func(): UIKit.sound("click"))
    return b


static func icon(path: String, tip: String = "") -> TextureRect:
    var r := TextureRect.new()
    r.texture = _tex(path)
    r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
    r.tooltip_text = tip
    r.mouse_filter = Control.MOUSE_FILTER_PASS if tip != "" else Control.MOUSE_FILTER_IGNORE
    return r


## A labelled bar (HP, mana, XP, stamina): kit frame + kit fill, value text optional.
static func bar(kind: String, value: float, max_value: float, width: int = 60, show_value: bool = false) -> Control:
    var p := ProgressBar.new()
    p.min_value = 0.0
    p.max_value = maxf(1.0, max_value)
    p.value = value
    p.show_percentage = false
    p.custom_minimum_size = Vector2(width, 6)
    var fill := ArtPalette.HP
    match kind:
        "mana":
            fill = ArtPalette.MANA
        "xp":
            fill = ArtPalette.XP
        "stamina":
            fill = ArtPalette.STAMINA
    p.add_theme_stylebox_override("fill", box(fill, Color(0, 0, 0, 0), 0, 0, 0))
    if not show_value:
        return p
    var hb := HBoxContainer.new()
    hb.add_child(p)
    hb.add_child(label("%d/%d" % [roundi(value), roundi(max_value)], 12, MUTED))
    return hb


static func fill(c: Control) -> void:
    c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Margin container; px in design units.
static func margin(design_px: int) -> MarginContainer:
    var m := MarginContainer.new()
    var v := px(design_px)
    m.add_theme_constant_override("margin_left", v)
    m.add_theme_constant_override("margin_right", v)
    m.add_theme_constant_override("margin_top", v)
    m.add_theme_constant_override("margin_bottom", v)
    return m


## A short message that slides in at the top and fades (orders refused, saves, unlocks).
static func toast(parent: Control, text: String, color: Color = TEXT) -> void:
    if parent == null or not parent.is_inside_tree():
        return
    var pc := PanelContainer.new()
    pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var l := label(text, 14, color)
    pc.add_child(l)
    parent.add_child(pc)
    pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    pc.position.y = 22
    pc.z_index = 100
    var t := pc.create_tween()
    t.tween_interval(1.6)
    t.tween_property(pc, "modulate:a", 0.0, 0.4)
    t.tween_callback(pc.queue_free)
