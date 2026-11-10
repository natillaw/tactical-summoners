extends Node
## Rendimiento del piso: mide FPS y compara ocultando categorías en el MISMO proceso (la GPU varía entre ejecuciones).
func _fps(seconds: float) -> float:
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await get_tree().process_frame
		frames += 1
	return frames / seconds

func _ready() -> void:
	CharacterProfile.tower_mode = OS.get_environment("TRAINING") == ""
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var decor: Node = main.arena.get_node_or_null("FloorDecor")
	print("BASE ", await _fps(2.0))
	if decor != null:
		for tag in ["Pine", "Grass", "Flower", "RockPath", "Rock_", "Mushroom", "Fern", "Clover"]:
			var hidden := []
			for n in decor.get_children():
				if String(n.name).contains(tag):
					n.visible = false
					hidden.append(n)
			print("SIN ", tag, " (", hidden.size(), " nodos) ", await _fps(1.5))
			for n in hidden:
				n.visible = true
		print("BASE2 ", await _fps(2.0))
	get_tree().quit()
