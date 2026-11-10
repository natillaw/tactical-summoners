extends Node
## Comprueba el ajuste automático de calidad: MODE=floor|town godot --path . res://tests/perf_auto.tscn
func _ready() -> void:
	CharacterProfile.mode = OS.get_environment("MODE") if OS.get_environment("MODE") != "" else "floor"
	CharacterProfile.quality_step = 0
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	for i in range(5):
		await get_tree().create_timer(5.0).timeout
		print("t=%d s  nivel=%s  FPS=%d" % [(i + 1) * 5, main.QUALITY[CharacterProfile.quality_step]["name"], Engine.get_frames_per_second()])
	get_tree().quit()
