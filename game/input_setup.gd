## Registers the input map at runtime (before the main scene loads).
##
## Esquema Battlerite: LMB/RMB para M1/M2, y Shift/Q/E/1/2/R (Space = saltar, F = interactuar).
## El loadout se edita con Tab (pausa la simulación).
## Mantener el mapa en código hace que el juego y las suites headless compartan
## exactamente las mismas acciones.
extends Node

const ACTIONS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"attack_m1": [],
	"attack_m2": [],
	"slot_shift": [KEY_SHIFT],
	"jump": [KEY_SPACE],
	"slot_q": [KEY_Q],
	"slot_e": [KEY_E],
	"slot_r": [KEY_R],
	"slot_1": [KEY_1],
	"slot_2": [KEY_2],
	"interact": [KEY_F],
	"toggle_loadout": [KEY_TAB],
	"restart_training": [KEY_F2],
	"refill_resources": [KEY_F4],
	"toggle_debug_overlay": [KEY_F3],
	"quit_game": [KEY_ESCAPE],
}

const SLOT_ACTIONS := {
	"SHIFT": "slot_shift",
	"Q": "slot_q",
	"E": "slot_e",
	"R": "slot_1",
	"S2": "slot_2",
	"F": "slot_r",
}


func _enter_tree() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key: int in ACTIONS[action]:
			_add_key(action, key)
	_add_mouse_button("attack_m1", MOUSE_BUTTON_LEFT)
	_add_mouse_button("attack_m2", MOUSE_BUTTON_RIGHT)


func _add_key(action: String, keycode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	if not _has_event(action, event):
		InputMap.action_add_event(action, event)


func _add_mouse_button(action: String, button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	if not _has_event(action, event):
		InputMap.action_add_event(action, event)


func _has_event(action: String, event: InputEvent) -> bool:
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing.is_match(event):
			return true
	return false
