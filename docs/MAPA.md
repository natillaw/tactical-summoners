# Mapa del proyecto (dónde tocar cada cosa)

## Escenas que se ven en el editor de Godot
- `game/main_3d.tscn` — escena principal (Arena, HUD, Crosshair, Status, Loadout, Debug).
- `game/world3d/training_arena.tscn` — el escenario; los `Spawns/*` son marcadores (meta: enemy, level, hp).
- `ui/debug_overlay.tscn`, `tools/pose_check.tscn` (ver poses), `tests/capture_3d.tscn`.
- El jugador y los enemigos NO son escenas: se crean por código al jugar (`game/world3d/arena_3d.gd`), por eso no salen en el árbol del editor.

## Combate y skills
- `combat/warrior_kit.gd` — TODOS los números de las skills (M1, M2, roll, parry, charge, seismic, bladestorm, pasiva). Tocar aquí cooldowns, daño, rangos.
- `game/sim/warrior_sim.gd` — lógica del jugador (ataques, combo, parry, stun, salto, daño recibido).
- `game/sim/dummy_sim.gd` — muñeco y golpes con telegraph (volumen/altura: `HIT_HEIGHT`).
- `game/sim/enemy_sim.gd` — IA y constantes del Soldado.
- `game/sim/combat_world.gd` — mundo: colisiones, spawn de enemigos.

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
