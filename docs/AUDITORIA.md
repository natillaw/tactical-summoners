# Auditoría del juego (2026-11-10)

Lista priorizada por impacto. Estado: ⬜ pendiente · ✅ hecho · ⏸ aplazado (con motivo).
Los números de balance salen de `tools/balance/floor_curve.gd` (ver sección final).

## Línea base medida antes de tocar nada

`tools/balance/floor_balance.gd` (bot de cada clase, nivel 1, contra cada campamento del piso 1):

| Clase | Camp. 1 (5 esbirros) | Camp. 2 (élite + aprendiz) | Camp. 3 (élite + 2 esbirros) |
|---|---|---|---|
| Guerrero | 83 % | 0 % (muere en 6 s) | 0 % (8 s) |
| Pícaro | 50 % | 0 % | 0 % |
| Mago | 16 % | 0 % | 0 % |
| Arquero | 0 % | 0 % | 0 % |

Los 15 tests headless pasan en la línea base.

## P0 — rompe el juego

1. **El piso 1 mata a un jugador de nivel 1.** Dos de los tres campamentos llevan un élite (copia de clase con
   todas sus skills, la misma vida y el mismo daño que el jugador). No hay fórmula por piso: el enemigo es
   "un jugador del nivel del piso" con multiplicadores fijos por arquetipo.
2. **Poise/stagger** sigue en sim, kits, HUD, barras de enemigos, ficha y VFX (≈130 referencias). La armadura
   solo servía como poise, así que al quitarlo hay que darle otra función.
3. **Los esbirros no cumplen la regla "básico + 1-2 skills"** de forma comprobada (nada lo testea) y el élite
   aparece ya en el piso 1.

## P1 — se nota mucho al jugar

4. **Combate torpe:** no hay cancelaciones (toda recuperación se espera entera), el buffer es de 0.22 s,
   varios casts con barra son largos (Starfall 1.6 s, Arcane Surge 2.2 s, Concentrated Shot 1.4 s) y los
   ultimates tienen 180 s de cooldown (en un piso de 3-5 min se usan una vez).
5. **Bosses sin fases:** el Coloso es un guerrero con ×6 vida; no cambia de comportamiento ni avisa de nada propio.
6. **No hay drops de equipo.** Solo materiales; `ItemRarity.WEIGHTS` es global (1 % legendario en cualquier
   nivel) y solo lo usa la tecla de depuración F6.
7. **30 de las 35 armas de `weapons/custom` no tienen receta ni entrada en `WeaponCatalog`** (solo las 5 espadas).
   Los 20 sets de armadura no tienen versión de grado 2.
8. **Ficha de personaje (I):** lista de texto, sin modelo, con "Poise (armadura)".

## P2 — pulido

9. Reglas de arma por clase: el catálogo nuevo trae alabardas, tridente, picas, mazos y varas que hoy no
   mapean a ningún tipo. El mago solo puede usar bastón (1 tipo), el guerrero 4.
10. Misiones: 20 tipos; revisar las que solo son "camina y pulsa F" y los tiempos que escalan con `total`.
11. Legibilidad: telegraphs de enemigos, anillos de AOE y barras de vida (tenían la línea de poise).
12. Clérigo: no existe como clase jugable (se quitó del creador). Hay 4 kits, no 5.
13. Assets: sin reporte de tris/escala/origen/materiales.

## Orden de trabajo

| # | Bloque | Estado |
|---|---|---|
| A | Combate: quitar poise/stagger, armadura → reducción física, cancelaciones, buffer, casts y cooldowns, hit-stop mínimo | ✅ |
| A2 | Combate: VFX y animaciones por skill (windup/impacto/color), contraste de enemigos, anillos de AOE | ⏸ sin revisar: se agotó el presupuesto |
| B | Balance: fórmula por piso, piso 1 sin élites, esbirros limitados, fases de boss, simulador | ✅ (falta afinar pisos 3-10 con `docs/BALANCE.md`) |
| C | Items: pesos de rareza por piso, drops raros, recetas para las 35 armas custom, tabla por script | ✅ |
| D | Clases: reglas de arma verificadas | ✅ parcial — falta revisar kit por kit y el Clérigo (no existe) |
| E | Pisos y misiones: rosters por piso revisados; los 20 tipos de misión | ⏸ misiones sin revisar |
| F | UI: ficha estilo WoW | ✅ código; ⏸ sin captura de verificación. HUD: solo se quitó la línea de poise |
| G | Assets con Blender | ⏸ sin empezar |

## Qué queda y por qué

El presupuesto de uso se agotó antes de lo previsto (la ventana de 5 h pasó del 3 % al 56 %). Queda, por orden:

1. Ejecutar y mirar las 4 capturas (tutorial piso 1, combate, ficha, jefe). La ficha nueva y las fases del jefe
   solo están cubiertas por tests de lógica e importación, no vistas en pantalla.
2. Leer `docs/BALANCE.md` y corregir outliers de los pisos 3-10 tocando solo `EnemyArchetypes.TIER` y los
   dos coeficientes de crecimiento.
3. VFX por skill y legibilidad (A2).
4. Los 20 tipos de misión (E) y el Clérigo (D).
5. Auditoría de assets con Blender (G).
