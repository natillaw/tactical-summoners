## View3D — conversión entre el plano de la simulación (2D, píxeles) y el mundo 3D.
##
## La simulación sigue siendo 2D y determinista: x→derecha, y→abajo, en píxeles.
## En 3D el suelo es el plano XZ (Y arriba) y 1 metro = PX_PER_M píxeles de sim.
## sim (x, y) → 3D (x / PX, h, y / PX). Con la cámara mirando hacia -Z, "arriba
## en pantalla" sigue siendo -y de la sim, igual que en el prototipo 2D.
class_name View3D
extends RefCounted

const PX_PER_M := 40.0


static func to3(sim_pos: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(sim_pos.x / PX_PER_M, height, sim_pos.y / PX_PER_M)


static func to2(world: Vector3) -> Vector2:
	return Vector2(world.x * PX_PER_M, world.z * PX_PER_M)


static func meters(px: float) -> float:
	return px / PX_PER_M


static func dir3(sim_dir: Vector2) -> Vector3:
	return Vector3(sim_dir.x, 0.0, sim_dir.y)


## Yaw (rotation.y) para que un modelo que mira a +Z apunte en `sim_dir`.
static func yaw_for(sim_dir: Vector2) -> float:
	return atan2(sim_dir.x, sim_dir.y)
