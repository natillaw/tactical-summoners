# Estado de implementación (lo que existe de verdad)

**Última revisión:** 2026-10-30 — commit de código auditado `509218b`.
**Evidencia disponible:** solo análisis estático (`audit/`). **No hay ninguna ejecución de pruebas registrada en el repo.** Las afirmaciones anteriores de "todas las suites PASS" (sesiones de Gemini, 2026-10-28/29) no aportaban salida y el análisis estático las contradice: se consideran **NO VERIFICADAS**.

Leyenda: **I** implementado (sin ejecutar) · **ID** implementado pero defectuoso · **P** parcial / solo datos · **N** no implementado. "F-0xx" = hallazgo en `audit/AUDIT_FINDINGS.json`.

## Motor y proyecto
- `project.godot`: Godot **4.7** (`config/features`), renderer `gl_compatibility`, 1280×720, autoload `Game`. Versión realmente instalada por el dueño: **sin verificar**.
- Ejecutar pruebas: `powershell -ExecutionPolicy Bypass -File tools\Run-Tests.ps1` (12 suites). Último resultado conocido: **ninguno registrado**.

## Por sistema
| Sistema | Estado | Archivos | Notas |
|---|---|---|---|
| Invocación (banners, pity, coste atómico, log 200) | I | `scripts/data/summon_config.gd`, `scripts/core/gacha.gd`, `Game.pull` | Si se supera la capacidad del roster, el mensaje dice "Not enough gems" (F-015) |
| Generación de héroes | ID | `scripts/core/hero_generator.gd`, `scripts/data/hero_tables.gd` | Misma semilla ≠ mismo héroe que en versiones previas sin subir `VERSION` (F-008) |
| HeroData + snapshot en guardado | I | `scripts/core/hero_data.gd` | — |
| Stats | P | idem | hp/atk/mag/def/spd; FUE/AGI/VIT/INT/TEM **no** (F-017) |
| Clases | P | `hero_tables.gd` | Commoner + Warrior/Rogue/Ranger/Cleric/Mage; avanzadas: lista vacía |
| Promoción por estrellas + XP por libros | ID | `Game.promote/train` | Héroes `class.none` → división por cero al llegar a 3★ (F-007) |
| Rasgos (16) y pasivas (16) | P | `hero_tables.gd` | Las pasivas no tienen efecto en juego; texto de turnos (F-016) |
| Trust/Obedience/Composure + ledger | P | `hero_data.gd` | Composure no cambia nunca; Trust solo con `ally_fell` −2 (F-019) |
| Memorias, relaciones | P | `hero_data.gd`, `game.gd` | Se actualizan en HQ y muertes |
| Rescate, cooperación, secretos | P | `hero_data.gd` | Solo se llaman desde las pruebas |
| Profesiones | P | `hero_tables.gd` | Se muestran; no tienen efecto (F-009) |
| Guardado atómico v5 + migraciones v1→v5 + `.bak` | I | `scripts/autoload/game.gd` | Los pisos se guardan como semilla (F-014) |
| Muerte permanente + memorial | I | `Game.record_death`, `scripts/ui/memorial_screen.gd` | — |
| Sandbox: mapa fijo 40×24, A*, selección, cámara 1-5/Tab/G, mover, stop | I | `scripts/sandbox/` | Ranura muerta sin mensaje (F-018) |
| Órdenes atacar/attack-move/mantener/seguir/interactuar/retirada | N | — | F-018 |
| Ataque automático, enemigos con telegrafía | I | `sandbox_hero.gd`, `sandbox_enemy.gd` | — |
| 1 habilidad activa por clase (Q) | I | `scripts/sandbox/skill_tables.gd` | La biblioteca D-022 no existe (F-010) |
| Misión "Recover the relic" | ID | `sandbox_screen.gd` | El relicario aparece en la extracción → éxito instantáneo (F-003) |
| Torre pisos 1-10 + mapa procedural | ID | `scripts/core/tower_expedition.gd`, `procedural_map.gd` | Error de tipos `SandboxMap`; no accesible desde la UI (F-002, F-013, F-020) |
| HQ (pantalla de asignación + producción fija) | P | `scripts/ui/hq_screen.gd`, `Game.process_headquarters_turn` | Sistemas paralelos `hq_facilities`/`town_buildings` (F-009) |
| HQ explorable | ID | `scripts/sandbox/hq_world.gd` | No compila (F-001); podría impedir cargar `main.gd` |
| Animaciones en código (D-020) | I | `scripts/sandbox/hero_anim.gd`, `sprite_composer.gd` | No verificadas visualmente |
| Sprites de enemigos y tiles (Pixel Crawler) | I | `enemy_sprites.gd`, `map_tiles.gd` | — |
| VFX de combate | ID | `combat_vfx.gd` | Ruta inexistente (F-012) |
| Diálogo por rasgo al entrar | P | `hero_chatter.gd` | Siempre habla del relicario |
| Personalidad de 8 dimensiones, síntesis, sacrificio, equipo, inventario, loot, afijos, sets, crafting, biomas, eventos, jefes, audio, fuente pixel | N | — | — |

## Pruebas (12 suites en `tools/Run-Tests.ps1`)
Previsión por análisis estático (ver `audit/GODOT_TEST_REPORT.md`): **fallarían** `sandbox`, `combat`, `mission` y `deep systems`; `procedural` no es verificable; las otras 7, sin fallo detectado. No hay pruebas de: arranque de `main.tscn`, modo Torre, `HQWorld`, promoción de `class.none`.

## Cómo actualizar este archivo
Solo con evidencia: pega el comando y el resumen de la salida, o escribe "NO VERIFICADO". Cambia la fila del sistema afectado; no añadas historia (va al commit).
