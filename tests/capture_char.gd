extends Node
## Captura de la ficha de personaje: CAPTURE_DIR=... godot --path . res://tests/capture_char.tscn
func _ready() -> void:
	CharacterProfile.mode = "town"
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.0).timeout
	for id in ["mena_cobre", "cuero_basto", "fibra", "madera", "hueso"]:
		Materials.add(id, 12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for r: Dictionary in Crafting.RECIPES:
		if r.has("armor") or r.has("weapon"):
			Crafting.craft(r, main.world.warrior, rng)
	main.char_panel.toggle()
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("CAPTURE_DIR") + "/char.png")
	get_tree().quit()
