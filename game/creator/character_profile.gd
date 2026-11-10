## CharacterProfile — personaje elegido en el creador (vive entre escenas).
class_name CharacterProfile
extends RefCounted

static var chosen: bool = false
## Torre: piso 1 (Praderas) con misión, o patio de entrenamiento (F3 alterna).
## Modo actual: "town" (pueblo), "floor" (piso de la torre) o "training" (patio). F3 cicla.
static var mode: String = "town"
static var weapon: Item = null
static var level: int = 1
static var xp: int = 0
static var started: bool = false
static var armor: Dictionary = {}
static var floor_seed: int = 1
static var player_name: String = "Héroe"
static var class_id: StringName = &"warrior"
static var appearance: Dictionary = {}
