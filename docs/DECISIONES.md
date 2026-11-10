# Registro de decisiones

Decisiones de diseño y técnicas de **Reflections**, en orden. Cada entrada dice
qué se decidió, por qué y qué queda abierto. Si una decisión cambia, no se borra:
se marca como **reemplazada** y se añade la nueva.

Estado: **Aceptada** · **Propuesta** (pendiente de confirmar) · **Reemplazada**.

---

## Contexto del juego (2026-11-08)

- RPG con PvP en el futuro. Torre de 100 pisos.
- Combate 100 % estilo Battlerite: skillshots, movimiento directo con WASD y
  apuntado con el ratón, independiente del movimiento.
- Clases básicas. Se empieza por el **Warrior** y se pule hasta que esté
  perfecto antes de pasar a otra clase.
- **Fuente de verdad del proyecto: la carpeta local `C:\dev\combat`.** GitHub
  está desactualizado y no hay que fiarse de él.

---

## D-001 · Perspectiva 3/4 top-down — Aceptada (2026-11-08)

**Decisión:** el mundo se ve en 3/4 top-down, no en cenital puro.

**Por qué:** los sprites LPC (y cualquier sprite renderizado con cámara
inclinada) muestran cara y pecho. En un mundo cenital no encajan. Battlerite
también usa una cámara inclinada.

**Reglas que salen de aquí:**
- La lógica de combate vive en el plano del suelo. La hitbox/hurtbox es un
  círculo pequeño en los pies, no el rectángulo del sprite.
- Los proyectiles viajan por el suelo, se dibujan a la altura del pecho y
  llevan su sombra debajo.
- Los telegraphs de suelo se dibujan sin foreshortening: lo que se ve es
  exactamente lo que golpea.
- El y-sort usa el origen en los pies.

## D-002 · Facing desacoplado del aim — Reemplazada por D-004 (2026-11-08): en 3D el cuerpo gira libre; sigue valiendo que VFX y arcos rotan 360° hacia el aim

**Decisión:** las skills, los trails del arma y los VFX rotan 360° libres hacia
el cursor. El sprite solo elige la dirección dibujada más cercana al aim, con
histéresis de unos 15–20° para que no parpadee cerca de los límites.

**Por qué:** con un número limitado de direcciones (4 u 8), lo que el jugador
lee en combate es el arco del ataque, no la pose del cuerpo.

## D-003 · Pipeline de personajes: Blender → sprites prerenderizados — Reemplazada por D-004 (2026-11-08)

**Opciones evaluadas:**

| | A. LPC 4→8 dir con herramienta | B. Blender → sprites en 8 dir |
|---|---|---|
| Lo que hace la herramienta | Importar, ordenar y validar frames; generar *borradores* de las diagonales | Renderizar todo automáticamente |
| Trabajo manual | Redibujar 2 diagonales × ~50 frames × cada capa (unos 1000 frames para un set modesto) | Montar el modelo una vez; después, cero por frame |
| Ropa y armadura | Cada capa necesita sus propias diagonales dibujadas a mano y alineadas al píxel | La ropa va skinneada al mismo rig y se anima sola; capas y oclusión salen exactas |
| Direcciones | 8 como máximo | 8 o 16, las que quieras, cambiando un número |
| Animaciones nuevas | Hay que dibujarlas a mano | Mixamo o animación propia, re-render |
| Licencia | Arte LPC CC-BY-SA/GPL: los derivados heredan la licencia y los créditos | Base CC0 (KayKit, Quaternius) o propia |
| Coste en tokens | Barato el código, pero el cuello de botella es el dibujo a mano | Un script de render más iteraciones de look viendo previews |

**Propuesta:** opción B. Base humanoide CC0 ya riggeada (no modelada desde cero
por código), armaduras como mallas separadas sobre el mismo rig, script de
Blender (bpy) que renderiza a baja resolución con shader toon, outline y paleta
cuantizada. Se renderizan 5 direcciones y las otras 3 se espejan. Cada pieza de
equipo sale como capa propia con el cuerpo como máscara de oclusión, así que el
equipamiento sigue siendo intercambiable en tiempo real.

**Abierto:** confirmar con el dueño; elegir base (estilo y proporciones);
resolución del sprite (64 vs 96 px); si la arena/tiles LPC conviven con el
nuevo look o también se cambian.

**Hecho verificado:** Blender 5.2 está instalado en la máquina.

## D-004 · El juego pasa a 3D real con los packs CC0 de Quaternius — Aceptada (2026-11-08)

**Decisión:** en vez de prerenderizar sprites, el juego es 3D en Godot. Base
humana: *Universal Base Characters* de Quaternius (CC0), con su esqueleto UE de
65 huesos. Ropa modular: *Modular Character Outfits – Fantasy*. Animaciones:
*Universal Animation Library 1 y 2* (sin root motion). Todos comparten el mismo
esqueleto, así que cualquier animación sirve para cualquier personaje humano.

**Por qué:** el dueño ya tiene los packs y le gusta el estilo; con 3D real hay
giro de 360° (ideal para el aim de Battlerite), equipo intercambiable sobre el
mismo rig y animaciones nuevas sin dibujar nada.

**Cómo está montado (prototipo del Warrior):**
- **La simulación no cambia**: sigue 2D, determinista, en píxeles. El 3D es solo
  presentación. Conversión fija: **1 m = 40 px de sim** (`game/world3d/view3d.gd`).
  Sim (x, y) → mundo (x/40, 0, y/40).
- `tools/blender/build_warrior.py` genera `warrior.glb` (cabeza del cuerpo base +
  outfit Ranger sin capucha + pelo y barba) y `sword_bronze.glb`. Texturas a 1K.
- `HumanoidRig` carga cualquier modelo humano y le pone las librerías `ual1/` y
  `ual2/`. Ojo: el importador de Godot **quita el sufijo `_Loop`** de los nombres
  (`Idle_Loop` → `ual1/Idle`) y los marca como bucle.
- **Sincronía animación ↔ sim:** cada ataque reproduce un tramo del clip con la
  velocidad calculada para que el impacto caiga justo al final del windup (cuando
  la sim aplica el daño). Además, al cargar se mide hacia dónde apunta la punta de
  la espada en el impacto y el cuerpo se gira para que la hoja caiga sobre el
  objetivo; el barrido del VFX sigue el sentido real de la espada.
- Feel: hit-stop en atacante y víctima, estela de espada pegada a la hoja real,
  shake de cámara, flash de daño, números de daño 3D.
- Cámara 3/4 estilo Battlerite (~53°, FOV 40) con un poco de adelanto hacia el ratón.
- Renderer **Forward+**. En la GPU integrada del dueño da ~40–55 FPS a 1280×720;
  sombras direccionales a 2048 y sin SSAO.
- El prototipo 2D sigue en `game/main.tscn` (no se ha borrado); la escena
  principal ahora es `game/main_3d.tscn`.

**Abierto:** personalización (caras, pelo, colores de ropa) sobre el mismo rig;
armaduras más "warrior" que el outfit Ranger; sustituir el arena procedural por
piezas del Medieval Village / Fantasy Props MegaKit; animación propia de estocada
(UAL no trae una frontal limpia; ahora se usa `Sword_Dash` alineado).

## 2026-11-08 — Solo tercera persona
- Se elimina la cámara top-down: el juego es 100 % tercera persona (mira central, ratón capturado, rueda = zoom 0.3×–2.2×, cámara orbita libre; WASD relativo a la cámara).
- Quieto, el personaje conserva su orientación (se ve 360° orbitando); al moverse/atacar gira.
- Estocada propia: Mixamo "Upward Thrust" retargeteada a UAL con `tools/bake_thrust.gd` → `assets/models/anims/thrust_retargeted.res` (clip `custom/thrust`). Salto reducido al 35 %.
- Archivado el pixel art/2D en `C:\dev\archivados\combat_2d_pixelart`.

## 2026-11-08 — Daño por arma, nivel, items, enemigo, escenas del editor
- **Daño (estilo WoW Classic):** golpe = tirada de arma (min–max) + AP/14·velocidad, × multiplicador de skill; crítico ×2, crit base 5 %. `CharacterStats` ya traía las fórmulas. Multiplicadores: Thrust 1.8, Charge 1.5, Seismic 3.5 (la más fuerte: ~3k con crítico a nv60). Sin números gigantes.
- **Nivel 1–60** (`game/items/progression.gd`): Fuerza 20→166, vida 300→4.5k. XP al matar enemigos. Debug: F5 +5 niveles, F7 nivel 60.
- **Items** (`game/items/`): rarezas Normal, Poco común, Raro, Épico, Único, Legendario (afijos 0/1/2/3/3/4). Armas: espada, hacha, maza, lanza, daga con rasgo propio (rasgos y efectos legendarios: solo datos, pendientes). F6 = arma aleatoria.
- **Enemigo "Soldado"** (`game/sim/enemy_sim.gd`, base Warrior): Golpe con telegraph, Carga, Guardia (<50 % vida). Escala con el nivel y sigue el nivel del jugador (modo de prueba). Siguientes: casters, rogues, clérigo (curandero: matar primero).
- **Editor de Godot:** `main_3d.tscn` ahora tiene los nodos (Arena, Level, HUD, Crosshair, Status, Loadout, Debug) y el escenario es `world3d/training_arena.tscn` con marcadores `Spawns/*` (meta enemy/level/hp). Los actores del jugador/enemigos se instancian en runtime.

