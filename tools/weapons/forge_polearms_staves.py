"""Lanzas y bastones rehechos desde cero con forge_lib (los anteriores no seguían el estilo: astas onduladas
y finas, puntas diminutas, bastones con ~20 materiales en arcoíris pastel, la lanza de caza con el origen
fuera de la malla).

  blender -b --factory-startup --python tools/weapons/forge_polearms_staves.py [-- solo_un_id]

Medidas en metros a escala real (el juego reescala por longitud). Origen = punto de agarre.
"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from forge_lib import Weapon

SHAFT = 0.022  # radio del asta de una lanza (grueso a propósito: se tiene que ver desde la cámara del juego)


def shaft(w, length, r=SHAFT, mat="wood", butt="steel"):
    w.cyl(0.06, length, r, r * 0.92, mat)
    w.cyl(0.0, 0.07, r * 0.5, r * 1.25, butt)  # regatón


def lanza_caza():
    w = Weapon("lanza_caza")
    shaft(w, 1.62, mat="wood_pale", butt="wood_dark")
    # punta de piedra tallada, ancha y corta, atada con cuero
    w.plate([(0, 1.56), (0.035, 1.60), (0.062, 1.70), (0.045, 1.84), (0, 1.97)], 0.03, "stone", bevel=0.011, mirror=True)
    w.wrap(1.52, 1.66, SHAFT * 1.5, "leather", 3)
    w.wrap(0.62, 0.86, SHAFT * 1.25, "leather", 4)
    w.cyl(1.47, 1.50, SHAFT * 1.7, SHAFT * 1.7, "bone")
    w.export(0.74)


def lanza_bronce():
    w = Weapon("lanza_bronce")
    shaft(w, 1.60, butt="bronze")
    w.cyl(1.52, 1.68, SHAFT * 1.5, SHAFT * 1.15, "bronze")  # cubo
    w.cyl(1.50, 1.53, SHAFT * 1.9, SHAFT * 1.9, "bronze")
    # hoja de laurel
    w.plate([(0, 1.66), (0.03, 1.70), (0.07, 1.80), (0.055, 1.93), (0, 2.08)], 0.026, "bronze", bevel=0.010, mirror=True)
    w.wrap(0.66, 0.90, SHAFT * 1.25, "cloth_red", 4)
    w.export(0.78)


def pica_soldado():
    w = Weapon("pica_soldado")
    shaft(w, 1.86, mat="wood_dark")
    w.cyl(1.78, 1.92, SHAFT * 1.5, SHAFT * 1.1, "steel")
    # punta larga de cuatro filos + topes laterales
    w.plate([(0, 1.90), (0.028, 1.95), (0.036, 2.02), (0, 2.34)], 0.03, "steel", bevel=0.010, mirror=True)
    w.plate([(0.0, 1.84), (0.10, 1.87), (0.115, 1.90), (0.0, 1.905)], 0.022, "steel", bevel=0.007, mirror=True)
    # banderín
    w.plate([(0.02, 1.74), (0.20, 1.70), (0.13, 1.655), (0.21, 1.60), (0.02, 1.62)], 0.012, "cloth_red")
    w.wrap(0.70, 0.94, SHAFT * 1.25, "leather", 4)
    w.export(0.82)


def tridente():
    w = Weapon("tridente")
    shaft(w, 1.58, mat="wood_dark", butt="iron")
    w.cyl(1.50, 1.66, SHAFT * 1.6, SHAFT * 1.3, "steel")
    # tres púas con lengüeta en una sola placa
    half = [(0, 1.62), (0.045, 1.64), (0.115, 1.72), (0.13, 1.80), (0.125, 1.98), (0.15, 1.96), (0.105, 2.08),
            (0.085, 1.82), (0.06, 1.76), (0.03, 1.76), (0.03, 2.00), (0.05, 1.99), (0, 2.14)]
    w.plate(half, 0.03, "steel", bevel=0.009, mirror=True)
    w.wrap(0.64, 0.88, SHAFT * 1.25, "cloth_blue", 4)
    w.export(0.76)


def alabarda():
    w = Weapon("alabarda")
    shaft(w, 1.72, mat="wood_dark", butt="iron")
    w.cyl(1.52, 1.80, SHAFT * 1.5, SHAFT * 1.3, "iron")
    # hoja de hacha (derecha), gancho (izquierda) y pica superior: contorno único, antihorario
    outline = [(0.0, 1.56), (0.07, 1.57), (0.20, 1.50), (0.245, 1.62), (0.25, 1.74), (0.20, 1.88), (0.07, 1.79),
               (0.03, 1.82), (0.035, 1.90), (0.0, 2.16), (-0.035, 1.90), (-0.03, 1.82),
               (-0.10, 1.80), (-0.17, 1.70), (-0.12, 1.72), (-0.07, 1.66), (-0.03, 1.60)]
    w.plate(outline, 0.03, "steel", bevel=0.010)
    w.wrap(0.68, 0.94, SHAFT * 1.25, "leather", 4)
    w.cyl(1.44, 1.47, SHAFT * 1.9, SHAFT * 1.9, "iron")
    w.export(0.80)


STAFF = 0.026  # radio del asta de un bastón


def staff_shaft(w, length, mat="wood", r=STAFF):
    w.cyl(0.05, length, r * 0.9, r, mat)
    w.cyl(0.0, 0.06, r * 0.45, r * 1.1, "bronze")


def vara_arcana():
    w = Weapon("vara_arcana")
    staff_shaft(w, 1.02, "wood")
    w.wrap(0.34, 0.52, STAFF * 1.2, "leather", 3)
    w.cyl(1.00, 1.05, STAFF * 1.5, STAFF * 1.9, "bronze")
    for k in range(3):  # tres garras que sujetan la gema
        w.cyl(1.04, 1.15, 0.009, 0.006, "bronze", 5, tilt=("XYZ"[0] if k == 0 else ("Y" if k == 1 else "X"), [28, -28, -28][k]), x=[0, 0.02, 0][k], y=[-0.02, 0, 0.02][k])
    w.gem((0, 0, 1.13), 0.055, "gem_arcane", 1.15)
    w.export(0.42)


def cayado_cristal():
    w = Weapon("cayado_cristal")
    staff_shaft(w, 1.34, "wood_pale")
    w.wrap(0.52, 0.76, STAFF * 1.2, "cloth_blue", 4)
    w.cyl(1.30, 1.37, STAFF * 1.4, STAFF * 2.3, "bronze")
    w.cyl(1.37, 1.40, STAFF * 2.3, STAFF * 2.3, "bronze")
    w.crystal((0, 0, 1.47), 0.055, 0.34, "gem_ice", 6)
    w.crystal((0.055, 0, 1.44), 0.034, 0.20, "gem_arcane", 5, tilt=("Y", 24))
    w.crystal((-0.05, 0.02, 1.43), 0.030, 0.17, "gem_arcane", 5, tilt=("Y", -26))
    w.export(0.62)


def baston_roble():
    w = Weapon("baston_roble")
    staff_shaft(w, 1.30, "wood_dark", STAFF * 1.15)
    w.wrap(0.50, 0.70, STAFF * 1.4, "leather", 3)
    # cabeza nudosa: el tronco se ensancha y tres raíces abrazan una gema verde
    w.cyl(1.28, 1.40, STAFF * 1.15, STAFF * 2.1, "wood_dark", 7)
    w.gem((0, 0, 1.49), 0.07, "gem_nature", 1.0)
    for ang, ax in ((30, "Y"), (-30, "Y"), (30, "X")):
        off = 0.062
        w.cyl(1.38, 1.60, 0.02, 0.008, "wood", 5, tilt=(ax, -ang * 0.55),
              x=(off if (ax == "Y" and ang > 0) else (-off if ax == "Y" else 0)), y=(-off if ax == "X" else 0))
    w.cyl(1.16, 1.19, STAFF * 1.7, STAFF * 1.7, "bronze")
    w.export(0.60)


def baston_fuego():
    w = Weapon("baston_fuego")
    staff_shaft(w, 1.30, "wood_dark")
    w.wrap(0.50, 0.74, STAFF * 1.2, "cloth_red", 4)
    w.cyl(1.22, 1.25, STAFF * 1.7, STAFF * 1.7, "iron")
    # brasero de hierro con corona y llama tallada
    w.cyl(1.28, 1.40, STAFF * 1.3, STAFF * 3.0, "iron", 8)
    w.cyl(1.40, 1.43, STAFF * 3.2, STAFF * 3.2, "gold", 8)
    w.crystal((0, 0, 1.47), 0.058, 0.30, "gem_fire", 5)
    w.crystal((0.045, 0.0, 1.45), 0.032, 0.19, "gem_fire", 4, tilt=("Y", 22))
    w.crystal((-0.04, 0.02, 1.45), 0.030, 0.16, "gem_fire", 4, tilt=("Y", -24))
    w.export(0.62)


def baston_hielo():
    w = Weapon("baston_hielo")
    staff_shaft(w, 1.30, "wood_pale")
    w.wrap(0.50, 0.74, STAFF * 1.2, "cloth_blue", 4)
    w.cyl(1.22, 1.25, STAFF * 1.7, STAFF * 1.7, "steel")
    w.cyl(1.28, 1.36, STAFF * 1.3, STAFF * 2.4, "steel", 6)
    # abanico de esquirlas de hielo
    w.crystal((0, 0, 1.44), 0.05, 0.40, "gem_ice", 4)
    w.crystal((0.06, 0, 1.42), 0.036, 0.27, "gem_ice", 4, tilt=("Y", 30))
    w.crystal((-0.06, 0, 1.42), 0.036, 0.27, "gem_ice", 4, tilt=("Y", -30))
    w.crystal((0.0, 0.05, 1.41), 0.028, 0.18, "gem_ice", 4, tilt=("X", -30))
    w.export(0.62)


ALL = [lanza_caza, lanza_bronce, pica_soldado, tridente, alabarda, vara_arcana, cayado_cristal, baston_roble, baston_fuego, baston_hielo]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for build in ALL:
        if not only or build.__name__ in only:
            build()
