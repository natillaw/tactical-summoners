## GameHud — HUD de combate de Reflections (Combat Tower).
##
## Lee [CombatWorld] en _process y se dibuja por código. Es presentación pura:
## no escribe estado de simulación. Muestra vida, Rage, Ultimate Charge,
## cooldowns de los 7 slots, buffs activos, banner, controles y muerte.
class_name GameHud
extends Control

const FONT := preload("res://assets/fonts/m5x7.ttf")

const PANEL := Color(0.055, 0.065, 0.095, 0.86)
const PANEL_EDGE := Color(0.33, 0.37, 0.47, 0.95)
const PANEL_EDGE_SOFT := Color(0.20, 0.23, 0.30, 0.9)
const TEXT := Color(0.93, 0.90, 0.83, 1.0)
const MUTED := Color(0.56, 0.60, 0.70, 1.0)
const GOLD := Color(0.94, 0.74, 0.36, 1.0)
const ORANGE := Color(1.0, 0.53, 0.18, 1.0)
const RED := Color(0.88, 0.28, 0.24, 1.0)
const HEALTH := Color(0.42, 0.78, 0.42, 1.0)
const HEALTH_LOW := Color(0.86, 0.38, 0.24, 1.0)
const RAGE := Color(0.93, 0.35, 0.20, 1.0)
const ULTIMATE := Color(0.55, 0.80, 1.0, 1.0)
const SHIELD := Color(0.62, 0.82, 0.95, 1.0)

const BAR_KEYS := ["M1", "M2", "SHIFT", "Q", "E", "R", "S2", "F"]
const SLOT_W := 41.0
const SLOT_H := 35.0
const SLOT_GAP := 2.0
const BAR_Y := 321.0
const STATUS_Y := 281.0

var world: CombatWorld
var _damage_flash: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	queue_redraw()


func bind(p_world: CombatWorld) -> void:
	if world == p_world:
		return
	world = p_world
	if world != null and world.warrior != null:
		world.warrior.damage_taken.connect(_on_damage_taken)


func _process(delta: float) -> void:
	_damage_flash = maxf(0.0, _damage_flash - delta * 3.5)
	queue_redraw()


func _on_damage_taken(_amount: float, _source_position: Vector2, is_dot: bool) -> void:
	if not is_dot:
		_damage_flash = 1.0


func _draw() -> void:
	if world == null or world.warrior == null:
		return
	var warrior := world.warrior

	_draw_status(warrior)
	_draw_buffs(warrior)
	_draw_abilities(warrior)
	_draw_cast_bar(warrior)
	_draw_controls()

	if _sim_last_stand_active(warrior) and warrior.alive:
		_draw_text("LAST STAND  +50%% DAÑO  +25%% VELOCIDAD", Vector2(0, 252), 7, ORANGE, HORIZONTAL_ALIGNMENT_CENTER, 640)

	_draw_damage_flash()
	if not warrior.alive:
		_draw_death()


## Barra de cast sobre la barra de skills (Concentrated Shot, hechizos fuertes del mago).
func _draw_cast_bar(warrior: WarriorSim) -> void:
	var progress := warrior.cast_progress()
	if progress < 0.0:
		return
	var rect := Rect2(240, 262, 160, 6)
	draw_rect(rect.grow(1.0), Color(0.04, 0.04, 0.06, 0.9))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * progress, rect.size.y)), Color(1.0, 0.82, 0.3, 1.0))
	_draw_text(String(warrior.current_skill.get("name", "")), Vector2(240, 259), 6, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 160)


func _sim_last_stand_active(warrior: WarriorSim) -> bool:
	if warrior.has_method("is_last_stand_active"):
		return bool(warrior.is_last_stand_active())
	return false


func _sim_last_stand_seconds(warrior: WarriorSim) -> float:
	if warrior.has_method("last_stand_seconds_left"):
		return float(warrior.last_stand_seconds_left())
	return 0.0


