extends Node
## ms de GPU por categoría de decoración (ocultándola): godot --path . res://tests/perf_cat.tscn
func _gpu(seconds: float) -> float:
	var rid := get_viewport().get_viewport_rid()
	var sum := 0.0
	var n := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await get_tree().process_frame
		sum += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		n += 1
	return sum / maxf(n, 1)

func _ready() -> void:
	CharacterProfile.mode = "floor"
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	main._auto_quality = false
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await get_tree().create_timer(4.0).timeout
	main._apply_quality(1)
	await get_tree().create_timer(2.0).timeout
	print("base gpu ms ", await _gpu(2.0))
	var holder: Node = main.arena.get_node("FloorDecor")
	for tag in ["CommonTree", "Pine", "Grass", "Clover", "Fern", "Flower", "Plant", "Petal", "Mushroom", "RockPath", "Rock_", "Bush", "Barrel", "Crate"]:
		var hidden := []
		for n in holder.get_children():
			if String(n.name).contains(tag):
				n.visible = false
				hidden.append(n)
		print("sin ", tag, " (", hidden.size(), ") ", await _gpu(1.5))
		for n in hidden:
			n.visible = true
	for n in holder.get_children():
		n.visible = false
	print("sin TODA la decoracion ", await _gpu(1.5))
	get_tree().quit()