## 2026-11-08 — Salto, Soldado con skin, revisión
- **Space = saltar, Shift = slot de movilidad** (Combat Roll). Saltar (>0.6 m) esquiva los golpes cuerpo a cuerpo.
- **Arquetipos de enemigo/clase:** guerrero (Soldado, hecho), caster, rogue, clérigo (curandero) y **arquero**.
- **Soldado:** modelo del Warrior teñido + espada, idle/correr/carga/ataque con espada. IA con espaciado: tras golpear se retira y rodea (120–170 px); solo entra a golpear con el ataque listo; la carga se detiene al llegar a distancia de golpe.
- **Daño normalizado (WoW Classic):** el ritmo de las skills no depende del arma, así que el golpe usa la tirada del arma × 2.6/velocidad + AP/14 × 2.6. Antes las armas lentas eran siempre mejores (corregido).

## 2026-11-08 — Soldado más "jugador", Charge aturde, hurt
- Charge aturde 1 s (antes ralentizaba). Enemigos aturdidos no se mueven ni atacan.
- Soldado: corre a 120 (jugador 168), rodea cambiando de lado, combos de 2 golpes (45 %), rueda para esquivar cuando empiezas un ataque cerca (55 %, cd 3.5 s), golpe cada 1.7 s.
- Fix: los clips que terminaban en to=1.0 se quedaban congelados en el último frame (pose "mirando arriba"); ahora enlazan siempre con la siguiente animación. Hurt del jugador visible.

## 2026-11-08 — M1 sin cooldown, golpes en volumen, Soldado con el kit completo
- **M1 sin cooldown** (jugador y enemigo): solo lo limita su animación (0.46 s por golpe, combo de 3).
- **Pose congelada:** al entrar en hit-stop `is_playing()` daba false y el rig daba el clip por terminado, dejándolo pausado a mitad de golpe. Ya no se evalúa el final del clip durante el hit-stop.
- **Daño en volumen:** los ataques del enemigo ya no pasan por debajo del salto (altura de golpe 90 px > pico del salto 61 px). Solo la voltereta (iframes) o el parry los evitan.
- **Soldado "como un jugador"** (usa los datos de `WarriorKit`): M1 en combo de 3 sin cooldown, Golpe pesado / Estocada / Ruptura sísmica con telegraph (cono, línea, círculo), Carga que daña y aturde 0.8 s al jugador, Parry que contraataca, Voltereta, Bladestorm (<50 % vida), Last Stand (<30 %), Guardia. Decide cada pocas décimas y reacciona a tus ataques con parry o voltereta.
- El jugador puede ser aturdido (`WarriorSim.stun_timer`): cancela el ataque y bloquea el control.

## 2026-11-08 — Sistema de daño único y actores como escenas
- `combat/damage_system.gd` centraliza tipo de daño, crítico y resistencias (físico, mágico, fuego, hielo, veneno, sagrado, sombra). Los kits por clase solo declaran `damage_type`; jugador y enemigos mitigan con `resist`. Sin fórmulas de daño duplicadas por clase.
- Presentación de actores en escenas (`player_actor.tscn`, `soldier_actor.tscn`, `dummy_actor.tscn`) con propiedades exportadas; la simulación sigue siendo código sin nodos (tests headless / netcode).

## 2026-11-08 — Estocada con Sword_Dash, combo de M1 arreglado
- El thrust usaba un clip de Mixamo que termina en pose diagonal hacia arriba y quedaba pausado ahí. Ahora usa el lance de Sword_Dash y todos los clips de ataque del jugador vuelven a idle al terminar.
- Bug del combo: la ventana solo se armaba al conectar, así que fallar reiniciaba siempre al golpe A (parecía un solo ataque). Ahora corre desde que acaba cada golpe: A→B→C.

## Gear Forge: generador de espadas/armaduras (2026-11-08)
- `tools/blender/gear_forge.py` (reemplaza a build_gear.py, que salía con estilo facetado equivocado). Estilo Quaternius: redondeado, bisel/subsurf, paleta apagada.
- Genera N espadones a 2 manos (hoja×guarda×pomo×metal×empuñadura) y sets de armadura (presets recluta/soldado/hierro/bronce + aleatorios), todo semilla-determinista, solo materiales de inicio. Salida en `assets/models/gear/` + `catalog.json`. Armadura rígida skineada al esqueleto de warrior.glb (reemplaza el outfit Ranger, no se suma).
- Uso: `blender -b --factory-startup --python tools/blender/gear_forge.py -- --swords 20 --armors 8 --seed 3 --preview x.png`

## 2026-11-08 — Rendimientos decrecientes de CC
- `combat/cc_diminish.gd`: el stun encadenado (jugador y enemigos) dura 100 % → 50 % → 25 % → inmune, y se reinicia a los 15 s. Evita el stun-lock eterno sin poise. Mismo sistema para roots y silencios cuando existan.

## 2026-11-08 — Skills de suelo, DoTs, registro de clases
- **Apuntado manual tipo Smite:** `InputMessage.aim_point` (punto del suelo bajo la mira). Una skill con `"target": "ground"` + `range` cae donde apuntas (limitada al alcance); un anillo en el suelo muestra el destino mientras la skill está lista. Seismic Break (R) es la primera (alcance 260). Sin punto apuntado cae sobre el jugador.
- **DoTs:** `combat/dot_tracker.gd`; `effects.dot = {damage_type, dps, duration}` en cualquier skill. Tick cada 0.5 s, respeta resistencias, mismo tipo refresca. Jugador y enemigos.
- **`combat/class_registry.gd`:** `WarriorSim` ya no importa `WarriorKit` directo, usa `ClassRegistry.kit(id)`. Contrato mínimo de un kit en `REQUIRED` (testeado). Añadir clase = su kit + una línea en KITS. (La sim aún se llama WarriorSim: falta generalizarla a `PlayerSim` al llegar la 2ª clase.)

## 2026-11-08 — Primer Mago (clase 2)
- `combat/mage_kit.gd` (mismo contrato que WarriorKit, maná con regeneración): Arcane Bolt (M1, proyectil sin cooldown), Fireball (M2, quemadura), Blink, Frost Nova (slow), Poison Cloud (suelo, veneno), Meteor (suelo), Arcane Surge (ultimate, suelo).
- Nuevo cast `projectile` en la sim (`projectiles`, colisión con enemigos y paredes); DoT con `dps_mult` (escala con el daño del jugador).
- `WarriorSim.set_class(id)` cambia kit/recurso/loadout; **F8** alterna Guerrero↔Mago en pruebas. HUD y loadout leen `ClassRegistry.active_kit()`.
- Pendiente del Mago: modelo/túnica propios (hoy es el modelo del Warrior sin espada), VFX propios (orbes con FxShape), balance, y que el loadout elija entre más cartas.

## 2026-11-08 — Creador de personaje, Mago solo arcano
- Pantalla inicial `game/creator/character_creator.tscn` (escena principal): nombre, clase (Guerrero y Mago jugables; Rogue/Cleric/Arquero aparecen como "próximamente"), cuerpo (hombre/mujer), piel, pelo (6 estilos), color de pelo, cejas y ropa (Campesino, Explorador ±capucha, 10 armaduras de `assets/models/gear`). Vista previa 3D giratoria, botón Aleatorio y Jugar.
- `CharacterBuilder` ensambla en runtime: cuerpo base + pelo + cejas + ropa injertando mallas al mismo esqueleto UE. `CharacterProfile` lleva la elección a `main_3d`. Assets extraídos a `assets/models/creator/` (~120 MB por las texturas 4K; recortar luego).
- **Mago solo arcano** (`DamageSystem.Type.ARCANE`): Arcane Bolt, Arcane Orb (DoT arcano), Blink, Arcane Pulse, Arcane Rift (suelo), Starfall (suelo), Arcane Surge. Las subclases (pyromancer, frostmage...) añadirán su elemento encima.
- Quitado F8 (cambio de clase en vivo, se cerraba el juego); la clase se elige ahora en el creador.

- Fix creador: el cuerpo base se recorta a cabeza/cuello/manos cuando hay ropa (la piel asomaba por la tela); cejas propias del cuerpo eliminadas (salían blancas) y se usan las del pack de pelo; pose de vista previa = Idle normal; eliminadas las armaduras generadas por script (solo ropa Quaternius).

