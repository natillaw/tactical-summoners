"""Mage set extras, added on top of the edited Quaternius Peasant robe (hats, circlet, mantles, fur, bone, ropes, cuffs).
    blender -b -P tools/outfits/make_mage_extras.py [-- set1 set2 ...]
Also gives Mage_Robe a Peasant material so it can be retextured per set.
Output: assets/models/creator/armor/{Male,Female}_Armor_<Set>_<slot>.gltf"""
import sys, math, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix
import armor_lib as L
from armor_lib import Acc, Body, add_box, add_cone, add_tube, box_uv, UVS
import make_armor as M
import make_rogue_extras as X

HEADF = X.HEADF
OUTFITS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "creator", "outfits"))


def patch_robe_materials():
    """Mage_Robe was exported without material: copy the Peasant material/texture tables so the game can retexture it."""
    for sex in ("Male", "Female"):
        rp = os.path.join(OUTFITS, f"{sex}_Mage_Robe.gltf"); sp = os.path.join(OUTFITS, f"{sex}_Peasant.gltf")
        g = json.load(open(rp)); o = json.load(open(sp))
        for k in ("materials", "textures", "images", "samplers"):
            if k in o: g[k] = o[k]
        g["materials"] = [m for m in o["materials"] if m.get("name") == "MI_Peasant"][:1] or o["materials"][:1]
        for m in g["meshes"]:
            for p in m["primitives"]: p["material"] = 0
        json.dump(g, open(rp, "w"), indent=2)


def brim(acc, B, z_off, width, up, mat="cloth", droop=0.0, rows=4, nth=72):
    tree = M.bvh(B); o, c, s = X.origin(B)
    rws = []
    for i in range(rows):
        row = []
        for j in range(nth):
            th = -math.pi + 2 * math.pi * j / nth
            d = Vector((math.sin(th), -math.cos(th), 0.0)); hit = tree.ray_cast(o, d, 0.3)
            r = (hit[0] - o).length if hit[0] is not None else 0.09
            t = i / (rows - 1); rad = r + 0.05 + width * t * (1.0 + 0.3 * math.cos(th)) + 0.008 * t * math.sin(6 * th)
            z = c.z + z_off + t * (0.04 * math.sin(th) ** 2 - 0.034 * math.cos(th) ** 2) - droop * t * t
            row.append(Vector((o.x + d.x * rad, o.y + d.y * rad, z)))
        rws.append(row)
    cos = [p for r in rws for p in r]; faces = []
    for i in range(rows - 1):
        for j in range(nth):
            jn = (j + 1) % nth; faces.append([i * nth + j, i * nth + jn, (i + 1) * nth + jn, (i + 1) * nth + j])
    acc.sheet(cos, faces, mat, box_uv(UVS.get(mat, 3.0)), 0.005, force=HEADF)


def wizard_hat(acc, B):
    """Tall bent cone with a wide drooping brim and a band."""
    o, c, s = X.origin(B)
    z0 = c.z + 0.05
    path = [Vector((0, c.y, z0)), Vector((0, c.y, z0 + 0.06)), Vector((0, c.y + 0.01, z0 + 0.125)), Vector((0, c.y + 0.035, z0 + 0.19)), Vector((0, c.y + 0.08, z0 + 0.24)), Vector((0, c.y + 0.125, z0 + 0.25))]
    add_tube(acc, path, [0.106, 0.096, 0.07, 0.042, 0.02, 0.006], 18, "cloth", force=HEADF)
    brim(acc, B, 0.05, 0.03, 0.0, "cloth", 0.022)
    X.head_wrap(acc, B, 0.44, 0.52, -math.pi, math.pi, lambda p, t: 0.05, "trim", 2, 48, None, 0.003, 0)
    add_box(acc, Vector((0, c.y - 0.112, z0 - 0.012)), (0.02, 0.006, 0.016), "trim", force=HEADF)   # buckle


