## LoadoutPanel — editor de habilidades del Warrior para pruebas.
##
## Tab lo abre y pausa TickManager (el toggle vive en Main). Muestra los 5 slots
## seleccionables y las 5 cartas del pool actual. Permite asignar con ratón o
## teclado, guardar/cargar en user://warrior_loadout.json y resetear al loadout
## por defecto.
##
## Es presentación/UI pura: los cambios se delegan a WarriorSim.set_loadout(),
## que sigue siendo el único dueño del estado de simulación.
class_name LoadoutPanel
extends Control

signal closed()

const FONT := preload("res://assets/fonts/m5x7.ttf")
const SAVE_PATH := "user://warrior_loadout.json"

const PANEL := Color(0.045, 0.052, 0.075, 0.97)
const PANEL_SOFT := Color(0.08, 0.09, 0.125, 0.96)
const EDGE := Color(0.30, 0.34, 0.44, 0.95)
const EDGE_SOFT := Color(0.17, 0.19, 0.26, 0.95)
const TEXT := Color(0.93, 0.90, 0.83, 1.0)
const MUTED := Color(0.56, 0.60, 0.70, 1.0)
const GOLD := Color(0.94, 0.74, 0.36, 1.0)
const ORANGE := Color(1.0, 0.53, 0.18, 1.0)
const GREEN := Color(0.55, 0.84, 0.50, 1.0)
const RED := Color(0.88, 0.32, 0.28, 1.0)

const SLOT_X := 8.0
const SLOT_Y := 54.0
const SLOT_W := 154.0
const SLOT_H := 40.0
const SLOT_GAP := 4.0

const GRID_X := 176.0
const GRID_Y := 54.0
const CARD_W := 148.0
const CARD_H := 36.0
const CARD_GAP_X := 4.0
const CARD_GAP_Y := 4.0
const CARD_COLS := 3

const BUTTON_Y := 318.0
const BUTTON_W := 100.0
const BUTTON_H := 22.0

var world: CombatWorld = null
var selected_slot_index: int = 0
var selected_card_index: int = 0


## Opciones del slot seleccionado (cada slot ofrece solo las skills de su rol).
func _pool() -> Array:
	var slot := String(ClassRegistry.active_kit().SELECTABLE_SLOTS[selected_slot_index])
	var options: Array = []
	for entry: Dictionary in ClassRegistry.active_kit().get_pool():
		if String(entry.get("slot", slot)) == slot:
			options.append(entry)
	return options
var status_text: String = ""
var status_color: Color = MUTED
var _status_timer: float = 0.0


func _ready() -> void:
	name = "LoadoutPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process(true)


func set_world(p_world: CombatWorld) -> void:
	world = p_world
	if world != null:
		_load_from_disk(false)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	if _status_timer > 0.0:
		_status_timer = maxf(0.0, _status_timer - delta)
		if _status_timer <= 0.0:
			status_text = ""
	queue_redraw()


func open() -> void:
	visible = true
	selected_slot_index = 0
	_status("LOADOUT EDITOR — TAB TO CLOSE", MUTED, 0.0)
	TickManager.set_paused(true)
	queue_redraw()


func close() -> void:
	visible = false
	TickManager.set_paused(false)
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _selected_slot() -> String:
	return String(ClassRegistry.active_kit().SELECTABLE_SLOTS[selected_slot_index])


func _selected_card() -> Dictionary:
	var pool: Array = _pool()
	if pool.is_empty():
		return {}
	var index := clampi(selected_card_index, 0, pool.size() - 1)
	var card: Dictionary = pool[index]
	return card


# --- Input ------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		match key:
			KEY_ESCAPE:
				close()
				get_viewport().set_input_as_handled()
			KEY_UP:
				selected_slot_index = posmod(selected_slot_index - 1, ClassRegistry.active_kit().SELECTABLE_SLOTS.size())
				queue_redraw()
			KEY_DOWN:
				selected_slot_index = posmod(selected_slot_index + 1, ClassRegistry.active_kit().SELECTABLE_SLOTS.size())
				queue_redraw()
			KEY_LEFT:
				selected_card_index = posmod(selected_card_index - 1, _pool().size())
				queue_redraw()
			KEY_RIGHT:
				selected_card_index = posmod(selected_card_index + 1, _pool().size())
				queue_redraw()
			KEY_ENTER, KEY_KP_ENTER:
				_assign_selected()
			KEY_S:
				_save_to_disk()
			KEY_L:
				_load_from_disk(true)
			KEY_R:
				_reset_loadout()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return

	var point := mouse.position
	for i: int in range(ClassRegistry.active_kit().SELECTABLE_SLOTS.size()):
		if _slot_rect(i).has_point(point):
			selected_slot_index = i
			queue_redraw()
			accept_event()
			return

	var pool_size: int = _pool().size()
	for i: int in range(pool_size):
		if _card_rect(i).has_point(point):
			selected_card_index = i
			_assign_selected()
			accept_event()
			return

	var labels := ["RESET", "SAVE", "LOAD", "CLOSE"]
	for i: int in range(labels.size()):
		if _button_rect(i).has_point(point):
			match i:
				0: _reset_loadout()
				1: _save_to_disk()
				2: _load_from_disk(true)
				3: close()
			accept_event()
			return


