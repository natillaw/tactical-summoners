"""Rogue set extras: pieces ADDED on top of the edited Quaternius base (bandanas, masks, turban, hat, capes, sashes, bandoliers...).
    blender -b -P tools/outfits/make_rogue_extras.py [-- set1 set2 ...]
Output: assets/models/creator/armor/{Male,Female}_Armor_<Set>_<slot>.gltf (cloth/leather/trim slots, tinted per set in game)."""
import sys, math, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix
import armor_lib as L
from armor_lib import Acc, Body, add_box, add_cone, add_tube, box_uv, UVS
import make_armor as M

HEADF = {"Head": 1.0}


def origin(B):
    c, s = M.head_frame(B)
    return Vector((0.0, c.y, c.z - 0.03)), c, s


def head_wrap(acc, B, phi0, phi1, th0, th1, off, mat, nphi=10, nth=30, cut=None, thick=0.004, smooth=1):
    """Cloth/leather lofted over the head by ray casts from inside the skull: conforms to nose, cheeks and brow.
    phi = elevation (0 = horizontal), th = azimuth (0 = front). off(phi, th) = distance proud of the skin."""
    tree = M.bvh(B); o, c, s = origin(B)
    def d_of(phi, th):
        return Vector((math.sin(th) * math.cos(phi), -math.cos(th) * math.cos(phi), math.sin(phi)))
    R = []
    for i in range(nphi + 1):
        phi = phi0 + (phi1 - phi0) * i / nphi; row = []
        for j in range(nth + 1):
            th = th0 + (th1 - th0) * j / nth; d = d_of(phi, th)
            hit = tree.ray_cast(o, d, 0.3)
            row.append((hit[0] - o).length if hit[0] is not None else 0.09)
        R.append(row)
    for _ in range(smooth):
        R2 = [r[:] for r in R]
        for i in range(nphi + 1):
            for j in range(nth + 1):
                tot = 0.0; ws = 0.0
                for di in (-1, 0, 1):
                    for dj in (-1, 0, 1):
                        ii = min(nphi, max(0, i + di)); jj = min(nth, max(0, j + dj)); w = (2.0 if di == 0 else 1.0) * (2.0 if dj == 0 else 1.0)
                        tot += R[ii][jj] * w; ws += w
                R2[i][j] = tot / ws
        R = R2
    cos = []
    for i in range(nphi + 1):
        phi = phi0 + (phi1 - phi0) * i / nphi
        for j in range(nth + 1):
            th = th0 + (th1 - th0) * j / nth
            cos.append(o + d_of(phi, th) * (R[i][j] + off(phi, th)))
    faces = []
    for i in range(nphi):
        for j in range(nth):
            if cut and cut(phi0 + (phi1 - phi0) * (i + 0.5) / nphi, th0 + (th1 - th0) * (j + 0.5) / nth):
                continue
            a = i * (nth + 1) + j; faces.append([a, a + 1, a + nth + 2, a + nth + 1])
    if not faces:
        return
    # outward winding
    f0 = faces[0]; pts = [cos[k] for k in f0]; n = (pts[1] - pts[0]).cross(pts[-1] - pts[0]); cen = sum(pts, Vector()) / 4
    if n.dot(cen - o) < 0:
        faces = [list(reversed(f)) for f in faces]
    used = sorted({v for f in faces for v in f}); mp = {v: k for k, v in enumerate(used)}
    cos2 = [cos[v] for v in used]; faces2 = [[mp[v] for v in f] for f in faces]
    acc.sheet(cos2, faces2, mat, box_uv(UVS.get(mat, 3.0)), thick, force=HEADF)


def tails(acc, B, y_off, z_drop, spread, mat="cloth", n=2):
    """Knot tails hanging behind the head (bandana / turban)."""
    o, c, s = origin(B)
    for k in range(n):
        sx = (k - (n - 1) / 2) * spread
        cos = []; faces = []
        for r in range(7):
            t = r / 6; w = 0.016 * (1 - 0.35 * t) + 0.004
            x = sx * (1 + 1.4 * t); y = c.y + 0.092 + y_off + 0.03 * t; z = c.z - 0.05 - z_drop * t - 0.01 * math.sin(t * 7 + k)
            cos += [Vector((x - w, y, z)), Vector((x + w, y, z))]
        for r in range(6):
            a = 2 * r; faces.append([a, a + 1, a + 3, a + 2])
        acc.sheet(cos, faces, mat, box_uv(3.0), 0.003, force=HEADF)