- Fix creador: el recorte del cuerpo comparaba el hueso 'Head' con minúsculas y borraba la cara (ahora case-insensitive). La vista previa se renderizaba a 640x360 (stretch canvas_items 2x) y se veía pixelada; ahora renderiza a 900x1100 en una textura. UI del creador compacta para que quepan todos los botones.

## 2026-11-08 — Mago: mana, Blink teleport, apuntado por mantener, Magic Spell Pack, VFX arcanos
- HUD lee el recurso/nombre/pasiva de la clase activa (Mana en azul, "MAGO"). El maná empieza lleno.
- **Blink = teletransporte** (`cast: "teleport"`): desapareces (columna de chispas) y apareces en el punto apuntado (alcance 280), invulnerable durante el cast.
- **Skills de suelo: mantener la tecla = apuntar (marcador), soltar = lanzar** (también Seismic Break del Warrior). El marcador solo se ve mientras la tecla está mantenida.
- **Magic Spell Pack** (Mixamo) retargeteado al esqueleto UAL con `tools/bake_spells.gd` -> `assets/models/anims/spells.res` (clip completo y `_upper`). El mago castea con la animación de tren superior sobre la locomoción (`HumanoidRig.overlay`), así que se mueve mientras lanza. Los tiempos de cada clip (start/contact/end) están en `mage_kit.gd`.
- VFX arcanos procedurales (`game/vfx3d/arcane_fx.gd`): orbe con estela de chispas y luz, ráfagas, columnas; sin assets externos.

## 2026-11-08 — Rogue, Ranger, maná lento
- Diseño base en `Downloads/new assets/Diseño de las cinco clases básicas.docx` (la clase del arquero se llama **Ranger**). Cleric queda para después.
- **Rogue** (`combat/rogue_kit.gd`, Energy, regen 25/s): Twin Fang (50) y Cross Cut (60) cuestan Energy → 2 ataques seguidos y esperar ~1.4 s. Shadowstep (teleport), Poisoned Blades, Fan of Knives, Backstab, Death Sentence. Dagas KayKit.
- **Ranger** (`combat/ranger_kit.gd`, Energy, regen 14/s): Quick Shot (gratis), Charged Shot (atraviesa), Evasive Leap (salto atrás), Multishot (3 flechas), Frost Trap, Volley, Rain of Arrows. Proyectiles con `count/spread/pierce`; dash con `dir: -1`.
- **Maná del Mago:** regen 1.5/s tras 2 s sin gastar, x4 fuera de combate (5 s sin golpes), sin ganancia por golpe; Arcane Bolt cuesta 4. Constantes de regeneración por kit (`RESOURCE_REGEN`, `_DELAY`, `_OOC_MULT`).
- Cara femenina: el recorte del cuerpo fallaba con la malla femenina (datos custom); ya corregido. `tools/bake_spells.gd` acepta carpeta/salida para convertir otros FBX de Mixamo (p. ej. animaciones del Warrior).

## 2026-11-08 — Rogue: M1 libre, Shadowstep con backstab, Fan of Knives (WotLK), VFX por clase
- Rogue M1 (Twin Fang) sin coste. **Shadowstep**: teleport al punto apuntado; si hay un enemigo bajo la mira aparece a su espalda y lo apuñala (×2.2).
- **Fan of Knives** al estilo WotLK: estallido instantáneo de cuchillos en todas direcciones que golpea a todos los cercanos y aplica veneno (VFX: 14 cuchillos disparados + nube verde). **Backstab** aturda 1 s (con DR).
- **Veneno verde**: ráfagas verdes al golpear y aura de burbujas verdes sobre el enemigo mientras dure el DoT (`DotTracker.dominant_type()` -> color del tipo).
- VFX para Warrior/Rogue/Ranger en `arcane_fx.gd`: chispas de impacto (acero/oro), escombros (Seismic), lluvia de flechas, cristales de hielo, boca de arma; partículas con textura radial suave (antes eran cuadrados).

## 2026-11-08 — Animaciones Mixamo por clase, patada, invisibilidad, saltos
- Nuevos FBX de Mixamo (`assets/models/anims/class/`) retargeteados con `tools/bake_spells.gd` -> `class_anims.res` (librería "class").
- **Warrior:** Seismic Break es ahora un salto hasta el punto apuntado (`cast: leap_slam`, anim Run Jump Attack, golpe al aterrizar). Parry: al desviar un golpe reproduce Block React Large.
- **Rogue:** idle con Knife Idle; Cross Cut (M2, 60 Energy) usa Mutant Jump Attack; **Vanish** (Q) reemplaza a Poisoned Blades: invisible 5 s, enemigos no te ven ni te dañan, atacar rompe la invisibilidad, personaje semitransparente.
- **Ranger:** apunta siempre (strafe con Aim Walk F/B/L/R, Aim Idle); Quick Shot = Aim Recoil, Charged Shot = Overdraw, Volley/Rain = Draw Arrow; **Evasive Leap** con arco de salto y Fall A Loop; **Kick** reemplaza a Frost Trap (empuja al enemigo, `effects.knockback`).
- Disponibles sin usar: Fall B Loop, Standing Dive Forward.

## 2026-11-08 — Rogue rehecho (R = Fan of Knives con vuelta 360°, F = Death Sentence con stun), M2 con salto real
- Los enemigos ya no siguen con la mirada a un jugador invisible (`DummySim.facing` solo se actualiza si lo ven).
- `leap_slam` generalizado: `lunge` (salto hacia delante que se frena delante del primer enemigo) + golpe en cono o área al aterrizar. Lo usan Cross Cut (M2 del Rogue, con el clip Mutant Jump Attack sincronizado) y Death Sentence (F, aturde 2 s).
- Rogue: E Backstab, R Fan of Knives (vuelta de 360° con cuchillos que salen escalonados, poco daño, veneno), F Death Sentence (gap closer + stun melee). Estrellas de stun sobre cualquier enemigo aturdido.
- Ranger: la postura de apuntado (strafe/aim idle, mirar a la cámara) solo dura 2.5 s tras disparar; fuera de eso usa idle y carrera normales. Arco rotado 90° para que quede vertical.

## 2026-11-08 — Rogue E = Cheap Shot (stun), M1 con ambas manos, Ranger sin postura, Kick en línea, R/F distintos
- Rogue: **E Cheap Shot** (puñetazo, 40 Energy, aturde 1.5 s) reemplaza a Backstab. M1 alterna Sword_Regular_A (mano derecha) y `ual1/Punch_Jab` (mano izquierda, medido por velocidad de manos); el jab no alinea el cuerpo (`no_align`).
- Ranger: quitada la postura de apuntado; tras disparar vuelve a idle/carrera normal. Arco girado -90° sobre el eje del puño (medido: vertical en 3 poses). Kick es `cast: line` con impacto seco (polvo + sonido de golpe, sin estela de espada).
- Ranger R = **Explosive Arrow** (proyectil que explota en área, `explode_radius`); F = **Rain of Arrows** en oleadas durante 2.1 s (`damage_interval`/`tick_mult` en aoe de suelo). Antes R (Volley) y F eran la misma lluvia.

## 2026-11-08 — Cast bars, flanqueo del Rogue, veneno apilable, cámara fija estilo Smite
- **Cast bar** (`cast_bar: true`): barra en el HUD; moverse o recibir un golpe antes de llenarla cancela el cast (se devuelve coste/carga, 0.6 s de cooldown). Usada en Concentrated Shot (Ranger M2, 1.4 s), y en el Mago: Arcane Orb (0.9 s), Starfall (1.6 s) y Arcane Surge (2.2 s); hay que estar quieto.
- **Rogue:** Cheap Shot (E) solo se lanza por la espalda del enemigo (`requires_behind`), con la animación Stabbing; M1/M2 hacen -20 % de daño de frente (`flank`). Veneno de Fan of Knives se acumula hasta 3 veces (+60 % del dps base por acumulación, sin explosión) — `DotTracker.add(..., max_stacks)`.
- **Dedos:** `tools/bake_spells.gd` ahora retargetea los dedos (antes las manos quedaban abiertas al disparar). Rehechos `spells.res` y `class_anims.res`.
- **Cámara estilo Smite:** el personaje siempre mira hacia donde mira la cámara (siempre se ve su espalda); al moverse en diagonal el cuerpo se inclina hasta 60°; hacia atrás reproduce la carrera al revés. Para girar hay que girar la cámara.

