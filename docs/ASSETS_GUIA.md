# Guía para hacer assets 3D por script (léela antes de tocar Blender)

Escrita tras revisar las 35 armas de `assets/models/weapons/custom`. Va dirigida a cualquier sesión (Sonnet
incluido) que genere o edite modelos con `blender -b`. Lo que sigue son las causas reales de los fallos que
se encontraron y la forma de trabajar que los evita.

## 1. El método: mirar siempre, medir siempre

Los fallos de la tanda anterior no eran de habilidad, eran de **no haber mirado el resultado**. Nadie renderizó
las 35 armas juntas, así que no se vio que las lanzas tenían el asta ondulada, que una maza tenía una pieza
flotando o que los bastones eran un arcoíris pastel.

Ciclo obligatorio para cada tanda de assets:

1. **Genera** (script en `tools/weapons/` o `tools/outfits/`).
2. **Audita con números:** `blender -b --factory-startup --python tools/blender/audit_weapons.py -- --sheet hoja.png --json audit.json`
   Imprime por arma: triángulos, tamaño, altura del origen, nº de materiales, caras sin material, vértices sueltos.
3. **Mira la hoja de contacto** (`hoja.png`: todas las armas a la misma altura, lado a lado). Abre la imagen
   con Read y revisa cada una contra la lista del punto 4. Si no la has mirado, no está hecha.
4. **Corrige y repite** hasta que la hoja pase. Solo entonces integra en el juego.
5. Pasa `tests/test_gear_designs.gd` y `tools/items/recipe_table.gd` (ningún arma sin receta, ninguna receta sin modelo).

Comparar en hoja de contacto es lo que enseña el estilo: un arma fuera de estilo se ve al instante al lado de las demás.

## 2. Qué es "estilo Quaternius" (en concreto)

- **Siluetas gruesas.** El juego se ve desde una cámara alta y lejana: un asta de 1 cm de radio desaparece.
  Mínimo ~2 cm de radio en astas, ~2.5 cm de grosor en hojas (a escala real, en metros).
- **Formas simples y rectas.** Un asta es un cilindro recto de 8 lados. Nada de curvas orgánicas ni ruido
  para "dar vida": eso se lee como error.
- **Sombreado plano, bisel de 1 segmento.** Sin subdivisión, sin smooth. El bisel es lo que da el brillo en la arista.
- **Colores planos y apagados, pocos.** Como mucho 5-6 materiales por arma, sin texturas. Saturación ≤ 0.62
  salvo gemas y runas (≤ 0.8). La paleta está en `tools/weapons/forge_lib.py` (`PAL`): acero, hierro, bronce,
  oro, tres maderas, cuero, tela roja/azul, hueso, piedra y cuatro gemas. **Usa esos nombres; no inventes colores.**
- **Un acento por arma.** Una venda roja, una gema, un banderín. No tres.
- **`metallic` ≤ 0.3.** El juego no tiene reflejos; un metal con `metallic` alto sale negro.
- **Presupuesto:** 250-600 triángulos para un arma hecha desde cero; hasta ~2000 si parte de un modelo del pack.

## 3. Convenciones técnicas del juego (si fallan, el arma se ve mal en la mano)

- Eje largo **+Z en Blender** (sale como +Y en el `.glb`); la hoja plana en el plano XZ (el grosor va en Y).
- **Origen = punto de agarre** para lanzas, bastones y arcos (`WeaponCatalog` los pega a la mano por el origen).
  Espadas, hachas, mazas y dagas se agarran por el mango y el catálogo lo calcula, pero el origen debe estar
  dentro de la malla. La lanza de caza anterior tenía el origen 19 cm *por debajo* del regatón.
- **Una sola malla, una sola isla lógica:** nada flotando. `finish_weapons.py` borra islas pequeñas cuya caja
  no toca ninguna otra, pero lo correcto es no crearlas.
- La escala real no importa (el juego reescala a la longitud de `WeaponDesigns[id].len`), pero trabaja en
  metros reales para que los grosores mínimos tengan sentido.
- Nombre del archivo = id de la tabla `game/items/weapon_designs.gd`. Arma nueva = fila nueva ahí
  (nombre, tipo, grado, taller, longitud, velocidad, DPS, coste). Sin fila no hay receta ni modelo en la mano.

## 4. Lista de revisión de la hoja de contacto

