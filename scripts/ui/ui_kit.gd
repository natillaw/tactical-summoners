class_name UIKit
extends RefCounted
## Small helpers so screens stay short: colors, theme, labels, buttons.

const BG := Color(0.078, 0.071, 0.122)
const PANEL := Color(0.122, 0.106, 0.200)
const PANEL_LIGHT := Color(0.18, 0.16, 0.29)
const ACCENT := Color(0.949, 0.757, 0.306)
const TEXT := Color(0.92, 0.91, 0.96)
const MUTED := Color(0.62, 0.60, 0.72)
const GOOD := Color(0.45, 0.85, 0.50)
const BAD := Color(0.95, 0.40, 0.40)


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), border_w: int = 0, radius: int = 8, margin: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.43, 0.55))
	t.set_stylebox("normal", "Button", box(PANEL_LIGHT, Color(0.30, 0.27, 0.48), 1, 8, 10))
	t.set_stylebox("hover", "Button", box(Color(0.25, 0.22, 0.40), ACCENT, 1, 8, 10))
	t.set_stylebox("pressed", "Button", box(Color(0.30, 0.25, 0.14), ACCENT, 2, 8, 10))
	t.set_stylebox("hover_pressed", "Button", box(Color(0.34, 0.28, 0.16), ACCENT, 2, 8, 10))
	t.set_stylebox("disabled", "Button", box(Color(0.11, 0.10, 0.17), Color(0.2, 0.18, 0.3), 1, 8, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(PANEL, Color(0.25, 0.22, 0.40), 1, 10, 10))
	t.set_stylebox("background", "ProgressBar", box(Color(0.08, 0.07, 0.13), Color(0.25, 0.22, 0.40), 1, 6, 2))
	t.set_stylebox("fill", "ProgressBar", box(Color(0.36, 0.62, 0.95), Color(0, 0, 0, 0), 0, 6, 2))
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	return t


static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, callback: Callable, min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(callback)
	return b


static func fill(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func margin(px: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", px)
	m.add_theme_constant_override("margin_right", px)
	m.add_theme_constant_override("margin_top", px)
	m.add_theme_constant_override("margin_bottom", px)
	return m
