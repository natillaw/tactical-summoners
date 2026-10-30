# Registro de decisiones — Tactical Summoners

**Autoridad máxima del proyecto.** Si otro documento contradice este, manda este. Un conflicto se reporta; no se resuelve en silencio.
**Consolidado:** 2026-10-30 desde `docs/archive/infos/docs/ai-context/DECISIONS.md` (D-001…D-022), `DESIGN_GAPS.md`, `REFERENCE_SYSTEMS.md`, `HANDOFF_LOG.md`, `SESSION_SUMMARY.md`, el prompt maestro del usuario (2026-10-30) y las imágenes de referencia. Nada se ha eliminado: lo retirado está en la sección SUSTITUIDAS.

| Estado | Significado | ¿Se implementa? |
|---|---|---|
| **CONFIRMADA** | Aprobada explícitamente por el dueño | Sí, cuando el roadmap lo indique |
| **PENDIENTE** | Idea del dueño o del proyecto que requiere decisión o detalle | **No.** Preguntar primero |
| **CANDIDATA** | Propuesta de agente o inspiración, no aprobada | No |
| **DIFERIDA** | Aprobada en principio, fuera del alcance actual | No hasta reactivarla |
| **SUSTITUIDA** | Reemplazada; solo historia | Nunca |

Qué está *implementado* no se registra aquí: ver `docs/IMPLEMENTATION_STATUS.md`.

---

## 1. CONFIRMADAS

### D-001 — Free-first (2026-10-27)
El gameplay central funciona sin APIs, suscripciones ni assets de pago. La generación procedural y el diálogo por defecto se basan en código/datos; una IA opcional nunca es dependencia del núcleo.

### D-002 — IP original
Inspiración amplia de sistemas, nunca expresión protegida. No se copian personajes, nombres, diálogos, arte, mapas, logos, música ni historia de *Pick Me Up: Infinite Gacha* (ni de otras referencias). Lista de nombres prohibidos: `docs/specs/REFERENCE_INSPIRATION.md`.

### D-004 — Identidad persistente
Todo héroe/mundo tiene ID estable. Apariencia, stats, origen e historia no se re-generan al cargar. Se guarda el resultado generado (snapshot versionado), no solo la semilla.

### D-005 — Prototipo local antes que backend
Validar el bucle localmente; mantener límites de servicio limpios para persistencia online futura.

### D-007 — Dirección de arte: pixel art 2D (actualizada 2026-10-28)
Pixel art 2D original: siluetas legibles, paleta limitada y cohesiva, telegrafías claras, UI legible, sprites modulares. Probar un héroe, un enemigo, un tileset y un panel antes de producir/importar en masa. (Sustituye la dirección 3D/low-poly.)

### D-008 — Nada de assets en masa antes de la prueba de arte
Probar primero un héroe, enemigo, arma, prop, tile e icono: estilo, escala, animación, rendimiento y licencia.

### D-009 — Flujo script-first en Godot (2026-10-27)
Escenas, nodos, configuración, setup de assets y pruebas se automatizan con scripts/CLI siempre que sea práctico. Generadores idempotentes; inspeccionar y preservar trabajo existente; verificar resultados.

### D-011 — Muerte permanente (2026-10-28)
Un héroe que llega a 0 PV en misión muere para siempre en esa partida. Se preservan su registro, historia, destino del equipo y entrada en el memorial; nunca se re-genera ni se borra en silencio. Sin resurrección en el primer prototipo. Avisar antes del despliegue y definir resultados de retirada/derrota.

### D-012 — Atributos iniciales; fórmulas provisionales (2026-10-28)
Atributos: Fuerza (FUE), Agilidad (AGI), Vitalidad (VIT), Intelecto (INT), Temple (TEM). Fórmulas propuestas (placeholder para pruebas de balance): PV = 40 + 10×VIT; daño físico = poder del arma + 2×FUE; poder mágico = poder del foco + 2×INT; defensa física = armadura + floor(VIT/2); iniciativa = AGI + TEM; energía = 3 + floor(TEM/3); precisión 85% + AGI% (con tope); evasión 2×AGI% (con tope). El estrés es un medidor de combate aparte, no un sexto atributo.