# ------------------------------------------------------------------ head pieces
def bandana(acc, B, trim=True, tail=True):
    """Cloth over nose-to-chin, tied behind the head."""
    def off(phi, th): return 0.008 + 0.006 * math.exp(-((phi + 0.05) / 0.12) ** 2)
    head_wrap(acc, B, -0.78, -0.02, -1.95, 1.95, off, "cloth", 9, 34, None, 0.004, 1)
    if trim:
        head_wrap(acc, B, -0.06, -0.01, -1.95, 1.95, lambda p, t: 0.016, "trim", 2, 34, None, 0.003, 0)
    if tail:
        tails(acc, B, 0.0, 0.1, 0.012)
    head_wrap(acc, B, -0.08, 0.0, 1.9, 4.4, lambda p, t: 0.012, "cloth", 2, 20, None, 0.003, 0)   # knot band around the back of the head


def beak_mask(acc, B):
    """Crow half-mask: leather cover over nose and mouth with a beak."""
    head_wrap(acc, B, -0.5, 0.0, -1.35, 1.35, lambda p, t: 0.012, "leather", 7, 24, None, 0.004, 1)
    o, c, s = origin(B)
    path = [Vector((0, c.y - 0.08, c.z - 0.03)), Vector((0, c.y - 0.115, c.z - 0.05)), Vector((0, c.y - 0.145, c.z - 0.085)), Vector((0, c.y - 0.155, c.z - 0.125))]
    add_tube(acc, path, [0.036, 0.03, 0.019, 0.004], 10, "leather", force=HEADF)
    head_wrap(acc, B, -0.08, 0.0, -1.35, 1.35, lambda p, t: 0.02, "trim", 2, 24, None, 0.003, 0)


def veil(acc, B):
    def off(phi, th): return 0.009 + 0.004 * math.sin(th * 5 + phi * 9)
    head_wrap(acc, B, -0.72, 0.05, -1.9, 1.9, off, "cloth", 9, 34, None, 0.003, 1)


def turban(acc, B):
    """Wrapped head cloth: diagonal bands, a folded front knot and a hanging tail."""
    def off(phi, th):
        wrap = 0.5 + 0.5 * math.sin((phi * 7.0) + th * 2.0)
        return 0.016 + 0.014 * wrap + 0.01 * max(0.0, phi - 0.9)
    head_wrap(acc, B, 0.36, 1.55, -math.pi, math.pi, off, "cloth", 12, 40, None, 0.005, 1)
    head_wrap(acc, B, 0.34, 0.4, -math.pi, math.pi, lambda p, t: 0.036, "trim", 2, 40, None, 0.003, 0)
    o, c, s = origin(B)
    add_cone(acc, Vector((0.012, c.y - 0.1, c.z + 0.07)), Vector((0.3, -1, 0.2)), 0.02, 0.03, 8, "trim", force=HEADF, r_top=0.006)   # front knot
    tails(acc, B, 0.0, 0.16, 0.0, "cloth", 1)


def hat(acc, B):
    """Duelist's cap: soft crown, brim turned up at the sides, long feather."""
    head_wrap(acc, B, 0.4, 1.55, -math.pi, math.pi, lambda p, t: 0.02 + 0.022 * math.sin(max(p, 0.0) * 1.7), "cloth", 10, 40, None, 0.005, 1)
    tree = M.bvh(B); o, c, s = origin(B)
    rows = []; nth = 40
    for i in range(3):
        row = []
        for j in range(nth):
            th = -math.pi + 2 * math.pi * j / nth
            d = Vector((math.sin(th), -math.cos(th), 0.0)); hit = tree.ray_cast(o + Vector((0, 0, 0.0)), d, 0.3)
            r = (hit[0] - o).length if hit[0] is not None else 0.09
            rad = r + 0.03 + i * 0.045
            up = 0.045 * abs(math.sin(th)) ** 1.5 * i + 0.01 * i
            row.append(Vector((o.x + d.x * rad, o.y + d.y * rad, c.z + 0.052 + up)))
        rows.append(row)
    cos = [p for r in rows for p in r]; faces = []
    for i in range(2):
        for j in range(nth):
            jn = (j + 1) % nth; faces.append([i * nth + j, i * nth + jn, (i + 1) * nth + jn, (i + 1) * nth + j])
    acc.sheet(cos, faces, "leather", box_uv(UVS["leather"]), 0.004, force=HEADF)
    head_wrap(acc, B, 0.38, 0.46, -math.pi, math.pi, lambda p, t: 0.036, "trim", 2, 40, None, 0.003, 0)   # hat band
    path = [Vector((0.075, c.y - 0.01, c.z + 0.07)), Vector((0.105, c.y + 0.02, c.z + 0.12)), Vector((0.105, c.y + 0.07, c.z + 0.17)), Vector((0.08, c.y + 0.13, c.z + 0.19)), Vector((0.045, c.y + 0.17, c.z + 0.17))]
    add_tube(acc, path, [0.006, 0.008, 0.009, 0.007, 0.002], 6, "cloth", force=HEADF)


