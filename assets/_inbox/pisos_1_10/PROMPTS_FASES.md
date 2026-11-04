# Prompts por fase — un chat nuevo (o /clear) por fase

## Fase 1 — Assets y bandidos
```
Rama: feat/pisos-1-10. Te paso la carpeta pisos_1_10; cópiala tal cual a assets/_inbox/pisos_1_10/.
Lee assets/_inbox/pisos_1_10/spec/REGLAS.md y spec/GHI_arte.md (solo "Assets" y "H").
Tarea:
1. Mueve los assets con la skill asset-import según la convención del repo.
2. Compositor de personajes: soporta las capas Accesorio y Mascara con el orden de presets/bandidos_presets.json → orden_capas.
3. Crea los 8 bandidos como datos (preset de capas, stats base, rol, drops vacíos por ahora) reutilizando el compositor de héroes.
4. Barón Carmesí: elige hoja x2 o escala ×2 en el nodo, documéntalo en DECISIONS.md, hitbox acorde.
5. Escena de prueba con los 8 y sus animaciones + smoke test. Mira 1 captura para confirmar que las capas quedaron bien.
```

## Fase 2 — Mapas de bosque y campamento
```
Rama: feat/pisos-1-10. Lee assets/_inbox/pisos_1_10/spec/REGLAS.md y spec/GHI_arte.md (solo "G" e "I").
Tarea:
1. Ajusta build_forest_tileset.gd a las rutas reales y genera el TileSet (Match Corners: pasto, tierra, agua).
2. Generador de mapas por semilla para los pisos 1–10: 2–3 zonas por piso, reglas de composición del spec, ≥1 tile de pasto entre tierra y agua.
3. Campamentos bandidos con los props (cobertura), fogata animada, jaula para rescate; círculo de menhires + altar para el piso 10.
4. Mira bosque_tiles.png y bosque_props.png una vez. Luego captura un mapa y revísalo contra las reglas; itera (máx. 5 capturas).
5. Smoke test del generador (semillas reproducibles, sin zonas inalcanzables). Guarda la captura final para que yo la revise.
```

## Fase 3 — Ítems, loot y recetas
```
Rama: feat/pisos-1-10. Lee assets/_inbox/pisos_1_10/spec/REGLAS.md y spec/A_items.md.
Tarea:
1. Lista con rg los ítems ya existentes y mapéalos a los IDs del spec (no dupliques).
2. Resources ItemData, LootEntry, FloorLootTable, RecipeData (adaptados a lo existente) y un script que genere todos los .tres desde UNA tabla.
3. LootService con RNG con semilla por piso; inventario {id: qty}; monedas cur_ aparte; cofre de misión y drops de jefe.
4. Recetas de alquimia, forja, construcción, portal y costos de promoción/síntesis conectados a los servicios existentes.
5. Tests: tasas por piso (muestreo con semilla), primer clear, recetas que consumen y producen bien.
```

## Fase 4 — Balance, party por piso e IA de enemigos
```
Rama: feat/pisos-1-10. Lee assets/_inbox/pisos_1_10/spec/REGLAS.md y spec/DE_balance_boss.md (solo "D").
Tarea:
1. Héroes máx. y misión por piso según la tabla. N.º de enemigos nunca igual al tamaño de la party.
2. IA por rol (tanque, asesino, sanador, artillero; invocador preparado) aplicada a los bandidos.
3. Presupuesto de amenaza por piso + modificadores (niebla, suelo dañino, enfurecidos, sin curación) + botón de retirada.
4. Pisos con 2–3 zonas para runs de 10–15 min (dificultad por mecánicas, no por HP).
5. Usa tests/playthrough_bot.gd (perfiles táctico y "a lo loco" si ya existen) y verifica: 1 héroe sin equipo muere en p3; p5 se pierde ≥50% al primer intento; el bot loco pierde mucho más que el táctico. Tabla resumen en consola, detalle en CSV.
```

## Fase 5 — Jefe del piso 10: Barón Carmesí
```
Rama: feat/pisos-1-10. Lee assets/_inbox/pisos_1_10/spec/REGLAS.md y spec/DE_balance_boss.md (solo "E").
Opcional: spec/F_backlog.md solo para dejar la arquitectura de jefes flexible.
Tarea:
1. Escudo de inmunidad + altar: 2 héroes canalizan 8 s → vulnerable 20 s; un golpe interrumpe; adds van al altar; el jefe presiona el altar al quedar vulnerable.
2. Tres fases por % de vida (1 altar → 2 altares → altar que se mueve). Todo número en config.
3. Pistas sutiles: hilo de luz, daño 0 con escudo que late, mural, cadáver, 1 línea de héroe por intento. Usa fx_escudo_altar.
4. Tests: inmune sin altar; vulnerable tras canalizar; interrupción; cambios de fase. Bot táctico vs loco en p10 (loco ≈ 0%).
5. Mira 1 captura de la pelea con escudo y altar.
```

## Fase 6 — Expediciones offline
```
Rama: feat/pisos-1-10. Lee assets/_inbox/pisos_1_10/spec/REGLAS.md y spec/BC_economia_expediciones.md (solo "C").
Tarea:
1. Se desbloquean al pasar p5; solo pisos ya superados; héroes en expedición no trabajan en el pueblo.
2. Cargas diarias recargables (3; el portal sube el máximo), botín 50–60%, nunca key_ ni primer clear, duración piso × 20 min.
3. floor_gap, riesgo por poder y almacén limitado implementados pero OFF en config.
4. Integra con el motor de actividad offline existente (no lo dupliques) y con LootService.
5. Tests: avance de tiempo simulado, límites de cargas, botín reducido, exclusión de key_.
```

## Fase 7 — Economía
```
Rama: feat/pisos-1-10. Lee assets/_inbox/pisos_1_10/spec/REGLAS.md y spec/BC_economia_expediciones.md (solo "B").
Tarea:
1. Pity de invocación (Raro cada 20, config), primer clear generoso vs repetición predecible.
2. Mercader con rotación (material viejo → nuevo). Costos de edificios ×1.5 por nivel. Sueldo de héroes como opción OFF.
3. Tope de acumulación offline 8–12 h.
4. Simulador headless de N días: imprime oro, shards, invocaciones y promociones por día en una tabla corta.
5. Verifica los ritmos: ~1 invocación cada 2 runs, promo 2★ cada ~10 runs. Ajusta números en config y reporta antes/después.
```
