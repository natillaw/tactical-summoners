extends Node
## A/B culling de hojas: MODE=floor godot --path . res://tests/perf_cull.tscn
func _fps(seconds: float) -> float:
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await get_tree().process_frame
		frames += 1
	return frames / seconds

func _set_cull(main: Node, mode: int) -> void:
	for mm in main.arena.find_children("*", "MultiMeshInstance3D", true, false):
		var mesh: Mesh = (mm as MultiMeshInstance3D).multimesh.mesh
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as BaseMaterial3D
			if mat != null:
				mat.cull_mode = mode

func _ready() -> void:
	CharacterProfile.mode = "floor"
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	main._auto_quality = false
	await get_tree().create_timer(6.0).timeout
	main._apply_quality(0)
	await get_tree().create_timer(2.0).timeout
	print("1 cull off ", await _fps(3.0))
	_set_cull(main, BaseMaterial3D.CULL_BACK)
	print("2 cull back ", await _fps(3.0))
	_set_cull(main, BaseMaterial3D.CULL_DISABLED)
	print("3 cull off ", await _fps(3.0))
	_set_cull(main, BaseMaterial3D.CULL_BACK)
	print("4 cull back ", await _fps(3.0))
	get_tree().quit()
