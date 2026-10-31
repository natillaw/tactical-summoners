# Pisos 1–10 (bosque + bandidos) — prompt por fase

Copia el bloque y cambia solo `FASE`. **Una fase por sesión** (`/clear` entre fases).

```
FASE = 1   # 1 assets+bandidos · 2 mapas+campamento · 3 ítems/loot · 4 balance+IA · 5 Barón · 6 expediciones · 7 economía

Material en assets/_inbox/pisos_1_10/ (ya filtrado: no busques más archivos).
Lee SOLO el spec de tu fase:
 1 → spec/GHI_arte.md (H)        2 → spec/GHI_arte.md (G, I)
 3 → spec/A_items.md             4 → spec/DE_balance_boss.md (D)
 5 → spec/DE_balance_boss.md (E) 6,7 → spec/BC_economia_expediciones.md
spec/F_backlog.md: no lo leas salvo que diseñes la arquitectura de misiones/jefes.

Reglas de tokens:
- No abras PNG/GIF; la metadata está en los .json.
- Archivos >200 líneas: rg -n y lee solo el rango. No releas lo ya leído.
- Edits pequeños; nunca reescribas archivos enteros.
- Godot/tests → log a archivo; muestra solo tail -n 30 o grep FAIL|ERROR.
- Sin subagentes. Sin narrar pasos. Plan ≤10 líneas y ejecuta (pregunta solo si choca con DECISIONS.md o una P-xx).
- Mapea a sistemas/IDs existentes antes de crear nuevos (rg, no lectura completa).
- Números en un archivo de config/datos.
- Assets: muévelos con la skill asset-import a su destino según la convención del repo.

Al terminar: commit en rama propia, una línea en IMPLEMENTATION_STATUS.md y DECISIONS.md si aplica, informe ≤20 líneas (cambios, comando de test + resultado, pendientes).
```

Preguntas abiertas (contesta cuando lleguen): ¿durabilidad del equipo? ¿cuántos slots por héroe? ¿sueldo de héroes?
