## DotTracker — daño en el tiempo (veneno, quemadura, sangrado...).
##
## Cada DoT tiene tipo de daño (DamageSystem.Type), daño por segundo y duración.
## Aplicar el mismo tipo otra vez refresca la duración y se queda con el mayor dps.
## tick() devuelve los golpes de este paso: [{type, amount}].
class_name DotTracker
extends RefCounted

const INTERVAL := 0.5

var _dots: Array = []


## `max_stacks` > 1: aplicar el mismo tipo otra vez acumula (hasta ese máximo); cada acumulación
## suma +60 % del dps base (1.0x, 1.6x, 2.2x), sin explotar ni nada más. Siempre refresca la duración.
func add(type: int, dps: float, duration: float, max_stacks: int = 1) -> void:
	for dot: Dictionary in _dots:
		if int(dot["type"]) == type:
			if max_stacks > 1:
				dot["stacks"] = mini(int(dot["stacks"]) + 1, max_stacks)
				dot["base"] = maxf(float(dot["base"]), dps)
			else:
				dot["base"] = maxf(float(dot["base"]), dps)
			dot["dps"] = float(dot["base"]) * (1.0 + 0.6 * float(int(dot["stacks"]) - 1))
			dot["left"] = maxf(float(dot["left"]), duration)
			return
	_dots.append({"type": type, "dps": dps, "base": dps, "stacks": 1, "left": duration, "acc": 0.0})


func stacks_of(type: int) -> int:
	for dot: Dictionary in _dots:
		if int(dot["type"]) == type:
			return int(dot["stacks"])
	return 0


func tick(delta: float) -> Array:
	var out: Array = []
	for dot: Dictionary in _dots:
		dot["left"] = float(dot["left"]) - delta
		dot["acc"] = float(dot["acc"]) + delta
		while float(dot["acc"]) >= INTERVAL:
			dot["acc"] = float(dot["acc"]) - INTERVAL
			out.append({"type": int(dot["type"]), "amount": float(dot["dps"]) * INTERVAL})
	_dots = _dots.filter(func(d: Dictionary) -> bool: return float(d["left"]) > 0.0)
	return out


## Tipo de daño del DoT más fuerte activo (para el aura visual), o -1.
func dominant_type() -> int:
	var best := -1
	var best_dps := -1.0
	for dot: Dictionary in _dots:
		if float(dot["dps"]) > best_dps:
			best_dps = float(dot["dps"])
			best = int(dot["type"])
	return best


func is_active() -> bool:
	return not _dots.is_empty()


func clear() -> void:
	_dots.clear()
