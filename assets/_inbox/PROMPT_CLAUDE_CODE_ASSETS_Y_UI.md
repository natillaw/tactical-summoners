# PROMPT para Claude Code — Tactical Summoners: integrar los packs nuevos, unificar el arte y hacer la interfaz completa

> Pégalo entero en Claude Code dentro de `C:\Users\natha\gamedev1\tactical-summoners-v10`.

---

Eres el desarrollador principal de **Tactical Summoners** (Godot 4.7.2, GDScript, UI construida por código). Tu tarea es:
**(A)** importar los packs de assets que acabo de descargar;
**(B)** ajustarlos para que todo parezca del mismo mundo que los héroes de Caz;
**(C)** diseñar e implementar la **interfaz de todo el juego** (HUD de combate, habilidades, órdenes, pueblo, invocación, roster, héroe, inventario, resultados, menús y opciones).
Trabaja por fases y, al final de cada fase, deja algo jugable y probado.

## 0. Antes de tocar nada (obligatorio)
1. Lee `CLAUDE.md`, `AGENTS.md`, `docs/specs/ART_DIRECTION.md` (sobre todo la sección "Cohesión con los héroes", D-055), `docs/ASSET_REGISTRY.md` y, en `docs/DECISIONS.md`, solo D-007, D-008, D-020, D-023, D-024, D-030, D-055, D-057 y D-058. Además lee `docs/specs/CONTROL_AND_MISSIONS.md` (HUD, órdenes, cámara 1-5) y `docs/specs/HEROES_AND_SUMMONING.md` (pantallas de héroe e invocación).
2. Mira cómo está hecha la UI hoy: `scripts/ui/ui_kit.gd`, `hero_info_panel.gd`, `town_screen.gd`, `summon_screen.gd`, `roster_screen.gd`, `party_screen.gd`, `star_row.gd`, `hero_portrait.gd`, `scripts/sandbox/sandbox_screen.gd` (HUD de expedición), `scripts/combat/skill_aim_view.gd` y `order_marker.gd`, y también `scripts/sandbox/combat_vfx.gd`, `enemy_sprites.gd` y `caz_art.gd`.
3. Ejecuta las pruebas (`tools\Run-Tests.ps1`) y guarda la línea base. **No rompas ninguna suite.** Si una ya fallaba antes, apúntalo y no la "arregles" a escondidas.
4. Si algo de este prompt contradice `docs/DECISIONS.md`, **manda DECISIONS**: avísame y pregunta. Si una tarea toca una idea PENDIENTE (P-xx), pregunta antes.
5. **Reglas fijas:** no modificar `assets/sprites/**` (héroes de Caz, D-023). No usar ningún asset sin licencia registrada (D-024). Los ajustes se hacen siempre sobre **copias** en `assets/processed/` generadas por script; los originales no se tocan. Pixel art solo con escalado entero y filtro *nearest*. Nada de 3D ni de assets con aspecto voxel o render en pantalla (D-007).

## 1. Los packs que bajé (están en `C:\Users\natha\Downloads\`)
Si no ves esa carpeta, pídeme que copie los zips a `assets/_inbox/` (tiene `.gdignore`). **No subas los zips crudos a git**: añade `assets/_inbox/*.zip` y `assets/_inbox/**/raw/` a `.gitignore` e importa al repo solo los archivos que se usen.