### D-013 — La identidad del personaje es la primera prioridad (2026-10-28)
Personalidad, trasfondo, habilidades y recuerdos persistentes van antes que amplitud de mundo, simulación de base o volumen de contenido. La personalidad afecta reacciones, eventos de relación y reglas de comportamiento limitadas, sin quitar el control al jugador.

### D-014 — Control RTS híbrido y mapas de misión continuos (2026-10-28)
Tiempo real **sin pausa ni cámara lenta**. Héroes autónomos (navegan y atacan) + órdenes directas del jugador + activación directa de habilidades. Cámara cenital de grupo por defecto. Exploración, interacción, combate y extracción comparten mapa. Misiones con objetivos distintos de "matar a todos". Jefes con mecánicas legibles y contrajuego, no solo más PV. Las órdenes directas son fiables y nunca se deniegan por una tirada de obediencia.
> La cláusula de D-014 "generación de mundo diferida, mapa fijo" queda **sustituida por D-026** (2026-10-30).

### D-015 — Foco de cámara con 1–5 y panel contextual (2026-10-28)
1–5 selecciona al héroe desplegado y la cámara lo sigue suavemente; aparecen su retrato, vitales, habilidades y órdenes. La simulación nunca se pausa. `Tab` vuelve a vista de grupo; `G` selecciona el escuadrón. Ranura vacía o muerta = mensaje claro, nunca seleccionar otro héroe en silencio.

### D-016 — Trust, Obedience y Composure separados (2026-10-28)
Trust (relación a largo plazo con el comandante/compañía), Obedience (disciplina de mando a largo plazo), Composure (estado a corto plazo en misión) + vínculos/rivalidades entre pares. Se guardan y muestran desde el inicio. En el MVP solo cambios deterministas por eventos y **ningún rechazo aleatorio de órdenes normales**. Efectos de comportamiento complejos, diferidos hasta que el control sea fiable.

### D-017 — Escuadrón de cinco, definitivo (2026-10-28, usuario explícito)
El escuadrón es de 5, también en la primera vertical slice. No proponer 3. El alcance se controla con una habilidad por héroe, comportamientos placeholder y mapa simple, no recortando el escuadrón. Roster de prueba ≥ 6. Las teclas 1–5 son obligatorias.

### D-018 — Síntesis, Sacrificio y Promoción (dirección aprobada, números abiertos) (2026-10-28)
- **Síntesis:** consumir un héroe para mejorar otro; deliberadamente con pérdidas; irreversible.
- **Sacrificio:** consumir un héroe para obtener materiales (interpretación del agente: ver P-12).
- **Promoción:** subir de tier con materiales; desbloquea capacidades (ranura de habilidad, opción de clase, tope de nivel, potencial).
- La identidad nunca cambia (ID, nombre, semilla, personalidad, historia). Un héroe sacrificado va al memorial con causa "sacrificed".
- Nombres originales; todos los números configurables y versionados. Spec completa: `docs/specs/HEROES_AND_SUMMONING.md` §14.
- Memoria desbloqueada al promocionar: ver P-11.

### D-019 — "No-hands Godot" (2026-10-28, dueño)
El dueño no opera el editor de Godot. Los agentes implementan escenas, nodos, recursos, importaciones y animaciones por script (GDScript, `@tool`, Godot headless) y PowerShell para archivos/git/herramientas, y los conectan ellos mismos. El dueño solo ejecuta un comando y reporta la salida. Nunca responder "abre el editor y haz clic".

