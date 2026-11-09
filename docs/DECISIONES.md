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
