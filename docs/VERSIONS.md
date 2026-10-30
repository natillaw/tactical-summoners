# Versiones para probar

Cada versión es un commit concreto de la rama `claude/tactical-summoners-audit-b3sqpo`. Puedes descargar cualquiera en ZIP, sin Git, con el enlace de la tabla, y probarlas cuando estés en casa.
Las pruebas automáticas se ejecutan en GitHub (Godot 4.7.1 Linux) con cada push. Pestaña **Actions** del repo → la ejecución → **Summary** (resultado).
**Capturas de la última versión (se ven en el móvil):** https://github.com/natillaw/tactical-summoners/tree/ci-screenshots/claude_tactical-summoners-audit-b3sqpo (abre `README.md` para verlas todas).

| Versión | Commit | Descargar | Qué contiene | Pruebas automáticas (Godot 4.7.1) |
|---|---|---|---|---|
| **v1** | `1bea618` | [ZIP](https://github.com/natillaw/tactical-summoners/archive/1bea618fb02e7d006e9912dc14ef6a7eb63ad10f.zip) | Auditoría + documentación consolidada + CI. **El código del juego es el original** (`509218b`) | **6/12 PASS** — [ejecución](https://github.com/natillaw/tactical-summoners/actions/runs/41113420228). Fallan: sandbox, combat, mission, animation, art, deep systems |
| **v2** | `fb3ee7c` | [ZIP](https://github.com/natillaw/tactical-summoners/archive/fb3ee7cbbd8fdf62a11830d7f14cc1031f9cea23.zip) | Fase 3: reparaciones F-001…F-005, F-007, F-013, F-038 + 2 suites nuevas | **14/14 PASS** — [ejecución](https://github.com/natillaw/tactical-summoners/actions/runs/41113770886) |
| **v3** | (ver el último commit de la rama) | [ZIP de la rama](https://github.com/natillaw/tactical-summoners/archive/refs/heads/claude/tactical-summoners-audit-b3sqpo.zip) | **El juego empieza en el pueblo** (D-030): 14 edificios, construir/mejorar con materiales, héroes paseando; Puerta de la Torre → entrenamiento o pisos 1-10; VFX de los packs en combate | **15/15 PASS** — [ejecución](https://github.com/natillaw/tactical-summoners/actions/runs/41116908580) |
| **v4** | `cf32596` | [ZIP](https://github.com/natillaw/tactical-summoners/archive/cf32596.zip) | Pisos 1-10 de **bosque** procedural con criaturas de bosque; pueblo con casas, árboles, flores y pozo; héroes autónomos en el pueblo; ficha del héroe al hacer clic; tecla M = mapa completo | **15/15 PASS** + capturas de los pisos 1-5 |
| **v5** | `e3f4f3a` | [ZIP](https://github.com/natillaw/tactical-summoners/archive/e3f4f3a.zip) | **Arte de Caz** en pueblo y pisos; 7 tipos de misión (combate, relicario, rescate, exploración, supervivencia, defensa, jefe); jefe orco en el piso 10; recompensas por piso; profesiones expertas ×2; claros irregulares | **15/15 PASS** + capturas pisos 1-5 y 10 |

## Qué probar a mano en cada versión (en Windows, con el editor o F5)
### v1 (estado original, como referencia)
- Al abrir el Sandbox **no aparecen héroes** y sale un error en la consola (F-038, confirmado en GitHub).
- "Living Headquarters → Explore Base" da error (F-001).

### v5
1. Pueblo con el pack de Caz: casas con tejado de paja/teja, fuente en la plaza, farolas, árboles; muñecos de entrenamiento y diana en el cuartel, tumbas en el memorial.
2. Pisos: F1 limpiar el piso · F2 limpiar · F3 relicario · F4 limpiar · F5 rescatar aldeano · F6 explorar 3 pistas · F7 limpiar · F8 sobrevivir 75 s · F9 defender el santuario 60 s · F10 matar al Jefe Orco.
3. Al ganar con tu escuadrón real: gemas, piedras, materiales (para construir) y libros.
4. Asigna en el Ayuntamiento un chef a la cocina o un minero al taller: producen el doble (la ficha del héroe dice "Expert at").

### v4
1. En el pueblo, mira a los héroes: pasean, entran en edificios, entrenan frente al cuartel, descansan en la plaza y hablan entre ellos (bocadillos).
2. **Clic en un héroe**: ficha con retrato, stats, Trust/Obedience/Composure, personalidad, equipo, colores de cada parte del sprite, relaciones, recuerdos y qué está haciendo.
3. Tower Gate → F1…F10: cada piso es un bosque distinto (claros, senderos y muros de árboles) con criaturas según el piso (slimes, ratas, murciélagos, setas, goblins…). Pulsa **M** para ver el mapa entero.

### v3
1. Al abrir el juego aparece **el pueblo**. Arrastra para moverte, rueda para zoom.
2. Clic en un edificio: **Enter** (Summoning Circle → invocar, Barracks → héroes, War Room → escuadrón, Memorial, Town Hall → asignar trabajos y pasar turno) o **Build/Upgrade** con materiales (Alchemy Lab empieza sin construir).
3. **Tower Gate** → "Training ground" (el mapa fijo de siempre) o pisos **F1–F10**.
4. En combate deberías ver tajos, flechas, curación, explosiones y zarpazos de los packs SpritePilot.
5. El botón **Menu** lleva al menú de depuración (gemas, piedras, libros, borrar partida).

### v2
1. Menú → **Sandbox**: aparecen 5 héroes. Prueba las teclas 1-5, Tab y G, el clic izquierdo y el clic derecho.
2. El **relicario** está en la sala lejana de arriba a la derecha y la salida (EXTRACT) está en otro sitio. Recogerlo ya no termina la misión: hay que llevarlo a EXTRACT.
3. Living Headquarters → **Explore Base**: se ven los héroes en el HQ (todavía sin decorado, P-04).
4. Invocar, ver el Roster, montar el Party (5) y volver al Sandbox con tu escuadrón real.
5. Si algo falla, dime la versión, qué hiciste y qué viste (una foto de la pantalla sirve).
Aún no hay un botón para jugar los pisos de la torre. Se prueban automáticamente (suite `tower`), pero el selector de piso está en la Fase 7.

## Problemas visuales conocidos (vistos en las capturas de v2; pendientes)
- **F-039** HQ explorable: los héroes se amontonan en 5 puntos, no hay suelo/paredes dibujados y la cabecera tapa la barra superior. Se arregla junto con el diseño del HQ in-game (P-04).
- **F-040** Sandbox: con la formación cerrada, los números de ranura y las barras de vida de héroes vecinos se solapan.