## 2026-11-08 — Enemigos de clase y Laboratorio de Balance
- **Enemigos de clase:** `CombatWorld.add_fighter(clase, equipo, pos, nivel)` crea un `WarriorSim` controlado por `BotBrain` (IA que usa las mismas skills, costes, cooldowns y barras de cast que un jugador; los de rango mantienen distancia, los melee entran y rodean). En el juego: `Arena3D.spawn_class_enemy()`, marcadores de spawn con meta `enemy_class` y **F9** = enemigo de clase al azar con tu nivel. Se distinguen por tinte rojizo, nombre y barra de vida.
- Todos los combatientes son objetivos entre sí (`targets_for`, equipos, `radius`/`facing`, slow/knockback/interrupt recibidos, colisión entre ellos).
- **Balance data:** `res://data/balance.json` (`BalanceData`): multiplicadores por clase (daño, vida, velocidad, crítico, cooldowns, regeneración) y sobrescritura de cualquier número de cualquier skill. Se lee en vivo, también en el juego.
- **Laboratorio de Balance:** `godot --path . res://tools/balance/balance_lab.tscn` — DPS en muñeco (desglose por skill, tramos de 10 s), duelos 1v1/2v2/1v2 con N repeticiones, matriz de clases, edición de stats y skills, guardar/recargar. Mismo motor por consola: `tools/balance/run_balance.gd` (headless, ver cabecera del archivo).

## 2026-11-08 — Strafe lateral y primer informe de balance
- Animaciones de strafe de Mixamo (`left_strafe`, `right_strafe`; también `great_sword_strafe` y `sword_and_shield_strafe` sin usar): movimiento lateral (45°–135° respecto a la cámara) reproduce el clip lateral con el cuerpo mirando a la cámara; hacia delante en diagonal se inclina; hacia atrás corre al revés.
- BotBrain decide skills aunque esté a mitad de otra acción (el buffer las encola): antes el Guerrero casi no usaba skills con M1 mantenido.
- CLI del simulador acepta `cmod.<clase>.<clave>=` y `skill.<id>.<clave>=` para probar cambios sin guardar.

## 2026-11-09 — Controles nuevos, defensa en M2, Poise/Stagger
- **Controles:** M1 básico · M2 defensa de la clase · Shift movilidad · Q/E/1/2 skills · **R ultimate** · **F interactuar** (acción `interact`, aún sin objetos/NPCs) · 3/4 gadgets (pendiente). Slots internos sin renombrar (`F` = ultimate, `R` = tecla 1, `S2` = tecla 2); las etiquetas del HUD y `ACTION_KEYS` de cada kit hacen la traducción.
- **M2 por clase:** Warrior **Block** (mantener; -80% físico / -40% hechizos; no gasta Rage); Rogue **Dodge Roll** (toque, invulnerable 0.03–0.22 s, gasta Energy; el roll sale del Warrior); Mago **Mana Shield** (mantener; absorbe daño 1 maná por punto, omni-direccional); Ranger **Evasive Step** (sin bloqueo; esquiva perfecta = +40 % de daño 1.5 s). Las antiguas M2 pasan a skills: Thrust (Q), Cross Cut (2), Arcane Orb (Q), Concentrated Shot (2). Warrior: Charge en Shift; E y 2 libres.
- **Perfect Parry / Arcane Deflection:** los primeros 0.2 s de la defensa anulan el golpe; si es físico además rompen el poise del atacante (stagger) y el parry lo contraataca / la deflection lo devuelve. Un hechizo parado solo se anula, sin romper poise.
- **Poise = armadura** (`ARMOR` por kit × `armor_mult`; Warrior 100, Ranger 55, Rogue 45, Mago 25, +0.6/nivel). Solo el daño FÍSICO gasta poise (los hechizos y DoT no). Poise 0 -> **stagger** 0.9 s, poise se restaura y hay inmunidad 3 s (sin cadenas infinitas); regenera tras 3 s sin golpes. Bloquear gasta poise. Enemigos: `60 + 3·nivel`.
- VFX/animaciones: pose de guardia (Sword_Block), chispas y anillo en perfect parry + block react, burbuja violeta pulsante del escudo con destello de absorción/rotura y anillo de deflection, fantasma durante los iframes, dive forward en el paso del Ranger, destello + anillo en stagger (también en enemigos), barra de poise en el HUD.

## 2026-11-09 — Rediseño del Mago y enemigos con IA
- **Mago (cada skill cambia algo distinto):** Q **Arcane Pull** (engancha y arrastra al objetivo + slow), E **Arcane Pulse** (repulsión + slow, defensa activa), 1 **Silence** (3.5 s sin skills, cancela casteos), 2 **Starfall** (cast, daño en zona), R **Arcane Surge** (cast de 2.2 s, empuja y silencia 2.5 s), Shift **Blink**, M2 **Mana Shield**. En el pool para intercambiar: **Time Rift** (zona de -55 % de velocidad 4 s) y Arcane Orb (DoT). Efectos nuevos de simulación: `silence` y `pull` (jugador, muñeco, Soldado y combatientes). VFX propios: cadena de energía (Pull), runas/remolino (Silence), zona persistente giratoria (Time Rift), ondas de repulsión (Pulse). Cada skill usa una animación Mixamo distinta.
- **Arquetipos de enemigo** (`enemy_archetypes.gd`): Soldado de Guardia, Campeón (bloquea con timing perfecto, bait, castiga staggers, mucho poise), Duelista (flanquea, roll, stun), Hechicero (kite, silencia, arrastra, escudo), Cazador (kite, salto, patada). F9 spawnea uno al azar; marcador `enemy_class` acepta arquetipo.
- **IA (BotBrain):** lee el tiempo hasta el impacto de tu ataque y reacciona (bloqueo/Perfect Parry, roll/paso, escudo de maná) con tiempo de reacción según dificultad; no golpea contra tu guardia (control en su lugar); remata al aturdido y espera una apertura para el ultimate; flanqueo si hay aliado; kiting y retirada a poca vida; busca la última posición vista si te vuelves invisible.

## 2026-11-09 — Arcane Bind (root) y rediseño del Rogue
- **Arcane Bind** reemplaza a Arcane Pull: ata al objetivo 2.5 s (`root`: no se mueve ni hace dash, sí puede atacar/castear; con rendimientos decrecientes). VFX: cristales/cadenas que brotan del suelo y anillo de atadura mientras dura. Aplica a jugador, muñeco, Soldado y combatientes.
- **Rogue:** M1 alterna puñalada (Mixamo Stabbing, derecha) y jab (izquierda); Cheap Shot = puñetazo (Punch_Cross); Shadowstep llega con una estocada (Dive Forward); Vanish lanza una bomba de humo (OverhandThrow) y da **Ambush** (+60 % al primer golpe desde el sigilo); Death Sentence = lance (Sword_Dash) + stun + ráfaga de 4 cortes alternando puñalada/jab + golpe final (`followups`).

## 2026-11-09 — Modo top-down (tecla C)
- **C** alterna entre tercera persona y top-down (estilo Battlerite/Albion): cámara aérea fija, ratón libre como puntero (apuntado de skills y de suelo hacia el cursor), el personaje gira al instante hacia el puntero, WASD relativo a la pantalla. La simulación ya era plana (2D), así que golpes, proyectiles, zonas y poise funcionan igual en ambos modos.

## 2026-11-09 — Top-down por defecto
- El juego arranca en **top-down** (C alterna a tercera persona). Salto eliminado (la tecla Space ya no hace nada; los saltos de skills — Cross Cut, Evasive Leap, Seismic — se mantienen como skills).
- **Cámara:** AvPág/RePág (PageUp/PageDown) cambian la inclinación; rueda = zoom; el muro sur se oculta en top-down.
- **Lanzamiento rápido (X alterna, por defecto ON en top-down):** las skills de suelo salen al pulsar, hacia el cursor; con OFF se mantiene hold-to-aim (marcador + anillo de alcance de la skill).
- **Legibilidad:** línea de apuntado hacia el cursor, anillo de alcance de las skills de suelo, anillo de equipo bajo los pies (dorado = tú, rojo = enemigo), barras de vida enemigas ×1.5, y **avisos en el suelo para los ataques de los enemigos de clase** (cono/línea/círculo con progreso) además de los del Soldado, con más relleno desde arriba.
- **Locomotión:** si existen en `assets/models/anims/class/` los clips `jog_backward` (o `run_backward`) y `jog_strafe_left/right` (o `run_strafe_*`), tras `tools/bake_spells.gd` se usan automáticamente para correr hacia atrás / lateral; si no, carrera al revés.

