extends Node
## Revisión visual completa: CAPTURE_DIR=... godot --path . res://tests/capture_review.tscn
func _shot(name: String, wait: float = 1.0) -> void:
	await get_tree().create_timer(wait).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("CAPTURE_DIR") + "/" + name + ".png")

func _ready() -> void:
	CharacterProfile.mode = "town"
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	var arena: Arena3D = main.arena
	var world: CombatWorld = main.world
	await _shot("r01_start", 1.5)
	arena.tp_zoom = 2.3
	world.warrior.position = Vector2(1200, 1100)
	await _shot("r02_town_wide", 1.6)
	arena.tp_zoom = 1.0
	for b: Dictionary in main._town["buildings"]:
		world.warrior.position = (b["center"] as Vector2) + Vector2(0, 60).rotated(-float(b["yaw"]))
		await _shot("r10_inside_" + String(b["id"]), 1.0)
	world.warrior.position = Vector2(1200, 880)
	arena.tp_zoom = 1.3
	await _shot("r20_portal", 1.2)
	var station: Dictionary = {}
	for st: Dictionary in main._town["stations"]:
		if st["id"] == "carpenter":
			station = st
	world.warrior.position = station["pos"] + Vector2(0, 60).rotated(-float(station["yaw"]))
	await _shot("r21_pre_panel", 0.8)
	Materials.add("madera", 9)
	Materials.add("fibra", 9)
	main.npc_panel.open_for(station, world.warrior)
	await _shot("r22_panel_carpenter", 0.6)
	main.npc_panel.close_panel()
	get_tree().quit()
