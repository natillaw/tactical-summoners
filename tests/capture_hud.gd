extends Node
## Captura del piso con HUD y combate: CAPTURE_DIR=... godot --path . res://tests/capture_hud.tscn
func _ready() -> void:
	CharacterProfile.mode = "floor"
	CharacterProfile.floor_saves = {}
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.5).timeout
	var world: CombatWorld = main.world
	var camp: Vector2 = main._floor["camps"][0]["center"]
	world.warrior.position = camp + Vector2(-190, 0)
	world.warrior.aim_dir = Vector2.RIGHT
	Input.action_press("attack_m1")
	await get_tree().create_timer(1.6).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("CAPTURE_DIR") + "/hud.png")
	Input.action_release("attack_m1")
	get_tree().quit()
