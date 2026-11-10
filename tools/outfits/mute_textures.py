"""Baja la saturación de las texturas de un grupo de sets para acercarlas a la paleta apagada de Quaternius.

  blender -b --factory-startup --python tools/outfits/mute_textures.py -- <prefijo> [sat_max=0.50] [valor=0.90]

Ejemplo: `-- mg` procesa assets/models/creator/outfits/T_*_BaseColor_mg_*.png.
Solo toca los píxeles cuya saturación supera `sat_max` (la tela teñida); cuero, metal y piel quedan igual.
Idempotente: pasarlo dos veces no cambia nada más. Para regenerar desde cero, vuelve a correr el
make_<clase>_textures.py correspondiente y después este script.
"""
import bpy, sys, os, glob
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIR = os.path.join(ROOT, "assets", "models", "creator", "outfits")

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
prefix = args[0] if args else "mg"
sat_max = float(args[1]) if len(args) > 1 else 0.50
value = float(args[2]) if len(args) > 2 else 0.90

for path in sorted(glob.glob(os.path.join(DIR, "T_*_BaseColor_%s_*.png" % prefix))):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    rgb = px[:, :3]
    mx = rgb.max(axis=1)
    mn = rgb.min(axis=1)
    sat = np.where(mx > 1e-5, (mx - mn) / np.maximum(mx, 1e-5), 0.0)
    over = sat > sat_max
    # Reducir saturación a sat_max: acercar cada canal al máximo (conserva el tono) y oscurecer un poco.
    k = np.where(over, sat_max / np.maximum(sat, 1e-5), 1.0)[:, None]
    muted = mx[:, None] - (mx[:, None] - rgb) * k
    muted = np.where(over[:, None], muted * value, rgb)
    px[:, :3] = muted
    img.pixels.foreach_set(px.reshape(-1))
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    print("OK %s  píxeles ajustados: %.0f%%" % (os.path.basename(path), 100.0 * over.mean()))
    bpy.data.images.remove(img)
