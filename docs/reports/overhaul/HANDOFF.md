# Handoff del overhaul LPC

**Fase actual: 4 terminada salvo la puerta del tamaño del Barón** (`baron_opciones.png`; `BanditArt.BARON_SCALE`, hoy 2). Siguiente: fase 5 (catálogo de vestuario, `item_visuals`, razas; puerta: emparejamientos `visual_id`).

Hecho:
- Fase 0: `.gdignore` y `.gitignore` para `assets/nuevos assets/` (sacados del índice), prompt viejo marcado SUSTITUIDO, inventario `USO_ASSETS_ANTES.md`, fixture de 200 semillas (`tests/test_hero_fixture.gd`), línea base `BASELINE.md` (25 suites en verde).
- Fase 1: LPC clonado en `../_vendor/lpc` (commit `86160e7`), `docs/specs/LPC_FORMAT.md` (formato, animaciones, razas, rejillas de packs), `escala.png` (`tools/overhaul_scale_shot.gd`), `ui_ab.png` (`tools/overhaul_ui_ab.gd`).

Puertas abiertas (no seguir sin respuesta):
1. Escala D-B: ¿rejilla lógica de 32 px con todo el arte a ×1 (los tiles de 16 px se colocan 2×2 por celda), o tiles de 16 px escalados ×2 como dice el prompt? Ver `escala.png`.
2. Estilo de UI: A (Dragon Regalia, actual) o B (CraftPix basic UI). Ver `ui_ab.png`.
3. Pesos humano/elfo (propuesta 80/20).

Siguiente paso exacto: con las respuestas, registrar D-072..D-078 (D-A..D-G) en `DECISIONS.md` y empezar la fase 2 (`tools/import_lpc.py` con recoloreo por paletas → `assets/pixel/lpc/`).

Fase 2 (hecha): `tools/lpc_manifest.json` + `tools/import_lpc.py` (recoloreo por paletas con numpy/Pillow) → `assets/pixel/lpc/`; `scripts/core/lpc_composer.gd` (`visual_layers`, `compose_anim`, `build_frames_for`, `pose_texture_for`, caché); `scripts/data/lpc_wardrobe.gd` (`STARTER_OUTFIT`, `STARTER_WEAPON_BY_CLASS`, `random_look`); `tests/smoke_lpc.gd` (ALL PASSED) y `tira_heroe.png`.
Pendiente técnico: armas con frames sobredimensionados (slash_128, thrust_oversize) no se importan aún; las animaciones que falten en un arma usan su hoja de walk.

Siguiente paso exacto (fase 3): `HeroGenerator.VERSION = 4` con `appearance_lpc` desde `hero_seed ^ 0x4C5043` y la raza por pesos de `SummonConfig`; migración de guardado (v13) que guarda `appearance_legacy`; cambiar a `LpcComposer` todos los llamadores de `SpriteComposer` (retrato, tarjeta, reveal, ficha, panel, party, roster, pueblo y sandbox con `HeroAnim` en 4 direcciones).

Fase 3 (hecha): generador v4 (`HeroGenerator.lpc_look`), `HeroData.look`, guardado v13 con migración (roster y memorial), `SpriteComposer` delega en `LpcComposer` (`uses_lpc`, `feet_offset`, `face_region`, `build_frames_legacy` con los nombres viejos de animación). Capturas en `docs/reports/overhaul/fase3/`.
Pendiente: `HeroAnim` en 4 direcciones reales (hoy los alias usan izquierda/derecha para atacar y caer), el ataque por arma (`ItemDefs.BASES[*].attack_anim`), la tarjeta del pueblo y del título se ven con LPC pero sin revisar en detalle.

Fase 4 (hecha): piezas bandidas importadas (pañuelo, capucha, capa, cuero, placas, cascos, parche, hacha, maza, bastones, mandoble), `scripts/data/lpc_factions.gd`, `BanditArt` reescrito sobre LPC (misma interfaz, 4 caras por tipo), test de facción en `smoke_bandits`.
Pendiente: armas con frames sobredimensionados (el bastón de cristal y el mandoble solo tienen walk/hurt a 64 px); las animaciones de enemigo usan la fila derecha y `hurt` como muerte.
