## InputMessage — Estructura de datos para los inputs del cliente por tick (ISSUE P0.4).
class_name InputMessage
extends RefCounted

var tick: int = 0
var peer_id: int = 0
var move_dir: Vector2 = Vector2.ZERO
## World-space direction the player is aiming at (normalised by the receiver).
var aim_dir: Vector2 = Vector2.RIGHT
## Punto del suelo bajo la mira (skills de suelo tipo Smite), en coordenadas de sim.
var aim_point: Vector2 = Vector2.ZERO
var has_aim_point: bool = false
var actions: Dictionary = {} # e.g. { "m1": true, "m2": false }


func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"peer_id": peer_id,
		"move_dir": [move_dir.x, move_dir.y],
		"aim_dir": [aim_dir.x, aim_dir.y],
		"aim_point": [aim_point.x, aim_point.y] if has_aim_point else null,
		"actions": actions
	}


static func from_dict(data: Dictionary):
	var msg = new()
	msg.tick = data.get("tick", 0)
	msg.peer_id = data.get("peer_id", 0)
	var arr = data.get("move_dir", [0, 0])
	msg.move_dir = Vector2(arr[0], arr[1])
	var aim = data.get("aim_dir", [1, 0])
	msg.aim_dir = Vector2(aim[0], aim[1])
	var point = data.get("aim_point", null)
	if point is Array and point.size() >= 2:
		msg.aim_point = Vector2(point[0], point[1])
		msg.has_aim_point = true
	msg.actions = data.get("actions", {})
	return msg
