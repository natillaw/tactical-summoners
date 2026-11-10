"""Axes, maces, daggers, spears, bows and staves with their own designs, edited from the Quaternius / KayKit models already in the game
(assets/models/weapons/*.fbx): reshaped parts, added pieces and a new palette. 5 designs per type.
    blender -b -P tools/weapons/make_weapons.py [-- type1 type2 ...]      (axe mace dagger spear bow staff)
Output: assets/models/weapons/custom/<id>.glb  (long axis +Y, same origin convention as the base model)."""
import sys, math, os, colorsys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, Matrix
import make_swords as S

V = Vector


def rgb(h, s, v):
    return colorsys.hsv_to_rgb(h, s, v)


def sphere(bm, c, r, mi, sub=2, squash=1.0):
    res = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r, matrix=Matrix.Translation(c) @ Matrix.Diagonal((1, 1, squash, 1)))
    for v in res["verts"]:
        for f in v.link_faces: f.material_index = mi


def ring(bm, c, r, depth, mi, seg=10):
    S.add_cone(bm, (c[0], c[1], c[2] - depth / 2), (0, 0, 1), r, r, depth, mi, seg)


def pm(ob, name, color, metal=0.0, rough=0.85):
    return S.mat_color(ob, name, color, metal, rough)


def scale_verts(ob, vset, sx=1.0, sy=1.0, sz=1.0, about=(0.0, 0.0, 0.0)):
    a = V(about)
    S.edit_verts(ob, vset, lambda v: V((a.x + (v.x - a.x) * sx, a.y + (v.y - a.y) * sy, a.z + (v.z - a.z) * sz)))


def all_verts(ob):
    return set(range(len(ob.data.vertices)))


def bend_blade(ob, vset, z0, length, curve, widen=0.0):
    def fn(v):
        t = max(0.0, (v.z - z0) / length)
        return V((v.x * (1.0 + widen * math.sin(min(1.0, t) * math.pi * 0.6)) + curve * t * t, v.y, v.z))
    S.edit_verts(ob, vset, fn)


def teeth(bm, z0, z1, n, x_edge, x_out, mi, y=0.026, both=True):
    step = (z1 - z0) / n
    for k in range(n):
        z = z0 + k * step
        for side in ((-1, 1) if both else (1,)):
            S.add_prism(bm, [(side * x_edge, z), (side * (x_out - 0.012 * k), z + 0.33 * step), (side * x_edge, z + 0.9 * step)][::side], -y, y, mi)


def finish(ob, name):
    S.finish(ob, name)


STEELS = lambda a, b, c: {"Steel": (a, 0.5, 0.5), "LightSteel": (b, 0.5, 0.45), "DarkSteel": (c, 0.45, 0.55)}


