import re


def edit(p, fn):
    s = open(p, encoding='utf-8', newline='').read().replace('\r\n', '\n')
    s = fn(s)
    open(p, 'w', encoding='utf-8', newline='').write(s)


def rep(s, o, n):
    assert o in s, o[:100]
    return s.replace(o, n, 1)


def block_range(s, name):
    i = s.index('const %s: Dictionary = {' % name)
    j = s.index('\n}\n', i) + 3
    return i, j


NEW_SKILLS = '''const ARCANE_PULL: Dictionary = {
	"id": &"arcane_pull",
	"clip": {"name": "standing_2h_magic_attack_02", "start": 1.0, "contact": 1.3, "end": 1.9},
	"name": "Arcane Pull", "short": "PULL", "slot": "Q",
	"kind": "control", "role": "Control / atraer", "description": "Proyectil rápido que ENGANCHA al objetivo y lo arrastra hasta ti (y lo ralentiza 1.2 s). Ideal contra quien huye o para sacarlo de su grupo.",
	"implemented": true, "selectable": true, "cast": "projectile", "anim": "cast",
	"damage_type": 7,
	"windup": 0.25, "active": 0.05, "recovery": 0.25, "cooldown": 10.0, "cost": 25.0,
	"speed": 760.0, "range": 440.0, "hit_radius": 12.0, "damage_mult": 0.6,
	"effects": {"pull": 170.0, "slow": {"factor": 0.6, "duration": 1.2}},
	"poise": 0.0, "rage_gain": 0.0, "move_factor": 0.4, "color": [0.85, 0.55, 1.0],
}

const ARCANE_SILENCE: Dictionary = {
	"id": &"arcane_silence",
	"clip": {"name": "standing_2h_magic_attack_04", "start": 0.5, "contact": 0.9, "end": 1.5},
	"name": "Silence", "short": "MUTE", "slot": "R",
	"kind": "control", "role": "Control / anti-skills", "description": "Proyectil que SILENCIA al objetivo 3.5 s: no puede usar skills (solo su ataque básico). Cancela cargas y casteos en curso.",
	"implemented": true, "selectable": true, "cast": "projectile", "anim": "cast",
	"damage_type": 7,
	"windup": 0.25, "active": 0.05, "recovery": 0.25, "cooldown": 14.0, "cost": 20.0,
	"speed": 640.0, "range": 460.0, "hit_radius": 12.0, "damage_mult": 0.3,
	"effects": {"silence": 3.5, "interrupt": true},
	"rage_gain": 0.0, "move_factor": 0.4, "color": [0.55, 0.45, 0.8],
}

const TIME_RIFT: Dictionary = {
	"id": &"time_rift",
	"clip": {"name": "standing_2h_cast_spell_01", "start": 0.33, "contact": 0.63, "end": 1.3},
	"name": "Time Rift", "short": "RIFT", "slot": "S2",
	"kind": "control", "role": "Control de zona", "description": "Apunta al suelo: una grieta temporal ralentiza muchísimo (-55%) a quien esté dentro durante 4 s. Para fijar enemigos antes de un hechizo grande.",
	"implemented": true, "selectable": true, "cast": "aoe", "anim": "cast", "target": "ground",
	"damage_type": 7,
	"windup": 0.35, "active": 0.10, "recovery": 0.25, "cooldown": 12.0, "cost": 30.0,
	"range": 300.0, "radius": 130.0, "damage_mult": 0.4, "lingering": 4.0,
	"effects": {"slow": {"factor": 0.45, "duration": 4.0}},
	"rage_gain": 0.0, "move_factor": 0.3, "color": [0.6, 0.55, 1.0],
}

'''


def mage(s):
    # quitar Arcane Rift (daño en el tiempo), añadir Pull / Silence / Time Rift
    i, j = block_range(s, 'ARCANE_RIFT')
    s = s[:i] + s[j:]
    k = s.index('## Pasiva (mismo contrato')
    s = s[:k] + NEW_SKILLS + s[k:]
    # Pulse: empuja
    s = rep(s, '"description": "Pulso arcano a tu alrededor: daña y ralentiza."', '"description": "Pulso arcano a tu alrededor: EMPUJA a los enemigos lejos de ti y los ralentiza. Defensa activa contra quien se pega."')
    s = rep(s, '"radius": 130.0, "damage_mult": 1.2, "effects": {"slow": {"factor": 0.5, "duration": 3.0}},', '"radius": 130.0, "damage_mult": 1.0, "effects": {"slow": {"factor": 0.5, "duration": 2.5}, "knockback": 190.0, "interrupt": true},')
    # Surge: empuja y silencia
    s = rep(s, '"range": 320.0, "radius": 160.0, "damage_mult": 6.0,\n	"rage_gain": 0.0, "move_factor": 0.0,', '"range": 320.0, "radius": 160.0, "damage_mult": 5.0,\n	"effects": {"knockback": 150.0, "silence": 2.5},\n	"rage_gain": 0.0, "move_factor": 0.0,')
    s = rep(s, '"description": "Ultimate. Cast 2.2 s (quieto): explosión arcana enorme donde apuntes."', '"description": "Ultimate. Cast 2.2 s (quieto): explosión arcana enorme donde apuntes; empuja y silencia 2.5 s a todos los alcanzados."')
    s = re.sub(r'const ALL_ABILITIES: Array = \[.*?\]', 'const ALL_ABILITIES: Array = [M1, M2, BLINK, ARCANE_ORB, ARCANE_PULL, ARCANE_PULSE, ARCANE_SILENCE, TIME_RIFT, STARFALL, ARCANE_SURGE]', s)
    s = re.sub(r'const POOL_ABILITIES: Array = \[.*?\]', 'const POOL_ABILITIES: Array = [BLINK, ARCANE_ORB, ARCANE_PULL, ARCANE_PULSE, ARCANE_SILENCE, TIME_RIFT, STARFALL, ARCANE_SURGE]', s)
    m = re.search(r'const DEFAULT_LOADOUT: Dictionary = \{.*?\n\}\n', s, flags=re.S)
    s = s[:m.start()] + 'const DEFAULT_LOADOUT: Dictionary = {\n\t"SHIFT": &"blink",\n\t"Q": &"arcane_pull",\n\t"E": &"arcane_pulse",\n\t"R": &"arcane_silence",\n\t"S2": &"starfall",\n\t"F": &"arcane_surge",\n}\n' + s[m.end():]
    return s
