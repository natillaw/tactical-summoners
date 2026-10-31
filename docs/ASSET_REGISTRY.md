# Registro de assets y licencias

Vista humana única. Los datos que gestiona la herramienta siguen en `assets/ASSET_REGISTRY.json` → `assets/CREDITS.md` (generados por `tools/Import-Asset.ps1` y `tools/prepare_crawler.py`; no editarlos a mano).
Consolidado de `ASSET_MANIFEST.md` (archivado) y de `audit/ASSET_AUDIT.md`.

## Reglas
1. **Sprites de héroes de Caz intactos** (D-023): no se editan los archivos de `assets/sprites/**`. Las mejoras se hacen por código, efectos, capas aparte o retratos derivados.
2. **Solo assets gratuitos con licencia leída y registrada aquí antes de usarse** (D-024). Que un asset sea gratis no implica que sea de dominio público: hay que leer la licencia del pack concreto.
3. **Prueba antes de importar en masa** (D-008): un héroe, un enemigo, un tile, un efecto y un icono al lado de los héroes de Caz.
4. Para cada asset se registra: ruta, URL de origen, autor, licencia exacta, URL de la licencia, fecha/versión, modificaciones, atribución, si permite uso comercial y si se ha probado en Godot.
5. No redistribuir packs crudos como biblioteca independiente. Antes de hacer público el repo, revisar las licencias marcadas con ⚠.
6. La imagen de referencia del HQ (`docs/specs/reference/hq_ingame_reference_THIRD_PARTY.jpg`) es una captura de un juego comercial de terceros: solo sirve como inspiración interna (D-002) y nunca se incluye en builds.

## Assets en el repositorio
| Pack | Ruta | Uso en el código | Licencia | Estado |
|---|---|---|---|---|
| Tiny Pixel Fantasy – Character Generator (Caz) | `assets/sprites/` (211 PNG, 576×384, celdas de 48 px; figura de estilo ~16 px) | `SpriteComposer` | ⚠ EULA solo enlazada (`assets/sprites/EULA_READ_ME.txt`); **texto no guardado**. Acreditar a Caz. | En uso; falta guardar la EULA y comprobar si permite modificaciones y repos públicos |
| **Tiny Pixel Fantasy – Base Pack (Caz)** | `assets/pixel/caz-base/` (Tiles: Outside, OutsideFeatures, RuralTown/City/Castle/Ship/Cave exterior+interior, Furniture; 8 Characters 576×384) | `CazArt` (pueblo y pisos de bosque) | ⚠ EULA del autor (CC BY 4.0 según el autor): acreditar a Caz. Subido por el dueño 2026-10-30 | **En uso (v5)** |
| Pixel Crawler Free Pack 2.11 (Anokolisa) — tiles | `assets/pixel/tilesets/pixel-crawler/` | `MapTiles` | Términos del autor (`Terms.txt`): crédito opcional, uso comercial sí, no revender | Importado |
| Pixel Crawler — mobs (8) | `assets/pixel/enemies/pixel-crawler/` | `EnemySprites` | Igual | Importado |
| SpritePilot (combat, creatures, effects, environment, magic, pickups, ui, weather) | `assets/packs/spritepilot-*/` | **Sí** (v10): combat, magic y effects en `CombatVFX.FX` | CC0 | Probado (`vfx` + capturas 06) |
| KILN FX Free Sampler | `assets/packs/KILN_FX_Free_Sampler/` | **Sí** (v10): tajos, chispas, explosiones, rayos, círculos, curación, humo, sangre, bolas de fuego | ⚠ Uso en juegos sí; **prohibido redistribuirlo como pack** | Sin prueba |
| Sprite Kitchen – Combat Essentials v0.1 | `assets/packs/sprite_kitchen_combat_essentials_v0.1/` | **Sí** (v10): cross/crescent slash, impactos, polvo | ⚠ Uso en juegos sí; **prohibido subirlo/redistribuirlo como pack**; no entrenar IA con él | Sin prueba |
| Voxel Dungeon Pack (Cole Foster) | `assets/packs/voxel-dungeon-pack-full/` (4 431 PNG, 47 MB) | **Sí**: criaturas de la torre (idle/run/death y, desde v10, attack/hurt) y efectos `fx/sheets` | CC0 | Sin prueba; estilo render 3D/voxel (riesgo de choque con D-007) |
| Copia duplicada de todos los packs | `assets/source_packs/` + `assets/*.zip` | No (salvo confusión de ruta) | — | **Duplicado** (F-021); no se elimina hasta comprobar referencias |