# --- Acciones ---------------------------------------------------------------


func _assign_selected() -> void:
	if world == null or world.warrior == null:
		return
	var card := _selected_card()
	if card.is_empty():
		return
	var slot := _selected_slot()
	world.warrior.assign_slot(slot, StringName(String(card["id"])))
	_status("%s  →  %s" % [String(card["name"]), slot], GREEN, 1.6)
	queue_redraw()


func _reset_loadout() -> void:
	if world == null or world.warrior == null:
		return
	world.warrior.set_loadout(ClassRegistry.active_kit().default_loadout())
	_status("DEFAULT LOADOUT RESTORED", GOLD, 1.8)
	queue_redraw()


func _save_to_disk() -> void:
	if world == null or world.warrior == null:
		return
	var data := {"loadout": world.warrior.loadout_to_strings()}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_status("SAVE FAILED", RED, 2.0)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_status("SAVED  user://warrior_loadout.json", GREEN, 2.0)
	queue_redraw()


func _load_from_disk(announce: bool) -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		if announce:
			_status("NO SAVED LOADOUT", RED, 1.8)
		return
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		if announce:
			_status("SAVE FILE CORRUPT", RED, 2.0)
		return
	var data: Dictionary = parsed
	var raw: Dictionary = data.get("loadout", {})
	var clean: Dictionary = ClassRegistry.active_kit().sanitize_loadout(raw)
	if world != null and world.warrior != null:
		world.warrior.set_loadout(clean)
	if announce:
		_status("LOADOUT LOADED", GREEN, 1.8)
	queue_redraw()


func _status(message: String, color: Color, seconds: float) -> void:
	status_text = message
	status_color = color
	_status_timer = seconds


# --- Dibujo -----------------------------------------------------------------


func _slot_rect(index: int) -> Rect2:
	return Rect2(SLOT_X, SLOT_Y + float(index) * (SLOT_H + SLOT_GAP), SLOT_W, SLOT_H)


func _card_rect(index: int) -> Rect2:
	var col := index % CARD_COLS
	var row := index / CARD_COLS
	return Rect2(
		GRID_X + float(col) * (CARD_W + CARD_GAP_X),
		GRID_Y + float(row) * (CARD_H + CARD_GAP_Y),
		CARD_W, CARD_H
	)


func _button_rect(index: int) -> Rect2:
	return Rect2(GRID_X + float(index) * (BUTTON_W + 4.0), BUTTON_Y, BUTTON_W, BUTTON_H)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.025, 0.04, 0.90))
	draw_rect(Rect2(6, 6, 628, 348), PANEL)
	draw_rect(Rect2(6, 6, 628, 348), EDGE, false, 1.0)

	_draw_text("WARRIOR  ·  LOADOUT EDITOR", Vector2(12, 26), 14, GOLD)
	_draw_text("TAB CLOSE   ·   SIMULATION PAUSED", Vector2(420, 24), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 206)

	_draw_slots()
	_draw_pool()
	_draw_footer()


