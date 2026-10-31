# Assets (en esta carpeta assets/; NO abras PNGs: la metadata está en los .json)
- tiles/: bosque_tiles.png (16 px), bosque_props.png, bosque_tileset.json (bloques, variantes y prop.* con rect/origin), build_forest_tileset.gd (EditorScript; ajusta rutas).
- tpf_bandidos/: Sprite/<Capa>/*.png (576×384, celdas 48×48, igual que el pack) + presets/bandidos_presets.json (orden_capas + preset por enemigo; orig: = pack original, new: = esta carpeta) + jefe_baron_carmesi_x2.png (celdas 96).
- campamento/: props_campamento.png, prop_fogata_anim.png (4×16×18, 8 fps), campamento.json (rect/origin).
- fx/: fx_*.png (tiras horizontales) + fx.json (frame_size, frames). Incluye escudo_altar 4×48×48.

# G. Mapas de bosque
- TileSet: terrain set Match Corners (0 pasto, 1 tierra, 2 agua). Índice en bloque = TL·1+TR·2+BL·4+BR·8. No hay transición tierra↔agua: deja ≥1 tile de pasto entre ellas.
- Composición: bordes orgánicos; 3–4 variantes de pasto con prob. baja; decoración en clusters; bosque denso e irregular con Y-sort y suelo oscurecido debajo; sombra elíptica bajo todo; CanvasModulate cálido y algo desaturado; punto focal táctico por mapa (círculo de menhires + altar en p10); 2–3 zonas por piso; semillas reproducibles.

# H. Bandidos (Tiny Pixel Fantasy)
- Todo humano se compone con el compositor de héroes. Capas nuevas: Accesorio y Mascara. Orden en bandidos_presets.json → orden_capas.
- Ropa de bandido: un solo tono pardo ceniza (prefijo b_). Marca: pañuelo rojo (capitán: parche). Se distinguen por silueta y arma.
- maton: básico, garrote, lento y pegador · arquero: artillero, huye si lo alcanzan · degollador: asesino, daga, va a la backline · bruto: tanque, casco · mago: área de fuego, frágil · chaman: sanador · capitan_bandido: miniboss p5 · jefe_baron_carmesi: jefe p10, ×2 de tamaño (usa la hoja x2 o escala ×2; elige y documenta), hitbox acorde.
- Enemigos como datos (preset, stats, rol, IA, drops de A).

# I. Campamento
Campamentos bandidos con los props dentro de los mapas (sirven de cobertura); fogata animada; jaula para la misión de rescate.
