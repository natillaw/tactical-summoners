Sesión one-shot: implementa los pisos 1–10 (bosque + bandidos) completos, en 7 fases seguidas, sin esperar mi OK entre fases.
Rama: feat/pisos-1-10. Te paso la carpeta pisos_1_10; si no está, cópiala tal cual a assets/_inbox/pisos_1_10/.

## Cómo trabajar (ahorro de tokens, obligatorio)
- Lee una vez spec/REGLAS.md y síguelo en todo momento.
- En cada fase lee SOLO la sección del spec indicada. No la releas en fases siguientes.
- Lleva el progreso en assets/_inbox/pisos_1_10/PROGRESS.md (≤3 líneas por fase: hecho, test, pendiente).
  Si el contexto se compacta o se corta la sesión, retoma desde ahí sin re-explorar el repo.
- Commit al cerrar cada fase ("fase N: …"). Entre fases no me escribas resúmenes; solo una línea "Fase N ✔" o "Fase N ⚠ motivo".
- Si una fase se bloquea (test que no pasa tras 3 intentos, o choque con DECISIONS.md/P-xx), anótalo en PROGRESS.md, déjalo aislado y sigue con la siguiente. No te detengas a preguntar salvo que el bloqueo impida todo lo demás.
- Capturas: solo las indicadas (≤960×540).

## Fase 1: Assets y bandidos (spec/GHI_arte.md: "Assets" y "H")
Mueve los assets con la skill asset-import. Compositor con capas Accesorio y Mascara (orden en bandidos_presets.json → orden_capas). Los 8 bandidos como datos reutilizando el compositor de héroes. Barón: hoja x2 o escala ×2 (decide y documenta), hitbox acorde. Escena de prueba + smoke test. 1 captura.

## Fase 2: Mapas y campamento (spec/GHI_arte.md: "G" e "I")
Ajusta y ejecuta build_forest_tileset.gd. Generador por semilla para pisos 1–10 con 2–3 zonas y las reglas de composición; ≥1 tile de pasto entre tierra y agua. Campamentos con props como cobertura, fogata animada, jaula de rescate, menhires + altar en p10. Mira bosque_tiles.png y bosque_props.png una vez; luego captura y revisa contra las reglas, iterando (máx. 5 capturas). Smoke test: semillas reproducibles, todo alcanzable. Guarda la captura final.

## Fase 3: Ítems, loot y recetas (spec/A_items.md)
Mapea primero los ítems existentes (rg). ItemData/LootEntry/FloorLootTable/RecipeData + script que genere los .tres desde una tabla. LootService con semilla por piso, inventario {id: qty}, cur_ aparte, cofres y drops de jefe. Recetas y costos conectados a los servicios existentes. Tests de tasas, primer clear y recetas.

## Fase 4: Balance, party e IA (spec/DE_balance_boss.md: "D")
Héroes máx. y misión por piso; enemigos ≠ tamaño de party. IA por rol aplicada a los bandidos. Presupuesto de amenaza, modificadores, retirada. Pisos de 2–3 zonas (runs de 10–15 min, dificultad por mecánicas, no HP). Con tests/playthrough_bot.gd (perfiles táctico y "a lo loco"; créalos si no existen): 1 héroe sin equipo muere en p3, p5 se pierde ≥50% al primer intento, el loco pierde mucho más que el táctico. Tabla resumen en consola, detalle en CSV.

## Fase 5: Barón Carmesí (spec/DE_balance_boss.md: "E")
Escudo + altar (2 héroes, 8 s → 20 s vulnerable, un golpe interrumpe, adds al altar), 3 fases, pistas sutiles, fx_escudo_altar, todo en config. Deja la arquitectura de jefes flexible (mira spec/F_backlog.md solo para eso, sin implementarlo). Tests de inmunidad, canalización, interrupción y fases; bot loco ≈ 0% en p10. 1 captura.

## Fase 6: Expediciones (spec/BC_economia_expediciones.md: "C")
Desbloqueo tras p5, cargas diarias, botín 50–60%, sin key_ ni primer clear, duración piso × 20 min, héroes ocupados. Opcionales en OFF. Integra con el motor offline existente y LootService. Tests con tiempo simulado.

## Fase 7: Economía (spec/BC_economia_expediciones.md: "B")
Pity (20, config), primer clear generoso, mercader con rotación, edificios ×1.5/nivel, tope offline 8–12 h, sueldo OFF. Simulador headless de N días con tabla corta. Ajusta la config hasta lograr ~1 invocación cada 2 runs y una promo 2★ cada ~10 runs.

## Cierre (único informe, ≤40 líneas)
Corre todas las suites (log a archivo, solo el resumen). Actualiza IMPLEMENTATION_STATUS.md, DECISIONS.md y VERSIONS.md.
Informe: estado por fase (✔/⚠), tabla de winrates de los bots, ritmos del simulador, rutas de las capturas para que las revise, pendientes y preguntas abiertas (durabilidad del equipo, slots por héroe, sueldo). No hagas push a main.
