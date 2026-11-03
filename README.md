# Project B — Reflections

RPG de acción 2D top-down (Godot 4). El diseño, las prioridades y los issues viven en un único documento de diseño; solo se implementa desde sus Partes A (prioridades) y B (issues).

## Arranque

1. Instala Godot 4 (≥ 4.6).
2. Abre el editor y elige **Importar** → `project.godot` en esta carpeta.
   - O desde terminal: `godot --editor --path .`

## Configuración base

- Física / tick de simulación: **60 Hz** (`physics/common/physics_ticks_per_second`).
- Resolución: 1280×720, stretch `canvas_items`.
- Input map:

| Acción | Tecla |
|---|---|
| `move_up` / `move_left` / `move_down` / `move_right` | W / A / S / D |
| `click` | Botón izquierdo del ratón |
| `skill_q` / `skill_w` / `skill_e` / `skill_r` | Q / W / E / R |
| `slot_1` … `slot_4` | 1 … 4 |

> ⚠️ `move_up` y `skill_w` comparten la tecla W (así lo pide el doc). Pendiente de decisión antes de P1.11.

## Estructura

| Carpeta | Contenido |
|---|---|
| `core/` | Tick, loop de juego, utilidades base |
| `net/` | Servidor, cliente, snapshots, predicción |
| `combat/` | Pipeline de efectos, stats, skills, CC, hit detection |
| `data/` | Recursos `.tres` (skills, saves) |
| `ui/` | Debug overlay y UI |
| `content/` | Clases, arenas, torre, dungeon |