# =============================================================== AXES
def axes():
    wood = {"LightWood": ((0.38, 0.24, 0.13), 0.0, 0.85), "DarkWood": ((0.24, 0.14, 0.08), 0.0, 0.9)}
    # 1 hachuela de leñador
    ob = S.load("axe_small"); S.paint(ob, {**STEELS((0.42, 0.44, 0.47), (0.56, 0.58, 0.62), (0.3, 0.3, 0.3)), **wood}); finish(ob, "hacha_lenador")
    # 2 hacha de hierro: broad head, back spike, red wraps
    ob = S.load("axe"); head = S.verts_of(ob, {"Steel", "LightSteel"})
    scale_verts(ob, {i for i in head if ob.data.vertices[i].co.x > 0.3}, 1.3, 1.0, 1.12, (0.3, 0, 2.2))
    bm = S.bm_open(ob); mi = pm(ob, "Steel", (0.4, 0.42, 0.45), 0.5, 0.5); mw = pm(ob, "Wrap", (0.5, 0.08, 0.06))
    S.add_cone(bm, (-0.12, 0, 2.35), (-1, 0, 0.05), 0.11, 0.015, 0.6, mi, 6)
    for z in (-0.2, -0.65, -1.1): ring(bm, (0.05, 0, z), 0.17, 0.13, mw)
    S.bm_close(ob, bm); S.paint(ob, {**STEELS((0.4, 0.42, 0.45), (0.56, 0.58, 0.62), (0.3, 0.3, 0.3)), **wood}); finish(ob, "hacha_hierro")
    # 3 hacha doble de bronce
    ob = S.load("axe_double"); head = S.verts_of(ob, {"Steel", "LightSteel"})
    scale_verts(ob, head, 0.92, 1.0, 0.92, (0.6, 0, 1.9))
    bm = S.bm_open(ob); mg = pm(ob, "Gold", (0.85, 0.66, 0.2), 0.6, 0.4)
    ring(bm, (0.62, 0, 1.55), 0.19, 0.16, mg, 8); ring(bm, (0.62, 0, 0.75), 0.17, 0.12, mg, 8)
    S.bm_close(ob, bm); S.paint(ob, {**STEELS((0.58, 0.37, 0.17), (0.78, 0.55, 0.26), (0.45, 0.3, 0.14)), "LightWood": ((0.3, 0.18, 0.1), 0, 0.85), "DarkWood": ((0.2, 0.12, 0.07), 0, 0.9)}); finish(ob, "hacha_doble_bronce")
    # 4 tomahawk: slim head, feather and beads
    ob = S.load("axe_small"); head = S.verts_of(ob, {"Steel", "LightSteel"})
    scale_verts(ob, head, 0.78, 1.0, 0.82, (0.1, 0, 0.9))
    bm = S.bm_open(ob); mf = pm(ob, "Feather", (0.8, 0.78, 0.7)); mr = pm(ob, "Wrap", (0.55, 0.2, 0.1))
    S.add_cone(bm, (0.0, 0.12, -0.9), (0.05, 0.1, -1), 0.07, 0.012, 0.85, mf, 5)
    for z in (-0.2, -0.45, -0.7): ring(bm, (0.0, 0, z), 0.15, 0.1, mr, 8)
    S.bm_close(ob, bm); S.paint(ob, {**STEELS((0.5, 0.5, 0.52), (0.64, 0.64, 0.66), (0.3, 0.3, 0.3)), "LightWood": ((0.55, 0.4, 0.22), 0, 0.85), "DarkWood": ((0.38, 0.26, 0.14), 0, 0.9)}); finish(ob, "tomahawk")
    # 5 hacha del verdugo: big dropped blade, near black
    ob = S.load("axe"); head = S.verts_of(ob, {"Steel", "LightSteel"})
    S.edit_verts(ob, head, lambda v: V((v.x * 1.25 if v.x > 0.2 else v.x, v.y, 3.5 - (3.5 - v.z) * 1.4)))
    bm = S.bm_open(ob); mr = pm(ob, "Wrap", (0.45, 0.04, 0.05)); mi = pm(ob, "Steel", (0.18, 0.17, 0.19), 0.5, 0.45)
    for z in (-0.3, -0.8): ring(bm, (0.05, 0, z), 0.17, 0.14, mr)
    S.add_cone(bm, (0.0, 0, 3.5), (0, 0, 1), 0.1, 0.01, 0.45, mi, 6)
    S.bm_close(ob, bm); S.paint(ob, {**STEELS((0.18, 0.17, 0.19), (0.5, 0.1, 0.1), (0.25, 0.24, 0.25)), "LightWood": ((0.14, 0.11, 0.1), 0, 0.9), "DarkWood": ((0.09, 0.07, 0.07), 0, 0.9)}); finish(ob, "hacha_verdugo")


