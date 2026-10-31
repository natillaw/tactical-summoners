# Reglas para todas las fases (ahorro de tokens)
- Material en assets/_inbox/pisos_1_10/ (ya filtrado: no busques más archivos). Lee SOLO el spec que indica tu fase.
- Imágenes: rects/origins/frames salen de los .json (no midas a ojo). Nunca abras GIFs ni previews.
  Capturas: headless reutilizando tests/capture_*.gd, reducidas a ≤960×540; máx. las que indique la fase.
- Archivos >200 líneas: rg -n y lee solo el rango. No releas lo ya leído.
- Edits pequeños; nunca reescribas archivos enteros.
- Godot/tests → log a archivo; muestra solo tail -n 30 o grep FAIL|ERROR.
- Sin subagentes. Sin narrar pasos. Plan ≤10 líneas y ejecuta (pregunta solo si choca con DECISIONS.md o una P-xx).
- Mapea a sistemas/IDs existentes antes de crear nuevos (rg, no lectura completa). Si un ID choca, conserva el del repo y anótalo.
- Todos los números en config/datos, en un solo lugar por sistema.
- No rompas el feel ni los controles estilo LoL ya ajustados.
- Al terminar: commit en la rama indicada, una línea en IMPLEMENTATION_STATUS.md, DECISIONS.md si hubo decisión nueva,
  informe ≤20 líneas (cambios, comando de test + resultado, pendientes). No hagas push a main.
