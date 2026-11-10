extends Node
## Armas equipadas visibles por clase/tipo: CAPTURE_DIR=... godot --path . res://tests/capture_weapons.tscn
const CASES := [
	[&"warrior", "sword", 0], [&"warrior", "sword", 3], [&"warrior", "axe", 2], [&"warrior", "mace", 2], [&"warrior", "spear", 1],
	[&"rogue", "dagger", 1], [&"mage", "staff", 1], [&"ranger", "bow", 2],
]

func _ready() -> void:
	CharacterProfile.mode = "training"
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(CASES.size()):
		var c: Array = CASES[i]
		CharacterProfile.class_id = c[0]
		CharacterProfile.chosen = false
		var main: Node3D = load("res://game/main_3d.tscn").instantiate()
		add_child(main)
		await get_tree().create_timer(0.8).timeout
		var w: WarriorSim = main.world.warrior
		w.set_class(c[0])
		if c[1] != "sword" or c[2] != 0:
			var item := ItemFactory.roll_weapon(rng, 3, c[2], c[1])
			item.id = "test_" + c[1]
			w.equip_weapon(item)
		main.arena.tp_zoom = 0.75
		main.arena.topdown = true
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("CAPTURE_DIR") + "/w%d_%s_%s_%d.png" % [i, c[0], c[1], c[2]])
		main.queue_free()
		await get_tree().process_frame
	get_tree().quit()
