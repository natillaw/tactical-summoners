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
