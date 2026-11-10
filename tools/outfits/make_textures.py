"""Recolors the Quaternius Ranger/Peasant outfit atlases into class starter sets.
Run: blender -b -P tools/outfits/make_textures.py
Shading (value) is preserved; only hue/saturation of the cloth, leather and metal
regions is remapped, so quality matches the originals."""
import bpy, numpy as np, os
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "creator", "outfits")
D = os.path.normpath(D)

def load(name):
    im = bpy.data.images.load(os.path.join(D, name)); w, h = im.size
    a = np.empty(w * h * 4, np.float32); im.pixels.foreach_get(a)
    return a.reshape(h, w, 4)

def save(arr, name):
    h, w, _ = arr.shape
    im = bpy.data.images.new(name, w, h, alpha=True, float_buffer=False)
    im.colorspace_settings.name = 'sRGB'
    im.pixels.foreach_set(arr.reshape(-1)); im.filepath_raw = os.path.join(D, name); im.file_format = 'PNG'; im.save()

def rgb2hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1); mn = rgb.min(-1); d = mx - mn
    h = np.zeros_like(mx); nz = d > 1e-6
    rc = nz & (mx == r); gc = nz & (mx == g) & ~rc; bc = nz & ~rc & ~gc
    h[rc] = ((g - b)[rc] / d[rc]) % 6; h[gc] = (b - r)[gc] / d[gc] + 2; h[bc] = (r - g)[bc] / d[bc] + 4
    return h / 6.0, np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0), mx

def hsv2rgb(h, s, v):
    i = np.floor(h * 6).astype(int) % 6; f = h * 6 - np.floor(h * 6)
    p = v * (1 - s); q = v * (1 - f * s); t = v * (1 - (1 - f) * s)
    out = np.empty(h.shape + (3,), np.float32)
    for k, (r, g, b) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
        m = i == k; out[m, 0] = r[m]; out[m, 1] = g[m]; out[m, 2] = b[m]
    return out

def window(h, lo, hi, soft=0.03):
    return np.clip((h - lo) / soft + 1, 0, 1) * np.clip((hi - h) / soft + 1, 0, 1)

def srgb2lin(x): return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)
def lin2srgb(x): return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(np.maximum(x, 0), 1 / 2.4) - 0.055)

def regions_ranger(h, s, v):
    cloth = window(h, 0.17, 0.46) * np.clip((s - 0.15) / 0.1, 0, 1)
    leather = window(h, 0.0, 0.13, 0.02) * np.clip((s - 0.2) / 0.1, 0, 1) * (1 - cloth)
    metal = np.clip((0.25 - s) / 0.1, 0, 1) * np.clip((v - 0.4) / 0.15, 0, 1)
    return cloth, leather, metal

def recolor_ranger(src, cloth_h, cloth_s, cloth_v, leather_h, leather_s, leather_v, metal_tint, metal_v, lift=0.0):
    rgb = lin2srgb(src[..., :3]) if False else src[..., :3]  # blender gives linear floats for sRGB images
    h, s, v = rgb2hsv(rgb)
    cw, lw, mw = regions_ranger(h, s, v)
    nh = h.copy(); ns = s.copy(); nv = v.copy()
    nh = np.where(cw > 0, cloth_h, nh); ns = ns * (1 - cw) + np.clip(s * cloth_s, 0, 1) * cw; nv = nv * (1 - cw) + (v * cloth_v + lift * np.maximum(0.0, 0.45 - v)) * cw
    if leather_h is not None: nh = np.where(lw > 0.5, leather_h, nh)
    ns = ns * (1 - lw) + np.clip(s * leather_s, 0, 1) * lw; nv = nv * (1 - lw) + v * leather_v * lw
    out = hsv2rgb(nh % 1.0, np.clip(ns, 0, 1), np.clip(nv, 0, 1))
    mt = np.array(metal_tint, np.float32)
    out = out * (1 - mw[..., None]) + (out * mt * metal_v) * mw[..., None]
    res = src.copy(); res[..., :3] = np.clip(out, 0, 1)
    return res

def recolor_peasant_blue(src):
    """Mage palette: slate periwinkle tunic, deep indigo-violet cloth (also used by the robe skirt),
    antique-gold leather. Shading is kept, only hue/sat/value are remapped."""
    rgb = src[..., :3]; h, s, v = rgb2hsv(rgb)
    light = np.clip((v - 0.30) / 0.15, 0, 1) * np.clip((0.55 - s) / 0.2, 0, 1)
    dark = np.clip((0.25 - v) / 0.1, 0, 1) * np.clip((s - 0.1) / 0.1, 0, 1)
    brown = window(h, 0.02, 0.14, 0.02) * np.clip((s - 0.35) / 0.1, 0, 1) * np.clip((0.55 - v) / 0.1, 0, 1) * (1 - dark) * (1 - light)
    nh, ns, nv = h.copy(), s.copy(), v.copy()
    # light cloth -> slate periwinkle (muted, a touch violet)
    nh = np.where(light > 0, 0.635, nh); ns = ns * (1 - light) + np.clip(0.18 + s * 0.65, 0, 0.5) * light; nv = nv * (1 - light * 0.1)
    # dark cloth -> rich indigo-violet, lifted so the folds read
    nh = np.where(dark > 0.5, 0.715, nh); ns = ns * (1 - dark) + np.clip(0.28 + s * 0.7, 0, 0.62) * dark; nv = nv * (1 - dark) + np.clip(v * 1.9 + 0.1, 0, 0.5) * dark
    # brown leather -> antique gold
    nh = np.where(brown > 0.5, 0.115, nh); ns = ns * (1 - brown) + np.clip(s * 0.85, 0, 1) * brown; nv = nv * (1 - brown) + np.clip(v * 1.15, 0, 1) * brown
    out = hsv2rgb(nh % 1.0, np.clip(ns, 0, 1), np.clip(nv, 0, 1))
    res = src.copy(); res[..., :3] = out
    return res

if __name__ == "__main__":
    rg = load("T_Ranger_BaseColor.png"); ps = load("T_Peasant_BaseColor.png")
    #            cloth h   s    v     leather h  s    v     metal tint            metal v
    save(recolor_ranger(rg, 0.995, 1.0, 1.25, None, 0.9, 0.78, (1.0, 1.0, 1.05), 1.0), "T_Ranger_BaseColor_warrior.png")
    save(recolor_ranger(rg, 0.62, 0.15, 0.75, None, 0.55, 0.55, (0.8, 0.82, 0.9), 0.75), "T_Ranger_BaseColor_rogue.png")
    save(recolor_ranger(rg, 0.10, 0.55, 1.1, None, 0.75, 1.1, (1.0, 0.95, 0.85), 1.0), "T_Ranger_BaseColor_archer.png")
    save(recolor_ranger(rg, 0.715, 0.62, 0.95, 0.105, 0.75, 1.2, (1.0, 0.9, 0.55), 1.0), "T_Ranger_BaseColor_mage.png")
    save(recolor_peasant_blue(ps), "T_Peasant_BaseColor_mage.png")
    print("textures done")