# =============================================================== MACES
def maces():
    # 1 garrote de clavos: wooden club studded with iron
    ob = S.load("hammer_small"); S.paint(ob, {"Steel": ((0.34, 0.21, 0.11), 0.0, 0.85), "LightSteel": ((0.45, 0.3, 0.16), 0.0, 0.85), "LightWood": ((0.3, 0.19, 0.1), 0, 0.85), "DarkWood": ((0.2, 0.12, 0.07), 0, 0.9)})
    bm = S.bm_open(ob); mi = pm(ob, "Iron", (0.4, 0.4, 0.43), 0.6, 0.5)
    for k in range(10):
        a = k * 2.4; r = 0.42
        S.add_cone(bm, (0.38 + math.cos(a) * 0.3, math.sin(a) * 0.38, 2.0 + 0.1 * (k % 4) * 0.8), (math.cos(a), math.sin(a), 0.1), 0.07, 0.01, 0.28, mi, 5)
    S.bm_close(ob, bm); finish(ob, "garrote_clavos")
    # 2 maza de hierro con banda dorada
    ob = S.load("hammer_small"); S.paint(ob, {**STEELS((0.3, 0.3, 0.33), (0.42, 0.43, 0.46), (0.25, 0.25, 0.27)), "LightWood": ((0.25, 0.16, 0.09), 0, 0.85), "DarkWood": ((0.16, 0.1, 0.06), 0, 0.9)})
    bm = S.bm_open(ob); mg = pm(ob, "Gold", (0.8, 0.62, 0.2), 0.6, 0.4)
    ring(bm, (0.38, 0, 1.55), 0.2, 0.1, mg, 8); ring(bm, (0.0, 0, 0.1), 0.15, 0.1, mg, 8)
    S.bm_close(ob, bm); finish(ob, "maza_hierro")
    # 3 martillo de guerra (bronce, compacto)
    ob = S.load("hammer_double"); scale_verts(ob, S.verts_of(ob, {"Steel", "LightSteel"}), 0.85, 0.9, 0.85, (0.0, 0, 2.3))
    S.paint(ob, {**STEELS((0.58, 0.37, 0.17), (0.78, 0.55, 0.26), (0.45, 0.3, 0.14)), "LightWood": ((0.5, 0.09, 0.07), 0, 0.9), "DarkWood": ((0.3, 0.06, 0.05), 0, 0.9)}); finish(ob, "martillo_guerra")
    # 4 maza estrellada: radial spikes
    ob = S.load("hammer_small"); S.paint(ob, {**STEELS((0.4, 0.42, 0.45), (0.56, 0.58, 0.62), (0.3, 0.3, 0.3)), "LightWood": ((0.33, 0.2, 0.11), 0, 0.85), "DarkWood": ((0.22, 0.13, 0.07), 0, 0.9)})
    bm = S.bm_open(ob); mi = pm(ob, "Steel", (0.4, 0.42, 0.45), 0.5, 0.5)
    for dirv in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0.7, 0.7, 0.3), (-0.7, 0.7, 0.3), (0.7, -0.7, 0.3), (-0.7, -0.7, 0.3)):
        d = V(dirv).normalized(); S.add_cone(bm, V((0.38, 0, 2.35)) + d * 0.45, d, 0.12, 0.012, 0.5, mi, 6)
    S.bm_close(ob, bm); finish(ob, "maza_estrellada")
    # 5 mazo de piedra con runas
    ob = S.load("hammer_double"); S.paint(ob, {**STEELS((0.5, 0.5, 0.47), (0.62, 0.62, 0.58), (0.4, 0.4, 0.38)), "LightWood": ((0.28, 0.2, 0.12), 0, 0.9), "DarkWood": ((0.18, 0.13, 0.08), 0, 0.9)})
    bm = S.bm_open(ob); mr = pm(ob, "Rune", (0.2, 0.7, 0.75), 0.0, 0.5)
    for x in (-0.75, 0.8):
        S.add_prism(bm, [(x - 0.12, 2.1), (x + 0.12, 2.1), (x + 0.12, 2.9), (x - 0.12, 2.9)], -0.4, 0.4, mr) if False else None
        S.add_box(bm, (x, 0.0, 2.35), (0.1, 0.42, 0.3), mr)
    S.bm_close(ob, bm); finish(ob, "mazo_piedra")


