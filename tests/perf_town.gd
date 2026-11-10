extends Node
## ms de GPU del pueblo por grupos: godot --path . res://tests/perf_town.tscn
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
	CharacterProfile.mode = "town"
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	main._auto_quality = false
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await get_tree().create_timer(4.0).timeout
	main._apply_quality(1)
	await get_tree().create_timer(2.0).timeout
	print("base ", await _gpu(2.0))
	var holder: Node = main.arena.get_node("TownDecor")
	var groups := {
		"multimesh (arboles/flora)": holder.get_children().filter(func(n: Node) -> bool: return n is MultiMeshInstance3D),
		"luces": holder.find_children("*", "OmniLight3D", true, false),
		"edificios": holder.get_children().filter(func(n: Node) -> bool: return n.name in ["blacksmith", "alchemy", "tavern", "leatherworker", "tailor", "carpenter"]),
		"mallas de la torre": holder.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D),
		"aldeanos": holder.get_children().filter(func(n: Node) -> bool: return n is Node3D and String(n.name).begins_with("@") or n.get_class() == "Node3D" and n.get_child_count() == 1 and n.name not in ["Portal"]),
		"suelo (plano)": main.arena.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D),
	}
	for key in groups:
		var arr: Array = groups[key]
		for n in arr:
			n.visible = false
		print("sin ", key, " (", arr.size(), ") ", await _gpu(1.5))
		for n in arr:
			n.visible = true
	get_tree().quit()