def domino(acc, B):
    """Leather eye mask with eye holes."""
    def cut(phi, th):
        return ((phi - 0.21) / 0.1) ** 2 + ((abs(th) - 0.34) / 0.19) ** 2 < 1.0
    head_wrap(acc, B, 0.0, 0.4, -1.35, 1.35, lambda p, t: 0.012, "leather", 24, 96, cut, 0.003, 1)


# ------------------------------------------------------------------ chest pieces
def torso_cloak(acc, B, z_top, z_bot, flare, back_from=0.7, mat="cloth", ragged=0.0, off0=0.022):
    """Cape on the back: open at the front, flaring and ragged at the hem."""
    zt0, zt1 = z_bot, z_top
    def off(z, th):
        k = (z_top - z) / max(z_top - z_bot, 1e-6)
        return (off0 + flare * k ** 1.3) * 1.43     # M.OFFK scales torso offsets: compensate so the numbers read as metres
    def ok(zc, thc):
        if abs(thc) < back_from: return False
        hem = z_bot + ragged * (0.5 + 0.5 * math.sin(thc * 9.0)) if ragged else z_bot
        return zc > hem
    M.torso(acc, B, z_bot, z_top, off, mat, 0.004, smooth=2, face_ok=ok, segs=64)


def baldric(acc, B, side=1, mat="leather", off=0.05, hilts=0, width=0.026):
    zt = M.zt_chest(B); zl = B.bone["spine_01"][0].z + 0.02
    def strap(zc, thc):
        c = side * math.asin(max(-1.0, min(1.0, (zc - (zl + 0.18)) * 0.6 / 0.17)))
        return abs(thc) < 1.7 and abs(thc - c) < width / 0.17 * 0.9
    M.torso(acc, B, zl - 0.02, zt, lambda z, th: off, mat, 0.004, face_ok=strap, segs=300, dz=0.004)
    tree = M.bvh(B)
    for k in range(hilts):
        z = zl + 0.0 + 0.07 * k + 0.05
        thc = side * math.asin(max(-1.0, min(1.0, (z - (zl + 0.18)) * 0.6 / 0.17)))
        d = Vector((math.sin(thc), -math.cos(thc), 0)); hit = tree.ray_cast(Vector((0, 0, z)), d, 0.45)
        r = (hit[0] - Vector((0, 0, z))).length if hit[0] is not None else 0.15
        p = Vector((math.sin(thc) * (r + 0.055), -math.cos(thc) * (r + 0.055), z))
        add_box(acc, p, (0.009, 0.009, 0.034), "leather", Matrix.Rotation(-thc, 3, 'Z') @ Matrix.Rotation(side * 0.5, 3, 'Y'))
        add_box(acc, p + Vector((0, 0, 0.04)).copy(), (0.016, 0.005, 0.005), "trim", Matrix.Rotation(-thc, 3, 'Z'))


def sash(acc, B, mat="cloth", tails_side=1):
    zp = B.bone["pelvis"][0].z
    M.torso(acc, B, zp + 0.01, zp + 0.11, lambda z, th: 0.034, mat, 0.005, smooth=1)
    M.band(acc, B, None, zp + 0.1, zp + 0.112, 0.04, "trim")
    for k, (dx, ln) in enumerate(((0.0, 0.3), (0.035, 0.24))):
        cos = []; faces = []
        for r in range(8):
            t = r / 7; w = 0.028 * (1 - 0.25 * t)
            x = tails_side * (0.15 + dx + 0.03 * t); y = -0.145 - 0.03 * t - 0.01 * math.sin(t * 6 + k)
            z = zp + 0.06 - ln * t
            cos += [Vector((x - w * 0.6, y, z)), Vector((x + w * 0.6, y - 0.012, z))]
        for r in range(7):
            a = 2 * r; faces.append([a, a + 1, a + 3, a + 2])
        acc.sheet(cos, faces, mat, box_uv(3.0), 0.004)


def scarf_neck(acc, B, mat="cloth"):
    zt = M.zt_chest(B)
    M.torso(acc, B, zt + 0.0, zt + 0.07, lambda z, th: 0.05, mat, 0.005, smooth=1)