func _draw_slots() -> void:
	_draw_text("SELECTABLE SLOTS", Vector2(SLOT_X + 2, SLOT_Y - 8), 7, MUTED)
	var loadout: Dictionary = {}
	if world != null and world.warrior != null:
		loadout = world.warrior.loadout

	for i: int in range(ClassRegistry.active_kit().SELECTABLE_SLOTS.size()):
		var slot := String(ClassRegistry.active_kit().SELECTABLE_SLOTS[i])
		var rect := _slot_rect(i)
		var selected := i == selected_slot_index
		fill_rect(rect, PANEL_SOFT if not selected else Color(0.13, 0.11, 0.07, 0.98))
		draw_rect(rect, GOLD if selected else EDGE_SOFT, false, 1.0)

		var id := StringName(String(loadout.get(slot, "")))
		var ability: Dictionary = ClassRegistry.active_kit().ability_by_id(id)
		var name := String(ability.get("name", "EMPTY"))
		_draw_text(ClassRegistry.active_kit().slot_label(slot), rect.position + Vector2(6, 12), 7, GOLD)
		_draw_text(name.to_upper(), rect.position + Vector2(6, 26), 7, TEXT if not ability.is_empty() else MUTED)
		if not ability.is_empty():
			_draw_text(_cost_label(ability), Vector2(rect.end.x - 6, rect.position.y + 12), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 60)
			if selected:
				draw_rect(rect.grow(-2.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.28), false, 1.0)


func _draw_pool() -> void:
	_draw_text("POOL  ·  5 SELECTABLE ABILITIES", Vector2(GRID_X, GRID_Y - 8), 7, MUTED)
	var pool: Array = _pool()
	var used := _slot_badges()

	for i: int in range(pool.size()):
		var card: Dictionary = pool[i]
		var rect := _card_rect(i)
		var selected := i == selected_card_index
		var id := String(card["id"])
		var is_used := used.has(id)
		fill_rect(rect, Color(0.10, 0.11, 0.15, 0.98) if not selected else Color(0.15, 0.12, 0.075, 0.98))
		draw_rect(rect, GOLD if selected else (ORANGE if is_used else EDGE_SOFT), false, 1.0)

		_draw_text(String(card.get("short", "")), rect.position + Vector2(5, 12), 7, GOLD if not selected else Color(1.0, 0.86, 0.50))
		_draw_text(String(card.get("name", "")), rect.position + Vector2(5, 24), 7, TEXT if selected else MUTED)
		_draw_text(_cost_label(card), Vector2(rect.end.x - 5, rect.position.y + 12), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 72)
		_draw_text("%.0fs" % float(card.get("cooldown", 0.0)), Vector2(rect.end.x - 5, rect.position.y + 24), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 48)

		if is_used:
			var badges: Array = used[id]
			var badge_text := ""
			for badge: String in badges:
				badge_text += badge + " "
			_draw_text(badge_text.strip_edges(), Vector2(rect.position.x + 5, rect.end.y - 4), 7, ORANGE)


func _draw_footer() -> void:
	draw_line(Vector2(12, 292), Vector2(628, 292), EDGE_SOFT, 1.0)

	var hints := [
		"UP/DOWN  SLOT",
		"LEFT/RIGHT  CARD",
		"ENTER  ASSIGN",
		"S  SAVE    L  LOAD",
		"R  RESET   TAB  CLOSE",
	]
	for i: int in range(hints.size()):
		_draw_text(String(hints[i]), Vector2(14, 302 + i * 9), 7, MUTED)

	var buttons := ["RESET", "SAVE", "LOAD", "CLOSE"]
	for i: int in range(buttons.size()):
		var rect := _button_rect(i)
		fill_rect(rect, PANEL_SOFT)
		draw_rect(rect, EDGE, false, 1.0)
		_draw_text(String(buttons[i]), Vector2(rect.position.x, rect.position.y + 14), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)

	if not status_text.is_empty():
		_draw_text(status_text, Vector2(GRID_X, 310), 7, status_color, HORIZONTAL_ALIGNMENT_RIGHT, 452)


func _slot_badges() -> Dictionary:
	var used: Dictionary = {}
	if world == null or world.warrior == null:
		return used
	var loadout: Dictionary = world.warrior.loadout
	for slot: String in ClassRegistry.active_kit().SELECTABLE_SLOTS:
		var id := String(loadout.get(slot, ""))
		if id.is_empty():
			continue
		if not used.has(id):
			used[id] = []
		var badges: Array = used[id]
		badges.append(ClassRegistry.active_kit().slot_label(slot))
	return used


func _cost_label(ability: Dictionary) -> String:
	var cost := roundi(float(ability.get("cost", 0.0)))
	if String(ability.get("kind", "")) == "ultimate":
		return "ULT" if cost <= 0 else "%dR + ULT" % cost
	return "FREE" if cost <= 0 else "%d R" % cost


# --- Primitivas -------------------------------------------------------------


func fill_rect(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color)


func _draw_text(text: String, at: Vector2, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(FONT, at, text, alignment, width, font_size, color)