| Zip | Qué es | Licencia (leer el archivo del zip o la página) | Veredicto |
|---|---|---|---|
| `Ninja Adventure - Asset Pack.zip` (94 MB) | Monstruos y jefes animados de 16 px, música (25), SFX, fuentes, VFX, iconos de hechizo, facesets, UI | CC0 | **Usar**: monstruos y jefes del bosque, música, SFX y VFX |
| `tinyRPG_dragonRegaliaGUI_v1_0.zip` | 9-slices, cabeceras, pestañas, barras, botones, cursores (`license.html`) | CC0 | **Usar**: base del theme de toda la UI |
| `FREE RPG SKILL ICONS 16x16.zip` / `32x32.zip` (kurai7) | 48 iconos de habilidad + borde dorado | Uso comercial sí, no redistribuir | **Usar**: iconos de habilidad |
| `MV Icons Complete Sheet - Free Icons.zip` (Caz) | Hoja de iconos de Caz (equipo, etc.) | CC BY 4.0, acreditar a Caz (ver `EULA - READ ME.txt`) | **Usar**: iconos de objetos y equipo (mismo artista que los héroes) |
| `Free - Raven Fantasy Icons.zip` (Clockwork Raven) | Iconos de 16, 32 y 64 px, más de 400 archivos | El zip **no trae licencia**: buscar la página en itch y registrarla; si no se puede confirmar, no usar | Pendiente de licencia: complemento de iconos |
| `kenney_interface-sounds.zip` | 100 sonidos de UI | CC0 (`License.txt`) | **Usar** |
| `xDeviruchi - 8-bit Fantasy & Adventure Music (2021).zip` (266 MB) | 10 loops | CC BY-SA 4.0, acreditar | **Usar**: título, pueblo, mazmorra, batalla, jefe. Convertir a OGG si viene en WAV |
| `m5x7.ttf`, `m6x11.ttf` (Daniel Linssen) | Fuentes pixel | m5x7 CC0; m6x11, verificar | **Usar**: m5x7 para el texto y m6x11 para los títulos |
| `Enemy_Animations_Set.zip` | Esqueletos ×2 y vampiro (attack, death, idle, move, hurt) | El zip **no trae licencia ni autor**: buscarlo | Pendiente de licencia; útil si se confirma |
| `2D Pixel Dungeon Asset Pack v2.0.zip` | Tileset de mazmorra + personajes + esqueletos animados (2018) | El zip **no trae licencia**: buscar la página (probablemente Pixel_Poem, itch) | Pendiente de licencia: tiles de mazmorra para los pisos que no son de bosque |
| `Cute_Fantasy_Free.zip` | Tiles, animales, enemigos, jugador | **Solo uso NO comercial** (`read_me.txt`) | **NO USAR** en el juego. Como mucho, como referencia |
| `items.zip` + `items_sheet.png` | 1244 PNG `itemN.png` sin autor | Desconocida | **NO USAR** hasta que yo diga de dónde salió |
| `pumpkin_dude.png` | Un solo sprite suelto de 0x72 | CC0 | Sobra. Me faltó bajar **16x16 DungeonTileset II** completo: avísame si lo necesitas |
| `assets/_inbox/ts_generated_kit/` (ya en el repo) | Kit propio: órdenes, social, estrellas, rareza, anillos, retícula, extracción, portal, invocación ×6 rarezas, ranuras de retrato, marcos | Original del proyecto | **Usar**. Leer su `manifest.json` (frames, fps, 9-slice) |

Packs que ya estaban: Caz (héroes y Base Pack), Pixel Crawler, SpritePilot, KILN, Sprite Kitchen y Voxel Dungeon. Los de mis Descargas con `kenney_ui-pack`, `kenney_game-icons`, `Pixel UI pack 3`, `Pixel_Castle_Interior_Tileset` y `Tiny RPG Character Asset Pack` también se pueden revisar como plan B, **pero no mezcles 3 estilos de UI**: elige uno.

**Para cada pack:** léelo, registra la licencia en `assets/ASSET_REGISTRY.json` → `CREDITS.md` con `tools/Import-Asset.ps1` (o amplía la herramienta) y actualiza `docs/ASSET_REGISTRY.md`. Haz además una pantalla de **Créditos** en el juego que se genere desde el registro.