## 2026-11-09 — Facing estilo Albion y skills con combos
- **Albion:** en top-down el personaje mira hacia donde corre; solo se orienta al cursor al atacar/castear. Siempre usa la carrera hacia delante (se acabó correr hacia atrás con el puntero al frente).
- **Combos (motor):** `skill.bonus_vs = {estado: multiplicador}` (estados: stunned, rooted, slowed, silenced, marked, poisoned) y efecto `mark` (objetivo marcado: +25 % de daño recibido, 6 s).
- **Warrior:** Sunder Armor (E, marca), Hamstring (2, slow + sangrado), Charge (aturde), Thrust (+50 % vs aturdido, +30 % vs ralentizado), Seismic (+40 % vs marcado, +30 % vs atado).
- **Rogue:** Fan of Knives (veneno x3) -> Cheap Shot (stun, más largo por la espalda) -> **Eviscerate** (+60 % vs envenenado, +40 % vs aturdido); Cross Cut pasa al pool.
- **Mago:** Arcane Bind / Time Rift / Pulse preparan a Starfall (+60 % vs atado, +30 % vs ralentizado) y Arcane Orb (+40 % vs atado).
- **Ranger:** **Bear Trap** (E, ata 2 s) -> Concentrated Shot (+50 % vs atado, +25 % vs ralentizado, +30 % vs marcado); Kick pasa al pool.

## 2026-11-09 — Poda y roles: 5 slots con opciones + skills de grupo + enemigos que obligan a elegir
- **Slots por rol (estilo Albion):** cada slot solo ofrece las skills de su rol (`ability.slot`); `assign_slot`, `sanitize_loadout` y el panel de loadout lo respetan. Warrior: Shift Charge · Q Thrust · E Sunder|Hamstring · 1 Seismic · 2 Rally Cry · R Bladestorm. Rogue: Shift Shadowstep|Cross Cut · Q Vanish · E Cheap Shot · 1 Eviscerate|Fan of Knives · 2 Mark for Death · R Death Sentence. Mago: Shift Blink · Q Bind|Time Rift · E Pulse|Silence · 1 Starfall|Orb · 2 Arcane Barrier · R Surge. Ranger: Shift Evasive Leap · Q Multishot|Explosive Arrow · E Bear Trap|Kick · 1 Concentrated Shot · 2 Hunter's Mark · R Rain.
- **Skills de grupo (slot 2):** `cast: team_buff` aplica a ti y a aliados en radio: Rally Cry (+20 % daño 6 s y poise), Arcane Barrier (absorbe 70 daño), Mark for Death / Hunter's Mark (marca +25 % para todo el equipo).
- **Mago:** Arcane Bolt ya no cuesta maná (M1 libre, como en el diseño de clases): DPS sostenido de 7 a ~31. Ultimate: carga por golpe 8 -> 4 (antes se lanzaba cada ~6 s).
- **Enemigos que obligan a elegir:** Esbirro (enjambre de 4, F10), Guardián (escudo permanente: de frente bloquea el 80 % del físico; hay que rodearlo, aturdirlo o usar magia) y Coloso (jefe: x6 vida, x3 poise, `cc_scale` 0.35 = el control dura un tercio).
- **Bots con combos:** puntúan las skills (remates esperan su preparación, preparan el estado que falta, ultimates con apertura).
- **Balance guardado en `data/balance.json`:** Rogue daño x0.85, Mago daño x1.2 (matriz nivel 5: el Rogue baja de ~95 % a ~81 % contra Warrior y Mago; el Mago deja de ser el último).

## 2026-11-09 — Piso 1 (Praderas) y ultimates por cooldown
- Ultimates: sin carga, cooldown 180 s (los bots empiezan con 25 s de cooldown para no abrir con ella).
- `MeadowFloor` (game/world3d/meadow_floor.gd): generador por semilla (camino sinuoso, 3 campamentos = 10 enemigos, bosque que encierra, props de campamento) + builder visual. `Arena3D.build_floor`. Misión "mata 10" en main_3d (Enter = otro mapa, F3 = alterna entrenamiento).
- IA: `BotBrain.aggro_range/group/alerted` — el campamento entero se alerta cuando uno te ve o es golpeado.
- Assets del kit (escala x0.4–0.6 para esta cámara). Hojas de CommonTree/TwistedTree/Bush salen rojas en Godot (causa sin resolver): por ahora solo pinos.
- Rendimiento del piso: decoración en MultiMesh por (modelo, malla, chunk de 9 m) con distancia de dibujo por tipo; sin sombras en vegetación; sombra solar a 35 m. El cuello era el overdraw de hojas (fill-rate), no los polígonos. `tests/perf_floor.gd` compara categorías en el mismo proceso (la GPU varía entre ejecuciones y los primeros segundos son más lentos).
- Mundo abierto: 3200x2200 px, 7 claros ("salas") cercados de árboles + senderos opcionales + bosque con manchas de densidad; 3 claros con campamento (10 enemigos).
- Enemigos por tier: copias de clase = ÉLITE (todas sus skills, sin nerf; nombre 'Élite …'); ESBIRROS (esbirro, esbirro_arquero, esbirro_mago) = pocas skills (`skills` en el arquetipo), trait `dumb` (no reaccionan a tus ataques), poca vida/daño. Aggro 260 px y alerta de campamento escalonada (0.5–2.4 s).
- Materiales (game/items/materials.gd): solo comunes (tier 1): piedra, mena de cobre, madera, fibra, hierba curativa (cura 25 por unidad), flor silvestre, hongo + botín (cuero basto, hueso, polvo arcano). Nodos de recolección en el piso (F, ~75 px): 9 filones, 8 piedras, 16 hierbas, 10 flores, 8 hongos, 14 fibras, 8 troncos; se ocultan al recogerlos. Los enemigos sueltan botín al morir (esbirros poco, élites más). Inventario estático `Materials.inventory`; materiales raros irán en pisos altos (campo `tier`).
- Balance piso 1: el héroe empieza en nivel 3; campamentos 5 esbirros / élite + aprendiz / élite + 2 esbirros; esbirros con daño x0.3. `tools/balance/floor_balance.gd` (bot por clase vs cada campamento). Los bots son jugadores flojos (kitear/esquivar), así que sus winrates son una cota baja.
- Pueblo (game/world3d/town.gd): hub con Herrería (Brann), Salón de Alquimia (Elowen), Taberna (Gorm) y al norte los cimientos de la Torre con un portal. Los edificios se entran (techo y muro delantero se ocultan al estar dentro, como WoW); cada uno tiene su NPC dentro. F junto a un NPC abre `NpcPanel` (ventana estilo WoW: pestañas, lista de recetas, detalle con materiales en verde/rojo, botón Crear). La taberna es diálogo (descansar = curar todo, rumores). F en el portal entra a un piso nuevo (semilla aleatoria).
- Crafteo (game/items/crafting.gd): armas de cobre (espada/hacha/maza/daga/lanza), armadura (yelmo, peto, grebas, botas: sube vida y poise) y pociones (vida H, elixir de fuerza J, arcana K). Todo es poco común nv.3 y se equipa si mejora. Armadura en `WarriorSim.armor_items` (+ `armor` suma al poise). Equipo, nivel y XP persisten entre pueblo/piso (`CharacterProfile`).
- Modos: F3 cicla town → floor → training. Héroe empieza nivel 1 con 2 pociones de vida. Enter tras la misión vuelve al pueblo. Esbirros más débiles (vida x0.35, daño x0.22) para nivel 1.
- Recursos procedurales: posición y cantidad de cada nodo dependen de la semilla del piso (±3-4 por tipo).
- Pisos guardados: `CharacterProfile.floor_saves[piso] = {seed, dead, gathered, done}`; al volver a entrar se regenera el mismo mapa (misma semilla), sin los enemigos muertos y con los nodos ya recogidos. Solo en memoria de la sesión (falta guardado a disco). El pueblo es fijo (semilla 7).
- Ficha de personaje (tecla I, `CharacterPanel`): slots arma/cabeza/pecho/piernas/manos/pies que suman stats, atributos y mochila (clic en slot de armadura = desequipar, clic en mochila = equipar). `Gear` gestiona equipar/mochila.
- Calidad al forjar: 85% poco común / 13% raro / 2% épico (stats x1.1/1.25/1.45 + afijos extra); único y legendario no se fabrican. La UI no muestra rareza antes de forjar; se revela al terminar.

## 2026-11-09 — Sets de inicio por clase (Guerrero, Mago, Arquero, Pícaro)
- A partir de los trajes Ranger y Peasant del pack Quaternius (hombre y mujer) se generan 4 sets básicos con Blender: `tools/outfits/make_textures.py` (recolor del atlas 4096² por hue/sat conservando el sombreado: guerrero rojo+acero, pícaro gris carbón con capucha, arquero caqui, mago azul) y `tools/outfits/make_geometry.py` (hombrera espejada para el guerrero hombre, túnica larga del mago + capucha).
- `CharacterBuilder.OUTFITS` ahora admite `parts` (archivo, `tex`, `hide`/`only`, `mat_from`); ids nuevos: `warrior`, `mage`, `archer`, `rogue`. Vista previa: `tools/outfit_preview.tscn` (con `CAPTURE_DIR`).
- Aún no asignados a las clases del juego (el actor sigue eligiendo ranger/peasant al azar).
- Revisión (mismo día): la falda del mago pasa de cilindro liso a túnica acampanada con pliegues, dobladillo ondulado, más larga atrás y ribete de cuero, pintada con zonas reales del atlas (no un color plano). Misma pieza para hombre y mujer.