### D-020 — Las animaciones que faltan se hacen en código, sin arte nuevo (2026-10-28, dueño)
La hoja de Tiny Pixel Fantasy (576×384 por capa, 12×8 frames de 48 px) tiene: movimiento en 4 direcciones, lunge lateral de 4 frames (filas 5-6, cols 2-5), pose tumbado de 2 frames por lado (filas 5-6, cols 0-1) y poses sueltas (señalar, mano alzada, agachado). NO tiene: hit, cast, arco, ataque arriba/abajo, muerte multi-frame, correr, bloquear, interactuar ni victoria. Se construyen en código: hit = destello blanco + retroceso; muerte = frames tumbado + caída/fundido; cast/arco = poses señalar/mano alzada + proyectil o efecto aparte; ataque arriba/abajo = lunge lateral + tween. Frames dibujados a mano solo como pulido opcional posterior, solo si la EULA lo permite y para TODAS las capas.

### D-021 — Equipo: muchas armas/armaduras de varios packs; el aspecto base no da stats (2026-10-28, dueño)
- Vendrán más clases y muchas variantes de armas/armaduras, de packs adicionales.
- Ropa/pelo base del generador = cosméticos, **sin stats**. Todos los stats vienen de objetos.
- La armadura equipada **reemplaza** (oculta) la capa base correspondiente; nunca se dibuja encima. El aspecto base guardado nunca cambia.
- Cada pack nuevo necesita: misma rejilla de 48 px o un mapa de frames por pack, estilo coherente, entrada de licencia y una entrada de datos por objeto (id, slot, archivo de capa, stats, clases permitidas).
- Abierto: ver P-14.

### D-023 — Los sprites originales de héroes no se modifican (2026-10-30, dueño; prompt de auditoría §6)
Los sprites de héroes son de **Tiny Pixel Fantasy – Character Generator by Caz**. No se reemplazan, redibujan ni modifican destructivamente (`assets/sprites/**`). Las mejoras preservan su identidad visual y se hacen con animaciones compatibles, efectos, interacciones y retratos derivados.

### D-024 — Solo assets gratuitos y con licencia registrada (2026-10-30, dueño)
Todo recurso nuevo debe ser gratuito, con su licencia leída y registrada en `docs/ASSET_REGISTRY.md` antes de usarse. (Refuerza D-001 y D-008.)

### D-025 — Estabilizar antes de ampliar (2026-10-30, dueño)
No se añaden sistemas nuevos encima de la base actual hasta reparar los errores de la auditoría (`audit/`) y tener pruebas ejecutadas con evidencia. Orden: memoria del proyecto → reparar el juego → construir lo que falta. Nada de reescrituras completas sin justificación demostrada.

### D-026 — Pisos de la torre generados proceduralmente (2026-10-30, dueño; resuelve P-01)
Los pisos de la torre se generan proceduralmente. Reglas obligatorias: semilla + versión del generador, validación de navegación y **snapshot persistido** (D-004; nunca regenerar un piso guardado con otro generador). Sustituye a D-003 y a la cláusula "mapa fijo" de D-014. Referencia visual: `docs/specs/reference/procedural_map_reference.jpg`. Biomas: siguen PENDIENTES (P-03).

### D-027 — Torre de 100 pisos; los pisos 1-10 son el primer alcance (2026-10-30, dueño; resuelve P-02)
La meta es una torre de 100 pisos. El primer alcance jugable son los pisos 1-10, con un jefe en el piso 10. Siguen abiertos: progreso y repetición de pisos, recompensas, desbloqueos cada 10 pisos (P-02b) y el diseño del jefe (P-25).

### D-028 — Clases base: las del código (2026-10-30, dueño; resuelve P-06)
Commoner, Warrior, Rogue, Ranger, Cleric y Mage (más Novice como estado "sin clase"). La biblioteca de habilidades (P-10) deberá adaptarse a estas clases; Thief, Spearman y Archer quedan como nombres antiguos (sus habilidades se conservan como ideas para reasignar). Clases avanzadas: siguen PENDIENTES (P-07).