## Candidatos investigados (no descargados)
| Uso | Fuente | Licencia indicada |
|---|---|---|
| Tiles del mismo artista (pueblo, bosque, cueva, castillo, barco) + 8 hojas de personaje | Tiny Pixel Fantasy Base Pack (Caz) — https://cazwolf.itch.io/tiny-pixel-fantasy1 | Según el autor CC BY 4.0, uso comercial; leer la EULA enlazada. Un tile por PNG (hay que empaquetarlos) |
| Tiles de mazmorra + monstruos + armas | 16x16 DungeonTileset II (0x72) — https://0x72.itch.io/dungeontileset-ii | CC0 |
| Más de 100 monstruos de 16×16 | Tiny Creatures (Clint Bellanger) — https://clintbellanger.itch.io/tiny-creatures | CC0 |
| Tiles de mazmorra y personajes chibi | Tiny Dungeon (Kenney) — https://opengameart.org/content/tiny-dungeon | CC0 (contorno grueso: posible choque de estilo) |
| Efectos de mago | Spell Effects (StarsteelGaming) — https://opengameart.org/content/spell-effects-by-starsteelgaming | CC0 |
| Proyectiles y explosiones de 16×16 | Pixel Art Spells (DevWizard) — https://opengameart.org/content/pixel-art-spells | CC0 |
| Efectos de pícaro, cortes e impactos | https://itch.io/c/7139964/attackeffect | Revisar cada página |
| Efectos elementales | NYKNCK — https://itch.io/c/5647574/spells-effects | Revisar |
| Iconos de habilidad | 250 Magical Pixel-art Icons; Unique Free 8-bit Spell Icons 16x16; 48 Free Swordsman Skills Icons — https://itch.io/c/5647574/spells-effects, https://itch.io/c/1960015/spell-effects | Revisar |
| Fuentes generales | Kenney, OpenGameArt, itch.io, Godot Asset Library, Freesound | Licencia según cada archivo |
Nota: muchos efectos son de 32×32; los héroes miden unos 16 px de ancho, así que hay que escalarlos.

## Assets de UI previstos (spec v1.5)
Retrato y marco para 5 ranuras numeradas; iconos de habilidad con overlay de cooldown, coste y rango; iconos de orden (mover, atacar, attack-move, mantener, seguir, interactuar, explorar, retirada/extracción); iconos de cámara (vista de grupo, héroe enfocado, aliado fuera de pantalla); marcadores sociales (Trust, Obedience, Composure, vínculo, rivalidad) que se entiendan sin depender del color; feedback de órdenes (destino, objetivo, orden inválida, progreso de interacción, zona de extracción).

## Carpetas sugeridas
`assets/_inbox/` → (`tools/Import-Asset.ps1`) → `assets/pixel/{characters,enemies,tilesets,ui,effects}/`.

## Lista de deseos para mejorar pueblo y bosque (investigado 2026-10-30; NO descargado)
La red de la sesión en la nube no permite itch.io ni OpenGameArt, así que el dueño los descarga y los deja en `assets/_inbox/`. Antes de usarlos hay que leer la licencia en la página de cada uno.
| Prioridad | Pack | Para qué | Enlace | Licencia (según la búsqueda; verificar) |
|---|---|---|---|---|
| 1 | Tiny Pixel Fantasy – Base Pack (Caz, el mismo artista de los héroes) | Casas y exteriores de pueblo, bosque y pradera, cuevas y castillos, con el mismo estilo que los héroes | https://cazwolf.itch.io/tiny-pixel-fantasy1 | "Name your own price" (se puede pagar 0); EULA del autor |
| 2 | Pixel Fantasy Tiles – Basics (Caz) | Tiles básicos complementarios del mismo autor | https://cazwolf.itch.io/pixel-fantasy-tiles-basics | Verificar |
| 3 | Adventure Awaits Asset Pack 10 | 16×16 top-down: 2 árboles y 3 casas | https://opengameart.org/content/adventure-awaits-asset-pack-10 | CC0 |
| 4 | Free Forest Tilesets (Ulerinn) | Tiles de bosque de 16, 32 y 48 px | https://ulerinn.itch.io/free-forest-tilesets | CC0 |
| 5 | Pixel Village (fin-nio) | 6 casas y 3 árboles (tiles de 8×8) | https://fin-nio.itch.io/pixel-village | Uso comercial y no comercial permitido |
| — | The Fantasy Tileset (Ventilatore) | 7 árboles × 5 colores y 6 casas con puertas animadas | https://ventilatore.itch.io/the-fantasy-tileset | Precio y licencia sin confirmar |
Hasta que lleguen, árboles, arbustos, rocas, flores, casas y el pozo se dibujan por código (`scripts/sandbox/proc_art.gd`).