## 2. Fase A — Importar y hacer un "art bible" en código
1. Extrae solo lo útil a `assets/pixel/{enemies,bosses,tilesets,ui,icons,fx}/<pack>/` y el audio a `assets/audio/{music,sfx,ui}/<pack>/`. Guarda un `Terms.txt` o `LICENSE` al lado de cada pack.
2. Crea `scripts/data/art_palette.gd` con la paleta oficial sacada de los héroes de Caz: contorno `#190657`, rampas azul, dorado, piel, piedra y los 6 colores de rareza del kit (común gris, poco común verde, raro azul, épico morado, legendario dorado, mítico rojo). La UI, los VFX tintados y los textos flotantes **solo** usan colores de aquí.
3. Crea `scripts/data/asset_catalog.gd`: un catálogo único con id → ruta, frame size, frames, fps, pivot y escala. Ningún script debe tener rutas de assets escritas a mano; migra `EnemySprites`, `CombatVFX`, `MapTiles` y `CazArt` a leer de ahí sin cambiar su comportamiento.

## 3. Fase B — Que todo parezca del mismo mundo
1. Amplía `tools/art_cohesion.gd` para que procese **todos** los packs nuevos y genere copias en `assets/processed/`:
   - **Contorno exterior** a la luminosidad de Caz (≈`#190657`), conservando como mucho un 25 % del tono propio.
   - **Cuantizado de paleta** suave hacia `art_palette` en enemigos, iconos y tiles de terceros (que se pueda desactivar por asset si queda peor). Sin colores puros ni brillo mayor que el de los héroes.
   - **Escala**: medir con `tools/measure_scale.gd` frente al héroe (31 px) y asignar la clase de tamaño de `CombatRules`. Los iconos de 32 px se usan en el HUD a 1× con nearest, nunca a escalas no enteras.
   - **Convención**: tiras horizontales de frames cuadrados, pies abajo, mirando a la derecha (voltear por código).
2. **Monstruos:** reemplaza en los pisos 1-10 (bosque, D-031) las criaturas **voxel** por monstruos pixel de Ninja Adventure, y por los de `Enemy_Animations_Set` y `2D Pixel Dungeon` si se confirma su licencia. Conserva roles y estadísticas de `enemy_defs.gd`, cambiando solo el aspecto. Los jefes de Ninja Adventure van a los pisos 5 y 10. Si un monstruo no tiene `attack` o `hurt`, hazlos por código (squash, lunge, flash blanco, knockback) con `hero_anim.gd` como modelo.
3. **Tiles:** el bosque y el pueblo siguen con Caz. Prepara un bioma de "mazmorra o torre interior" con Caz `CastleInterior`/`CaveInterior` + `2D Pixel Dungeon` (si la licencia lo permite) para cuando se use. **No mezcles en una misma pantalla dos tilesets con contorno distinto.**
4. **VFX:** baja la saturación y ajusta el contorno de los efectos de terceros. Los anillos, la retícula, el marcador de destino y la zona de extracción pasan a usar el kit propio (`ts_generated_kit/world/`).
5. Genera `tests/capture_cohesion.tscn` con una captura donde salgan héroes de Caz, cada monstruo nuevo, tiles, iconos y VFX juntos sobre el bosque. **Revísala tú mismo** y lista lo que todavía desentona.

## 4. Fase C — La interfaz completa (lo más importante)
### 4.1 Base: un solo Theme
- `scripts/ui/ui_theme.gd` construye **por código** un `Theme` global con los 9-slices de Dragon Regalia (o el panel del kit propio): paneles, botones (rest, hover, pressed, disabled), pestañas, cabeceras, barras, tooltips, scrollbars, sliders, checkboxes y campos de texto. Fuentes: m5x7 (cuerpo) y m6x11 (títulos), tamaños enteros y sin antialiasing. Todo con la paleta de `art_palette`.
- Resolución base de pixel art (propón 640×360 o 480×270 tras una prueba) con `stretch_mode = viewport` o `canvas_items` y escalado entero. La UI tiene que verse nítida a 1280×720, 1920×1080 y 2560×1440.
- **Sonidos de UI** (Kenney) en un autoload `UiSfx`: hover, click, confirmar, cancelar, error, abrir/cerrar panel, subir de nivel y pull de invocación por rareza. **Música** con un autoload `Music` con crossfade: título, pueblo, expedición, combate (sube al detectar enemigos), jefe y resultados.
- Accesibilidad: nada se comunica solo con color (forma, icono o texto además del color), tooltips en todo icono, y escala de UI en opciones.
- Refactoriza `ui_kit.gd` para que todas las pantallas usen los mismos componentes: `UiPanel`, `UiButton`, `IconButton`, `Bar` (HP, maná, XP, stamina con valor numérico opcional), `StarRow` (hasta 7★ con las estrellas del kit), `RarityFrame`, `PortraitSlot`, `Tooltip` rico (título, rareza, descripción, stats, coste, cooldown) y `Toast`/notificación.