### D-029 — 7 estrellas y 70 niveles (2026-10-30, dueño; resuelve P-08)
7★ con 70 niveles: una estrella por cada 10 niveles (star_gate = ceil(nivel/10), como en la biblioteca de habilidades). Sustituye a la escala del código (5★, topes 10/20/40/60/80). Implementarlo exige cambiar `HeroTables.MAX_STARS`/`STAR_DATA`, las odds de los banners (7 entradas), los colores de estrella, la migración de guardados (subir `SAVE_VERSION`) y las pruebas. Es una tarea de la Fase 5, no antes de la reparación (D-025). Nombres de rareza: siguen PENDIENTES (P-09).

### D-030 — El juego empieza en el pueblo; el pueblo se construye (2026-10-30, dueño; resuelve P-04 y parte de P-22)
Lo primero que ve el jugador es **la base = el pueblo**, no un menú. Desde el pueblo se hace todo lo demás (invocar, héroes, escuadrón, torre, memorial, gestión). El pueblo es un **mapa fijo y persistente** (siempre el mismo). Se **construye y mejora** con edificios: herrería, hospital, alquimia, etc. Implementación inicial (v3): vista cenital como el resto del juego (el estilo isométrico de la imagen de referencia queda como opción futura), edificios definidos en `scripts/data/town_tables.gd`, coste en materiales, niveles 0 (sin construir) a máx. Efectos concretos de herrería y alquimia esperan al equipo/crafting (P-19, P-20); bonus por profesión sigue PENDIENTE (P-05).

### D-031 — Pisos 1-10 desbloqueados y con bioma de bosque (2026-10-30, dueño; resuelve P-03 para 1-10 y P-02b por ahora)
Todos los pisos 1-10 están desbloqueados (son los que hay por ahora). Bioma: **bosque**, "nada loco". Implementación (v4): claros de hierba con flores, senderos de tierra en los pasillos, muros de árboles; criaturas de bosque del pack Voxel Dungeon por piso (slimes, ratas, murciélagos, arañas, setas, goblins, hobgoblins, orcos, gólems; jefe orco en el piso 10). Tamaños de piso reducidos a 40-60 celdas para que sean jugables y ligeros. Progreso real de la torre (desbloqueo, recompensas por piso) sigue PENDIENTE (P-02b).

### D-032 — Héroes con autonomía total en el pueblo; ficha al hacer clic (2026-10-30, dueño)
En el pueblo cada héroe decide qué hacer (pasear, visitar edificios, entrenar, trabajar, descansar, charlar), según su personalidad y su trabajo. Es solo visual hasta que existan los sistemas de entrenamiento, etc. Al hacer clic en un héroe se abre su ficha: equipo, colores, stats, personalidad, relaciones, recuerdos y actividad actual.

### D-033 — Progreso rápido de torre y profesiones expertas (2026-10-30, dueño: "sí")
- Completar un piso da recompensa (gemas, piedras, materiales, libros; números provisionales en `Game.complete_floor`) y queda registrado (`tower_cleared`). Todos los pisos 1-10 siguen desbloqueados.
- Profesiones: un experto produce ×2 en su edificio (cocina: chef/granjero/pescador/cazador; taller: leñador/minero/cantero/constructor/ingeniero/herrero; hospital: médico/sacerdote/alquimista; taberna: artista/mercader). Tabla en `TownTables` ("experts").
- El dueño pide un **sistema de profesiones mucho más sólido**: esta es solo la primera capa; el diseño completo sigue PENDIENTE (P-05).

### D-034 — Misiones por tipo de piso (2026-10-30)
Implementados 7 tipos (combate, recuperación, rescate, exploración, supervivencia, defensa, jefe) según `TowerExpedition`. El jefe del piso 10 (Jefe Orco) es la primera versión: más vida, golpe telegrafiado más amplio y lento; fases y mecánicas de arena (P-25) siguen pendientes.

---

## 2. PENDIENTES (ideas que se conservan; no implementar sin respuesta del dueño)

