extends Node
## Captura del pueblo (necesita renderer): CAPTURE_DIR=... godot --path . res://tests/capture_town.tscn
func _shot(name: String) -> void:
	await get_tree().create_timer(1.2).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("CAPTURE_DIR") + "/" + name + ".png")

func _ready() -> void:
	CharacterProfile.mode = "town"
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	await _shot("town_start")
	var arena: Arena3D = main.arena
	var world: CombatWorld = main.world
	arena.tp_zoom = 1.9
	world.warrior.position = Vector2(1200, 1150)
	await _shot("town_tower")
	var st: Dictionary = main._town["stations"][0]
	var b: Dictionary = main._town["buildings"][0]
	arena.tp_zoom = 1.0
	world.warrior.position = (b["center"] as Vector2) + Vector2(0, 40).rotated(-float(b["yaw"]))
	await _shot("town_inside")
	main._interact()
	await _shot("town_panel")
	get_tree().quit()