### 4.2 HUD de expedición y combate (`sandbox_screen.gd`)
Distribución (ajústala si chocas con algo y explícame por qué):
- **Abajo-izquierda: barra de party.** 5 `PortraitSlot` numerados 1-5 (normal, enfocado, muerto, del kit) con retrato, HP, recurso y estados (iconos pequeños con duración). Clic o tecla 1-5 = enfocar. Además, marcadores compactos de **Confianza, Obediencia y Compostura** (iconos social_* + medidor) y un aviso visible cuando un héroe **desobedece** o pierde la compostura.
- **Abajo-centro: barra de habilidades del héroe enfocado.** Iconos de kurai7 o Ninja según `skill_defs.gd`, con overlay radial de **cooldown**, coste, rango (en el tooltip y como círculo al pasar el ratón, reutilizando `skill_aim_view.gd`), teclas Q, W, E, R y estado "sin recurso" o "fuera de rango". Al lado, la pasiva.
- **Abajo-derecha: panel de órdenes.** Botones con los iconos `order_*` del kit: mover, atacar, attack-move, mantener, seguir, interactuar, explorar y retirada o extracción, con atajos visibles. Feedback de orden: marcador de destino, retícula de objetivo, `order_invalid` con motivo en un toast y la **orden activa** de cada héroe.
- **Arriba-izquierda: objetivo de la misión** (tipo de misión con icono, progreso y temporizador si lo hay), piso actual y si es un piso de pico o de jefe.
- **Arriba-derecha: minimapa** con niebla de guerra (`fog_map`), héroes, enemigos vistos, salida o extracción, y botones de cámara (vista de grupo `Tab`, seguir héroe).
- **Mundo:** anillos de selección (aliado, enemigo, foco animado) **debajo** de los pies (z-index correcto), barras de vida pequeñas sobre los enemigos solo si están heridos o seleccionados, flechas de aliados fuera de pantalla con su número, telegrafías de jefes con zona segura e insegura claras y textos flotantes con la fuente pixel.
- **Jefe:** barra grande arriba-centro con nombre, fases y escudo.
- **Pausa/menú (Esc):** como el juego no se pausa (D-010), Esc abre opciones **sin pausar** salvo que DECISIONS diga otra cosa: pregúntame.

### 4.3 Pueblo (`town_screen.gd`) — el pueblo es la pantalla principal (D-030)
- Barra superior de **recursos** (comida, madera, piedra, gemas, piedras de promoción, libros) con los iconos `res_*` del kit y tooltips de ingreso y gasto por día.
- Botones de acceso rápido: Invocar, Roster, Party, Inventario, Construir, Torre (portal), Memorial y Opciones.
- Paneles de edificio con el Theme: trabajadores, producción, camas, pacientes, almacén, obras y "!" con motivo, más el modo construir y mover con fantasma del edificio, coste y validez.
- El portal de la torre usa `ts_generated_kit/world/tower_portal.png` animado en el mapa del pueblo.

