## CharacterProfile — personaje elegido en el creador (vive entre escenas).
class_name CharacterProfile
extends RefCounted

static var chosen: bool = false
## Torre: piso 1 (Praderas) con misión, o patio de entrenamiento (F3 alterna).
static var tower_mode: bool = true
static var floor_seed: int = 1
static var player_name: String = "Héroe"
static var class_id: StringName = &"warrior"
static var appearance: Dictionary = {}