Para cada arma, de un vistazo:

- [ ] ¿Se reconoce el tipo de arma solo por la silueta, en pequeño?
- [ ] ¿El asta o el mango es recto y del grosor de los demás?
- [ ] ¿Hay algo flotando, atravesado o colgando que no debería?
- [ ] ¿El borde de la hoja es limpio? (dientes irregulares = deformación mal aplicada, no "detalle")
- [ ] ¿Los colores son de la paleta? ¿Algún color chillón o pastel?
- [ ] ¿Se distingue de sus hermanas de tipo por la forma y no solo por el color?
- [ ] ¿La cabeza del arma tiene tamaño suficiente respecto al asta? (se tiende a hacerla pequeña)

## 5. Dos formas de construir, y cuándo usar cada una

**A. Desde cero con `forge_lib.py`** (lanzas y bastones actuales, `forge_polearms_staves.py`). Úsala cuando la
forma sea geométrica: astas, puntas, cabezas, gemas. Piezas disponibles:

| Pieza | Para qué |
|---|---|
| `cyl(z0, z1, r0, r1, mat)` | astas, casquillos, anillos, regatones, braseros |
| `plate(contorno, grosor, mat, bevel, mirror)` | cualquier hoja: se dibuja el contorno 2D y sale la placa biselada |
| `gem(centro, r, mat)` / `crystal(base, r, h, mat)` | gemas facetadas y cristales |
| `wrap(z0, z1, r, mat, bandas)` | vendas de cuero o tela |
| `box(...)` | cabezas de martillo, bloques |
| `export(grip_z)` | guarda el `.glb` con el origen en el agarre |

La hoja se diseña como **contorno**: lista de puntos `(x, z)` en sentido antihorario; con `mirror=True` se da
solo la mitad derecha de abajo arriba. Así el borde sale limpio siempre. Dibuja primero el contorno en papel
(o en comentarios) con 5-15 puntos; más puntos no lo mejoran.

**B. Editando un modelo del pack** (espadas, hachas, mazas, dagas, arcos; `make_swords.py`, `make_weapons.py`).
Úsala cuando el pack ya tiene la base. Reglas:

- Mueve y escala **grupos enteros de vértices** (toda la hoja, toda la guarda). Deformar vértice a vértice
  con una curva sobre una malla de pocos polígonos produce los dientes y escalones que se ven en
  `cuchillo_curvo` y `espada_alfanje`. Si necesitas una curva, primero añade cortes (loop cuts) a la hoja.
- Si añades una pieza, **comprueba que toca** a la malla (solapa 2-3 mm). Después pasa `finish_weapons.py`.
- Cambia colores creando materiales con nombre real. No reutilices "LightWood" para un azul.

## 6. Lo que se corrigió en esta revisión

| Problema encontrado | Dónde | Arreglo |
|---|---|---|
| Astas onduladas y muy finas, puntas diminutas | las 5 lanzas | rehechas con `forge_lib` |
| ~20 materiales por arma, arcoíris pastel | 4 bastones | rehechos: 4-6 materiales de paleta |
| Origen fuera de la malla | `lanza_caza` | origen en el agarre |
| Piezas flotantes | `garrote_clavos`, `maza_estrellada`, `punal_ceremonial` | borradas por `finish_weapons.py` |
| Colores por encima de la saturación de la paleta | 21 armas | saturación limitada a 0.62 |
| Materiales con nombres heredados engañosos | 25 armas | renombrados por color real |
| Normales y vértices duplicados | 25 armas | soldados y recalculados |

## 7. Pendiente conocido (siguiente tanda)

- `maza_hierro`: queda una abrazadera dorada desplazada del mango (no es una isla suelta por caja; hay que
  moverla o borrarla a mano en `make_weapons.py`).
- `cuchillo_curvo`, `daga_veneno`, `espada_alfanje`, `espada_xifos`: filo con escalones por la deformación;
  rehacer la hoja con `plate()` conservando guarda y mango.
- `mazo_piedra`: las losas turquesa colgantes no leen como runas; cambiarlas por una runa incrustada en la cabeza.
- Cabezas de lanzas y bastones: funcionan pero son pequeñas respecto al asta; agrandarlas ~1.4×.
- Las armaduras (`tools/outfits/`) no se han auditado con este método: falta una hoja de contacto equivalente.
