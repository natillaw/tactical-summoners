extends Node
## Escena (necesita autoloads): godot --headless --path . res://tests/test_floor_persistence.tscn
## El piso generado se guarda: enemigos muertos y nodos recogidos siguen así al volver a entrar.
var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", msg)

func _enter() -> Node3D:
	CharacterProfile.mode = "floor"
	var main: Node3D = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	return main

func _ready() -> void:
	CharacterProfile.floor_saves = {}
	CharacterProfile.current_floor = 1
	var main := await _enter()
	var total: int = main.arena.enemy_index.size()
	var seed_a: int = int(CharacterProfile.floor_saves[1]["seed"])
	var first: WarriorSim = main.arena.enemy_index.keys()[0]
	first.alive = false
	main._gather(main.arena.gather_nodes[0])
	main._save_progress()
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var again := await _enter()
	_check(int(CharacterProfile.floor_saves[1]["seed"]) == seed_a, "mismo piso (misma semilla) al volver")
	_check(again.arena.enemy_index.size() == total - 1, "el enemigo muerto no reaparece (%d de %d)" % [again.arena.enemy_index.size(), total])
	_check(not again.arena.gather_nodes[0]["left"], "el nodo recogido sigue recogido")
	print("floor persistence: ", "OK" if fails == 0 else "%d fallos" % fails)
	get_tree().quit(1 if fails > 0 else 0)
