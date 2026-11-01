# Handoff del overhaul LPC

**Fase actual: 1 terminada, esperando las puertas del dueño.** Rama `feat/overhaul-lpc` (local, sin remoto).

Hecho:
- Fase 0: `.gdignore` y `.gitignore` para `assets/nuevos assets/` (sacados del índice), prompt viejo marcado SUSTITUIDO, inventario `USO_ASSETS_ANTES.md`, fixture de 200 semillas (`tests/test_hero_fixture.gd`), línea base `BASELINE.md` (25 suites en verde).
- Fase 1: LPC clonado en `../_vendor/lpc` (commit `86160e7`), `docs/specs/LPC_FORMAT.md` (formato, animaciones, razas, rejillas de packs), `escala.png` (`tools/overhaul_scale_shot.gd`), `ui_ab.png` (`tools/overhaul_ui_ab.gd`).

Puertas abiertas (no seguir sin respuesta):
1. Escala D-B: ¿rejilla lógica de 32 px con todo el arte a ×1 (los tiles de 16 px se colocan 2×2 por celda), o tiles de 16 px escalados ×2 como dice el prompt? Ver `escala.png`.
2. Estilo de UI: A (Dragon Regalia, actual) o B (CraftPix basic UI). Ver `ui_ab.png`.
3. Pesos humano/elfo (propuesta 80/20).

Siguiente paso exacto: con las respuestas, registrar D-072..D-078 (D-A..D-G) en `DECISIONS.md` y empezar la fase 2 (`tools/import_lpc.py` con recoloreo por paletas → `assets/pixel/lpc/`).
