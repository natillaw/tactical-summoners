extends Node
## Captura del piso 1 (necesita renderer): CAPTURE_DIR=... godot --path . res://tests/capture_floor.tscn
func _ready() -> void:
	var dir := OS.get_environment("CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://captures_3d")
	DirAccess.make_dir_recursive_absolute(dir)
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.5).timeout
	var arena: Arena3D = main.arena
	var world: CombatWorld = main.world
	var node: Dictionary = arena.gather_nodes[0]
	world.warrior.position = node["data"]["pos"] + Vector2(-30, 20)
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/floor_gather.png")
	main._gather(main._nearest_gather())
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/floor_gathered.png")
	get_tree().quit()