def circlet(acc, B, spikes=True):
    o, c, s = X.origin(B)
    X.head_wrap(acc, B, 0.4, 0.5, -math.pi, math.pi, lambda p, t: 0.034, "trim", 2, 48, None, 0.004, 0)
    tree = M.bvh(B); d = Vector((0, -math.cos(0.46), math.sin(0.46))); hit = tree.ray_cast(o, d, 0.3)
    r = (hit[0] - o).length if hit[0] is not None else 0.1
    p = o + d * (r + 0.04)
    add_cone(acc, p + Vector((0, 0, -0.004)), Vector((0, -0.3, 1)), 0.014, 0.03, 6, "cloth", force=HEADF, r_top=0.004)
    if spikes:
        for k, a in enumerate((-0.5, -0.25, 0.25, 0.5)):
            dd = Vector((math.sin(a), -math.cos(a), 0.0)); hit2 = tree.ray_cast(o + Vector((0, 0, 0.09)), dd, 0.3)
            rr = (hit2[0] - (o + Vector((0, 0, 0.09)))).length if hit2[0] is not None else 0.1
            pp = o + Vector((0, 0, 0.09)) + dd * (rr + 0.034)
            add_cone(acc, pp, Vector((dd.x * 0.3, dd.y * 0.3, 1)), 0.008, 0.022 + 0.01 * (k in (1, 2)), 5, "trim", force=HEADF)


def bone_horns(acc, B):
    tree = M.bvh(B); o, c, s = X.origin(B)
    for sx in (-1, 1):
        d = Vector((sx, 0, 0.3)).normalized(); hit = tree.ray_cast(o, d, 0.3)
        r = (hit[0] - o).length if hit[0] is not None else 0.09
        b = o + d * (r + 0.03)
        path = [b, b + Vector((sx * 0.03, -0.01, 0.03)), b + Vector((sx * 0.055, -0.03, 0.085)), b + Vector((sx * 0.05, -0.06, 0.14))]
        add_tube(acc, path, [0.016, 0.013, 0.008, 0.002], 8, "bone", force=HEADF)


def shawl(acc, B, hem, depth, mat="cloth", trim=None, flare=0.035, edge=0.016):
    """Shoulder cape with a shaped hem: hem(th) = how far below the collar the edge hangs (points, scallops...)."""
    zt = M.zt_chest(B); z_top = zt + 0.03
    def zh(th): return zt - hem(th)
    def off(z, th): return (0.036 + flare * max(0.0, zt - z) / depth) * 1.43
    M.torso(acc, B, zt - depth, z_top, off, mat, 0.005, smooth=2, face_ok=lambda zc, th: zc > zh(th) + (edge if trim else 0.0), segs=220, dz=0.0025)
    if trim:
        M.torso(acc, B, zt - depth, z_top, lambda z, th: off(z, th) + 0.008, trim, 0.004, smooth=2, face_ok=lambda zc, th: zh(th) < zc <= zh(th) + edge, segs=220, dz=0.002)


def fur_collar(acc, B, mat="bone"):
    zt = M.zt_chest(B)
    # puffy ring made of two lobes so it reads as fur, not as a tube
    for k, (z0, z1, amp) in enumerate(((zt - 0.02, zt + 0.045, 0.036), (zt + 0.02, zt + 0.075, 0.03))):
        M.torso(acc, B, z0, z1, lambda z, th, z0=z0, z1=z1, amp=amp: (0.04 + amp * math.sin((z - z0) / (z1 - z0) * math.pi) + 0.006 * math.sin(th * 14)) * 1.43, mat, 0.008, smooth=1, segs=96, dz=0.006)


def satchel(acc, B):
    """Leather strap across the chest with a flap bag on the hip."""
    X.baldric(acc, B, -1, "leather", 0.052, 0, 0.03)
    zp = B.bone["pelvis"][0].z
    add_box(acc, Vector((0.17, 0.0, zp - 0.04)), (0.03, 0.065, 0.058), "leather", Matrix.Rotation(-0.08, 3, 'Z'))
    add_box(acc, Vector((0.171, 0.0, zp - 0.0)), (0.034, 0.069, 0.026), "leather", Matrix.Rotation(-0.08, 3, 'Z'))
    add_box(acc, Vector((0.2, -0.0, zp - 0.012)), (0.006, 0.012, 0.016), "trim")


