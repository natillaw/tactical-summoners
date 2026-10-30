class_name HQWorld
extends Node2D
## Explorable Headquarters world where persistent heroes walk around and interact with facilities (Mega Prompt Phase 3).

signal back_requested

var _map: ProceduralMap
var _heroes_nodes: Dictionary = {} # hero_id -> Node2D
var _ui_layer: CanvasLayer


func _ready() -> void:
	# Generate a cozy HQ map layout
	_map = ProceduralMap.new(60, 40, 9999, 1)
	
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.18)
	bg.size = _map.world_size()
	add_child(bg)

	# Draw walls / floors simply or via tile representation
	_spawn_heroes()
	_setup_hud()


func _spawn_heroes() -> void:
	var spawn_idx := 0
	var composer := SpriteComposer.new()
	
	for id in Game.heroes:
		var h: HeroData = Game.heroes[id]
		var hero_node := Node2D.new()
		hero_node.name = "Hero_%s" % h.id
		
		# Position at spawn cells or facility
		var cell := _map.spawn_cells[spawn_idx % _map.spawn_cells.size()]
		hero_node.position = _map.center_of(cell)
		
		# FIX: Tipado explícito de la variable sprite como Node2D (o Sprite2D si corresponde)
		var sprite: Node2D = composer.compose(h.appearance)
		if sprite != null:
			sprite.scale = Vector2(1.5, 1.5)
			hero_node.add_child(sprite)
		
		var name_lbl := UIKit.label(h.display_name(), 12, h.star_color())
		name_lbl.position = Vector2(-40, -45)
		hero_node.add_child(name_lbl)

		add_child(hero_node)
		_heroes_nodes[h.id] = hero_node
		spawn_idx += 1


func _setup_hud() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	var margin := UIKit.margin(20)
	_ui_layer.add_child(margin)
	UIKit.fill(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_child(UIKit.button("< Back to Menu", func(): back_requested.emit(), Vector2(140, 40)))
	header.add_child(UIKit.label("Living Headquarters (Explorable)", 28, UIKit.ACCENT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	header.add_child(UIKit.button("Process HQ Turn", func(): Game.process_headquarters_turn(), Vector2(160, 40)))
	root.add_child(header)


func _process(delta: float) -> void:
	# Simple autonomous wandering for heroes in HQ
	for id in _heroes_nodes:
		var node := _heroes_nodes[id] as Node2D
		if node == null:
			continue
		# Slight random movement or idling
		if randf() < 0.01:
			var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
			var target := node.position + offset
			if not _map.is_blocked(target):
				node.position = node.position.move_toward(target, 20.0 * delta)