| ID | Tema | Lo que existe / origen | Pregunta abierta |
|---|---|---|---|
| P-01 | ~~Generación procedural de pisos/mundo~~ | **RESUELTA → D-026** (2026-10-30) | — |
| P-02 | ~~Torre de 100 pisos; primeros 10 como alcance inicial~~ | **RESUELTA → D-027** (2026-10-30) | — |
| P-02b | Progreso de la torre | D-027 | Repetición de pisos, recompensas por piso, desbloqueos cada 10 pisos (mazmorras, instalaciones, tope de nivel: REFERENCE #15) |
| P-03 | **Biomas** (pisos 1-10 → bosque, D-031; resto pendiente) | Imagen de mapa (piedra, agua profunda, hierba, lava, cristal mágico, puentes, puertas); 8 familias temáticas del Bible: Ashen/cursed kingdom, Verdant/overgrown wilds, Arcane/fractured reality, Umbral/abyssal depths, Storm/sky-isles, Forge/clockwork empire, Tidal/drowned civilization, Crystal/glass desert (etiquetas de trabajo) | ¿Qué biomas en los pisos 1-10? |
| P-04 | ~~HQ in-game explorable, no un menú~~ **RESUELTA → D-030** | Imagen `hq_ingame_reference_THIRD_PARTY.jpg` (sala con zonas etiquetadas, héroes paseando con bocadillos de diálogo); `HQWorld` (Mega Prompt) | ¿Vista isométrica o cenital? ¿Qué zonas? |
| P-05 | **Profesiones de vida pasada** | 20 profesiones en `HeroTables.PROFESSIONS` (granjero, chef, herrero, leñador, minero, constructor, médico, mercader, guardia, cazador, sastre, ingeniero, explorador, erudito, alquimista, sacerdote, pescador, mozo de cuadra, cantero, artista), cada una con bonus y acción improvisada (Gemini, 2026-10-29) | ¿Afectan a producción, crafting y/o combate? ¿Cómo? |
| P-06 | ~~Conjunto de clases base~~ | **RESUELTA → D-028** (2026-10-30) | — |
| P-07 | **Clases avanzadas por promoción** | Berserker, Assassin, Sniper, Templar, Sorcerer (HANDOFF 2026-10-28 23:41; no en código) | ¿Confirmadas? ¿Una por clase base? |
| P-08 | ~~Estrellas y niveles~~ | **RESUELTA → D-029** (2026-10-30) | — |
| P-09 | **Rarezas** | Spec: Common/Uncommon/Rare/Epic/Legendary (provisional). Código: 1-5★. Regla vigente: rareza ≠ personalidad ni moralidad | ¿Nombres o estrellas? |
| P-10 | **Biblioteca de habilidades (D-022)** | 130 habilidades en `docs/specs/SKILLS.md` (7 "implemented", 124 "spec"); regla 4 activas + 1 definitiva; nivel 1-70; ≥30 aprendibles y ≥20 exclusivas por clase de combate; cada skill con qué hace, cómo se juega en tiempo real, sinergia, etiquetas de enemigo; API prevista `SkillLibrary` + generador `tools/gen_skill_library.py` (**no existen en el repo**) | ¿Se mantiene la regla y se regenera para las clases de P-06? |
| P-11 | **Memoria desbloqueada al promocionar** | D-018 "MAYBE": revelaría un recuerdo ya guardado en la generación, nunca inventaría hechos | Sí/No |
| P-12 | **Significado de "sacrificio"** | Interpretación del agente: héroe → materiales | Confirmar |
| P-13 | **Rescate de caídos con temporizador de agonía** | Descrito en `SESSION_SUMMARY` (no existe en código); `rescue_hero()` existe solo como función de datos | ¿Es idea del dueño? ¿Cómo encaja con D-011? |
| P-14 | **Ropa interior por defecto vs cuerpo base** al equipar armaduras | D-021 | Elegir |
| P-15 | **Secretos y cadenas de descubrimiento** | `discover_secret()` idempotente, no heredable tras la muerte (solo datos + test) | Alcance y fuentes de secretos |
| P-16 | **Legado tras la muerte** | Prompt 2026-10-30; memorial existente | Definir qué deja un héroe muerto (reliquias, archivo, recuerdos en otros héroes…) |
| P-17 | **Expediciones** | Bible pilar 4 ("base, economía, equipo y expediciones se refuerzan"); prompt 2026-10-30 | ¿Son las misiones de torre o envíos sin control directo? |
| P-18 | **Eventos de misión / objetivos que cambian** | REFERENCE #9 (explorar → exterminar → escapar), prompt | Alcance |
| P-19 | **Inventario, loot procedural, afijos, sets** | Prompt 2026-10-30; Bible exige guardar inventario/equipo | Necesita spec: `docs/specs/ITEMS_AND_LOOT.md` |
| P-20 | **Crafting** | Bible "Base/economy: training, crafting, research, storage, production"; prompt | Recetas, estaciones, relación con profesiones |
| P-21 | **Economía y recursos** | Código: gemas, piedras de promoción, libros, comida, materiales, medicina; REFERENCE #17 moneda abstracta única (CANDIDATA) | Fuentes, sumideros, topes |
| P-22 | **Construcción e instalaciones** | Código: cocina/taller/enfermería/sala común con niveles; edificios de pueblo (ayuntamiento, 2 dormitorios, herrería, cocina, enfermería) donde cada dormitorio da +5 de capacidad; REFERENCE #8 (estación de promoción, casa de conversión, archivo de reliquias de caídos) | ¿Un único modelo? ¿Qué instalaciones? |
| P-23 | **Producción** | Código: cantidades fijas por trabajador; se pretendía bonificar por profesión | Reglas |
| P-24 | **Diálogo de personalidad ("chatter")** | `HeroChatter` (frases por rasgo al entrar al piso); Roadmap: plantillas deterministas por evento; LLM solo opcional para verbalizar (Bible) | ¿Plantillas por evento? |
| P-25 | **Jefe del piso 10** | Principios confirmados en D-014; nada diseñado | Diseño concreto |
| P-26 | **Política de duplicados, renombrar y liberar héroes** | Spec §9: recomendado = cada tirada es un héroe distinto, nombres repetidos con callsign (implementado) | Decidir si hay conversión en fragmentos, renombrado o liberación |
| P-27 | **Pasivas en tiempo real** | 16 pasivas con texto heredado de turnos/filas | Reescribir para tiempo real |
| P-28 | **Protocolo de agentes** | Antes: claims + STATE_HASH + `ts_sync.py` (archivado 2026-10-30). Ahora: ramas + PRs + evidencia | Confirmar el nuevo flujo |

### Preguntas abiertas heredadas (de DESIGN_GAPS, todas conservadas)
**Durante el prototipo de control:** G-01 plataforma/entrada (teclado+ratón propuesto) · G-02 pathfinding, evitación y reparto alrededor del destino · G-03 semántica y bindings finales de órdenes · G-04 ajuste del ataque básico (alcance, wind-up, recuperación, intervalo, proyectil, línea de visión) · G-05 habilidades: energía vs cooldown, objetivo, interrupción, canalización · G-06 legibilidad sin pausa (duración de telegrafías, avisos, zoom, densidad del HUD) · G-07 esquiva automática de peligros letales telegrafiados (acotada y legible) · G-08 percepción enemiga (línea de visión, ruido, radio, persecución) · G-09 compleción de misión (objetivo, extracción, enemigos opcionales, extracción fallida, recompensas parciales) · G-10 muerte/lesión (cuándo se guarda la muerte, recuperación de equipo, coste de retirada, escuadrón entero caído) · G-11 qué rasgos afectan preferencias transparentes · G-12 economía de invocación (probabilidades, coste, pity, pools, duplicados) · G-13 stats y crecimiento (presupuesto inicial, potencial, subida de nivel, compatibilidad clase/skill) · G-14 estados alterados (duración, acumulación, resistencia, ticks, control de masas en tiempo real) · G-15 legibilidad de jefes.
**Crecimiento (D-018):** G-21 eficiencia de síntesis, qué se transfiere, topes, bonus por misma clase · G-22 tipos y cantidades de materiales del sacrificio; ¿se pueden sacrificar tiers altos? · G-23 número de tiers y tabla de desbloqueos · G-24 = P-11 · G-25 ¿sacrificios/muertes cambian el Trust de otros y cuánto? · G-26 fuente de materiales de promoción tras el prototipo.
**Antes de ampliar el arte:** G-16 resolución interna, tamaño de sprite/tile, paleta, convención de frames · G-17 estilo de retrato y cómo se compone y persiste la variación visual · G-18 fuentes de assets con licencia o plan de arte original.

---

## 3. CANDIDATAS (inspiración, no requisitos)
De `docs/specs/REFERENCE_INSPIRATION.md`: clase exclusiva de invocación / clases disponibles según tier de nacimiento (#6) · instalaciones de promoción, conversión y archivo de reliquias de caídos (#8) · máquina de estados de objetivos cambiantes (#9) · opinión del héroe visible en objetivos opcionales, sin cancelar órdenes (#10) · regalos que suben Trust (#11) · jefes inmunes hasta activar un mecanismo del campo (#12) · moneda abstracta única con nombre original (#17). Ideas de agentes: profesiones con "acción improvisada" de combate; diálogo de entrada por rasgo.

## 4. DIFERIDAS
- **D-006 — Multijugador asíncrono primero:** visitas, defensas en instantánea, invasiones, rankings, eventos. Tiempo real fuera del alcance inicial.
- Progreso offline (basado en timestamp, con tope, idempotente; hora de servidor cuando haya online).
- Diálogo con LLM opcional (validado, nunca decide estado del juego).
- REFERENCE #7 mazmorras diarias de materiales · #13 repetición de misiones · #16 invasiones con penalización · #18 pisos ocultos por subquests. (#14 multi-escuadrón: NO por ahora.)
- Fuera de alcance inicial (Bible): multijugador en tiempo real, mundo abierto continuo, LLM locales, APIs generativas de pago, campaña enorme hecha a mano, monetización, producción masiva de assets antes de validar estilo.

---

## 5. SUSTITUIDAS (historia; no implementar nunca)
| Antes | Sustituida por | Nota |
|---|---|---|
| Dirección de arte 3D estilizada / low-poly (2026-10-27) | D-007 | — |
| **D-010** Combate por turnos y por rangos/filas (2026-10-28) | D-014 | Restos en código: filas FRONT/BACK en `party_screen.gd`, pasivas con "turno/fila" (ver P-27) |
| "La primera vertical slice puede usar 3 héroes" (changelog v1.4) | D-017 | — |
| Contador único `loyalty` | D-016 (Trust + Obedience) | Migración v1→v2 en el guardado |
| "Loyalty" como medidor aparte | Diferido indefinidamente (spec §7) | Solapa con Trust/Obedience |
| **D-003** "Mundos procedurales diferidos; mazmorra fija" (2026-10-28) | **D-026** | Los héroes procedurales siguen siendo núcleo (parte vigente de D-003) |
| Escala 5★ / niveles 10-20-40-60-80 (código) | D-029 | Pendiente de migrar en la Fase 5 |
| Clases Thief / Spearman / Archer (biblioteca de skills) | D-028 | Sus habilidades se conservan como ideas en `docs/specs/SKILLS.md` |
| "El repo/ZIP es solo documentación; no hay proyecto Godot" | Estado real del repo | — |
| Protocolo multiagente con claims, STATE_HASH, CONTEXT_BUNDLE/LITE | Ramas + PR + evidencia (P-28) | Archivado en `docs/archive/infos/` |
| Instalación por "drops" ZIP (`Apply-DropD.ps1`, `Update-Project.ps1`) | Git | Archivado |