## 2026-11-09 — Más peinados y paleta del mago
- Peinados nuevos (copias editadas en Blender con `tools/outfits/make_hair.py`, mismas texturas y material que los originales; un archivo ajustado por sexo `_M`/`_F`): Media melena (bob, corte inclinado), Al hombro ondulado, Largo ondulado, Doble moño, Tupé, Desordenado, Voluminoso, Corto texturado, Barba larga y Perilla. `HAIRS` admite `file_f`. Descartados tras verlos: cresta y barba corta (se veían mal). Vista previa: `tools/hair_preview.tscn` (`HAIR_ONLY`, `HAIR_SEX`, `HAIR_COLOR`).
- Mago: ya no es azul puro. Túnica azul-lavanda apagada, falda y capucha índigo-violeta, cuero en dorado antiguo. La falda usa un parche de tela del atlas calculado automáticamente (solo texels de tela).
- Ojo: tras cambiar un .gltf, `--import` a veces no lo reimporta; borrar su `.scn` en `.godot/imported/` y reimportar.
- Assets integrados (sesión de pulido): SFX por categoría (`Sfx`, 131 wavs en assets/audio/sfx/game: combate, hechizos, pasos por superficie, UI, crafteo, recolección, puertas, portal, rugidos de enemigos al alertarse, viento ambiente); iconos de skills por clase (HUD) y de objetos/materiales (ventanas); fuente Cinzel en ventanas y letreros; texturas Kenney Particle Pack en `ArcaneFx` (chispas con forma, trazos de corte, destellos, círculos mágicos en el suelo); aldeanos Craftpix en el pueblo (FBX en T-pose con brazos bajados por código). No usados: Kenney UI (estilo moderno, no encaja), música (no hay pistas descargadas), Brackeys VFX bundle (pendiente), Medieval Weapons.
- Ojo: `SkillIcons`/`ItemIcons` ya existían en archive/ (class_name global): los nuestros son `HeroSkillIcons`/`HeroItemIcons`. Piedra y madera usan iconos dibujados (no hay en los packs).

## 2026-11-09 — 5 armaduras de guerrero con casco (placas / malla)
- Sets (ids de `CharacterBuilder.OUTFITS`): `armor_footman` (Soldado: yelmo nasal, malla, tabardo rojo), `armor_knight` (Caballero: yelmo cerrado, placas, hombreras apiladas, tabardo azul), `armor_hoplite` (Hoplita: yelmo corintio con cresta, coraza de bronce, pteruges), `armor_norse` (Norteño: yelmo con cuernos y cofia de malla, malla + escamas, hombreras redondas) y `armor_dark` (Caballero Oscuro: placas negras con púas y yelmo con visera). Hombre y mujer. Ocultan el pelo (`hide_hair`).
- Generación: `tools/outfits/make_armor.py` + `armor_lib.py` (Blender). El torso y las extremidades son lofts regulares alrededor del cuerpo (radio por ray-cast, suavizado) para tener bordes limpios; pantalones/botas propios (se ocultan Legs/Feet de Ranger porque se tragaban las placas). Cascos, hombreras, cuernos, púas, tabardos, pteruges: primitivas skinneadas (cascos solo a Head).
- Materiales por ranura (`plate/mail/leather/trim/cloth/bone`): texturas neutras tileables (`tools/outfits/make_armor_textures.py`) + tinte por set (`ARMOR_TINTS`) + oclusión horneada en vertex color. Vista previa: `ARMOR=1 ZOOM=n tools/outfit_preview.tscn`.
- Pendiente: asignar a la clase guerrero y al botín/crafteo (hoy solo existen como opciones de ropa del creador).

## 2026-11-10 — Armaduras: ajuste de talla/estilo y sets en el sistema de crafteo
- Cascos ~16 % más pequeños y pegados al cráneo; coraza/extremidades con offsets ×0.7, hombreras ×0.88, tabardos más estrechos. Placas con caras planas (aristas marcadas), botas cerradas con puntera (sin dedos), colores apagados y poco brillo (el juego no tiene reflejos, así que `metallic` es bajo).
- Sets (5 piezas c/u: cabeza, pecho, piernas, manos, pies; receta en herrería, `Item.set_id`, `ArmorSets`): Soldado de Leva (armor ×1.15), Escudero de Acero (armor ×1.3, más caro), Panoplia de Bronce (+fuerza), Cota del Norte (aguante ×1.25, +fuerza, +crit), Hierro Ennegrecido (armor ×0.8, +crit, +poder de ataque). Mismo presupuesto de nivel que el cobre; la calidad al forjar multiplica como antes.
- El set del peto equipado decide el aspecto del héroe (`ArmorSets.outfit_for` en `warrior_actor_3d.gd`); se aplica al cargar la escena (no cambia en vivo al equipar).

- Caballero: el yelmo cuadrado (cubo) se cambió por un armet redondeado con cúpula, visera con ranura de ojos, ranuras de respiración, cresta baja y banda en la frente.
- Simplificación estilo equipo inicial: los 5 sets pasan a túnica/jerkin + peto o coraza solo en el pecho, hombreras pequeñas, brazales y botas de cuero (se quitaron placas de piernas/brazos, rodilleras y escamas). Mismas piezas y stats.
- Pulido: pantalones de lino por set (nuevo slot `pants`), botas de cuero con puño y suela, gorjal de placa en caballero/hoplita/oscuro, tinte de acero más oscuro en el Escudero.
- Pueblo ampliado: Peletería (Hilda: cuero), Sastrería (Maren: tela ligera) y Carpintería (Tobin: arcos, bastón, garrote, lanza) con NPC, interior y recetas propias; las puertas de todos los edificios miran a la plaza (antes miraban hacia fuera). Tipos de arma nuevos: arco y bastón.
- UI: barras de vida de enemigos estilo League (`UnitBars`, 2D): marco, divisiones cada 100, insignia de nivel, "vida / máxima", poise fino, estados; élites con marco dorado y esbirros más pequeños. Recursos del jugador (vida, poise, recurso, XP) abajo al centro sobre la barra de skills, y ambas más pequeñas. Bug de las barras 3D (se desplazaban al inclinar la cámara) eliminado al dibujarlas en 2D.
- Revisión lógica: el guardado de pisos duplicaba enemigos muertos (se guarda al cambiar de modo y otra vez al salir) y contaba kills dobles; ahora sin duplicados. Atajos de pociones/ficha bloqueados con ventanas abiertas. Se quitó un obstáculo invisible en el centro de cada local.

## 2026-11-10 — Armaduras pieza a pieza
- Cada set se exporta por ranura (`Male_Armor_<Set>_<head|chest|legs|hands|boots>.gltf`, `export_split`). `CharacterBuilder.build` acepta `opts["gear"] = {ranura: set}`: cada ranura muestra la pieza equipada o, si falta, la ropa base de Campesino; mangas ajustadas de Ranger bajo los brazales. `ArmorSets.gear_for(CharacterProfile.armor)` lo calcula, se mezclan sets libremente.
- Pelo: con casco puesto se oculta (barbas se quedan salvo bajo yelmos cerrados: Escudero, Hierro); sin casco se ve. Vista previa `MIX=1` (piezas sueltas) y `HAIR=<id>`.
- Sombreado suave con aristas duras por ángulo (42°) en vez de caras planas; cúpulas de casco cerradas; pantalón y bota por separado (caña de bota, puño, suela).