# =============================================================== DAGGERS
def daggers():
    # 1 daga de ladrón
    ob = S.load("dagger"); S.paint(ob, {**STEELS((0.3, 0.32, 0.35), (0.45, 0.47, 0.5), (0.2, 0.2, 0.22)), "LightWood": ((0.14, 0.1, 0.08), 0, 0.9), "DarkWood": ((0.09, 0.06, 0.05), 0, 0.9)}); finish(ob, "daga_ladron")
    # 2 cuchillo curvo
    ob = S.load("dagger"); bl = S.verts_of(ob, {"Steel", "LightSteel"}); bend_blade(ob, bl, 0.31, 1.7, 0.5, 0.5)
    S.paint(ob, {**STEELS((0.66, 0.68, 0.72), (0.82, 0.84, 0.88), (0.6, 0.45, 0.16)), "LightWood": ((0.4, 0.15, 0.1), 0, 0.9), "DarkWood": ((0.27, 0.09, 0.06), 0, 0.9)}); finish(ob, "cuchillo_curvo")
    # 3 daga de hueso con dientes
    ob = S.load("dagger_2"); bm = S.bm_open(ob); mi = pm(ob, "Bone2", (0.8, 0.76, 0.62), 0.0, 0.7)
    teeth(bm, 1.0, 2.2, 5, 0.15, 0.27, mi, 0.02)
    S.bm_close(ob, bm); S.paint(ob, {"Steel": ((0.88, 0.84, 0.7), 0.0, 0.7), "LightSteel": ((0.95, 0.92, 0.82), 0.0, 0.65), "Gold": ((0.5, 0.36, 0.22), 0.0, 0.8), "LightWood": ((0.3, 0.2, 0.12), 0, 0.9), "DarkWood": ((0.2, 0.13, 0.08), 0, 0.9)}); finish(ob, "daga_hueso")
    # 4 puñal ceremonial con gema
    ob = S.load("dagger_2"); bm = S.bm_open(ob); mgem = pm(ob, "Gem", (0.75, 0.05, 0.12), 0.2, 0.2)
    sphere(bm, (0, 0, -0.9), 0.17, mgem, 2); sphere(bm, (0, 0, 0.8), 0.1, mgem, 1)
    S.bm_close(ob, bm); S.paint(ob, {"Steel": ((0.82, 0.66, 0.24), 0.65, 0.4), "LightSteel": ((0.92, 0.8, 0.4), 0.65, 0.35), "Gold": ((0.85, 0.68, 0.22), 0.65, 0.4), "LightWood": ((0.4, 0.05, 0.08), 0, 0.85), "DarkWood": ((0.25, 0.03, 0.05), 0, 0.9)}); finish(ob, "punal_ceremonial")
    # 5 daga de veneno: green blade with a dark groove
    ob = S.load("dagger"); bm = S.bm_open(ob); mg = pm(ob, "Groove", (0.14, 0.3, 0.14), 0.3, 0.5)
    S.add_prism(bm, [(-0.035, 0.5), (0.035, 0.5), (0.035, 1.6), (0, 1.7), (-0.035, 1.6)], -0.04, 0.04, mg)
    S.bm_close(ob, bm); S.paint(ob, {"Steel": ((0.3, 0.56, 0.3), 0.4, 0.45), "LightSteel": ((0.45, 0.72, 0.42), 0.4, 0.4), "DarkSteel": ((0.2, 0.2, 0.2), 0.4, 0.55), "LightWood": ((0.12, 0.2, 0.1), 0, 0.9), "DarkWood": ((0.08, 0.13, 0.07), 0, 0.9)}); finish(ob, "daga_veneno")


