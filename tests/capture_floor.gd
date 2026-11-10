extends Node
## Captura del piso 1 (necesita renderer): CAPTURE_DIR=... godot --path . res://tests/capture_floor.tscn
func _ready() -> void:
	var dir := OS.get_environment("CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://captures_3d")
	DirAccess.make_dir_recursive_absolute(dir)
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.0).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/floor_start.png")
	var arena: Arena3D = main.arena
	var world: CombatWorld = main.world
	var camp: Vector2 = main._floor["camps"][0]["center"]
	world.warrior.position = camp + Vector2(-420, 0)
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/floor_camp.png")
	arena.tp_zoom = 1.8
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/floor_wide.png")
	get_tree().quit()