## 2026-11-10 — 5 sets de pícaro (editando el set base de Quaternius)
- Sin geometría propia: partiendo de los trajes Ranger/Peasant (piezas modulares) se recolorean (`tools/outfits/make_rogue_textures.py`, atlas a 2048 para no inflar el repo) y se editan las capuchas (`make_rogue_geometry.py`: capucha corta y capucha picuda). `CharacterBuilder.QSETS` dice de qué traje sale cada ranura; se mezclan pieza a pieza igual que los de guerrero.
- Sets: Ladrón de Callejón, Sombra de Cuervo (capucha picuda + hombreras), Bribón del Desierto (túnica de Peasant), Batidor del Bosque (verde + hombreras), Hoja Carmesí. Stats: armor ×0.5–0.65, aguante ×0.75–1.0, con crítico/poder de ataque repartido (nivel bajo, sin OP). Recetas en Sastrería (cabeza, piernas) y Peletería (pecho, manos, pies).
- Las mangas base ya no llevan el brazal (lo añade la ranura de manos).
- Pícaros, no solo recolores: `tools/outfits/make_rogue_extras.py` añade piezas encima del traje Quaternius (ajustadas a la cabeza por ray-cast): bandana con nudo (Ladrón, pelo visible, sin barba), capucha picuda + máscara de pico (Cuervo), turbante + velo (Desierto), capucha + bandana + capa (Batidor), gorra con pluma + antifaz (Carmesí); además bandoleras con cuchillos, capas, fajines, correas de muslo, muñequeras, puños de encaje, espinas. Banderas `hair`/`beard` por set en `CharacterBuilder.QSETS`.
- Pueblo tranquilo: el jugador usa idle/caminata normales (`ual1/Idle`, `ual1/Walk`), armas guardadas, camina a la mitad de velocidad y no puede atacar. Los NPC de oficio tienen su animación (herrero/carpintero cortan, alquimista vierte, sastre conversa, tabernero con brazos cruzados) en vez de T-pose.
- Guardado a disco (`SaveGame`, user://savegame.json): personaje, nivel, XP, materiales, mochila, equipo y pisos (semilla, muertos, recogidos). Se guarda al cambiar de zona, cada 45 s y al cerrar; el creador carga la partida (botón CONTINUAR / "Nuevo (borra partida)"). Solo guarda si hay personaje elegido (las escenas de prueba no pisan tu partida).
- Pisos 1-10 (praderas): el piso N genera enemigos de nivel N con más esbirros y élites (campeones desde el 5, coloso en el último campamento de los pisos 5 y 10); al cumplir la misión se abre un portal verde en la sala más lejana (F sube al piso siguiente). En el portal del pueblo, ←/→ elige entre los pisos desbloqueados. Árboles rojos (TwistedTree/Bush_Common) y secos grises (DeadTree) reservados para el tier +10; los rojos no eran un bug, son árboles de otoño del kit.
- Armas por clase: guerrero (espada, hacha, maza, lanza), pícaro (daga, espada), mago (bastón), arquero (arco, daga). Lo que tu clase no puede empuñar va a la mochila (deshabilitado). Cofres en las salas sin campamento (botín según la semilla del piso). Cleric eliminado de la lista del creador (queda para más adelante).
- Skills: Mark for Death lanza un cuchillo giratorio; el sangrado (Hamstring y otros DoT físicos) muestra gotas rojas; Eviscerate y Death Sentence tienen fogonazos propios. Calidad gráfica: F11 cicla 100% / 77% / 59% de resolución con FSR.
- Pulido pícaros: capucha picuda más baja y natural (antes un tubo), pico del cuervo curvo de una pieza, antifaz con huecos de ojos elípticos suaves.
- Cascos de pícaro, bugs corregidos uno a uno: bandana con banda de nudo sobre el pelo y colas pegadas a la nuca (antes flotaban), sin tabla de ribete en el pico del Cuervo, turbante que envuelve hasta las orejas sin mancha naranja, gorra con ala más pequeña y pelo visible, antifaz con correa trasera. Con capucha el pelo ahora se ve (Cuervo, Batidor). `export` de Blender reintenta si el editor de Godot bloquea el .bin. Los cascos de guerrero no se tocaron.
- Armas visibles (`WeaponCatalog`, assets/models/weapons: Quaternius Medieval Weapons + KayKit staff): lo que equipas se ve en la mano (espada/hacha/maza/lanza/daga/arco/bastón) con un aspecto distinto según rareza (p. ej. espada normal -> dorada -> claymore); los enemigos llevan armas según su arquetipo (esbirros hachas pequeñas, guardián martillo, coloso martillo grande...). El pícaro lleva dagas dobles. Se reconstruye al cambiar de arma. Corregido: en el pueblo las armas no se ocultaban (otra línea las volvía visibles cada frame).
- Nitidez: MSAA 2x, anisotrópico 8x, mipmap bias -0.35, sombra solar 4096, alpha-to-coverage en hojas, contraste/saturación +12%. Rendimiento medido con tiempos de GPU (no FPS, que fluctúan): los árboles comunes de copa redonda costaban ~12x más GPU que un pino (sobredibujado), por eso ahora son ~18% de los árboles; piso 1 ~16 ms GPU y pueblo ~10 ms a calidad alta. Ajuste automático de calidad (4 niveles: MSAA -> FXAA -> FSR 85% -> 70%, con menos distancia de vegetación) si el promedio de FPS baja de 52 durante 10 s; F11 la cambia a mano.
- Capucha picuda del Cuervo ajustada a la cabeza (antes flotaba muy alta); bandana, velo y pico ya no dejan ver la nariz (el paño se tensa sobre ella en vez de moldearla).
- Pico del Cuervo más pequeño y pegado: máscara ajustada a nariz y boca con un pico corto curvado (mandíbula inferior de ribete) y correa trasera. `tools/outfit_preview.tscn` acepta `SOLO=<n>` para ver un solo personaje de perfil.

## 2026-11-10 — 5 sets de mago
- Mismo método que los pícaros: base Peasant (túnica + falda de túnica `Mage_Robe`, ya con material para recolorear) y capucha Ranger recoloreadas a 2048 (`make_mage_textures.py`) + piezas añadidas (`make_mage_extras.py`). Sets (`CharacterBuilder.QSETS`, prefijo de textura `mg`): Aprendiz de Magia (capucha, bufanda con nudo, cuerda, zurrón), Chispa de Brasa (diadema con llamas, chal de cuatro puntas con ribete dorado, fajín), Escarcha del Norte (cuello de piel, chal festoneado de piel, broche de copo), Sabio Errante (sombrero puntiagudo con ala ondulada, capa en V con estrellas, broche), Osario Penitente (capucha con cuernos de hueso, costillas, esternón, espolones).
- Stats: armor ×0.4–0.55, aguante ×0.75–1.0, poder de ataque/crítico repartido; recetas en Sastrería (cabeza, pecho, piernas, manos) y Peletería (botas).
- Previews: `MAGE=1` (`SOLO`, `ZF` para mujer). Las ventanas de Godot se abren fuera de pantalla (`--position 9000,9000`).

## 2026-11-10 — 5 sets de arquero
- Base: traje Ranger (el natural del arquero) recoloreado a 2048 (`make_archer_textures.py`; `recolor_ranger` gana `lift` para que las zonas oscuras no queden negras) + piezas añadidas (`make_archer_extras.py`: aljaba con flechas y plumas, gorra con pluma, sombrero de ala ancha con barbiquejo, cornamenta con corona de hojas, cinta de plumas, cuentas, cuello/manto de piel, correas, vendas, taparrabos). Sets (`QSETS`, prefijo `ar`): Montero Novato, Explorador de la Llanura, Guardabosques, Centinela del Norte (capucha + hombreras, el más resistente), Rastreador de Dunas.
- Stats: armor ×0.6–0.8, aguante ×0.8–1.1, poder de ataque/crítico repartido. Recetas en Peletería. Preview `ARCHER=1`.
- Sombreros más pequeños: sombrero de sabio (ala y copa), sombrero de explorador. Las 100 piezas de set (20 sets) están en las recetas de Herrería, Sastrería y Peletería.

## 2026-11-10 — 5 espadas con diseño propio
- `tools/weapons/make_swords.py` (Blender) edita copias de las espadas Quaternius del juego (forma de la hoja, piezas añadidas, paleta) y las exporta a `assets/models/weapons/custom/*.glb`: Espada de Recluta (hierro, corta), Xifos de Bronce (hoja ancha, empuñadura roja), Alfanje del Desierto (curvo, guarda dorada), Espada Larga de Acero (acanaladura, pomo grande), Colmillo de Sangre (claymore dentada con cuernos).
- Integración: `Item.model_id` (guardado en `SaveGame`), `WeaponCatalog.CUSTOM` (modelo + longitud; el actor lo usa si el arma equipada tiene `model_id`) y 5 recetas de Herrería con `model`, `speed`, `dps_mult` y extras (`Crafting._apply_sword_design` reajusta el daño para mantener el DPS: Recluta ×0.95/2.4 s … Colmillo ×1.15/3.0 s + poder de ataque). Vista previa: `tools/weapon_preview.tscn`. Test: `tests/test_gear_designs.gd`.
- Lore: `docs/LORE.md` (la Torre es una memoria; cada piso es un Pliegue; los enemigos son Ecos: Sombras = esbirros, Ecos de Héroe = élites con las clases, Colosos cada 10 pisos con una Llave). Gadgets (solo diseño, por oficio): `docs/GADGETS.md`.
- Ritmo de nivel (`FloorRewards`): pisos 1-3 = 1 nivel cada uno (garantizado); desde el 4, cada piso vale ×0.78 del anterior (piso 10 ≈ 0.2 de nivel). XP del piso según atribuciones (enemigos derrotados, opcional, rapidez, sigilo, camino difícil ×1.5); matar da XP directo por tier (esbirro/élite/jefe). Resumen de recompensa (`RewardPanel`).
- Materiales por grado (escala a 100 pisos): cada tramo de 10 pisos usa 2 grados. Praderas: grado 1 (pisos 1-5: cobre, madera, fibra, hierba, cuero basto, polvo arcano) y grado 2 (6-10: hierro, roble, lino, salvia, cuero curtido, esencia arcana; ~70 % de los nodos). Colosos sueltan pieza única (Colmillo del Umbral p5, Corazón de la Pradera p10). Recetas de grado 2 generadas automáticamente desde las de grado 1 (stats ×1.9, nivel de objeto 8) y bloqueadas hasta llegar al piso 6. Pociones Mayores se usan antes que las normales.
- Misiones por piso (`MissionCatalog`/`MissionLayout`/`MissionRuntime`/`FloorController`): 20 tipos (clear, hunt, duel, guardian, boss, stealth, waves, survivor, timed, gather, harvest, treasure, ambush, explore, hidden, banners, beacons, delivery, rescue, choice) + 1 objetivo opcional (sin pociones, rapidez, sin bajar del 50 %, todos los cofres, sin alerta). Piso 1 = clear, pisos 5 y 10 = boss, el resto por semilla. Interactuables (altares, balizas, estandartes, reliquia, jaula, cartel) con F; brújula para objetivos lejanos; el aliado del rescate sigue al jugador (rasgo `ally` en BotBrain) y si cae el objetivo pasa a limpiar el piso. Estado de la misión se guarda con el piso. Tests: `tests/test_missions.gd` (lógica de todos los tipos con host simulado, 7700+ comprobaciones) y `tests/test_mission_scenes.tscn` (humo en el juego real, 169 comprobaciones; es una escena porque necesita autoloads).
- Iconos de skills recoloreados por clase: guerrero rojo, mago celeste, pícaro amarillo, arquero verde claro.
- Capturas/pruebas con render: abrir la ventana fuera de pantalla (`--position 6000,4000`) para no tapar lo que el usuario esté viendo.

## 2026-11-10 — Auditoría: sin poise/stagger, cancelaciones, fórmula de enemigos por piso, drops y 35 armas crafteables
Lista priorizada y estado en `docs/AUDITORIA.md`. Referencia de combate: Albion Online.

- **Poise y stagger eliminados** (reemplaza la entrada "Poise/Stagger" del 2026-11-09): fuera de la sim (`WarriorSim`, `DummySim`, `EnemySim`), kits, HUD, barras de enemigos, ficha, actores y tests. **La armadura pasa a reducir el daño físico:** `reducción = armadura / (armadura + 320)`, tope 60 % (`WarriorSim.physical_reduction`). Guerrero nv.1 ≈ 23 %, Arquero 14 %, Pícaro 12 %, Mago 7 %. La magia la ignora. Perfect Parry / Arcane Deflection ya no aturden: anulan, devuelven daño e interrumpen el cast del atacante. Rally Cry cura un 8 % en vez de restaurar poise.
- **Cancelaciones y buffer:** buffer de input 0.22 → 0.35 s. Pasado el 35 % de la recuperación, cualquier acción en el buffer la corta (`RECOVERY_CANCEL`). Una skill de escape (dash/teleport de movilidad o esquiva) corta además el windup del básico y los casts con barra (devuelve el coste). Las ráfagas con golpes encadenados terminan antes de poder cortarse.
- **Casts y cooldowns más cortos:** Arcane Orb 0.9 → 0.6 s, Starfall 1.6 → 1.0 s (cd 14 → 12), Arcane Surge 2.2 → 1.4 s, Concentrated Shot 1.4 → 0.9 s. **Ultimates: cooldown 180 → 60 s** (en un piso de 3-5 min se usan varias veces). Hit-stop con tope de 0.05 s (`HumanoidRig.HITSTOP_MAX`).
- **Fórmula de enemigos por piso** (`EnemyArchetypes.floor_scale`, única fuente): el enemigo es un combatiente de su clase con nivel = piso; encima, por tier, `vida × TIER.health × (1 + 0.03·(piso−1))`, `daño × TIER.damage × (1 + 0.05·(piso−1))` y `windup × TIER.windup`. Esbirro 0.20 / 0.40 / ×2.0 · Élite 0.80 / 0.60 / ×1.5 · Jefe 4.2 / 0.70 / ×1.7. Los `mods` de cada arquetipo son ahora relativos a su tier. El windup alargado solo afecta a enemigos: su telegraph se lee.
- **Piso 1 = tutorial:** solo esbirros (3 + 3 + 4 = 10). Pisos 2-3: un élite solo en el último campamento. Pisos 4-7: un élite por campamento menos el primero. Pisos 8+: dos en el último. Campeones desde el 6. Esbirros: básico + como mucho 2 skills (`MINION_MAX_SKILLS`, testeado).
- **Jefes con fases** (`CombatWorld._update_bosses`): al 66 % y al 33 % de vida el Coloso se detiene 1.6 s (aviso con onda roja + ventana de daño), invoca 2 / 3 esbirros y vuelve con daño ×1.15 / ×1.3, velocidad ×1.08 / ×1.16 y cooldowns ×0.8 / ×0.65. En el campamento del jefe no hay élites.
- **Simulador:** `tools/balance/floor_curve.gd` (bot por clase con el nivel y equipo esperados contra cada campamento, pisos 1-10) escribe `docs/BALANCE.md`. Línea base antes del cambio: nivel 1 ganaba 0 % contra dos de los tres campamentos del piso 1. Con la primera versión de la fórmula: 100 % en pisos 1-2 con 74-94 % de vida restante.
- **Drops de equipo** (`Loot`): esbirro 1.5 %, élite 8 %, jefe 100 % (mínimo Raro), cofre 6 %, completar piso 15 % (25 % con el opcional). Nivel de objeto = piso. **Pesos de rareza por piso** (`ItemRarity.weights_for_floor`): piso 1 = 82 / 18 / 0…; piso 5 = 62.5 / 30 / 7.5; piso 10 = 38 / 36 / 20 / 5 / 0.8 / 0; legendarios desde el piso 20. Armadura genérica de drop: `ItemFactory.roll_armor`.
- **35 armas con modelo propio crafteables** (`WeaponDesigns`): una tabla da modelo, tipo, grado, taller, velocidad, DPS y coste. 16 de grado 1 (cobre, madera, fibra, cuero basto, polvo arcano) y 19 de grado 2 (hierro, roble, lino, cuero curtido, esencia arcana; piso 6+). Presupuesto por grado ±5 %: un arma con crítico o poder de ataque pega algo menos. `WeaponCatalog.CUSTOM` desaparece (lee de `WeaponDesigns`). Los 20 sets de armadura ganan versión de grado 2. `tools/items/recipe_table.gd` genera `docs/RECETAS.md` y falla si hay armas huérfanas, recetas sin modelo, materiales sin uso o costes de grado incoherente (lo mismo en `tests/test_gear_designs.gd`).
- **Reglas de arma por clase** (sin cambios, verificadas contra el catálogo): Guerrero espada/hacha/maza/lanza · Pícaro daga/espada · Mago bastón · Arquero arco/daga.
- **Ficha de personaje estilo WoW** (`CharacterPanel`): modelo en idle en un SubViewport (se gira arrastrando, lleva el equipo y el arma), slots alrededor con borde del color de la rareza, atributos en el centro y mochila en cuadrícula con aviso de mejora/peor.
- **Curva medida y corregida:** con la primera fórmula el piso 1 daba 100 % de victorias al bot (74-86 % de vida restante), pero la vida enemiga crecía más rápido que el daño del jugador (esbirro: 4 golpes en el piso 1, 8 en el 10; Coloso: ~230-290 golpes básicos). Corrección: la vida se divide entre `1 + 0.05·(piso−1)` (`HEALTH_EASE`, sustituye al crecimiento +3 %) y el jefe baja de ×4.2 a ×2.0 de vida. Resultado en `docs/BALANCE.md`.
- **Armas custom revisadas en Blender** (`docs/ASSETS_GUIA.md`, guía para futuras sesiones): hoja de contacto + auditoría (`tools/blender/audit_weapons.py`); las 5 lanzas y los 5 bastones se rehicieron desde cero con `tools/weapons/forge_lib.py` (astas rectas y gruesas, hojas a partir de un contorno, 3-6 materiales de paleta, origen en el agarre); a las otras 25 se les pasó `tools/weapons/finish_weapons.py` (soldar, normales, piezas flotantes, saturación ≤ 0.62, nombres de material reales). Regla para todo asset nuevo: generar → auditar → mirar la hoja de contacto → corregir.
- **Pendiente** (ver `docs/AUDITORIA.md`): capturas de verificación, clase Clérigo, revisión de los 20 tipos de misión, VFX por skill, auditoría de assets con Blender, afinar la curva de los pisos 3-10 con el simulador.
