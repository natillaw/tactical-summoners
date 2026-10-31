# Prueba de juego automática: pueblo + pisos 1-5 (2026-10-31)

Rama: `ccr-cb2bbfa2-cg889y` (contenido de `feat/ui-and-art-unification`). Godot 4.7.2 Linux headless.

## Cómo se probó
- `tools/run_tests.sh` (con los finales de línea corregidos en una copia): **24/24 PASS**.
- `tests/playthrough_bot.tscn`: un "jugador" automático. Hace lo siguiente:
  - crea una cuenta nueva, recibe las 10 invocaciones iniciales y construye el pueblo;
  - asigna trabajos, equipa el botín, elige habilidades y lee los libros;
  - juega los pisos 1-5 con órdenes de jugador: attack-move, W/E/R, rescatar, recoger, llevar la reliquia y escapar con X;
  - no usa trucos de daño. Si falla un piso, repite el anterior para subir de nivel.
  - Variables: `PT_FROM` (piso inicial), `PT_ATTEMPTS`, `PT_TRACE`.
  - Ventaja que el bot tiene sobre un jugador: conoce la posición de los objetivos a través de la niebla. Por eso los tiempos medidos son un **mínimo**.
- Muestra: 17 cuentas nuevas y 93 intentos de piso. Resultado: 81 éxitos, 7 bloqueos (piso 4) y 1 escape. Aparte hay 11 intentos del piso 5 con héroes de nivel 1, de los que 9 terminaron en escape.
- Diagnósticos de apoyo:

  | Archivo | Qué comprueba |
  |---|---|
  | `tests/diag_pockets` | Celdas libres sin ruta en los mapas |
  | `tests/diag_trap` | Que un empujón atrapa a un héroe |
  | `tests/diag_reach` | Qué se puede alcanzar desde la entrada |
  | `tests/diag_clues` | Dónde aparecen las pistas de exploración |
  | `tests/diag_exploit` | Bucle de invocar y sacrificar |
  | `tests/diag_perf` | Coste del minimapa, de la lógica y de la niebla |

## Errores
| # | Gravedad | Qué pasa | Evidencia | Causa / arreglo propuesto |
|---|---|---|---|---|
| B1 | **Crítica** | La escuadra (o un enemigo) queda atrapada y un piso de "combate" no se puede terminar: solo queda escapar. | 2 de 17 cuentas: el piso 4 queda en TIMEOUT con 5-6 enemigos vivos en los 3 intentos ("squad stuck near (82, 63)"). `diag_pockets`: los 30 mapas generados (6 cuentas × 5 pisos) tienen entre 8 y 25 celdas libres a las que A* no llega, y muchas tocan el mapa solo en diagonal. `diag_trap`: un empujón de 12 px mete a un héroe en una de esas celdas y luego `find_path` devuelve vacío. | `_nudge`, `_nudge_any` y `_push` solo comprueban el punto de destino, y A* usa `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`, así que se entra cruzando una esquina pero no se puede salir. Arreglo: (a) al generar el mapa, rellenar con árboles las celdas que no se alcanzan desde la entrada; (b) en los empujones, no permitir pasar una esquina en diagonal. |
| B2 | Alta | `tools/run_tests.sh` tiene finales CRLF y en Linux/CI no arranca (`set: -: invalid option`). | Primera ejecución aquí. Hay 22 archivos con CRLF (20 `.gd`, el `.sh` y el `.ps1`). | Añadir `.gitattributes` (`*.sh text eol=lf`) y normalizar. Además, el CI solo se activa en `main` y `claude/**`: `feat/ui-and-art-unification` y esta rama nunca pasaron por el CI. |
| B3 | Media | El minimapa recorre todas las celdas del mapa en cada fotograma. | `diag_perf`: 6,6 ms por fotograma en el piso 5, alrededor del 40 % del presupuesto a 60 FPS, antes de dibujar nada. La lógica de juego cuesta 0,85 ms por tick y la niebla 1,7 ms. | Dibujar el mapa una vez en una textura y redibujar solo cuando cambie la niebla. Importa para el iGPU Ryzen. |
| B4 | Baja | `ERROR: Lambda capture at index 0 was freed` en la consola. | Aparece al salir de la misión con golpes en vuelo. Los temporizadores de `sandbox_hero.gd` (`_area_flash_later`, `_feel_later`, `_fx_later`), `CombatVFX._later` y `CombatFeel.freeze` capturan nodos que ya se liberaron. | No rompe nada, pero ensucia el registro. Conectar con un `Callable` del propio nodo (que se desconecta solo) o usar `weakref`. |
| B5 | Sin confirmar | En una cuenta nueva que entró directamente al piso 5, la escuadra no se movió en 30 min (0 bajas). | Visto 1 vez en unos 15 intentos y no reproducido. | Puede ser B1 en la zona de salida. |

