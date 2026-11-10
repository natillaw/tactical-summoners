extends Node
## Caminata en el pueblo: CAPTURE_DIR=... godot --path . res://tests/capture_walk.tscn
func _ready() -> void:
	CharacterProfile.mode = "town"
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.2).timeout
	main.arena.tp_zoom = 0.55
	Input.action_press("move_right")
	await get_tree().create_timer(0.9).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("CAPTURE_DIR") + "/walk.png")
	print("ANIM ", main.arena.warrior_actor.rig.current(), " speed_m ", View3D.meters(main.world.warrior.velocity.length()))
	Input.action_release("move_right")
	get_tree().quit()
