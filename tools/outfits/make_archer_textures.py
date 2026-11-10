"""Archer set palettes: recolors of the Quaternius Ranger atlas (the natural archer base), saved at 2048.
Run: blender -b -P tools/outfits/make_archer_textures.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_textures as M
import make_rogue_textures as R

if __name__ == "__main__":
    rg = M.load("T_Ranger_BaseColor.png")
    #            cloth h s v       leather h s v        metal tint        mv
    sets = {
        "montero":      (0.30, 0.52, 0.62, 0.07, 0.70, 0.85, (0.9, 0.95, 0.8), 0.9),    # forest green
        "llanura":      (0.12, 0.42, 1.00, 0.09, 0.60, 1.10, (1.0, 0.95, 0.8), 1.0),    # khaki
        "guardabosques": (0.40, 0.55, 0.55, 0.08, 0.50, 0.55, (0.8, 0.9, 0.85), 0.8),   # dark moss
        "centinela":    (0.58, 0.28, 0.78, 0.08, 0.35, 0.65, (0.85, 0.9, 1.0), 1.0),    # slate blue
        "dunas":        (0.06, 0.72, 0.95, 0.10, 0.55, 1.10, (1.0, 0.85, 0.6), 0.95),   # rust and sand
    }
    for k, a in sets.items():
        M.save(R.half(M.recolor_ranger(rg, *a, lift=0.55)), f"T_Ranger_BaseColor_ar_{k}.png")
    print("archer textures done")