# =============================================================== SPEARS
def spears():
    head_m = {"Steel", "LightSteel"}; shaft_m = {"DarkWood", "LightWood"}
    wood = {"LightWood": ((0.4, 0.27, 0.15), 0, 0.85), "DarkWood": ((0.26, 0.17, 0.09), 0, 0.9)}
    # 1 lanza de caza: shorter shaft
    ob = S.load("spear"); sh = S.verts_of(ob, shaft_m)
    S.edit_verts(ob, sh, lambda v: V((v.x, v.y, 5.65 - (5.65 - v.z) * 0.7 if v.z < 5.65 else v.z)))
    S.paint(ob, {**STEELS((0.42, 0.44, 0.47), (0.56, 0.58, 0.62), (0.3, 0.3, 0.3)), **wood}); finish(ob, "lanza_caza")
    # 2 pica de soldado: big head + red pennant
    ob = S.load("spear"); hd = S.verts_of(ob, head_m); scale_verts(ob, hd, 1.4, 1.4, 1.15, (0.0, 0, 5.65))
    bm = S.bm_open(ob); mr = pm(ob, "Flag", (0.6, 0.08, 0.07))
    S.add_prism(bm, [(0.1, 5.4), (0.95, 5.15), (0.75, 5.0), (0.95, 4.8), (0.1, 4.7)], -0.03, 0.03, mr)
    S.bm_close(ob, bm); S.paint(ob, {**STEELS((0.45, 0.47, 0.5), (0.6, 0.62, 0.66), (0.3, 0.3, 0.3)), **wood}); finish(ob, "pica_soldado")
    # 3 lanza de bronce: leaf head
    ob = S.load("spear"); hd = S.verts_of(ob, head_m)
    S.edit_verts(ob, hd, lambda v: V((v.x * (1.0 + 1.1 * math.sin(math.pi * min(1.0, (v.z - 5.65) / 1.9)) ** 1.1), v.y * 1.3, v.z)))
    bm = S.bm_open(ob); mg = pm(ob, "Gold", (0.85, 0.66, 0.2), 0.6, 0.4); ring(bm, (0, 0, 5.55), 0.2, 0.18, mg, 8)
    S.bm_close(ob, bm); S.paint(ob, {**STEELS((0.58, 0.37, 0.17), (0.78, 0.55, 0.26), (0.45, 0.3, 0.14)), **wood}); finish(ob, "lanza_bronce")
    # 4 tridente
    ob = S.load("spear"); bm = S.bm_open(ob); mi = pm(ob, "Steel", (0.45, 0.47, 0.5), 0.55, 0.45)
    S.add_box(bm, (0, 0, 5.62), (0.55, 0.07, 0.07), mi)
    for x in (-0.5, 0.5):
        S.add_cone(bm, (x, 0, 5.65), (0, 0, 1), 0.07, 0.012, 1.5, mi, 6)
    S.bm_close(ob, bm); S.paint(ob, {**STEELS((0.45, 0.47, 0.5), (0.6, 0.62, 0.66), (0.3, 0.3, 0.3)), "LightWood": ((0.25, 0.3, 0.32), 0, 0.85), "DarkWood": ((0.15, 0.2, 0.22), 0, 0.9)}); finish(ob, "tridente")
    # 5 alabarda: spear + axe blade
    ob = S.load("spear"); bm = S.bm_open(ob); mi = pm(ob, "Steel", (0.42, 0.44, 0.47), 0.5, 0.5)
    S.add_prism(bm, [(0.1, 5.9), (0.45, 5.95), (1.05, 5.55), (0.95, 4.95), (0.45, 4.9), (0.1, 5.0)], -0.05, 0.05, mi)
    S.add_cone(bm, (-0.1, 0, 5.4), (-1, 0, 0.1), 0.08, 0.012, 0.6, mi, 5)
    S.bm_close(ob, bm); S.paint(ob, {**STEELS((0.42, 0.44, 0.47), (0.56, 0.58, 0.62), (0.3, 0.3, 0.3)), **wood}); finish(ob, "alabarda")


