# Mapa del proyecto (dónde tocar cada cosa)

## Escenas que se ven en el editor de Godot
- `game/main_3d.tscn` — escena principal (Arena, HUD, Crosshair, Status, Loadout, Debug).
- `game/world3d/training_arena.tscn` — el escenario; los `Spawns/*` son marcadores (meta: enemy, level, hp).
- `ui/debug_overlay.tscn`, `tools/pose_check.tscn` (ver poses), `tests/capture_3d.tscn`.
- **Actores (ábrelos y edítalos):** `game/actors3d/warrior_actor.tscn`, `soldier_actor.tscn`, `dummy_actor.tscn`. Propiedades en el Inspector: modelo, espada, tinte, nombre. Al jugar se instancian desde `arena_3d.gd`, por eso no salen dentro de Main3D.

## Combate y skills
- `combat/warrior_kit.gd` — TODOS los números de las skills (M1, M2, roll, parry, charge, seismic, bladestorm, pasiva). Tocar aquí cooldowns, daño, rangos.
- `game/sim/warrior_sim.gd` — lógica del jugador (ataques, combo, parry, stun, salto, daño recibido).
- `game/sim/dummy_sim.gd` — muñeco y golpes con telegraph (volumen/altura: `HIT_HEIGHT`).
- `game/sim/enemy_sim.gd` — IA y constantes del Soldado.
- `game/sim/combat_world.gd` — mundo: colisiones, spawn de enemigos.

## Daño (sistema único para todas las clases)
- `combat/damage_system.gd` — tipos (físico, mágico, fuego, hielo, veneno, sagrado, sombra), crítico y resistencias. Una skill declara `"damage_type"` en su kit; los objetivos tienen `resist` por tipo. Tipo nuevo = una fila en `TYPES`.

## Estadísticas, nivel e items
- `game/items/progression.gd` — nivel 1–60, vida, fuerza, XP.
- `game/items/item.gd`, `item_factory.gd`, `item_rarity.gd` — armas y rarezas.
- `combat/stats.gd`, `stat_block.gd` — fórmulas de daño (AP, crítico).

## Presentación (animación, VFX, cámara)
- `game/actors3d/warrior_actor_3d.gd` — modelo/animaciones del jugador (clips por skill).
- `game/actors3d/enemy_actor_3d.gd`, `dummy_actor_3d.gd` — enemigo y muñeco.
- `game/actors3d/humanoid_rig.gd` — reproductor de animaciones.
- `game/world3d/arena_3d.gd`, `view3d.gd` — arena, cámara, efectos.
- `game/vfx3d/` — shapes de telegraph, impactos, estela.

## UI / input / pruebas
- `game/ui/` (hud, crosshair, loadout_panel), `game/input_setup.gd` (teclas), `game/main_3d.gd` (hotkeys debug).
- `tests/` y `combat/tests/` — tests; `tools/run_tests.sh`.
- `docs/DECISIONES.md` — registro de decisiones.