func _sim_rage(warrior: WarriorSim) -> float:
	if warrior.has_method("rage"):
		return float(warrior.rage())
	if warrior.has_method("resource"):
		return float(warrior.resource.get_current())
	return 0.0


func _sim_rage_max(warrior: WarriorSim) -> float:
	if warrior.has_method("rage_max"):
		return float(warrior.rage_max())
	if warrior.has_method("resource"):
		return float(warrior.resource.max_amount)
	return 100.0


func _sim_ultimate(warrior: WarriorSim) -> float:
	return float(warrior.ultimate())


func _sim_cooldown_left(warrior: WarriorSim, slot: String) -> float:
	return float(warrior.cooldown_left(slot))


func _sim_cooldown_total(warrior: WarriorSim, slot: String) -> float:
	return float(warrior.cooldown_total(slot))


# --- Paneles ----------------------------------------------------------------


## Recursos del jugador: centrados abajo, sobre la barra de skills (no tapan al personaje, que va al centro).
func _draw_status(warrior: WarriorSim) -> void:
	var left := 236.0
	var width := 168.0
	var health_ratio: float = warrior.health / maxf(warrior.max_health, 1.0)
	var health_color := HEALTH if health_ratio > 0.30 else HEALTH_LOW
	# Insignia con el nivel, a la izquierda.
	var badge := Rect2(left - 16.0, STATUS_Y, 13.0, 25.0)
	draw_rect(badge.grow(1.0), PANEL_EDGE)
	draw_rect(badge, PANEL)
	_draw_text(str(warrior.progression.level), Vector2(badge.position.x, badge.position.y + 18.0), 9, GOLD, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x)
	_draw_text("NV", Vector2(badge.position.x, badge.position.y + 7.0), 5, MUTED, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x)
	# Vida.
	var hp := Rect2(left, STATUS_Y, width, 10.0)
	draw_rect(hp.grow(1.5), Color(0.03, 0.03, 0.05, 0.95))
	draw_rect(hp, Color(0.09, 0.10, 0.12, 0.95))
	draw_rect(Rect2(hp.position, Vector2(hp.size.x * health_ratio, hp.size.y)), health_color)
	draw_rect(Rect2(hp.position, Vector2(hp.size.x * health_ratio, 3.0)), Color(1, 1, 1, 0.16))
	var ticks := int(warrior.max_health / 100.0)
	for i in range(1, ticks + 1):
		var x := hp.position.x + hp.size.x * (float(i) * 100.0 / warrior.max_health)
		if x < hp.end.x - 1.0:
			draw_line(Vector2(x, hp.position.y), Vector2(x, hp.end.y), Color(0.03, 0.03, 0.05, 0.9), 1.0)
	_draw_text("%d / %d" % [ceili(warrior.health), ceili(warrior.max_health)], Vector2(hp.position.x, hp.end.y - 2.0), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, width)
	# Poise: línea fina bajo la vida.
	_bar(Rect2(left, STATUS_Y + 11.0, width, 1.5), clampf(warrior.poise / maxf(warrior.max_poise, 1.0), 0.0, 1.0), Color(0.95, 0.85, 0.4, 1.0))
	# Recurso (rage / maná / energía).
	var resource_name := String(ClassRegistry.active_kit().RESOURCE_NAME)
	var resource_color := RAGE
	if resource_name == "Mana":
		resource_color = Color(0.30, 0.50, 1.0, 1.0)
	elif resource_name == "Energy":
		resource_color = Color(1.0, 0.85, 0.2, 1.0)
	var res := Rect2(left, STATUS_Y + 14.0, width, 7.0)
	var rage_ratio: float = _sim_rage(warrior) / maxf(_sim_rage_max(warrior), 1.0)
	draw_rect(res.grow(1.5), Color(0.03, 0.03, 0.05, 0.95))
	draw_rect(res, Color(0.09, 0.10, 0.12, 0.95))
	draw_rect(Rect2(res.position, Vector2(res.size.x * rage_ratio, res.size.y)), resource_color)
	draw_rect(Rect2(res.position, Vector2(res.size.x * rage_ratio, 2.0)), Color(1, 1, 1, 0.16))
	if rage_ratio >= 0.999:
		draw_rect(res, GOLD, false, 1.0)
	_draw_text("%d / %d" % [floori(_sim_rage(warrior)), floori(_sim_rage_max(warrior))], Vector2(res.position.x, res.end.y - 1.0), 6, TEXT, HORIZONTAL_ALIGNMENT_CENTER, width)
	# Experiencia: hilo fino bajo el recurso.
	var xp_next := float(Progression.xp_to_next(warrior.progression.level))
	_bar(Rect2(left, STATUS_Y + 23.0, width, 1.5), clampf(float(warrior.progression.xp) / maxf(xp_next, 1.0), 0.0, 1.0), Color(0.55, 0.45, 0.95, 1.0))


