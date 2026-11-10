"""Rogue set palettes: recolors of the Quaternius Ranger / Peasant atlases (same method as make_textures.py), saved at 2048.
Run: blender -b -P tools/outfits/make_rogue_textures.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import make_textures as M


def half(a):   # 4096 -> 2048 (2x2 block mean): the new atlases stay light; the top-down camera never needs 4k
    h, w, c = a.shape
    return a.reshape(h // 2, 2, w // 2, 2, c).mean(axis=(1, 3))


def peasant(src, light, dark, leather_v=1.0):
    """light cloth -> light=(h, s, v-mul); dark cloth -> dark=(h, s); leather keeps hue, value*leather_v."""
    h, s, v = M.rgb2hsv(src[..., :3])
    lt = np.clip((v - 0.30) / 0.15, 0, 1) * np.clip((0.55 - s) / 0.2, 0, 1)
    dk = np.clip((0.25 - v) / 0.1, 0, 1) * np.clip((s - 0.1) / 0.1, 0, 1)
    nh, ns, nv = h.copy(), s.copy(), v.copy()
    nh = np.where(lt > 0, light[0], nh); ns = ns * (1 - lt) + np.clip(light[1] + s * 0.4, 0, 0.85) * lt; nv = nv * (1 - lt) + v * light[2] * lt
    nh = np.where(dk > 0.5, dark[0], nh); ns = ns * (1 - dk) + np.clip(dark[1] + s * 0.5, 0, 0.8) * dk
    lw = (1 - lt) * (1 - dk); nv = nv * (1 - lw) + v * leather_v * lw
    out = src.copy(); out[..., :3] = np.clip(M.hsv2rgb(nh % 1.0, np.clip(ns, 0, 1), np.clip(nv, 0, 1)), 0, 1)
    return out


if __name__ == "__main__":
    rg = M.load("T_Ranger_BaseColor.png"); ps = M.load("T_Peasant_BaseColor.png")
    #                      cloth h  s     v     leather h s    v     metal tint           metal v
    sets = {
        "ladron":   (0.60, 0.20, 0.60, 0.07, 0.55, 0.50, (0.8, 0.82, 0.9), 0.7),     # slate-blue street thief
        "cuervo":   (0.74, 0.28, 0.36, 0.75, 0.30, 0.34, (0.7, 0.72, 0.85), 0.6),    # near-black violet
        "desierto": (0.11, 0.48, 1.05, None, 0.70, 1.15, (1.0, 0.92, 0.7), 0.95),    # sand and ochre
        "bosque":   (0.30, 0.72, 0.82, 0.13, 0.65, 0.68, (0.9, 0.95, 0.8), 0.9),     # woodland green
        "carmesi":  (0.00, 0.72, 0.78, 0.02, 0.75, 0.52, (1.0, 0.85, 0.8), 0.85),    # dark crimson
    }
    for k, a in sets.items():
        M.save(half(M.recolor_ranger(rg, *a)), f"T_Ranger_BaseColor_rg_{k}.png")
    M.save(half(peasant(ps, (0.11, 0.30, 1.0), (0.09, 0.30), 1.0)), "T_Peasant_BaseColor_rg_desierto.png")
    M.save(half(peasant(ps, (0.0, 0.55, 0.62), (0.98, 0.5), 0.7)), "T_Peasant_BaseColor_rg_carmesi.png")
    print("rogue textures done")
