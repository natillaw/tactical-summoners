"""Mage set palettes: recolors of the Quaternius Peasant (robe, tunic, boots) and Ranger (hood, sleeves) atlases, saved at 2048.
Run: blender -b -P tools/outfits/make_mage_textures.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_textures as M
import make_rogue_textures as R

if __name__ == "__main__":
    rg = M.load("T_Ranger_BaseColor.png"); ps = M.load("T_Peasant_BaseColor.png")
    #   id        ranger: cloth h s v      leather h s v          metal tint        mv    peasant: light (h s v)   dark (h s)    leather v
    sets = {
        "aprendiz": ((0.66, 0.40, 0.85, 0.11, 0.70, 1.05, (1.0, 0.9, 0.6), 0.9), (0.64, 0.30, 1.0), (0.68, 0.45), 1.05),    # lavender tunic, indigo robe
        "brasa":    ((0.02, 0.75, 0.85, 0.07, 0.70, 0.70, (1.0, 0.85, 0.6), 0.9), (0.03, 0.62, 0.85), (0.01, 0.70), 0.75),   # cream-orange tunic, ember-red robe
        "escarcha": ((0.56, 0.30, 1.00, 0.60, 0.12, 0.90, (0.85, 0.9, 1.0), 1.0), (0.55, 0.25, 1.15), (0.58, 0.45), 1.0),    # ice tunic, steel-blue robe
        "sabio":    ((0.78, 0.45, 0.75, 0.09, 0.60, 0.70, (1.0, 0.85, 0.5), 0.9), (0.78, 0.30, 1.0), (0.76, 0.58), 0.8),     # lilac tunic, deep violet robe
        "osario":   ((0.75, 0.25, 0.40, 0.75, 0.30, 0.38, (0.8, 0.8, 0.9), 0.7), (0.12, 0.10, 0.80), (0.75, 0.35), 0.5),     # bone-grey tunic, black-violet robe
    }
    for k, (r, pl, pd, lv) in sets.items():
        M.save(R.half(M.recolor_ranger(rg, *r)), f"T_Ranger_BaseColor_mg_{k}.png")
        M.save(R.half(R.peasant(ps, pl, pd, lv, 2.2)), f"T_Peasant_BaseColor_mg_{k}.png")
    print("mage textures done")
