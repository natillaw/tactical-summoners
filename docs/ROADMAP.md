# Roadmap

Juego 3D en tercera persona, combate desafiante tipo Dark Souls. Enemigos con skills como las del jugador, pero variadas (no copias de las clases). 100 pisos: mapas procedurales + misiones hechas a mano. 5 clases base (guerrero, rogue, mago, cleric, arquero); luego raras, épicas y únicas (estilo Overgeared). Crafting e items.

## Estado actual
Hecho: Warrior jugable, daño por arma + nivel 1–60, rarezas de items, DamageSystem (tipos y resistencias), Soldado con el kit del Warrior, salto/roll/parry/stun, actores como escenas.

## Fase 1 — Fundamentos de combate (siguiente)
- Feel del Warrior: pulir estocada, cancel de animaciones, stagger/poise (rompe-guardia), lock-on de cámara.
- Stamina para rodar/atacar/parry (base del estilo Souls) y ventanas de castigo.
- DamageSystem completo: efectos en el tiempo (veneno, quemadura), daño base por tipo (poder mágico), mitigación por armadura.
- Migrar skills a un formato común para todas las clases (`ClassKit` genérico: WarriorKit pasa a ser datos).
- Sistema de estados/efectos (stun, slow, bleed, buffs) compartido por jugador y enemigos.

## Fase 2 — Las 5 clases
- Rogue, Mago, Cleric y Archer con kit propio (M1, M2, 5 skills, pasiva, recurso propio).
- Selección de clase al entrar (menú) y escenas de actor por clase.
- Proyectiles y daño a distancia (mago, arquero), curación/buffs (cleric), sigilo/combos (rogue).
- Tests por clase y balance base (tabla de DPS/supervivencia por nivel).

## Fase 3 — Enemigos y jefes
- Arquetipos distintos: caster, rogue, cleric (curandero, matar primero), arquero, bestias, y mini-jefes.
- Cada enemigo con skills propias que solo recuerdan a las de clase (variar tipos de daño, patrones, debilidades).
- IA con roles de grupo (tanque al frente, soporte atrás), telegraphs legibles, patrones de jefe por fases.
- Jefes de piso con mecánicas únicas.

## Fase 4 — Pisos
- Generador procedural por piso (salas, pasillos, spawns, trampas) con temas visuales por bloque de pisos.
- Misiones hechas a mano por piso (herramienta/formato de datos: objetivos, diálogos, eventos).
- Escalado de dificultad 1–100, escaleras/avance, guardado de progreso.
- Más arte de entorno (piezas modulares) y variedad por tema.

## Fase 5 — Items y crafting
- Catálogo de items (armas, armaduras, accesorios, consumibles) con rasgos y afijos; efectos legendarios (hoy son solo datos).
- Drops por enemigo/piso, inventario y equipo con UI.
- Crafting: materiales, recetas, mejora/encantamiento, desguace.
- Economía básica (tienda, oro).

## Fase 6 — Progresión y clases especiales
- Árboles/especializaciones, stats y reasignación.
- Clases raras, épicas y únicas con condiciones de desbloqueo.
- Logros, ranking, rejugabilidad.

## Fase 7 — Multijugador, pulido y lanzamiento
- Netcode (la simulación ya es determinista y sin nodos, pensada para esto): lobbies, cooperativo por piso.
- Audio, música, VFX, UI/UX final, accesibilidad, rendimiento.
- Balance con playtests, guardado en la nube, build de prueba cerrada.

## Cosas que quizá no has contado
Tutorial/primer piso guiado, guardado/carga, menús y opciones (controles, gráficos), muerte y penalización, dificultad/modos, localización (ES/EN), herramientas de editor para misiones y enemigos, y una pipeline de arte consistente (modelos de enemigos, armas, entornos).
