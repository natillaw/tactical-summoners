## DotTracker — daño en el tiempo (veneno, quemadura, sangrado...).
##
## Cada DoT tiene tipo de daño (DamageSystem.Type), daño por segundo y duración.
## Aplicar el mismo tipo otra vez refresca la duración y se queda con el mayor dps.
## tick() devuelve los golpes de este paso: [{type, amount}].
class_name DotTracker
extends RefCounted

const INTERVAL := 0.5

var _dots: Array = []


func add(type: int, dps: float, duration: float) -> void:
	for dot: Dictionary in _dots:
		if int(dot["type"]) == type:
			dot["dps"] = maxf(float(dot["dps"]), dps)
			dot["left"] = maxf(float(dot["left"]), duration)
			return
	_dots.append({"type": type, "dps": dps, "left": duration, "acc": 0.0})


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
