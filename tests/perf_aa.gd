extends Node
## FPS con distintos ajustes de nitidez (mismo proceso): MODE=town|floor godot --path . res://tests/perf_aa.tscn
func _fps(seconds: float) -> float:
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await get_tree().process_frame
		frames += 1
	return frames / seconds

func _ready() -> void:
	CharacterProfile.mode = OS.get_environment("MODE") if OS.get_environment("MODE") != "" else "floor"
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(5.0).timeout
	var vp := get_viewport()
	print("1 base ", await _fps(2.5))
	vp.msaa_3d = Viewport.MSAA_2X
	print("2 msaa2x ", await _fps(2.5))
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	print("3 msaa2x+fxaa ", await _fps(2.5))
	vp.msaa_3d = Viewport.MSAA_DISABLED
	print("4 solo fxaa ", await _fps(2.5))
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	print("5 base otra vez ", await _fps(2.5))
	get_tree().quit()