## Balance y diseño
| # | Observación | Datos |
|---|---|---|
| D1 | Los pisos duran mucho menos de lo previsto en D-056 (10-30 min). | Ruta directa del bot: P1 ≈ 2-2,5 min, P2 ≈ 1-1,5, P3 ≈ 2, P4 ≈ 2,5-3, P5 ≈ 1-1,5. Un jugador que explore a ciegas tardará más, pero difícilmente 10 min. |
| D2 | Los pisos 1-4 son demasiado fáciles; el 5 es el único muro. | 0 muertes en más de 70 pisos 1-4 superados, con la vida mínima casi siempre por encima del 70 %. El piso 5 con héroes de nivel 8-9 se pasó en todas las cuentas. Con nivel 1 hubo 9 escapes en 11 intentos. |
| D3 | El jefe del piso 5 se puede ir a buscar directamente, sin hacer nada más. | Victorias con 4-12 de 28 enemigos muertos, en 1-1,5 min. El jefe no tiene fases ni habilidades, solo más vida y daño. |
| D4 | La misión de exploración se resuelve en un solo viaje. | `diag_clues`: las 3 pistas quedan a menos de 260 px del objetivo, porque se eligen de las últimas celdas de la lista. |
| D5 | Las gemas no limitan nada y permiten un bucle de invocar y sacrificar. | 2000 gemas iniciales y 10 por invocación dan 200 invocaciones. Con una sola cama libre, 150 invocaciones dieron 5 héroes de 5★ y 14 de 4★, y los sacrificios llenaron los materiales hasta el tope del almacén. Esto anula las "probabilidades iniciales" y la economía. |
| D6 | Los materiales son el cuello de botella y la ascensión llega tarde. | Primera ascensión: Salón 2 (120) + Santuario (90) + coste (30) = 240 materiales. Los héroes llegan al nivel 9-10 de 10 hacia el piso 5. En 8 días de juego el bot solo llegó al Salón 2 y nunca pudo ascender. El taller (1 puesto, unos 25 materiales al día) es casi la única fuente aparte de las recompensas de piso (30-70). |
| D7 | Los recursos recogidos casi no tienen uso. | Madera, piedra, mineral, pieles, colmillos y gel se acumulan. Solo sirven si existe el taller o el santuario. |
| D8 | Los arqueros dominan y los guerreros aportan poco. | Alcance de los héroes a distancia: 190; golpe a distancia enemigo: 150. Squads de 3-4 exploradores/arqueros barren los pisos. Los guerreros hacen poco daño y "not enough fury" aparece 50-130 veces por piso. |
| D9 | Escapar con X mata a los caídos que no están junto a la salida. | En el piso 5 con nivel 1, cada escape costó 3-4 muertes permanentes. Es coherente con D-036, pero muy duro: ¿no debería poder cargarse a un herido? (pregunta de diseño) |
| D10 | El almacén (150 por recurso) se llena pronto. | Para el día 5 las comidas están al tope y la cocina se para: hace falta el almacén muy temprano. |
| D11 | Los "experts" de `TownTables` usan los ids antiguos `occupation.*`, distintos de los ids de profesión (`lumberjack`…). | `best_workplaces("lumberjack")` devuelve vacío. Solo la ficha del héroe, que usa `h.profession`, lo aprovecha bien. |
| D12 | `Tiny Pixel Fantasy - Base Pack.zip` en la raíz duplica `assets/pixel/caz-base/`. | Ocupa 700 KB. Moverlo fuera del repo o a una carpeta de fuentes. |

## Sin verificar
- La imagen, el sonido y la música (headless).
- Clics reales en la UI de construcción, del inventario y de la ficha (solo las suites `ui full` y `boot`).
- FPS en el PC del dueño.
- Cuánto tarda un jugador humano explorando con niebla.