# =============================================================== BOWS
def bows():
    # 1 arco corto
    ob = S.load("bow_wooden"); scale_verts(ob, all_verts(ob), 0.9, 1.0, 0.78); S.paint(ob, {"DarkWood": ((0.4, 0.26, 0.14), 0, 0.85), "LightWood": ((0.55, 0.38, 0.2), 0, 0.85)}); finish(ob, "arco_corto")
    # 2 arco de cazador: dark wood, leather grip wraps
    ob = S.load("bow_wooden2"); bm = S.bm_open(ob); ml = pm(ob, "Wrap", (0.2, 0.13, 0.08))
    for z in (-0.35, 0.0, 0.35): S.add_cone(bm, (0.05, 0, z - 0.05), (0, 0, 1), 0.2, 0.2, 0.12, ml, 8)
    S.bm_close(ob, bm); S.paint(ob, {"DarkWood": ((0.24, 0.17, 0.11), 0, 0.85), "LightWood": ((0.3, 0.2, 0.12), 0, 0.85)}); finish(ob, "arco_cazador")
    # 3 arco largo: tall, slim, pale wood
    ob = S.load("bow_wooden"); scale_verts(ob, all_verts(ob), 0.82, 1.0, 1.12); S.paint(ob, {"DarkWood": ((0.62, 0.48, 0.26), 0, 0.8), "LightWood": ((0.4, 0.28, 0.14), 0, 0.85)}); finish(ob, "arco_largo")
    # 4 arco de cuerno: bone-white with tip spikes
    ob = S.load("bow_golden"); bm = S.bm_open(ob); mb = pm(ob, "Gold", (0.9, 0.86, 0.72), 0.0, 0.6)
    for z in (-2.72, 2.72): S.add_cone(bm, (1.05, 0, z), (0.2, 0, 1 if z > 0 else -1), 0.1, 0.01, 0.4, mb, 5)
    S.bm_close(ob, bm); S.paint(ob, {"Gold": ((0.9, 0.86, 0.72), 0.0, 0.6), "LightWood": ((0.35, 0.22, 0.12), 0, 0.85)}); finish(ob, "arco_cuerno")
    # 5 arco rúnico: teal limbs, glowing gem at the grip
    ob = S.load("bow_evil"); bm = S.bm_open(ob); mg = pm(ob, "Gem", (0.2, 0.9, 0.9), 0.0, 0.3)
    sphere(bm, (0.2, 0, 0.0), 0.16, mg, 2)
    S.bm_close(ob, bm); S.paint(ob, {"Red": ((0.14, 0.45, 0.5), 0.35, 0.45), "Black": ((0.08, 0.12, 0.15), 0.3, 0.6)}); finish(ob, "arco_runico")


# =============================================================== STAVES (KayKit models are texture-atlas based: flatten first)
def flatten(ob):
    """Replace the atlas texture with flat per-colour materials sampled at each face centre (so it can be recoloured)."""
    me = ob.data
    img = [n.image for m in me.materials for n in m.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image][0]
    w, h = img.size; px = list(img.pixels)
    uv = me.uv_layers.active.data; cols = {}; assign = []
    for p in me.polygons:
        u = sum(uv[l].uv.x for l in p.loop_indices) / len(p.loop_indices); v = sum(uv[l].uv.y for l in p.loop_indices) / len(p.loop_indices)
        x = min(w - 1, max(0, int(u * w))); y = min(h - 1, max(0, int(v * h))); i = (y * w + x) * 4
        c = tuple(round(px[i + k] * 8) / 8 for k in range(3))
        cols.setdefault(c, len(cols)); assign.append(cols[c])
    me.materials.clear(); order = sorted(cols, key=cols.get)
    for k, c in enumerate(order):
        m = bpy.data.materials.new(f"c{k}"); m.use_nodes = True; me.materials.append(m)
        b = m.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value = (*c, 1.0); b.inputs["Roughness"].default_value = 0.7
    for p, a in zip(me.polygons, assign): p.material_index = a
    return order


