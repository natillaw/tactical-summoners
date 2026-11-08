## Mira central para la cámara en tercera persona.
class_name Crosshair
extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var c := size * 0.5
	var col := Color(1, 1, 1, 0.9)
	draw_circle(c, 2.0, col)
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(c + d * 8.0, c + d * 16.0, col, 2.0)
