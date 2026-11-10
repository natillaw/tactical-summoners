## CharacterProfile — personaje elegido en el creador (vive entre escenas).
class_name CharacterProfile
extends RefCounted

static var chosen: bool = false
## Torre: piso 1 (Praderas) con misión, o patio de entrenamiento (F3 alterna).
## Modo actual: "town" (pueblo), "floor" (piso de la torre) o "training" (patio). F3 cicla.
static var mode: String = "town"
static var weapon: Item = null
static var level: int = 1
## Objetos que no llevas puestos.
static var bag: Array = []
## Pisos ya generados: piso -> {seed, dead (índices de enemigos muertos), gathered (nodos recogidos), done}.
static var floor_saves: Dictionary = {}
static var current_floor: int = 1
## Piso más alto desbloqueado (se sube al completar la misión del piso actual).
static var max_floor: int = 1
## El guardado en disco se revisa una sola vez por ejecución (en el creador).
static var save_checked: bool = false
static var xp: int = 0
static var started: bool = false
static var armor: Dictionary = {}
static var floor_seed: int = 1
static var player_name: String = "Héroe"
static var class_id: StringName = &"warrior"
static var appearance: Dictionary = {}


## Vuelve todo a los valores de un personaje nuevo.
static func reset() -> void:
	chosen = false
	mode = "town"
	weapon = null
	level = 1
	xp = 0
	started = false
	bag = []
	armor = {}
	floor_saves = {}
	current_floor = 1
	max_floor = 1
	player_name = "Héroe"
	class_id = &"warrior"
	appearance = {}
