## CCDiminish — rendimientos decrecientes del control de masas (estilo WoW).
##
## Cada familia de CC (stun, root, silence...) acorta su duración si se encadena:
## 100 % → 50 % → 25 % → inmune, hasta que pasan RESET_SECONDS sin recibir ese CC.
class_name CCDiminish
extends RefCounted

const RESET_SECONDS := 15.0
const STEPS := [1.0, 0.5, 0.25]

var _count: Dictionary = {}   # familia → CC recibidos
var _since: Dictionary = {}   # familia → segundos desde el último


func tick(delta: float) -> void:
	for kind: String in _since.keys():
		_since[kind] = float(_since[kind]) + delta
		if float(_since[kind]) >= RESET_SECONDS:
			_since.erase(kind)
			_count.erase(kind)


## Duración efectiva (0 = inmune) y registra el CC.
func apply(kind: String, seconds: float) -> float:
	var n := int(_count.get(kind, 0))
	_since[kind] = 0.0
	if n >= STEPS.size():
		return 0.0
	_count[kind] = n + 1
	return seconds * float(STEPS[n])


func reset() -> void:
	_count.clear()
	_since.clear()