func _draw_buffs(warrior: WarriorSim) -> void:
	_panel(Rect2(392, 6, 238, 44))
	_draw_text("ACTIVE EFFECTS", Vector2(398, 18), 7, MUTED)
	var entries: Array[String] = []
	var casting_id := String(warrior.current_skill.get("id", ""))
	if warrior.is_attacking() and not warrior.current_skill.is_empty():
		entries.append("CASTING  %s" % String(warrior.current_skill.get("name", "")))
	if _sim_last_stand_active(warrior):
		entries.append("LAST STAND  %.1fs" % _sim_last_stand_seconds(warrior))
	if warrior.is_parrying():
		entries.append("PARRY  ACTIVA")
	elif casting_id == "charge":
		entries.append("CHARGE  ACTIVO")
	elif casting_id == "bladestorm":
		entries.append("BLADESTORM  ACTIVO")
	elif casting_id == "seismic_break":
		entries.append("SEISMIC BREAK  ACTIVO")
	if entries.is_empty():
		entries.append("NONE")
	for i: int in range(mini(entries.size(), 3)):
		_draw_text(String(entries[i]), Vector2(398, 29 + i * 9), 7, SHIELD if i == 0 else TEXT)


func _draw_abilities(warrior: WarriorSim) -> void:
	var total_width := float(BAR_KEYS.size()) * SLOT_W + float(BAR_KEYS.size() - 1) * SLOT_GAP
	var start_x := (640.0 - total_width) * 0.5
	for i: int in range(BAR_KEYS.size()):
		var slot := String(BAR_KEYS[i])
		var rect := Rect2(start_x + float(i) * (SLOT_W + SLOT_GAP), BAR_Y, SLOT_W, SLOT_H)
		_draw_ability_slot(rect, warrior, slot)