### 4.4 Invocación (`summon_screen.gd`)
- Banners con odds visibles (7 rarezas o estrellas según DECISIONS), contador de pity y botones ×1 y ×10 con coste.
- **Secuencia de revelado:** círculo `summon_circle_<rareza>` girando → rayo `summon_beam_<rareza>` → `card_back_<rareza>` que se voltea → héroe con su marco de rareza, estrellas, clase y rasgos destacados. Se puede saltar, y en ×10 hay resumen en rejilla. La rareza alta tiene más shake, partículas y sonido (sin pasarse). No se copian pantallas de ningún gacha real (D-002).

### 4.5 Héroe, roster y party
- **Roster:** rejilla de `RarityFrame` + retrato + estrellas + nivel + clase, con filtros (clase, rareza, estado, profesión), orden y búsqueda. Los muertos van al Memorial.
- **Ficha de héroe (pestañas):** Resumen (sprite animado, atributos, rasgos, personalidad, trasfondo), Habilidades (rejilla con iconos, nivel, libros, entrenar), Equipo (8 ranuras con los marcos de Dragon Regalia), Progresión (nivel y estrellas hasta 7★, ascensión con Suerte y pity, síntesis, sacrificio y promoción, con un **preview de lo que se gana y se pierde** antes de confirmar), Profesión (principal y secundaria con nivel 0-10) y Relaciones (vínculos y rivalidades con iconos).
- **Party:** 5 ranuras (arrastrar y soltar), sinergias visibles y aviso de party incompleta.

### 4.6 Inventario, forja y botín
- Rejilla con iconos de Caz MV (y Raven si se confirma), con borde según **rareza** (6 rarezas, D-039), tooltip con afijos, sets y comparación con lo equipado (flechas ▲▼, no solo color), y filtros. En la forja: receta, materiales que tienes o te faltan, y calidad según la profesión.

### 4.7 Resultados de expedición y otras pantallas
- Resultados: MVP, XP por héroe con barra animada, drops con rareza, muertes, recursos y botón "volver al pueblo".
- Pantalla de título (música, fondo con el bosque y héroes animados), carga entre escenas con fade, bienvenida (`welcome_screen.gd`), **Opciones** (volumen de música, SFX y UI, escala de UI, pantalla completa, atajos visibles) y **Créditos** generados desde el registro de assets.

## 5. Pruebas y evidencia
- Añade la suite `tests/smoke_ui_full.gd`: abre cada pantalla, comprueba que no hay errores de script ni texturas nulas (todas las rutas del `asset_catalog` existen), que el Theme se aplica y que los atajos 1-5, Q/W/E/R y las órdenes responden.
- Amplía `tests/capture_screens.tscn` con capturas de: HUD en combate con 5 héroes, jefe, pueblo, invocación (cada fase del revelado), roster, ficha de héroe (cada pestaña), inventario, resultados, opciones y créditos. **Míralas** y corrige lo que se vea feo: textos cortados, solapes, escalado borroso, colores fuera de paleta.
- Ejecuta todas las suites. Cita la salida real; nunca supongas un PASS.

## 6. Entrega
- Trabaja en una rama (`feat/ui-and-art-unification`), con commits pequeños por fase. Sin push a `main` y sin merge sin mi permiso.
- Actualiza `docs/ASSET_REGISTRY.md`, `assets/CREDITS.md`, `docs/IMPLEMENTATION_STATUS.md` (solo con evidencia), `docs/VERSIONS.md` y un informe `docs/reports/UI_AND_ART_UNIFICATION_REPORT.md` con capturas antes y después, qué packs se usaron y cuáles no, y licencias pendientes.
- Al terminar, dime: qué cambiaste, qué ejecutaste (con la salida), qué quedó sin verificar y una lista corta de cosas que tengo que probar yo a mano en Windows.

**Cuándo preguntarme en vez de decidir:** licencias dudosas, cualquier P-xx pendiente, la resolución base, si Esc pausa o no, y cualquier cambio de gameplay. Lo visual decídelo tú, guiado por la cohesión con Caz.
