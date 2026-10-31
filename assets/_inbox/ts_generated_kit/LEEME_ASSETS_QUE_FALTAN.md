# Assets que faltan para el demo (investigado 2026-10-31)

Referencia de estilo: héroes de **Tiny Pixel Fantasy (Caz)**, tiles de 16 px, contorno morado oscuro `#190657`, héroe de unos 31 px de alto, paleta saturada pero suave.
La sesión en la nube **no puede descargar** de itch.io, OpenGameArt ni Kenney (bloqueo del proxy), así que estos los descarga el dueño a `assets/_inbox/` y se importan con `tools/Import-Asset.ps1`. Hay que leer la licencia de cada página antes de usarlos (D-024).

## Prioridad 1 — sin esto el demo se ve incompleto

| Falta | Pack | Licencia (según la página) | Notas |
|---|---|---|---|
| Monstruos pixel que reemplacen a los voxel (bosque, pisos 1-10) + jefes | **Ninja Adventure Asset Pack** (Pixel-boy) — https://pixel-boy.itch.io/ninja-adventure-asset-pack | CC0 | 16 px, más de 20 monstruos y 6 jefes animados, 25 pistas de música, más de 20 SFX, 2 fuentes, más de 30 VFX, iconos de hechizo y facesets. El pack que más huecos tapa. Los monstruos voxel chocan con D-007. |
| Más variedad de enemigos (rotación de piso) | **Tiny Creatures** (Clint Bellanger) — https://clintbellanger.itch.io/tiny-creatures | CC0 | 180 sprites de 16×16, casi sin animación: animar por código (bob, squash, flash). |
| Iconos de objetos y equipo en el estilo de Caz | **Pixel Fantasy RPG Icons – Complete Free Collection** (Caz) — https://cazwolf.itch.io/caz-pixel-free | CC BY 4.0, uso comercial sí, se pueden editar, **acreditar a Caz** | Mismo artista que los héroes. Incluye "MV RTP Equipment". |
| Iconos de habilidad | **48 Free Pixel RPG Skill Icons 16x16** (kurai7) — https://kurai7.itch.io/40-free-pixel-rpg-skill-icons-16x16-gui-and-status-icons | Gratis, uso comercial sí, crédito opcional, no redistribuir | 48 iconos de 16 px y 32 px, 6 variantes de color, borde dorado. Junto con los iconos de hechizo de Ninja Adventure cubre el banco de habilidades del slice. |
| Interfaz (paneles 9-slice, barras, botones, cursores, marco de minimapa y retrato) | **Tiny RPG – Dragon Regalia GUI** (tiopalada) — https://tiopalada.itch.io/tiny-rpg-dragon-regalia-gui | CC0 (el autor pide que no se use para entrenar IA) | 10 botones con 4 estados, 8 ranuras de equipo, 5 marcos, 3 barras y cursores animados. |
| Fuente pixel | **m5x7** (Daniel Linssen) — https://managore.itch.io/m5x7 (y **m6x11**, https://managore.itch.io/m6x11, para títulos) | m5x7: CC0, atribución apreciada. m6x11: verificar | Tiene acentos y ñ; la UI está en español. |
| Música | Las 25 pistas de Ninja Adventure (CC0) + **8-Bit Fantasy & Adventure Music Pack** (xDeviruchi) — https://xdeviruchi.itch.io/8-bit-fantasy-adventure-music-pack | xDeviruchi: CC BY-SA 4.0, acreditar, no revender | Diez pistas en loop: título, pueblo, mazmorra, batalla, jefe… |
| Efectos de sonido de UI | **Interface Sounds** (Kenney) — https://kenney.nl/assets/interface-sounds | CC0 | Clics, confirmar, error. Kenney también tiene "RPG Audio" e "Impact Sounds" (CC0) para golpes y pasos. |

## Prioridad 2 — pulido

| Falta | Pack | Licencia | Notas |
|---|---|---|---|
| Retratos de héroe (5 ranuras del HUD) | **Pixel Fantasy – Character Generator** (Caz) — https://cazwolf.itch.io/pixel-charagen | "Name your own price", EULA de Caz | Exporta facesets. Alternativa sin descarga: derivar el retrato por código recortando la cabeza del sprite (D-023 lo permite). |
| Tiles de mazmorra y torre más allá del bosque | **16x16 DungeonTileset II** (0x72) — https://0x72.itch.io/dungeontileset-ii | CC0 | Con trampas, palancas y autotiles. Contorno algo distinto: pasarlo por `tools/art_cohesion.gd`. |
| Tiles extra de Caz | **Pixel Fantasy Tiles – Basics** — https://cazwolf.itch.io/pixel-fantasy-tiles-basics | Verificar precio y EULA | Mismo artista. |

## Ya generado (no hace falta buscarlo) — `assets/_inbox/ts_generated_kit/`
Pixel art original hecho por script con la paleta de Caz y su contorno `#190657`. No hay terceros, así que no hace falta acreditar a nadie. Frames en tiras horizontales; detalles en `manifest.json`.
- **Órdenes (16 px):** mover, atacar, attack-move, mantener, seguir, interactuar, explorar, retirada/extracción y orden inválida.
- **Social (16 px):** Confianza (corazón), Obediencia (cuerno), Compostura (gota), vínculo (anillos) y rivalidad (espadas cruzadas). Cada uno tiene una forma distinta para no depender del color.
- **Estrellas** llena y vacía, en 16 px y 9 px (para la fila de 7★), y **gemas de rareza** ×6 (común → mítica).
- **Mundo:** anillo de selección (aliado, enemigo, neutral y foco animado), retícula de objetivo, marcador de destino, zona de extracción animada, flecha de aliado fuera de pantalla, **portal de la torre** animado (32×48) e icono de héroe caído.
- **Invocación:** círculo mágico animado (64 px, 8 frames), rayo de revelado y reverso de carta, en las 6 rarezas.
- **UI:** ranuras de retrato 1-5 (normal, enfocado, muerto), marcos 9-slice por rareza, panel 9-slice, marco de barra y rellenos (HP, maná, XP, stamina).

## Qué sigue sin cubrir (lo genero si hace falta)
Iconos de recursos del pueblo (comida, madera, piedra, gemas, piedra de promoción, libro de habilidad), iconos de profesión ×11 y marcadores de misión por tipo.