func _draw_ability_slot(rect: Rect2, warrior: WarriorSim, slot: String) -> void:
	var ability: Dictionary = warrior.ability_for_slot(slot)
	var left := _sim_cooldown_left(warrior, slot)
	var total := _sim_cooldown_total(warrior, slot)
	var idle := not warrior.is_attacking()

	var is_ultimate := String(ability.get("kind", "")) == "ultimate"
	var affordable := true
	if not ability.is_empty():
		var rage_cost := float(ability.get("cost", 0.0))
		var has_rage := _sim_rage(warrior) + 0.001 >= rage_cost
		if is_ultimate:
			affordable = has_rage and _sim_ultimate(warrior) + 0.001 >= float(ability.get("charge", ClassRegistry.active_kit().ULTIMATE_COST))
		else:
			affordable = has_rage

	var is_parry := String(ability.get("id", "")) == "parry"
	var edge := PANEL_EDGE
	if is_parry and warrior.is_parrying():
		edge = ORANGE
	elif is_ultimate and affordable:
		edge = ULTIMATE
	elif not affordable:
		edge = Color(0.32, 0.24, 0.24, 0.95)

	draw_rect(rect, PANEL)
	draw_rect(rect, edge, false, 1.0)

	_draw_text(ClassRegistry.active_kit().slot_label(slot), rect.position + Vector2(3, 7), 5, MUTED)
	if slot == "M1" or slot == "M2":
		_draw_text(slot, Vector2(rect.position.x, rect.position.y + 7), 5, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 3)

	if ability.is_empty():
		_draw_text("EMPTY", Vector2(rect.position.x, rect.position.y + 26), 7, MUTED, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
		return

	var short := String(ability.get("short", ability.get("name", "")))
	var icon_color := GOLD if left <= 0.0 and affordable else Color(0.62, 0.64, 0.72, 1.0)
	var icon_center := rect.position + Vector2(rect.size.x * 0.5, 14)
	var icon := HeroSkillIcons.get_icon(ClassRegistry.active_kit().CLASS_ID, String(ability.get("id", "")))
	if icon != null:
		var tint := Color.WHITE if left <= 0.0 and affordable else Color(0.5, 0.5, 0.58, 1.0)
		draw_texture_rect(icon, Rect2(icon_center - Vector2(10, 10), Vector2(20, 20)), false, tint)
	else:
		_draw_glyph(String(ability.get("cast", "melee")), icon_center, icon_color)

	_draw_text(short, Vector2(rect.position.x, rect.position.y + rect.size.y - 1), 6, TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)

	var cost_label: String = ClassRegistry.active_kit().cost_label(ability)
	if not cost_label.is_empty():
		_draw_text(cost_label, Vector2(rect.position.x, rect.position.y + 17), 5, MUTED if affordable else RED, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)

	if left > 0.05:
		var ratio := clampf(left / maxf(total, 0.001), 0.0, 1.0)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * ratio)), Color(0.02, 0.02, 0.04, 0.66))
		_draw_text("%.1f" % left, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.7), 7, Color(0.95, 0.92, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	elif idle and affordable:
		draw_rect(rect.grow(-2.0), Color(edge.r, edge.g, edge.b, 0.22), false, 1.0)

	if is_parry and warrior.is_parrying():
		_draw_text("!", rect.position + Vector2(rect.size.x - 12, 9), 7, ORANGE)

	if is_ultimate:
		var charge_ratio: float = clampf(_sim_ultimate(warrior) / maxf(ClassRegistry.active_kit().ULTIMATE_COST, 1.0), 0.0, 1.0)
		draw_rect(Rect2(rect.position.x + 2, rect.end.y - 2, (rect.size.x - 4) * charge_ratio, 2), ULTIMATE)


func _draw_glyph(cast: String, center: Vector2, color: Color) -> void:
	match cast:
		"line":
			draw_line(center + Vector2(-10, 4), center + Vector2(10, -4), color, 2.0)
			draw_line(center + Vector2(10, -4), center + Vector2(5, -5), color, 2.0)
			draw_line(center + Vector2(10, -4), center + Vector2(6, 1), color, 2.0)
		"aoe":
			draw_arc(center, 8.0, 0.0, TAU, 18, color, 2.0)
			draw_circle(center, 2.0, color)
		"dash":
			draw_line(center + Vector2(-10, 0), center + Vector2(9, 0), color, 2.0)
			draw_line(center + Vector2(9, 0), center + Vector2(4, -5), color, 2.0)
			draw_line(center + Vector2(9, 0), center + Vector2(4, 5), color, 2.0)
		"leap":
			draw_arc(center + Vector2(0, 6), 7.0, PI, TAU, 14, color, 2.0)
			draw_line(center + Vector2(0, 8), center + Vector2(0, -8), color, 2.0)
			draw_line(center + Vector2(0, -8), center + Vector2(-4, -3), color, 2.0)
			draw_line(center + Vector2(0, -8), center + Vector2(4, -3), color, 2.0)
		"counter", "buff":
			_draw_shield(center, color)
		"banner":
			draw_line(center + Vector2(-5, 9), center + Vector2(-5, -9), color, 2.0)
			draw_rect(Rect2(center + Vector2(-4, -9), Vector2(12, 8)), color)
		_:
			_draw_sword_icon(center, -0.65, color, false)


func _draw_shield(center: Vector2, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -9),
		center + Vector2(8, -5),
		center + Vector2(7, 4),
		center + Vector2(0, 9),
		center + Vector2(-7, 4),
		center + Vector2(-8, -5),
	])
	draw_polyline(points, color, 2.0)
	draw_line(center + Vector2(0, -9), center + Vector2(0, 9), color, 1.0)


