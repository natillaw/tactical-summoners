"""Archer set extras, added on top of the recoloured Quaternius Ranger outfit (quivers, caps, hats, antlers, feathers, furs, straps).
    blender -b -P tools/outfits/make_archer_extras.py [-- set1 set2 ...]
Output: assets/models/creator/armor/{Male,Female}_Armor_<Set>_<slot>.gltf"""
import sys, math, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix
import armor_lib as L
from armor_lib import Acc, Body, add_box, add_cone, add_tube, box_uv, UVS
import make_armor as M
import make_rogue_extras as X
import make_mage_extras as MX

HEADF = X.HEADF


def feather(acc, p, d, length, mat="cloth", spine="bone", force=None, curl=0.4):
    """One curved feather: a fat leaf-shaped tube plus a thin spine."""
    d = d.normalized(); side = d.cross(Vector((0, 0, 1))).normalized()
    path = [p + d * length * t + side * curl * length * 0.3 * t * t + Vector((0, 0, -0.25 * length * t * t)) for t in (0.0, 0.3, 0.65, 1.0)]
    add_tube(acc, path, [0.004, 0.013, 0.011, 0.002], 6, mat, force=force)
    add_tube(acc, [path[0], path[3]], [0.0025, 0.002], 4, spine, force=force)


def quiver(acc, B, arrows=5, mat="leather", flip=1):
    """Leather quiver slung across the back with arrow shafts and fletching sticking out."""
    zt = M.zt_chest(B)
    lo = Vector((flip * 0.08, 0.205, zt - 0.36)); hi = Vector((-flip * 0.03, 0.17, zt - 0.02))
    add_tube(acc, [lo, lo.lerp(hi, 0.5), hi], [0.046, 0.053, 0.056], 14, mat)
    add_tube(acc, [hi.lerp(lo, 0.06), hi.lerp(lo, 0.1)], [0.062, 0.062], 14, "trim")           # rim
    add_tube(acc, [lo.lerp(hi, 0.3), lo.lerp(hi, 0.34)], [0.058, 0.058], 14, "trim")           # strap ring
    d = (hi - lo).normalized()
    for k in range(arrows):
        a = 2 * math.pi * k / arrows
        base = hi + Vector((math.cos(a) * 0.026, math.sin(a) * 0.02, 0)) - d * 0.02
        tip = base + d * (0.15 + 0.02 * (k % 3)) + Vector((math.cos(a) * 0.012, 0.0, 0))
        add_tube(acc, [base, tip], [0.004, 0.004], 5, "bone")
        for j in range(3):
            aa = 2 * math.pi * j / 3
            s0 = tip - d * 0.045 + Vector((math.cos(aa) * 0.004, math.sin(aa) * 0.004, 0))
            add_cone(acc, s0, d + Vector((math.cos(aa) * 0.5, math.sin(aa) * 0.5, 0)) * 0.3, 0.003, 0.045, 3, "cloth", r_top=0.012)


def strap_pair(acc, B):
    X.baldric(acc, B, -1, "leather", 0.052, 0, 0.026)


def cap(acc, B):
    """Soft hunter's cap: slouched crown, folded band, short peak at the front and a long feather."""
    o, c, s = X.origin(B)
    X.head_wrap(acc, B, 0.34, 1.55, -math.pi, math.pi, lambda p, t: 0.03 + 0.026 * math.sin(max(p, 0.0) * 1.6) + 0.006 * math.sin(5 * t), "cloth", 11, 56, None, 0.005, 1)
    X.head_wrap(acc, B, 0.3, 0.42, -math.pi, math.pi, lambda p, t: 0.05, "trim", 2, 56, None, 0.003, 0)
    tree = M.bvh(B)
    rows = []; nth = 30
    for i in range(3):
        row = []
        for j in range(nth + 1):
            th = -1.15 + 2.3 * j / nth; d = Vector((math.sin(th), -math.cos(th), 0.0)); hit = tree.ray_cast(o, d, 0.3)
            r = (hit[0] - o).length if hit[0] is not None else 0.09
            t = i / 2; rad = r + 0.045 + 0.06 * t * math.cos(th) ** 2
            row.append(Vector((o.x + d.x * rad, o.y + d.y * rad, c.z + 0.052 - 0.022 * t)))
        rows.append(row)
    cos = [p for r in rows for p in r]; faces = []
    for i in range(2):
        for j in range(nth):
            a = i * (nth + 1) + j; faces.append([a, a + 1, a + nth + 2, a + nth + 1])
    acc.sheet(cos, faces, "leather", box_uv(UVS["leather"]), 0.004, force=HEADF)
    feather(acc, Vector((0.085, c.y - 0.01, c.z + 0.075)), Vector((0.5, 0.75, 0.55)), 0.17, "cloth", "bone", HEADF)


