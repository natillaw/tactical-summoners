extends Node
## Tiempos CPU/GPU de render (ms): MODE=floor|town godot --path . res://tests/perf_gpu.tscn
func _ready() -> void:
	CharacterProfile.mode = OS.get_environment("MODE") if OS.get_environment("MODE") != "" else "floor"
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	main._auto_quality = false
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	for step in [0, 1, 3]:
		main._apply_quality(step)
		await get_tree().create_timer(4.0).timeout
		var rid := get_viewport().get_viewport_rid()
		print("q%d cpu=%.1fms gpu=%.1fms fps=%d draws=%d" % [step, RenderingServer.viewport_get_measured_render_time_cpu(rid), RenderingServer.viewport_get_measured_render_time_gpu(rid), Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	get_tree().quit()