def star(acc, p, r, normal, mat="trim", n=6, force=None):
    """Little n-pointed star badge facing 'normal'."""
    nrm = normal.normalized(); e1 = nrm.cross(Vector((0, 0, 1)) if abs(nrm.z) < 0.9 else Vector((1, 0, 0))).normalized(); e2 = nrm.cross(e1)
    for k in range(n):
        a = 2 * math.pi * k / n
        add_cone(acc, p, e1 * math.cos(a) + e2 * math.sin(a), r * 0.28, r, 4, mat, force=force)


def clasp(acc, B, mat="trim"):
    zt = M.zt_chest(B)
    add_box(acc, Vector((0.03, -0.1, zt + 0.02)), (0.014, 0.006, 0.014), mat)
    add_box(acc, Vector((-0.03, -0.1, zt + 0.02)), (0.014, 0.006, 0.014), mat)
    cos = []; faces = []
    for r in range(7):
        t = r / 6; x = 0.0; y = -0.105 - 0.01 * math.sin(math.pi * t); z = zt + 0.026 - 0.012 * math.sin(math.pi * t)
        cos += [Vector((-0.03 + 0.06 * t - 0.002, y, z)), Vector((-0.03 + 0.06 * t + 0.002, y, z))]
    for r in range(6):
        a = 2 * r; faces.append([a, a + 1, a + 3, a + 2])
    acc.sheet(cos, faces, mat, box_uv(3.0), 0.003)


def rope_belt(acc, B, pouches=1):
    zp = B.bone["pelvis"][0].z
    M.torso(acc, B, zp + 0.04, zp + 0.075, lambda z, th: 0.032, "leather", 0.004, smooth=1)
    add_box(acc, Vector((0.05, -0.15, zp + 0.057)), (0.02, 0.008, 0.02), "trim")
    for k in range(2):
        path = [Vector((0.05 + 0.012 * k, -0.155, zp + 0.05)), Vector((0.058 + 0.02 * k, -0.162, zp - 0.04)), Vector((0.06 + 0.03 * k, -0.158, zp - 0.12 - 0.02 * k))]
        add_tube(acc, path, [0.006, 0.006, 0.005], 6, "leather")
    for k in range(pouches):
        add_box(acc, Vector((-0.17 - 0.0 * k, -0.07, zp + 0.0)), (0.032, 0.045, 0.04), "leather", Matrix.Rotation(0.15, 3, 'Z'))
        add_box(acc, Vector((-0.17, -0.1, zp + 0.025)), (0.034, 0.01, 0.012), "trim")


def sash(acc, B, mat="cloth"):
    X.sash(acc, B, mat, 1)


def ribs(acc, B, n=4):
    """Thin rib arcs that sweep down towards the back and shorten towards the belly."""
    zt = M.zt_chest(B)
    for k in range(n):
        z = zt - 0.07 - 0.04 * k; reach = 1.3 - 0.12 * k
        zc = lambda th, z=z, reach=reach: z - 0.028 * (abs(th) / reach) ** 2
        M.torso(acc, B, z - 0.05, z + 0.012, lambda zz, th: 0.05, "bone", 0.004, smooth=0,
                face_ok=lambda zct, thc, zc=zc, reach=reach: 0.07 < abs(thc) < reach and abs(zct - zc(thc)) < 0.0085, segs=240, dz=0.0022)


def sternum(acc, B):
    zt = M.zt_chest(B)
    M.torso(acc, B, zt - 0.2, zt - 0.02, lambda z, th: 0.05, "bone", 0.005, smooth=0, face_ok=lambda zc, thc: abs(thc) < 0.07, segs=200, dz=0.004)


def bone_spurs(acc, B):
    for sd in (-1, 1):
        h = B.bone["upperarm_" + ("l" if sd > 0 else "r")][0]
        for k, (dx, dz, ln) in enumerate(((0.01, 0.07, 0.075), (0.07, 0.065, 0.06), (0.125, 0.055, 0.045))):
            add_cone(acc, h + Vector((sd * dx, 0.0, dz)), Vector((sd * 0.35, 0, 1)), 0.016, ln, 6, "bone")