def wide_hat(acc, B):
    """Wide-brim explorer hat with a pinched crown and a chin strap."""
    o, c, s = X.origin(B)
    X.head_wrap(acc, B, 0.4, 1.55, -math.pi, math.pi, lambda p, t: 0.03 + 0.03 * math.sin(max(p, 0.0) * 1.7) - 0.012 * math.exp(-((t) / 0.4) ** 2) * (p > 1.2), "cloth", 10, 56, None, 0.005, 1)
    MX.brim(acc, B, 0.048, 0.05, 0.0, "cloth", 0.025)
    X.head_wrap(acc, B, 0.4, 0.5, -math.pi, math.pi, lambda p, t: 0.05, "trim", 2, 56, None, 0.003, 0)
    for sx in (-1, 1):
        path = [Vector((sx * 0.112, c.y, c.z + 0.04)), Vector((sx * 0.105, c.y - 0.01, c.z - 0.05)), Vector((sx * 0.07, c.y - 0.04, c.z - 0.13)), Vector((sx * 0.015, c.y - 0.06, c.z - 0.152))]
        add_tube(acc, path, [0.004, 0.004, 0.004, 0.004], 5, "leather", force=HEADF)


def antlers(acc, B):
    tree = M.bvh(B); o, c, s = X.origin(B)
    for sx in (-1, 1):
        d = Vector((sx * math.sin(0.85), -math.cos(0.85), 0)); d = Vector((d.x * math.cos(0.5), d.y * math.cos(0.5), math.sin(0.5)))
        hit = tree.ray_cast(o, d, 0.3); r = (hit[0] - o).length if hit[0] is not None else 0.1
        b = o + d * (r + 0.02)
        beam = [b, b + Vector((sx * 0.03, 0.005, 0.04)), b + Vector((sx * 0.065, 0.025, 0.1)), b + Vector((sx * 0.08, 0.055, 0.17)), b + Vector((sx * 0.07, 0.085, 0.25))]
        add_tube(acc, beam, [0.016, 0.013, 0.01, 0.007, 0.002], 8, "bone", force=HEADF)
        for k, (i, dx, dy, dz, ln) in enumerate(((1, 0.05, -0.01, 0.06, 0.07), (2, 0.06, -0.02, 0.07, 0.08), (3, 0.04, 0.04, 0.08, 0.07))):
            p0 = beam[i]; p1 = p0 + Vector((sx * dx, dy, dz)) * (ln / 0.08)
            add_tube(acc, [p0, p0.lerp(p1, 0.5) + Vector((sx * 0.005, 0, 0.01)), p1], [0.009, 0.006, 0.0015], 6, "bone", force=HEADF)
    X.head_wrap(acc, B, 0.36, 0.46, -math.pi, math.pi, lambda p, t: 0.034, "leather", 2, 56, None, 0.003, 0)
    for k in range(9):                                     # leaf wreath
        th = -2.2 + 4.4 * k / 8; dd = Vector((math.sin(th), -math.cos(th), math.sin(0.42) / 1.0)); dd = Vector((math.sin(th) * math.cos(0.42), -math.cos(th) * math.cos(0.42), math.sin(0.42)))
        hit = tree.ray_cast(o, dd, 0.3); rr = (hit[0] - o).length if hit[0] is not None else 0.1
        add_cone(acc, o + dd * (rr + 0.03), Vector((dd.x, dd.y, 0.35)) + Vector((math.sin(th) * 0.5, 0, 0)), 0.012, 0.04, 4, "cloth", force=HEADF, r_top=0.002)


def feather_band(acc, B):
    o, c, s = X.origin(B)
    X.head_wrap(acc, B, 0.34, 0.46, -math.pi, math.pi, lambda p, t: 0.03, "cloth", 2, 56, None, 0.004, 0)
    X.head_wrap(acc, B, 0.46, 0.5, -math.pi, math.pi, lambda p, t: 0.034, "trim", 2, 56, None, 0.003, 0)
    base = Vector((-0.085, c.y + 0.035, c.z + 0.04))
    for k, (dirv, ln, m) in enumerate(((Vector((-0.5, 0.45, 0.85)), 0.2, "cloth"), (Vector((-0.75, 0.3, 0.6)), 0.18, "bone"), (Vector((-0.35, 0.65, 0.7)), 0.17, "trim"))):
        feather(acc, base + Vector((0, 0.008 * k, 0.006 * k)), dirv, ln, m, "bone", HEADF, -0.4)
    add_tube(acc, [base + Vector((0.003, -0.005, -0.01)), base + Vector((0.0, 0.004, -0.04)), base + Vector((0.01, 0.0, -0.075))], [0.004, 0.004, 0.003], 5, "leather", force=HEADF)   # tie
    add_cone(acc, base + Vector((0.01, -0.005, -0.075)), Vector((0, 0, -1)), 0.009, 0.02, 6, "bone", force=HEADF)


