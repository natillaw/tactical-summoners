class_name SandboxMapView
extends Node2D
## Draws the fixed test map. With the Pixel Crawler tileset installed (T-025) it draws the baked
## tile texture; otherwise it falls back to a rich, detailed procedural stone dungeon style.

var map: NavMap
var _baked: Texture2D = null
var _tried := false


func _init(m: NavMap = null) -> void:
	map = m


func _draw() -> void:
	if map == null:
		return
	if not _tried:
		_tried = true
		_baked = ForestArt.bake(map, (map as ProceduralMap).seed_value) if map is ProceduralMap else MapTiles.bake(map)
	if _baked != null:
		draw_texture(_baked, Vector2.ZERO)
	else:
		var cell: float = float(NavMap.CELL)
		for y in map.height:
			for x in map.width:
				var r := Rect2(float(x) * cell, float(y) * cell, cell, cell)
				var is_wall: bool = map.is_blocked_cell(Vector2i(x, y))
				if is_wall:
					# Rich layered stone wall with brick bevels and highlights
					draw_rect(r, Color(0.16, 0.13, 0.22))
					draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(cell - 4, cell - 4)), Color(0.20, 0.17, 0.28))
					draw_rect(Rect2(r.position, Vector2(cell, 7)), Color(0.32, 0.27, 0.46))
					draw_line(r.position + Vector2(0, 7), r.position + Vector2(cell, 7), Color(0.10, 0.08, 0.15), 1.5)
					draw_line(r.position + Vector2(cell * 0.5, 7), r.position + Vector2(cell * 0.5, cell), Color(0.10, 0.08, 0.15), 1.0)
					draw_line(r.position + Vector2(2, cell * 0.5), r.position + Vector2(cell - 2, cell * 0.5), Color(0.24, 0.20, 0.34), 1.0)
				else:
					# Detailed stone floor slab with bevel borders
					var shade: float = 0.155 if (x + y) % 2 == 0 else 0.175
					draw_rect(r, Color(shade, shade * 0.92, shade * 1.25))
					draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(cell - 2, cell - 2)), Color(shade * 1.2, shade * 1.1, shade * 1.4), false, 1.0)
					
					# Decorative stone tile cross lines for stone paver look
					draw_line(r.position + Vector2(0, cell * 0.5), r.position + Vector2(cell, cell * 0.5), Color(shade * 0.7, shade * 0.65, shade * 0.8), 0.7)
					draw_line(r.position + Vector2(cell * 0.5, 0), r.position + Vector2(cell * 0.5, cell), Color(shade * 0.7, shade * 0.65, shade * 0.8), 0.7)

					# Wall shadow casting to the south of walls
					if y > 0 and map.is_blocked_cell(Vector2i(x, y - 1)):
						draw_rect(Rect2(r.position, Vector2(cell, 10)), Color(0, 0, 0, 0.4))

	# Extraction/goal marker with gorgeous glowing portal effect
	var g: Vector2 = map.center_of(map.extract_cell)
	draw_circle(g, 24.0, Color(0.15, 0.75, 0.45, 0.3))
	draw_arc(g, 24.0, 0.0, TAU, 36, Color(0.45, 0.95, 0.65), 4.0)
	draw_arc(g, 18.0, 0.0, TAU, 28, Color(0.70, 1.0, 0.85, 0.8), 2.5)
	draw_circle(g, 6.0, Color(0.85, 1.0, 0.90, 0.9))
	draw_string(ThemeDB.fallback_font, g + Vector2(-32, -32), "EXTRACT", HORIZONTAL_ALIGNMENT_CENTER, 64, 16, Color(0.80, 1.0, 0.85))
