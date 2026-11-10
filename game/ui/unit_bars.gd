## UnitBars — barras de vida sobre enemigos al estilo League of Legends, dibujadas en 2D.
##
## Marco oscuro, fondo, relleno rojo con divisiones cada 100 de vida, insignia con el nivel a la
## izquierda, vida restante en número ("234 / 300"), nombre y estados encima y una línea fina de
## Los élites tienen marco dorado y son más grandes; los esbirros, más pequeños.
## Sustituye a las barras 3D (que se desalineaban al inclinar la cámara).
class_name UnitBars
extends Control

const FONT := preload("res://assets/fonts/m5x7.ttf")
const BORDER := Color(0.04, 0.04, 0.06, 0.95)
const BACK := Color(0.10, 0.09, 0.11, 0.92)
const FILL := Color(0.80, 0.22, 0.20)
const FILL_LOW := Color(0.95, 0.45, 0.20)
const GOLD := Color(0.95, 0.76, 0.32)

var arena: Arena3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if arena == null or arena.camera == null:
		return
	var cam := arena.camera
	var items: Array = []
	for a: WarriorActor3D in arena.enemy_actors:
		if is_instance_valid(a) and a.sim != null and a.sim.alive:
			items.append({"pos": a.global_position, "sim": a.sim, "fighter": true})
	for a: WarriorActor3D in arena.ally_actors:
		if is_instance_valid(a) and a.sim != null and a.sim.alive:
			items.append({"pos": a.global_position, "sim": a.sim, "fighter": true, "ally": true})
	for d: DummyActor3D in arena.dummy_actors:
		if is_instance_valid(d) and d.sim != null and d.sim.get("alive") != false and float(d.sim.health) > 0.0:
			items.append({"pos": d.global_position, "sim": d.sim, "fighter": false})
	# De lejos a cerca para que las cercanas queden encima.
	items.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return (x["pos"] as Vector3).z < (y["pos"] as Vector3).z)
	var to_local := get_global_transform_with_canvas().affine_inverse()
	for item: Dictionary in items:
		var world_pos: Vector3 = item["pos"] + Vector3(0.0, 2.45, 0.0)
		if cam.is_position_behind(world_pos):
			continue
		var screen := cam.unproject_position(world_pos)
		_draw_unit(to_local * screen, item["sim"], bool(item["fighter"]), bool(item.get("ally", false)))


func _draw_unit(at: Vector2, sim: Object, fighter: bool, ally: bool = false) -> void:
	var tier := "minion"
	var name_text := "Muñeco"
	var level := 1
	if fighter:
		var data := EnemyArchetypes.data(String(sim.get("archetype_id")))
		tier = "minion" if ally else String(data.get("tier", "elite"))
		name_text = String(sim.get("display_name"))
		level = int(sim.progression.level)
	else:
		name_text = "Soldado" if sim is EnemySim else "Muñeco"
		level = int(sim.get("level") if sim.get("level") != null else 1)
	var width := 50.0
	var height := 7.0
	var border := BORDER
	match tier:
		"elite":
			width = 62.0
			height = 8.0
			border = GOLD
		"boss":
			width = 90.0
			height = 10.0
			border = Color(0.9, 0.3, 0.9)
		"minion":
			width = 46.0
			height = 6.0
	var hp := float(sim.health)
	var max_hp := maxf(float(sim.max_health), 1.0)
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var bar := Rect2(at.x - width * 0.5 + 6.0, at.y - height, width, height)
	# Insignia de nivel (cuadrado a la izquierda).
	var badge := Rect2(bar.position.x - 12.0, bar.position.y - 2.0, 11.0, height + 4.0)
	draw_rect(badge.grow(1.0), border)
	draw_rect(badge, Color(0.13, 0.12, 0.16, 1.0))
	_text(str(level), Vector2(badge.position.x, badge.position.y + badge.size.y - 2.0), 7, Color(0.95, 0.95, 0.9), badge.size.x)
	# Marco, fondo, relleno.
	draw_rect(bar.grow(1.5), border)
	draw_rect(bar, BACK)
	var fill := Color(0.35, 0.8, 0.4) if ally else (FILL if ratio > 0.3 else FILL_LOW)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y * 0.35)), Color(1, 1, 1, 0.16))  # brillo superior
	# Divisiones cada 100 de vida (como las marcas de League).
	var ticks := int(max_hp / 100.0)
	for i in range(1, ticks + 1):
		var x := bar.position.x + bar.size.x * (float(i) * 100.0 / max_hp)
		if x < bar.end.x - 1.0:
			draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), BORDER, 1.0)
	# Vida restante en número.
	_text("%d / %d" % [ceili(hp), ceili(max_hp)], Vector2(bar.position.x, bar.end.y - 0.5 + (0.0 if height > 6.0 else -0.5)), 7 if height > 5.0 else 5, Color(1, 1, 1, 0.95), bar.size.x)
	# Nombre y estados encima.
	var tag := ""
	if _num(sim, "silence_timer") > 0.0:
		tag += "[SILENCIADO] "
	if _num(sim, "root_timer") > 0.0:
		tag += "[ATADO] "
	if _num(sim, "mark_timer") > 0.0:
		tag += "[MARCADO] "
	if _num(sim, "stun_timer") > 0.0:
		tag += "[ATURDIDO] "
	var name_color := Color(1.0, 0.86, 0.45) if tier == "elite" else (Color(1.0, 0.6, 0.95) if tier == "boss" else Color(0.95, 0.92, 0.88))
	_text(name_text, Vector2(bar.position.x - 12.0, bar.position.y - 7.0), 7, name_color, width + 12.0, true)
	if bool(sim.get("quest_target")):  # objetivo de la misión
		tag = ("◆ OBJETIVO " + tag).strip_edges()
	if tag != "":
		_text(tag.strip_edges(), Vector2(bar.position.x - 12.0, bar.position.y - 15.0), 7, Color(1.0, 0.8, 0.35), width + 12.0, true)


## Lectura segura: los muñecos no tienen todos los campos (silencio, atadura...).
func _num(obj: Object, prop: String) -> float:
	var value: Variant = obj.get(prop)
	return float(value) if value != null else 0.0


func _text(text: String, pos: Vector2, size: int, color: Color, width: float, outline: bool = false) -> void:
	if outline:
		for off: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_string(FONT, pos + off, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, BORDER)
	draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)