def beads(acc, B, side=1):
    zt = M.zt_chest(B); zl = B.bone["spine_01"][0].z + 0.02
    tree = M.bvh(B)
    for k in range(7):
        z = zl + 0.0 + 0.045 * k + 0.02
        thc = side * math.asin(max(-1.0, min(1.0, (z - (zl + 0.18)) * 0.6 / 0.17)))
        d = Vector((math.sin(thc), -math.cos(thc), 0)); hit = tree.ray_cast(Vector((0, 0, z)), d, 0.45)
        r = (hit[0] - Vector((0, 0, z))).length if hit[0] is not None else 0.15
        p = Vector((math.sin(thc) * (r + 0.05), -math.cos(thc) * (r + 0.05), z))
        add_cone(acc, p, Vector((math.sin(thc), -math.cos(thc), 0)), 0.013, 0.018, 6, "bone", r_top=0.008)


def neckerchief(acc, B):
    zt = M.zt_chest(B)
    X.scarf_neck(acc, B, "cloth")
    for sx, ln in ((-1, 0.07), (1, 0.05)):
        cos = []; faces = []
        for r in range(5):
            t = r / 4; w = 0.034 * (1 - t)
            cos += [Vector((sx * 0.01 - w, -0.125 - 0.01 * t, zt + 0.02 - ln * t)), Vector((sx * 0.01 + w, -0.125 - 0.01 * t, zt + 0.02 - ln * t))]
        for r in range(4):
            a = 2 * r; faces.append([a, a + 1, a + 3, a + 2])
        acc.sheet(cos, faces, "cloth", box_uv(3.0), 0.003)


def fur_mantle(acc, B):
    MX.fur_collar(acc, B)
    MX.shawl(acc, B, lambda th: 0.06 + 0.035 * abs(math.sin(7 * th)), 0.14, "bone", None, 0.03)


def knee_wraps(acc, B):
    X.knee_wraps(acc, B)


def build(name, B):
    acc = Acc(B); A = lambda slot: setattr(acc, "slot", slot)
    if name == "montero":
        A("head"); cap(acc, B)
        A("chest"); quiver(acc, B, 5); strap_pair(acc, B)
        A("legs"); knee_wraps(acc, B)
        A("hands"); X.wrist_wraps(acc, B, "leather", 2)
        A("boots"); X.boot_cuffs(acc, B, "leather")
    elif name == "llanura":
        A("head"); wide_hat(acc, B)
        A("chest"); neckerchief(acc, B); quiver(acc, B, 4, "leather", -1); X.baldric(acc, B, 1, "leather", 0.05, 0, 0.026)
        A("legs"); X.thigh_straps(acc, B, "r", True)
        A("hands"); X.wrist_wraps(acc, B, "cloth", 3)
        A("boots"); X.boot_cuffs(acc, B, "trim")
    elif name == "guardabosques":
        A("head"); antlers(acc, B)
        A("chest"); fur_mantle(acc, B); quiver(acc, B, 6)
        A("legs"); knee_wraps(acc, B); X.thigh_straps(acc, B, "l", False)
        A("hands"); X.wrist_wraps(acc, B, "leather", 3)
    elif name == "centinela":
        A("chest"); MX.fur_collar(acc, B); quiver(acc, B, 5); strap_pair(acc, B)
        A("hands"); X.wrist_wraps(acc, B, "leather", 2)
        A("legs"); knee_wraps(acc, B)
    elif name == "dunas":
        A("head"); feather_band(acc, B)
        A("chest"); beads(acc, B, 1); beads(acc, B, -1); X.baldric(acc, B, 1, "leather", 0.05, 0, 0.026); X.baldric(acc, B, -1, "leather", 0.052, 0, 0.026); X.sash(acc, B, "cloth", -1)
        A("legs"); X.loin_panels(acc, B, "cloth")
        A("hands"); X.wrist_wraps(acc, B, "cloth", 4)
        A("boots"); X.boot_cuffs(acc, B, "cloth")
    return acc


SETS = ["montero", "llanura", "guardabosques", "centinela", "dunas"]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else SETS
    for sex in ("Male", "Female"):
        for name in only:
            B = Body(sex)
            acc = build(name, B)
            if acc.faces:
                L.export_split(acc, f"{sex}_Armor_{name.capitalize()}")
            print("built", sex, name, len(acc.verts), "verts")
    print("archer extras done")
