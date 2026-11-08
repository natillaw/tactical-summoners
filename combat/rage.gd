## Rage — Recurso de combate del Warrior.
##
## Se extiende de ClassResource para reutilizar la arquitectura de recursos
## de clase existente (generate/consume/get_current/is_full). El Warrior
## empieza con 0 Rage y puede entrar en combate sin recursos: Charge genera
## Rage al impactar, y las demás habilidades lo consumen.
class_name Rage
extends ClassResource

## Cantidad de Rage que se otorga al iniciar el combate (0: empieza vacío).
@export var starting_rage: float = 0.0
## Umbral bajo de vida para activar Last Stand (fracción de vida máxima).
@export var last_stand_threshold: float = 0.30
## Bonus de daño mientras Last Stand está activo (multiplicador).
@export var last_stand_damage_bonus: float = 1.50
## Bonus de velocidad de movimiento mientras Last Stand está activo.
@export var last_stand_speed_bonus: float = 1.25
## Cooldown interno de Last Stand en segundos (evita activaciones repetidas).
@export var last_stand_cooldown: float = 10.0


func _init() -> void:
	resource_name = "Rage"
	current_amount = starting_rage
	max_amount = 100.0
	min_amount = 0.0


## Devuelve la cantidad de Rage inicial.
func starting_rage_value() -> float:
	return starting_rage


## Indica si Last Stand debería activarse por la vida actual del Warrior.
func should_activate_last_stand(current_health: float, max_health: float) -> bool:
	if max_health <= 0.0:
		return false
	return (current_health / max_health) <= last_stand_threshold
