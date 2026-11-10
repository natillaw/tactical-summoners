extends Node
## Capturas de interactuables y HUD de misión: CAPTURE_DIR=... godot --path . --position 6000,4000 res://tests/capture_mission.tscn
const TYPES := ["banners", "waves", "rescue", "delivery", "hunt", "beacons"]

func _ready() -> void:
	CharacterProfile.mode = "floor"
	CharacterProfile.chosen = false
	for type: String in TYPES:
		CharacterProfile.floor_saves = {}
		CharacterProfile.current_floor = 6
		CharacterProfile.force_mission = type
		var main: Node3D = load("res://game/main_3d.tscn").instantiate()
		add_child(main)
		await get_tree().create_timer(0.7).timeout
		var world: CombatWorld = main.world
		var rt: MissionRuntime = main.floor_ctl.runtime
		var look_at: Vector2 = world.warrior.position
		var ids: Array = main.arena.interacts.keys()
		if not ids.is_empty():
			look_at = main.arena.interacts[ids[0]]["data"]["pos"] + Vector2(-60, 70)
		elif type == "hunt":
			var target := int(rt.spec["layout"]["target"])
			for f: WarriorSim in main.arena.enemy_index:
				if int(main.arena.enemy_index[f]) == target:
					look_at = f.position + Vector2(-200, 100)
		world.warrior.position = look_at
		main.arena.tp_zoom = 0.9
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("CAPTURE_DIR") + "/m_%s.png" % type)
		main.queue_free()
		await get_tree().process_frame
	get_tree().quit()
