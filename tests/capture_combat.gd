extends Node
## Captura de un combate real del piso 1 (necesita renderer):
##   CAPTURE_DIR=... godot --path . --position 9000,9000 --resolution 1280x720 res://tests/capture_combat.tscn
## Un bot juega con el héroe contra el primer campamento; guarda combat_1..3.png durante la pelea.
func _ready() -> void:
	var dir := OS.get_environment("CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://captures_3d")
	DirAccess.make_dir_recursive_absolute(dir)
	CharacterProfile.mode = "floor"
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.5).timeout
	var world: CombatWorld = main.world
	var camps: Array = main._floor["camps"]
	var camp: Dictionary = camps[0]
	world.warrior.position = world.resolve_position((camp["center"] as Vector2) + Vector2(-150, 60), 14.0, world.warrior)
	world.warrior_bot = BotBrain.new(3)
	for i in range(3):
		await get_tree().create_timer(2.2 if i == 0 else 1.4).timeout
		get_viewport().get_texture().get_image().save_png(dir + "/combat_%d.png" % (i + 1))
	get_tree().quit()
