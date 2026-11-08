## DamageNumber3D — número de daño que sube y se desvanece (Label3D billboard).
class_name DamageNumber3D
extends Label3D


func setup(amount: float, critical: bool, color: Color = Color(1.0, 0.92, 0.75)) -> void:
	text = str(int(round(amount))) + ("!" if critical else "")
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = true
	pixel_size = 0.0011 if critical else 0.0008
	font_size = 32
	outline_size = 10
	modulate = Color(1.0, 0.78, 0.25) if critical else color
	outline_modulate = Color(0.05, 0.03, 0.02, 1.0)
	render_priority = 10
	outline_render_priority = 9


func launch() -> void:
	var drift := Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.15, 0.15))
	var start := position
	scale = Vector3.ONE * 1.6
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", start + Vector3(0, 0.9, 0) + drift, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.tween_property(self, "outline_modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.chain().tween_callback(queue_free)