func _draw_sword_icon(center: Vector2, angle: float, color: Color, heavy: bool) -> void:
	draw_set_transform(center, angle, Vector2.ONE)
	var width := 3.0 if heavy else 2.0
	draw_line(Vector2(0, 9), Vector2(0, -10), color, width)
	draw_line(Vector2(-5, -6), Vector2(5, -6), color, 2.0)
	draw_line(Vector2(-2, 8), Vector2(2, 8), color, 2.0)
	if heavy:
		draw_circle(Vector2(0, -10), 1.5, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_controls() -> void:
	_panel(Rect2(536, 254, 96, 100))
	var lines := [
		"LMB/RMB ATK",
		"WASD MOVE",
		"C CAMERA",
		"SHIFT ROLL",
		"TAB LOADOUT",
		"F2 RESET",
		"F4 REFILL",
		"X QUICKCAST",
		"F5-F7 LVL/ARMA",
	]
	for i: int in range(lines.size()):
		_draw_text(String(lines[i]), Vector2(542, 265 + i * 10), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 84)


# --- Overlays ---------------------------------------------------------------


func _draw_damage_flash() -> void:
	var amount := 0.0
	if _damage_flash > 0.0:
		amount = 0.35 * _damage_flash
	if world != null and world.warrior != null and world.warrior.alive:
		var ratio: float = world.warrior.health / maxf(world.warrior.max_health, 1.0)
		if ratio < 0.30:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
			amount = maxf(amount, 0.10 + 0.08 * pulse)
	if amount > 0.0:
		draw_rect(Rect2(0, 0, 640, 360), Color(0.65, 0.06, 0.06, amount), false, 7.0)


func _draw_death() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.04, 0.01, 0.02, 0.62))
	_draw_text("YOU DIED", Vector2(0, 176), 28, RED, HORIZONTAL_ALIGNMENT_CENTER, 640)
	_draw_text("THE TRAINING DUMMY WON THIS ROUND", Vector2(0, 194), 7, MUTED, HORIZONTAL_ALIGNMENT_CENTER, 640)
	_draw_text("PRESS  F2  TO RISE AGAIN", Vector2(0, 210), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 640)


# --- Primitivas -------------------------------------------------------------


func _panel(rect: Rect2) -> void:
	draw_rect(rect, PANEL)
	draw_rect(rect, PANEL_EDGE_SOFT, false, 1.0)
	draw_line(rect.position + Vector2(1, 1), Vector2(rect.end.x - 1, rect.position.y + 1), Color(PANEL_EDGE.r, PANEL_EDGE.g, PANEL_EDGE.b, 0.55), 1.0)


func _bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, Color(0.08, 0.09, 0.12, 0.95))
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped > 0.0:
		var fill := Rect2(rect.position, Vector2(rect.size.x * clamped, rect.size.y))
		draw_rect(fill, color)
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, 1.0)), color.lightened(0.35))
	draw_rect(rect, Color(0.02, 0.03, 0.05, 0.9), false, 1.0)


func _draw_text(text: String, at: Vector2, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(FONT, at, text, alignment, width, font_size, color)