# ------------------------------------------------------------------ legs / hands
def thigh_straps(acc, B, side="r", sheath=True):
    h, tl = B.bone["thigh_l"]; sx = -1 if side == "r" else 1
    for t in (0.3, 0.52):
        M.limb(acc, B, "thigh", t - 0.03, t + 0.03, lambda tt, th: 0.026, "leather", 0.004)
    if sheath:
        p = Vector((sx * 0.145, -0.03, tl.z + (h.z - tl.z) * 0.6))
        add_box(acc, p, (0.014, 0.012, 0.075), "leather", Matrix.Rotation(sx * 0.1, 3, 'Y'))
        add_box(acc, p + Vector((0, -0.01, 0.085)), (0.012, 0.01, 0.022), "trim")


def knee_wraps(acc, B):
    for t in (0.08, 0.16):
        M.limb(acc, B, "calf", t - 0.03, t + 0.03, lambda tt, th: 0.034, "leather", 0.004)


def loin_panels(acc, B, mat="cloth"):
    zp = B.bone["pelvis"][0].z
    M.surcoat(acc, B, zp + 0.03, 0.5, 0.075, mat, 0.12, True, True, 0.05)


def wrist_wraps(acc, B, mat="cloth", n=4):
    for k in range(n):
        t = 0.42 + 0.13 * k
        M.limb(acc, B, "lowerarm", t - 0.04, t + 0.045, lambda tt, th: 0.026, mat, 0.004)


def forearm_spikes(acc, B):
    for sd in (-1, 1):
        for t in (0.5, 0.75):
            h, tl = B.bone["lowerarm_" + ("l" if sd > 0 else "r")]
            p = h + (tl - h) * t + Vector((0, -0.045, 0.02))
            add_cone(acc, p, Vector((0, -0.4, 1)), 0.014, 0.05, 6, "trim")


def cuffs_lace(acc, B):
    M.limb(acc, B, "lowerarm", 0.78, 1.0, lambda t, th: 0.034 + 0.02 * (t - 0.78) / 0.22, "cloth", 0.004)


def boot_cuffs(acc, B, mat="trim"):
    M.limb(acc, B, "calf", 0.16, 0.24, lambda t, th: 0.044, mat, 0.004)


# ------------------------------------------------------------------ sets
def build(name, B):
    acc = Acc(B)
    A = lambda slot: setattr(acc, "slot", slot)
    if name == "ladron":
        A("head"); bandana(acc, B)
        A("chest"); baldric(acc, B, 1, "leather", 0.05, 3); baldric(acc, B, -1, "leather", 0.05, 0)
        A("legs"); thigh_straps(acc, B, "r")
        A("hands"); wrist_wraps(acc, B, "leather", 2)
        A("boots"); M.limb(acc, B, "calf", 0.4, 0.45, lambda t, th: 0.034, "trim", 0.004)
    elif name == "cuervo":
        A("head"); beak_mask(acc, B)
        A("chest"); torso_cloak(acc, B, M.zt_chest(B) + 0.02, B.bone["spine_01"][0].z - 0.05, 0.025, 0.55, "cloth", 0.05)
        A("legs"); knee_wraps(acc, B)
        A("hands"); forearm_spikes(acc, B)
        A("boots"); boot_cuffs(acc, B)
    elif name == "desierto":
        A("head"); turban(acc, B); veil(acc, B)
        A("chest"); sash(acc, B, "cloth", 1); baldric(acc, B, -1, "cloth", 0.046, 0, 0.034)
        A("legs"); loin_panels(acc, B, "cloth")
        A("hands"); wrist_wraps(acc, B, "cloth", 4)
        A("boots"); boot_cuffs(acc, B, "cloth")
    elif name == "bosque":
        A("head"); bandana(acc, B, True, True)
        A("chest"); torso_cloak(acc, B, M.zt_chest(B) + 0.01, B.bone["pelvis"][0].z - 0.28, 0.05, 0.65, "cloth", 0.06)
        scarf_neck(acc, B)
        A("legs"); knee_wraps(acc, B); thigh_straps(acc, B, "l", False)
        A("hands"); wrist_wraps(acc, B, "leather", 3)
        A("boots"); M.limb(acc, B, "calf", 0.42, 0.47, lambda t, th: 0.034, "trim", 0.004)
    elif name == "carmesi":
        A("head"); hat(acc, B); domino(acc, B)
        A("chest"); sash(acc, B, "cloth", -1); baldric(acc, B, 1, "leather", 0.05, 0)
        A("legs"); loin_panels(acc, B, "cloth")
        A("hands"); cuffs_lace(acc, B)
        A("boots"); boot_cuffs(acc, B, "trim")
    return acc


SETS = ["ladron", "cuervo", "desierto", "bosque", "carmesi"]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else SETS
    for sex in ("Male", "Female"):
        for name in only:
            B = Body(sex)
            acc = build(name, B)
            L.export_split(acc, f"{sex}_Armor_{name.capitalize()}")
            print("built", sex, name, len(acc.verts), "verts")
    print("rogue extras done")
