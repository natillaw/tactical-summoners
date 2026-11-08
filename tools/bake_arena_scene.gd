## Genera game/world3d/training_arena.tscn (escenario editable en el editor de Godot)
## a partir del código de Arena3D. Solo hace falta volver a ejecutarlo si se quiere
## regenerar desde cero (¡pisa los cambios hechos a mano en la escena!):
##   godot --headless --path . --script res://tools/bake_arena_scene.gd
extends SceneTree

const OUT := "res://game/world3d/training_arena.tscn"

# Marcadores de aparición: [nombre, posición de sim, meta]
const SPAWNS := [
	["Soldado1", Vector2(480, 150), {"enemy": true, "level": 1}],
	["Muneco1", Vector2(680, 400), {"hp": 4000.0}],
	["Muneco2", Vector2(280, 420), {"hp": 4000.0}],
]


func _init() -> void:
	var arena := Arena3D.new()
	root.add_child(arena)  # los hijos con grupos necesitan árbol
	var level := Node3D.new()
	level.name = "TrainingArena"
	arena.build_static(level)
	var spawns := Node3D.new()
	spawns.name = "Spawns"
	level.add_child(spawns)
	for entry: Array in SPAWNS:
		var marker := Marker3D.new()
		marker.name = entry[0]
		marker.position = View3D.to3(entry[1])
		for key: String in entry[2]:
			marker.set_meta(key, entry[2][key])
		spawns.add_child(marker)
	_own(level, level)
	var packed := PackedScene.new()
	print("pack ", packed.pack(level))
	print("save ", ResourceSaver.save(packed, OUT))
	quit()


func _own(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_own(child, owner_node)
