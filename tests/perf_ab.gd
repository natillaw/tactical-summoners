extends Node
## A/B de rendimiento en el mismo proceso: MODE=town|floor godot --path . res://tests/perf_ab.tscn
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
	await get_tree().create_timer(4.0).timeout
	print("A BASE ", await _fps(2.0))
	var lights: Array = main.find_children("*", "OmniLight3D", true, false)
	print("lights ", lights.size())
	for l in lights: l.visible = false
	print("B sin luces omni ", await _fps(2.0))
	for l in lights: l.visible = true
	var sun: Array = main.find_children("*", "DirectionalLight3D", true, false)
	for l in sun: l.shadow_enabled = false
	print("C sin sombras ", await _fps(2.0))
	for l in sun: l.shadow_enabled = true
	var decor: Array = main.arena.find_children("*Decor", "Node3D", true, false)
	for d in decor: d.visible = false
	print("D sin decoracion ", await _fps(2.0))
	for d in decor: d.visible = true
	main.arena.get_viewport().scaling_3d_scale = 0.5
	print("E resolucion 50% ", await _fps(2.0))
	main.arena.get_viewport().scaling_3d_scale = 1.0
	print("F BASE2 ", await _fps(2.0))
	var holder: Node = main.arena.get_node_or_null("FloorDecor")
	if holder == null:
		holder = main.arena.get_node_or_null("TownDecor")
	for tag in ["CommonTree", "Pine", "Grass", "Clover", "Fern", "Flower", "RockPath", "Rock_", "Bush"]:
		var hidden := []
		for n in holder.get_children():
			if String(n.name).contains(tag):
				n.visible = false
				hidden.append(n)
		print("G sin ", tag, " (", hidden.size(), ") ", await _fps(1.5))
		for n in hidden:
			n.visible = true
	get_tree().quit()
