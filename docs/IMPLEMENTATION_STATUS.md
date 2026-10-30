# Estado de implementación (lo que existe de verdad)

**Última revisión:** 2026-10-30 — versión **v2** (`fb3ee7c`), ver `docs/VERSIONS.md`.
**Evidencia:** GitHub Actions, Godot 4.7.1 Linux headless. v1 (código original): **6/12 PASS** ([run 41113420228](https://github.com/natillaw/tactical-summoners/actions/runs/41113420228)). v2: **14/14 PASS** ([run 41113770886](https://github.com/natillaw/tactical-summoners/actions/runs/41113770886)); capturas sin errores de script. Las afirmaciones de "todas las suites PASS" de sesiones anteriores eran falsas (la v1 falla 6). Nada se ha probado aún a mano en Windows.

Leyenda: **I** implementado (sin ejecutar) · **ID** implementado pero defectuoso · **P** parcial / solo datos · **N** no implementado. "F-0xx" = hallazgo en `audit/AUDIT_FINDINGS.json`.

## Motor y proyecto
- `project.godot`: Godot **4.7** (`config/features`), renderer `gl_compatibility`, 1280×720, autoload `Game`. Versión realmente instalada por el dueño: **sin verificar**.
- Ejecutar pruebas: CI en cada push (`.github/workflows/godot-ci.yml`), `tools/run_tests.sh` (Linux) o `tools\Run-Tests.ps1` (Windows). **14 suites**, último resultado: 14/14 PASS (v2).

## Por sistema
| Sistema | Estado | Archivos | Notas |
|---|---|---|---|
| Invocación (banners, pity, coste atómico, log 200) | I | `scripts/data/summon_config.gd`, `scripts/core/gacha.gd`, `Game.pull` | Si se supera la capacidad del roster, el mensaje dice "Not enough gems" (F-015) |
| Generación de héroes | ID | `scripts/core/hero_generator.gd`, `scripts/data/hero_tables.gd` | Misma semilla ≠ mismo héroe que en versiones previas sin subir `VERSION` (F-008) |
| HeroData + snapshot en guardado | I | `scripts/core/hero_data.gd` | — |
| Atributos y stats (D-035) | I (v6, probado: `combat core`) | `HeroData.attributes()`, `CombatRules.derive()` | FUE/AGI/VIT/INT/TEM → vida, poderes, armadura, M.RES, velocidad, cadencia, crítico, energía, resistencia a estados |
| Clases | P | `hero_tables.gd` | Commoner + Warrior/Rogue/Ranger/Cleric/Mage; avanzadas: lista vacía |
| Promoción por estrellas + XP por libros | I | `Game.promote/train` | F-007 reparado en v2 (prueba en `test_core`). Escala actual 5★; D-029 pide 7★/70 (Fase 5) |
| Rasgos (16) y pasivas (16) | P | `hero_tables.gd` | Las pasivas no tienen efecto en juego; texto de turnos (F-016) |
| Trust/Obedience/Composure + ledger | P | `hero_data.gd` | Composure no cambia nunca; Trust solo con `ally_fell` −2 (F-019) |
| Memorias, relaciones | P | `hero_data.gd`, `game.gd` | Se actualizan en HQ y muertes |
| Rescate, cooperación, secretos | P | `hero_data.gd` | Solo se llaman desde las pruebas |
| Profesiones | P | `hero_tables.gd` | Se muestran; no tienen efecto (F-009) |
| Guardado atómico v5 + migraciones v1→v5 + `.bak` | I | `scripts/autoload/game.gd` | Los pisos se guardan como semilla (F-014) |
| Muerte permanente + memorial | I | `Game.record_death`, `scripts/ui/memorial_screen.gd` | — |
| Mapas: base común `NavMap` (fijo `SandboxMap` + procedural `ProceduralMap`) | I (v2, probado) | `scripts/core/nav_map.gd` | En v1 el sandbox no tenía héroes en Godot 4.7 (F-038) |
| Sandbox: mapa fijo 40×24, A*, selección, cámara 1-5/Tab/G, mover, stop | I (v2, probado) | `scripts/sandbox/` | Ranura muerta sin mensaje (F-018) |
| Órdenes atacar/attack-move/mantener/seguir/interactuar/retirada | N | — | F-018 |
| Núcleo de combate (Combatant, daño, críticos, estados, caída/agonía/rescate, D-036/D-037) | I (v6, probado: `combat core`) | `scripts/combat/` | Fases 4-8 del plan en `audit/COMBAT_AUDIT.md` |
| Habilidades activas y recursos de clase (D-040…D-046) | I (v8, probado: `skills`, `mission`; CI 18/18 en `304c2f6`) | `scripts/data/skill_defs.gd`, `sandbox_hero.gd`, `combat_zone.gd`, `HeroData.skills/loadout/skill_choices`, `Game.skill_books` | ≈45 habilidades, Q/W/E/R, lanzamientos interrumpibles solo por control, elecciones por nivel, libros y Biblioteca, save v8. **Sin uso automático de habilidades por la IA del héroe** (pendiente de decisión). Pasivas siguen sin efecto (P-27). `skill_tables.gd` antiguo ya no se usa |
| Ataque automático, enemigos con telegrafía | I | `sandbox_hero.gd`, `sandbox_enemy.gd` | — |
| 1 habilidad activa por clase (Q) | I | `scripts/sandbox/skill_tables.gd` | La biblioteca D-022 no existe (F-010) |
| Misiones: 7 tipos por piso + relicario en entrenamiento (D-034) | I (v5, probado: `smoke_tower` cubre los 7 tipos) | `sandbox_screen.gd` | Relicario en `map.relic_cell`, extracción en `map.extract_cell` (F-003/F-013 reparados) |
| Torre pisos 1-10 + mapa procedural (bosque, D-031) | I (v4, probado: `smoke_tower` pisos 1/5/10 + capturas 1-5) | `scripts/core/tower_expedition.gd`, `procedural_map.gd` | F-002 reparado. Falta selector de piso en la UI y misiones por tipo (F-020) |
| **Pueblo (pantalla inicial, D-030)** | I (v3, probado: `test_town`, `boot`, `tower` + capturas) | `scripts/ui/town_screen.gd`, `scripts/sandbox/town_*.gd`, `scripts/data/town_tables.gd` | 14 edificios con niveles; construir/mejorar con materiales; producción × nivel; save v6. Herrería/alquimia sin efecto hasta P-19/P-20 |
| HQ (pantalla de asignación, desde el Ayuntamiento) | I | `scripts/ui/hq_screen.gd` | Producción depende del nivel del edificio |
| HQ explorable | P (v2, probado: se construye sin errores) | `scripts/sandbox/hq_world.gd` | F-001 reparado (en v1 era error en ejecución; el juego sí arrancaba). Sin decorado (P-04) |
| Animaciones en código (D-020) | I | `scripts/sandbox/hero_anim.gd`, `sprite_composer.gd` | No verificadas visualmente |
| Sprites de enemigos y tiles (Pixel Crawler) | I | `enemy_sprites.gd`, `map_tiles.gd` | — |
| VFX de combate | I (v3) | `combat_vfx.gd` | F-012 reparado; efectos SpritePilot en ataques, habilidades y golpes enemigos |
| Diálogo por rasgo al entrar | P | `hero_chatter.gd` | Siempre habla del relicario |
| Personalidad de 8 dimensiones, síntesis, sacrificio, equipo, inventario, loot, afijos, sets, crafting, biomas, eventos, jefes, audio, fuente pixel | N | — | — |

## Pruebas (14 suites)
core, summons v2, ui smoke, sandbox, memorial v3, combat, mission, animation, art, simulation, deep systems, procedural, **boot** (escena principal + todas las pantallas), **tower** (pisos 1/5/10 + HQWorld). v2: 14/14 PASS. Capturas automáticas: `tests/capture_screens.tscn` (no es pass/fail).

## Cómo actualizar este archivo
Solo con evidencia: pega el comando y el resumen de la salida, o escribe "NO VERIFICADO". Cambia la fila del sistema afectado; no añadas historia (va al commit).