def cuffs(acc, B, mat="cloth", trim=True, wide=0.03):
    M.limb(acc, B, "lowerarm", 0.76, 1.0, lambda t, th: wide * (0.5 + 0.5 * (t - 0.76) / 0.24) + 0.012, mat, 0.004, 1)
    if trim:
        M.limb(acc, B, "lowerarm", 0.74, 0.78, lambda t, th: wide * 0.5 + 0.02, "trim", 0.004)


def scarf(acc, B, mat="cloth"):
    X.scarf_neck(acc, B, mat)
    zt = M.zt_chest(B)
    add_cone(acc, Vector((-0.045, -0.118, zt + 0.015)), Vector((-0.2, -1, -0.2)), 0.02, 0.025, 8, mat)   # knot
    for k, (sx, ln) in enumerate(((-0.05, 0.3), (-0.02, 0.22))):
        cos = []; faces = []
        for r in range(10):
            t = r / 9; w = 0.026 * (1 - 0.25 * t) + 0.002
            x = sx + 0.012 * math.sin(t * 5 + k * 2); y = -0.138 - 0.014 * t - 0.006 * math.sin(t * 6); z = zt + 0.0 - ln * t
            cos += [Vector((x - w, y, z)), Vector((x + w, y - 0.006, z))]
        for r in range(9):
            a = 2 * r; faces.append([a, a + 1, a + 3, a + 2])
        acc.sheet(cos, faces, mat, box_uv(3.0), 0.004)


def knee_gem(acc, B):
    pass


def build(name, B):
    acc = Acc(B)
    A = lambda slot: setattr(acc, "slot", slot)
    zt = M.zt_chest(B)
    if name == "aprendiz":
        A("chest"); rope_belt(acc, B, 0); scarf(acc, B); satchel(acc, B)
        A("hands"); cuffs(acc, B, "cloth", True, 0.026)
    elif name == "brasa":
        A("head"); circlet(acc, B, True)
        # four-pointed shawl (front, back and shoulders) edged in gold
        A("chest"); shawl(acc, B, lambda th: 0.05 + 0.13 * (0.5 + 0.5 * math.cos(4 * th)), 0.2, "leather", "trim", 0.03)
        sash(acc, B)
        star(acc, Vector((0.0, -0.17, B.bone["pelvis"][0].z + 0.06)), 0.03, Vector((0, -1, 0)), "trim")
        A("hands"); cuffs(acc, B, "trim", False, 0.02)
    elif name == "escarcha":
        A("chest"); fur_collar(acc, B); shawl(acc, B, lambda th: 0.07 + 0.035 * abs(math.sin(6 * th)), 0.14, "cloth", "bone", 0.02, 0.026)
        star(acc, Vector((0.0, -0.118, zt - 0.02)), 0.026, Vector((0, -1, 0)), "trim", 8)
        A("hands"); cuffs(acc, B, "bone", False, 0.034)
    elif name == "sabio":
        A("head"); wizard_hat(acc, B)
        A("chest"); rope_belt(acc, B, 0); clasp(acc, B)
        shawl(acc, B, lambda th: 0.0 if abs(th) < 1.45 else 0.42 * ((abs(th) - 1.45) / (math.pi - 1.45)) ** 0.9, 0.45, "cloth", "trim", 0.04, 0.014)
        for k in range(3):
            star(acc, Vector((-0.07 + 0.07 * k, 0.21, zt - 0.1 - 0.06 * (k % 2))), 0.022, Vector((0, 1, 0)), "trim")
        A("hands"); cuffs(acc, B, "cloth", True, 0.034)
    elif name == "osario":
        A("head"); bone_horns(acc, B)
        A("chest"); bone_spurs(acc, B); ribs(acc, B, 4); sternum(acc, B)
        A("hands"); X.forearm_spikes(acc, B)
    return acc


SETS = ["aprendiz", "brasa", "escarcha", "sabio", "osario"]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else SETS
    patch_robe_materials()
    for sex in ("Male", "Female"):
        for name in only:
            B = Body(sex)
            acc = build(name, B)
            if acc.faces:
                L.export_split(acc, f"{sex}_Armor_{name.capitalize()}")
            print("built", sex, name, len(acc.verts), "verts")
    print("mage extras done")