edit('combat/mage_kit.gd', mage)


def sim(s):
    s = rep(s, "var knock_timer: float = 0.0\n", "var knock_timer: float = 0.0\nvar silence_timer: float = 0.0\n")
    s = rep(s, "func _tick_timers(delta: float) -> void:\n", "func _tick_timers(delta: float) -> void:\n	silence_timer = maxf(0.0, silence_timer - delta)\n")
    s = rep(s, "	if cooldown_left(slot) > 0.0:\n		return false\n	if bool(ability.get(\"requires_behind\"", "	if silence_timer > 0.0 and slot != \"M1\" and slot != \"M2\":\n		return false  # silenciado: solo ataque básico y defensa\n	if cooldown_left(slot) > 0.0:\n		return false\n	if bool(ability.get(\"requires_behind\"")
    s = rep(s, "	if bool(effects.get(\"interrupt\", false)) and state == AttackState.WINDUP:\n		_cancel_cast()\n", "	var silence := float(effects.get(\"silence\", 0.0))\n	if silence > 0.0:\n		silence_timer = maxf(silence_timer, silence)\n		if state == AttackState.WINDUP and String(current_slot) not in [\"M1\", \"M2\"]:\n			_cancel_cast()\n	var pull := float(effects.get(\"pull\", 0.0))\n	if pull > 0.0 and source != Vector2.ZERO:\n		var to_source := source - position\n		var travel := minf(pull, maxf(to_source.length() - 70.0, 0.0))\n		knock_vel = to_source.normalized() * (travel / 0.18)\n		knock_timer = 0.18\n	if bool(effects.get(\"interrupt\", false)) and state == AttackState.WINDUP:\n		_cancel_cast()\n")
    return s
edit('game/sim/warrior_sim.gd', sim)


def dummy(s):
    s = rep(s, "var knock_timer: float = 0.0\n", "var knock_timer: float = 0.0\nvar silence_timer: float = 0.0\n")
    s = rep(s, "func _tick_effects(delta: float) -> void:\n", "func _tick_effects(delta: float) -> void:\n	silence_timer = maxf(0.0, silence_timer - delta)\n")
    s = rep(s, "func apply_effects(effects: Dictionary, source: Vector2 = Vector2.ZERO) -> void:\n", "func apply_effects(effects: Dictionary, source: Vector2 = Vector2.ZERO) -> void:\n	var silence := float(effects.get(\"silence\", 0.0))\n	if silence > 0.0:\n		silence_timer = maxf(silence_timer, silence)\n		effect_applied.emit(\"silence\", silence)\n	var pull := float(effects.get(\"pull\", 0.0))\n	if pull > 0.0 and source != Vector2.ZERO:\n		var to_source := source - position\n		var travel := minf(pull, maxf(to_source.length() - 70.0, 0.0))\n		knock_vel = to_source.normalized() * (travel / 0.18)\n		knock_timer = 0.18\n		interrupt()\n")
    return s
edit('game/sim/dummy_sim.gd', dummy)


def enemy(s):
    s = rep(s, "func _decide_attack(warrior: Object, dir: Vector2, distance: float) -> bool:\n	var hp := health / maxf(max_health, 1.0)\n", "func _decide_attack(warrior: Object, dir: Vector2, distance: float) -> bool:\n	var hp := health / maxf(max_health, 1.0)\n	if silence_timer > 0.0:  # silenciado: solo puede dar su combo básico\n		if distance <= float(WarriorKit.M1[\"range\"]) + TARGET_RADIUS and _breath <= 0.0:\n			combo_index = 0\n			_begin_m1_swing()\n			return true\n		return false\n")
    s = rep(s, "	if attack_began and distance < REACT_DISTANCE:", "	if attack_began and distance < REACT_DISTANCE and silence_timer <= 0.0:")
    return s
edit('game/sim/enemy_sim.gd', enemy)
print("mage+sim ok")
