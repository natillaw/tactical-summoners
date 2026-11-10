## GameTheme — tipografía (Cinzel, SIL OFL) de las ventanas de juego.
class_name GameTheme
extends RefCounted

static var _font: FontFile


static func font(bold: bool = false) -> FontFile:
	if _font == null:
		_font = load("res://assets/fonts/Cinzel-Regular.ttf") as FontFile
	return load("res://assets/fonts/Cinzel-Bold.ttf") as FontFile if bold else _font


static func make(size: int) -> Theme:
	var theme := Theme.new()
	theme.default_font = font()
	theme.default_font_size = size
	return theme