def hue_shift(ob, order, dh, ds=1.0, dv=1.0, keep_dark=True):
    for k, c in enumerate(order):
        h, s, v = colorsys.rgb_to_hsv(*c)
        if s > 0.12:
            h = (h + dh) % 1.0; s = min(1.0, s * ds); v = min(1.0, v * dv)
        else:
            v = min(1.0, v * dv)
        b = ob.data.materials[k].node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value = (*colorsys.hsv_to_rgb(h, s, v), 1.0)


def staves():
    # 1 bastón de roble: warm amber crystal
    ob = S.load("kk_staff"); o = flatten(ob); hue_shift(ob, o, -0.25, 0.8, 0.95); finish(ob, "baston_roble")
    # 2 cayado de cristal: cyan + extra crystal
    ob = S.load("kk_staff"); o = flatten(ob); hue_shift(ob, o, 0.08)
    bm = S.bm_open(ob); mg = pm(ob, "Crystal", (0.35, 0.85, 0.95), 0.2, 0.25)
    sphere(bm, (0.05, 0, 1.55), 0.17, mg, 1, 1.9); sphere(bm, (0.28, 0, 1.3), 0.1, mg, 1, 1.6); sphere(bm, (-0.2, 0, 1.3), 0.1, mg, 1, 1.6)
    S.bm_close(ob, bm); finish(ob, "cayado_cristal")
    # 3 bastón de fuego: red body + flame cones
    ob = S.load("kk_staff"); o = flatten(ob); hue_shift(ob, o, -0.36, 1.2, 1.0)
    bm = S.bm_open(ob); mf = pm(ob, "Flame", (1.0, 0.5, 0.1), 0.0, 0.4); my = pm(ob, "Flame2", (1.0, 0.8, 0.2), 0.0, 0.4)
    for k in range(6):
        a = k * math.tau / 6; S.add_cone(bm, (0.05 + math.cos(a) * 0.13, math.sin(a) * 0.13, 1.18), (math.cos(a) * 0.25, math.sin(a) * 0.25, 1), 0.07, 0.005, 0.45 + 0.1 * (k % 2), mf if k % 2 else my, 5)
    S.bm_close(ob, bm); finish(ob, "baston_fuego")
    # 4 bastón de hielo: pale blue + ice shards
    ob = S.load("kk_staff"); o = flatten(ob); hue_shift(ob, o, 0.18, 0.7, 1.1)
    bm = S.bm_open(ob); mi = pm(ob, "Ice", (0.75, 0.92, 1.0), 0.1, 0.2)
    for k in range(7):
        a = k * math.tau / 7; S.add_cone(bm, (0.05 + math.cos(a) * 0.17, math.sin(a) * 0.17, 1.1), (math.cos(a) * 0.5, math.sin(a) * 0.5, 1), 0.06, 0.004, 0.5 + 0.12 * (k % 3), mi, 4)
    S.bm_close(ob, bm); finish(ob, "baston_hielo")
    # 5 vara arcana: purple wand with an orb
    ob = S.load("kk_wand"); o = flatten(ob); hue_shift(ob, o, 0.42, 1.0, 0.9)
    bm = S.bm_open(ob); mo = pm(ob, "Orb", (0.65, 0.3, 0.95), 0.0, 0.25)
    sphere(bm, (0.0, 0, 0.82), 0.14, mo, 2)
    S.bm_close(ob, bm); finish(ob, "vara_arcana")


FAMILIES = {"axe": axes, "mace": maces, "dagger": daggers, "spear": spears, "bow": bows, "staff": staves}

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(FAMILIES)
    for k in only:
        FAMILIES[k]()
    print("weapons done")
