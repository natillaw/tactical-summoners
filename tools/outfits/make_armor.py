"""Five warrior armor sets (helmet + torso + arms + legs), male and female. Run:
    blender -b -P tools/outfits/make_armor.py [-- set1 set2 ...]
Output: assets/models/creator/armor/{Male,Female}_Armor_<set>.gltf (geometry + material slots; textures/tints are set in game)."""
import sys, math
sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix
import armor_lib as L
from armor_lib import Acc, Body, shell, lathe, add_box, add_cone, add_tube, arc_band, dome, cyl_uv, box_uv, UVS

TORSO = {"spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"}
ARM_U = ("upperarm_l", "upperarm_r"); ARM_L = ("lowerarm_l", "lowerarm_r")
THIGH = ("thigh_l", "thigh_r"); CALF = ("calf_l", "calf_r"); FOOT = ("foot_l", "foot_r", "ball_l", "ball_r")


def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a))); return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ body shells
def torso_uv(B, mat):
    n = max(3, round(2 * math.pi * 0.17 * UVS[mat]))
    return cyl_uv(Vector((0, 0.0, 0)), Vector((0, 0, 1)), UVS[mat], n)


def limb_uv(B, bone, mat):
    r = 0.06 if "arm" in bone else 0.08
    n = max(2, round(2 * math.pi * r * UVS[mat]))
    fl = cyl_uv(B.bone[bone + "_l"][0], B.bone[bone + "_l"][1] - B.bone[bone + "_l"][0], UVS[mat], n)
    fr = cyl_uv(B.bone[bone + "_r"][0], B.bone[bone + "_r"][1] - B.bone[bone + "_r"][0], UVS[mat], n)
    return lambda co, nrm: fl(co, nrm) if co.x >= 0 else fr(co, nrm)


from mathutils.bvhtree import BVHTree
OFFK = 0.7   # armour hugs the body: all offsets are scaled by this
RCAST = {"foot": 0.1, "upperarm": 0.13, "lowerarm": 0.11, "thigh": 0.118, "calf": 0.13}
_BVH = {}


def bvh(B):
    if id(B) not in _BVH:
        _BVH[id(B)] = BVHTree.FromPolygons([tuple(c) for c in B.co], [tuple(f) for f in B.faces])
    return _BVH[id(B)]


def limb(acc, B, bone, t0, t1, off, mat, thick=0.006, smooth=0, segs=22, axis=None, cap=False):
    """Clean tube lofted around a limb bone (both sides). Radius = body surface (ray-cast from the axis, smoothed) + off(t, theta);
    theta=0 is the front of the limb. Gives regular topology and crisp edges, independent of the body mesh layout."""
    tree = bvh(B)
    for sd in ("l", "r"):
        h, tl = axis(sd) if axis else B.bone[bone + "_" + sd]; d = tl - h; ln = d.length; dn = d / ln
        e1 = (Vector((0, -1, 0)) - dn * Vector((0, -1, 0)).dot(dn)).normalized(); e2 = dn.cross(e1)
        nt = max(3, min(46, round((t1 - t0) * ln / 0.011)))
        R = []
        for k in range(nt + 1):
            t = t0 + (t1 - t0) * k / nt; o = h + dn * (ln * t); row = []
            for i in range(segs):
                th = 2 * math.pi * i / segs; dr = e1 * math.cos(th) + e2 * math.sin(th)
                best = 0.0
                hit = tree.ray_cast(o, dr, 0.32)                 # outwards from the axis
                if hit[0] is not None: best = (hit[0] - o).length
                D = RCAST[bone]                                   # and inwards from just outside: robust if the axis sits near the skin
                hit2 = tree.ray_cast(o + dr * D, -dr, D)
                if hit2[0] is not None: best = max(best, (hit2[0] - o).length)
                row.append(best if best > 0.02 else 0.06)
            R.append(row)
        Rbase = None
        for it in range(2 + smooth):   # blur: lose muscle bumps, keep the silhouette
            if it == 2: Rbase = [r[:] for r in R]
            R2 = [r[:] for r in R]
            for k in range(nt + 1):
                for i in range(segs):
                    acc_r = 0.0; wsum = 0.0
                    for dk in (-1, 0, 1):
                        kk = min(nt, max(0, k + dk))
                        for di in (-1, 0, 1):
                            w = (2.0 if dk == 0 else 1.0) * (2.0 if di == 0 else 1.0)
                            acc_r += R[kk][(i + di) % segs] * w; wsum += w
                    R2[k][i] = acc_r / wsum
            R = R2
        if Rbase is not None:   # plates never dip below the lightly-smoothed skin (shin crest, kneecap)
            R = [[max(a, b) for a, b in zip(r1, r2)] for r1, r2 in zip(R, Rbase)]
        cos = []; faces = []; ao = []
        ntiles = max(2, round(2 * math.pi * 0.07 * UVS[mat])); uvs = {}
        for k in range(nt + 1):
            t = t0 + (t1 - t0) * k / nt; o = h + dn * (ln * t)
            for i in range(segs + 1):
                ii = i % segs; th = 2 * math.pi * ii / segs; dr = e1 * math.cos(th) + e2 * math.sin(th)
                cos.append(o + dr * (R[k][ii] + off(t, th) * OFFK))
        if cap:   # close the far end with a rounded tip (toe cap)
            o = h + dn * (ln * t1)
            for sc in (0.75, 0.4, 0.05):
                for i in range(segs + 1):
                    ii = i % segs; th = 2 * math.pi * ii / segs; dr = e1 * math.cos(th) + e2 * math.sin(th)
                    cos.append(o + dn * (ln * 0.12 * (1 - sc) ) + dr * ((R[nt][ii] + off(t1, th) * OFFK) * sc))
            nt += 3
        for k in range(nt):
            for i in range(segs):
                a_ = k * (segs + 1) + i; faces.append([a_, a_ + 1, a_ + segs + 2, a_ + segs + 1] if sd == "l" else [a_, a_ + segs + 1, a_ + segs + 2, a_ + 1])
        def uvf(co, nrm, o=h, ax=dn, ee1=e1, ee2=e2):
            dd = co - o; ang = math.atan2(dd.dot(ee2), dd.dot(ee1)) / (2 * math.pi)
            return (ang * ntiles, dd.dot(ax) * UVS[mat])
        acc.sheet(cos, faces, mat, uvf, thick)


def torso(acc, B, z0, z1, off, mat, thick=0.006, smooth=0, face_ok=None, segs=40):
    """Clean ring-loft around the vertical axis (cuirasses, hauberks, bands). Radius = body surface from ray casts (blurred),
    + off(z, theta) with theta=0 at the front. face_ok(z, theta) can drop quads (e.g. diagonal straps, front-only plates)."""
    tree = bvh(B); capx = B.bone["clavicle_l"][1].x
    nz = max(3, min(60, round((z1 - z0) / 0.011))); R = []
    last = 0.15
    for k in range(nz + 1):
        z = z0 + (z1 - z0) * k / nz; row = []
        for i in range(segs):
            th = -math.pi + 2 * math.pi * i / segs; d = Vector((math.sin(th), -math.cos(th), 0))
            hit = tree.ray_cast(Vector((0, 0.0, z)), d, 0.45)
            r = (hit[0] - Vector((0, 0.0, z))).length if hit[0] is not None else last
            r = min(r, capx / max(abs(math.sin(th)), 0.3)); row.append(r)
        R.append(row)
    for it in range(3 + smooth):
        R2 = [r[:] for r in R]
        for k in range(nz + 1):
            for i in range(segs):
                tot = 0.0; ws = 0.0
                for dk in (-1, 0, 1):
                    kk = min(nz, max(0, k + dk))
                    for di in (-1, 0, 1):
                        w = (2.0 if dk == 0 else 1.0) * (2.0 if di == 0 else 1.0); tot += R[kk][(i + di) % segs] * w; ws += w
                R2[k][i] = tot / ws
        R = R2
    cos = []; ntiles = max(3, round(2 * math.pi * 0.17 * UVS[mat]))
    for k in range(nz + 1):
        z = z0 + (z1 - z0) * k / nz
        for i in range(segs + 1):
            th = -math.pi + 2 * math.pi * i / segs; r = R[k][i % segs] + off(z, th) * OFFK
            cos.append(Vector((math.sin(th) * r, -math.cos(th) * r, z)))
    faces = []
    for k in range(nz):
        for i in range(segs):
            if face_ok:
                zc = z0 + (z1 - z0) * (k + 0.5) / nz; thc = -math.pi + 2 * math.pi * (i + 0.5) / segs
                if not face_ok(zc, thc): continue
            a_ = k * (segs + 1) + i; faces.append([a_, a_ + 1, a_ + segs + 2, a_ + segs + 1])
    if not faces: return
    used = sorted({v for f in faces for v in f}); mp = {v: n for n, v in enumerate(used)}
    cos2 = [cos[v] for v in used]; faces2 = [[mp[v] for v in f] for f in faces]
    def uvf(co, nrm):
        return ((math.atan2(co.x, -co.y) / (2 * math.pi) + 0.5) * ntiles, co.z * UVS[mat])
    acc.sheet(cos2, faces2, mat, uvf, thick)


def band(acc, B, bones, z0, z1, off, mat="trim", thick=0.005):
    """Thin horizontal strip (trim at hems/collars), proud of the armor under it."""
    torso(acc, B, z0, z1, lambda z, th: off, mat, thick)


def zt_chest(B):
    return B.bone["clavicle_l"][0].z + 0.045


# ------------------------------------------------------------------ pauldrons / joints (left side then mirrored)
def pauldron_stack(acc, B, lames=4, spike=False, trim=True, scale=1.0, mat="plate"):
    v0, f0 = len(acc.verts), len(acc.faces)
    h = B.bone["upperarm_l"][0]
    r0 = (0.088 if B.sex == "Male" else 0.075) * scale * 0.88
    # domed cap on the shoulder joint
    dome(acc, h + Vector((0.01, 0.0, 0.012)), (r0 * 1.15, r0 * 1.25, r0 * 0.95), mat, lat0=0.0, lat1=math.pi / 2 + 0.38, seg=18, rings=7, thick=0.007)
    for k in range(lames):
        o = h + Vector((0.005 + k * 0.034 * scale, 0, 0))
        arc_band(acc, o, Vector((1, 0, 0)), Vector((0, 0, 1)), r0 * (1.02 - 0.05 * k), r0 * (1.0 - 0.05 * k - 0.0), 0.05 * scale, -1.95, 1.95, mat, steps=16, rings=3, thick=0.006)
    if trim:   # border trim on the outer lame + a ridge on the cap
        o = h + Vector((0.005 + (lames - 1) * 0.034 * scale + 0.05 * scale, 0, 0))
        arc_band(acc, o, Vector((1, 0, 0)), Vector((0, 0, 1)), r0 * (1.0 - 0.05 * (lames - 1)) + 0.002, r0 * (1.0 - 0.05 * (lames - 1)) + 0.002, 0.012, -1.95, 1.95, "trim", steps=16, rings=2, thick=0.004)
    if spike:
        add_cone(acc, h + Vector((0.02, 0.0, r0 * 0.95)), Vector((0.1, 0, 1)), 0.022, 0.075, 8, "trim")
        for k in range(1, lames, 2):
            add_cone(acc, h + Vector((0.005 + k * 0.034 * scale + 0.02, 0, r0 * (0.98 - 0.05 * k))), Vector((0.5, 0, 1)), 0.014, 0.04, 6, "trim")
    acc.mirror_from(v0, f0)


def pauldron_round(acc, B, scale=1.0):
    """Norse round shoulder shield: big dome with a bronze rim and boss."""
    v0, f0 = len(acc.verts), len(acc.faces)
    h = B.bone["upperarm_l"][0]
    r = (0.1 if B.sex == "Male" else 0.088) * scale * 0.85
    c = h + Vector((0.03, 0.0, 0.03))
    rot = Matrix.Rotation(0.5, 3, 'Y')   # tilted a little outwards
    dome(acc, c, (r, r, r * 0.55), "plate", rot=rot, lat1=math.pi / 2, seg=20, rings=6, thick=0.008)
    dome(acc, c + rot @ Vector((0, 0, r * 0.52)), (r * 0.3, r * 0.3, r * 0.2), "trim", rot=rot, lat1=math.pi / 2, seg=12, rings=3, thick=0.006)
    arc_band(acc, c - rot @ Vector((0, 0, 0.0)), rot @ Vector((0, 0, 1)), Vector((1, 0, 0)), r * 1.0, r * 1.0, 0.014, -math.pi, math.pi, "trim", steps=24, rings=2, thick=0.005)
    # lower tier under it
    arc_band(acc, h + Vector((0.01, 0, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), r * 0.9, r * 0.82, 0.09, -2.2, 2.2, "leather", steps=14, rings=3, thick=0.006)
    acc.mirror_from(v0, f0)


def pauldron_small(acc, B):
    v0, f0 = len(acc.verts), len(acc.faces)
    h = B.bone["upperarm_l"][0]; r = (0.082 if B.sex == "Male" else 0.07) * 0.88
    dome(acc, h + Vector((0.015, 0, 0.01)), (r * 1.05, r * 1.1, r * 0.8), "plate", lat1=math.pi / 2 + 0.2, seg=16, rings=6, thick=0.006)
    arc_band(acc, h + Vector((0.0, 0, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), r * 0.98, r * 0.92, 0.05, -2.0, 2.0, "leather", steps=14, rings=3, thick=0.006)
    arc_band(acc, h + Vector((0.048, 0, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), r * 0.93, r * 0.93, 0.012, -2.0, 2.0, "trim", steps=14, rings=2, thick=0.004)
    acc.mirror_from(v0, f0)


def pauldron_disc(acc, B):
    """Hoplite shoulder guards: two stacked bronze lames."""
    v0, f0 = len(acc.verts), len(acc.faces)
    h = B.bone["upperarm_l"][0]; r = (0.085 if B.sex == "Male" else 0.073) * 0.88
    dome(acc, h + Vector((0.012, 0, 0.01)), (r * 1.1, r * 1.15, r * 0.85), "plate", lat1=math.pi / 2 + 0.3, seg=16, rings=6, thick=0.006)
    for k in range(2):
        arc_band(acc, h + Vector((0.01 + k * 0.04, 0, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), r * (1.0 - 0.05 * k), r * (0.97 - 0.05 * k), 0.048, -1.9, 1.9, "plate", steps=16, rings=3, thick=0.006)
    arc_band(acc, h + Vector((0.01 + 0.04 + 0.046, 0, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), r * 0.93, r * 0.93, 0.012, -1.9, 1.9, "trim", steps=16, rings=2, thick=0.004)
    acc.mirror_from(v0, f0)


def elbow_and_knee(acc, B, elbow=True, knee=True, spike=False):
    v0, f0 = len(acc.verts), len(acc.faces)
    if elbow:
        e = B.bone["lowerarm_l"][0]
        dome(acc, e + Vector((0.0, 0.03, 0.0)), (0.055, 0.052, 0.05), "plate", rot=Matrix.Rotation(-math.pi / 2, 3, 'X'), lat1=math.pi / 2 + 0.2, seg=14, rings=5, thick=0.006)
        if spike:
            add_cone(acc, e + Vector((0.0, 0.08, 0.0)), Vector((0, 1, 0.1)), 0.018, 0.05, 6, "trim")
    if knee:
        k = B.bone["calf_l"][0]
        dome(acc, k + Vector((0, -0.03, 0.0)), (0.07, 0.068, 0.058), "plate", rot=Matrix.Rotation(math.pi / 2, 3, 'X'), lat1=math.pi / 2 + 0.25, seg=16, rings=6, thick=0.006)
        if spike:
            add_cone(acc, k + Vector((0, -0.095, 0.0)), Vector((0, -1, 0)), 0.02, 0.05, 6, "trim")
    acc.mirror_from(v0, f0)


# ------------------------------------------------------------------ helmets (all skinned to Head only)
def head_frame(B):
    c = Vector((0.0, B.head.y - 0.002, B.head.z + 0.118))
    return c, B.hs * 0.84


def dome_profile(R, h, steps, pointy=0.0, rim=None):
    pts = list(rim or [])
    for k in range(1, steps + 1):
        phi = (math.pi / 2) * k / steps * 0.985
        pts.append((R * math.cos(phi) ** (1 + pointy), h * math.sin(phi)))
    return pts


def head_force():
    return {"Head": 1.0}


def helmet_nasal(acc, B, tint_nose=True):
    c, s = head_frame(B); R = 0.112 * s
    prof = dome_profile(R, 0.132 * s, 8, 0.45, [(R * 0.99, -0.06 * s), (R * 1.01, -0.02 * s), (R, 0.02 * s)])
    def rim(th): return -0.004 - 0.13 * (max(0.0, min(1.0, (abs(th) - 0.6) / 2.2)) ** 1.2)
    def shape(th, k, r, dz):
        if k == 0: return r, rim(th) * s
        if k == 1: return r, max(dz, rim(th) * s + 0.015)
        if k == 2: return r, max(dz, rim(th) * s + 0.035)
        return r, dz
    lathe(acc, prof, c, 1.0, 1.12, 32, shape, None, "plate", 0.006, force=head_force())
    # brow band + nose guard + rivets
    band_prof = [(R * 1.012, 0.0), (R * 1.012, 0.025 * s)]
    lathe(acc, band_prof, c + Vector((0, 0, 0.0)), 1.0, 1.12, 32, lambda th, k, r, dz: (r, (rim(th) + dz * (1 if k else 0) * 0.0 + (0.0 if k == 0 else 0.026)) * s), lambda th, dz: abs(th) > 2.0, "trim", 0.004, force=head_force())
    front_y = c.y - R * 1.12 - 0.004
    add_box(acc, Vector((0, front_y, c.z - 0.028 * s)), (0.013 * s, 0.007, 0.055 * s), "trim", force=head_force())
    for sx in (-1, 1):
        add_cone(acc, Vector((sx * R * 0.98 * 0.78, c.y - R * 1.12 * 0.62, c.z + 0.012 * s)), Vector((sx * 0.6, -0.8, 0)), 0.007, 0.006, 6, "trim", force=head_force())
    add_cone(acc, c + Vector((0, 0, 0.128 * s)), Vector((0, 0, 1)), 0.014, 0.02, 8, "trim", force=head_force())


def helmet_great(acc, B):
    """Rounded armet/sallet: domed skull, tapering face guard with an eye slit and breathing slits, comb on top."""
    c, s = head_frame(B); R = 0.116 * s
    zs = [-0.15, -0.125, -0.1, -0.075, -0.05, -0.028, -0.008, 0.015, 0.04]
    prof = [(R * (0.8 + 0.2 * sstep(-0.16, 0.0, z)), z * s) for z in zs]
    prof += dome_profile(R * 0.995, 0.118 * s, 8, 0.0)
    def shape(th, k, r, dz):
        # the face guard pushes forward into a soft point; the back of the neck is cut short
        f = 1.0 + 0.1 * max(0.0, math.cos(min(abs(th), 1.4) * math.pi / 2.8)) ** 2 * (1 - sstep(-0.05, 0.03, dz / s)) * sstep(-0.16, -0.06, dz / s)
        z = dz + (0.035 * s * sstep(1.8, 3.0, abs(th)) if dz < 0 else 0.0)
        return r * f, z
    def cut(th, dz):
        dz /= s
        if abs(th) < 0.85 and -0.03 < dz < -0.012: return True                              # eye slit
        if abs(th) < 0.62 and -0.115 < dz < -0.045 and int(abs(th) / 0.13 + 0.5) % 2 == 0 and abs(th) > 0.05: return True   # breathing slits
        return False
    lathe(acc, prof, c, 1.0, 1.12, 40, shape, cut, "plate", 0.006, force=head_force())
    lathe(acc, [(R * 1.0, 0.0 * s), (R * 1.0, 0.016 * s)], c, 1.0, 1.12, 40, lambda th, k, r, dz: (r * (1.0 + 0.1 * max(0.0, math.cos(min(abs(th), 1.4) * math.pi / 2.8)) ** 2 * 0.0), dz), lambda th, dz: abs(th) > 1.9, "trim", 0.004, force=head_force())   # brow band
    zdome = lambda y: c.z + 0.118 * s * max(0.0, 1 - ((y - c.y) / (R * 1.12)) ** 2) ** 0.5 - 0.003
    crest(acc, B, c, s, c.y - R * 0.9, c.y + R * 1.0, 0.03 * s, 0.012, "trim", zdome)
    for sx in (-1, 1):
        add_cone(acc, Vector((sx * R * 0.72, c.y - R * 1.12 * 0.6, c.z - 0.02 * s)), Vector((sx * 0.5, -0.8, 0)), 0.006, 0.006, 6, "trim", force=head_force())


def crest(acc, B, c, s, y0, y1, h, w, mat, z_base_fn):
    n = 14; cos = []; faces = []
    for k in range(n + 1):
        y = y0 + (y1 - y0) * k / n
        zb = z_base_fn(y); zt = zb + h * (math.sin(math.pi * (0.12 + 0.76 * k / n)) ** 0.7)
        cos.append(Vector((w / 2, y, zb))); cos.append(Vector((w / 2, y, zt)))
    for k in range(n):
        a = 2 * k; faces.append([a, a + 2, a + 3, a + 1])
    acc.sheet(cos, faces, mat, box_uv(UVS[mat]), w, force=head_force())


def helmet_corinthian(acc, B):
    c, s = head_frame(B); R = 0.116 * s
    zs = [-0.145, -0.115, -0.085, -0.06, -0.04, -0.02, -0.0, 0.025, 0.05]
    prof = [(R * (0.93 + 0.07 * sstep(-0.15, -0.04, z)), z * s) for z in zs]
    prof += dome_profile(R * 0.995, 0.122 * s, 6, 0.1)[:]
    def shape(th, k, r, dz):
        # cheeks flare a little forward/out, brow ridge on the front
        f = 1.0 + 0.035 * math.exp(-((abs(th) - 0.95) / 0.5) ** 2) * (1 if dz < 0 else 0)
        return r * f, dz
    def cut(th, dz):
        dz /= s
        if 0.12 < abs(th) < 0.82 and -0.045 < dz < -0.006: return True          # eyes
        if abs(th) < 0.58 and -0.145 < dz < -0.075: return True                 # mouth/chin opening
        return False
    lathe(acc, prof, c, 1.0, 1.12, 36, shape, cut, "plate", 0.007, force=head_force())
    # cheek/brow trim ring + crest
    lathe(acc, [(R * 1.0 + 0.003, 0.05 * s), (R * 1.0 + 0.003, 0.064 * s)], c, 1.0, 1.12, 36, None, None, "trim", 0.004, force=head_force())
    zdome = lambda y: c.z + 0.118 * s * max(0.0, 1 - ((y - c.y) / (R * 1.12)) ** 2) ** 0.5 - 0.004
    crest(acc, B, c, s, c.y - R * 1.0, c.y + R * 1.12, 0.085 * s, 0.022, "cloth", zdome)
    crest(acc, B, c, s, c.y - R * 0.85, c.y + R * 0.95, 0.018 * s, 0.03, "trim", zdome)


def helmet_norse(acc, B):
    c, s = head_frame(B); R = 0.113 * s
    prof = dome_profile(R, 0.118 * s, 7, 0.15, [(R * 1.0, -0.075 * s), (R * 1.02, -0.03 * s), (R * 1.01, 0.0)])
    def rim(th): return 0.0 - 0.08 * (max(0.0, min(1.0, (abs(th) - 0.7) / 2.4)) ** 1.1)
    def shape(th, k, r, dz):
        if k == 0: return r, rim(th) * s
        if k == 1: return r, max(dz, rim(th) * s + 0.02)
        return r, dz
    lathe(acc, prof, c, 1.0, 1.12, 32, shape, None, "plate", 0.007, force=head_force())
    lathe(acc, [(R * 1.015 + 0.002, 0.0), (R * 1.015 + 0.002, 0.03 * s)], c, 1.0, 1.12, 32, lambda th, k, r, dz: (r, (rim(th) + (0.0 if k == 0 else 0.03)) * s), None, "trim", 0.005, force=head_force())
    front_y = c.y - R * 1.12 - 0.004
    add_box(acc, Vector((0, front_y, c.z - 0.03 * s)), (0.01 * s, 0.006, 0.05 * s), "trim", force=head_force())
    # mail aventail around back and sides
    prof_m = [(R * 1.03, -0.01 * s), (R * 1.05, -0.06 * s), (R * 1.12, -0.115 * s), (R * 1.22, -0.165 * s)]
    lathe(acc, prof_m, c, 1.0, 1.1, 32, lambda th, k, r, dz: (r, dz - 0.05 * s * max(0.0, abs(th) - 1.6) * (1 if k > 0 else 0)), lambda th, dz: abs(th) < 1.05, "mail", 0.006, force=head_force())
    # horns
    for sx in (-1, 1):
        path = [Vector((sx * R * 0.98, c.y, c.z + 0.04 * s)), Vector((sx * (R + 0.05), c.y - 0.005, c.z + 0.055 * s)), Vector((sx * (R + 0.105), c.y - 0.015, c.z + 0.1 * s)),
                Vector((sx * (R + 0.125), c.y - 0.03, c.z + 0.165 * s)), Vector((sx * (R + 0.112), c.y - 0.05, c.z + 0.225 * s))]
        add_tube(acc, path, [0.024, 0.02, 0.0145, 0.009, 0.002], 8, "bone", force=head_force())
        add_cone(acc, path[0] + Vector((0, 0, 0)), Vector((-sx, 0, 0)), 0.03, 0.012, 10, "trim", force=head_force())


def helmet_dark(acc, B):
    c, s = head_frame(B); R = 0.115 * s
    zs = [-0.155, -0.125, -0.095, -0.065, -0.04, -0.022, -0.004, 0.02, 0.05]
    prof = [(R * (0.88 + 0.12 * sstep(-0.16, -0.03, z)), z * s) for z in zs]
    prof += dome_profile(R, 0.15 * s, 7, 0.65)[:]
    def shape(th, k, r, dz):
        beak = 0.05 * s * max(0.0, math.cos(min(abs(th), 1.2) * math.pi / 2.4)) ** 1.6 * sstep(-0.13, -0.075, dz / s) * (1 - sstep(0.0, 0.06, dz / s))
        return r + beak / 1.12, dz
    def cut(th, dz):
        dz /= s
        if abs(th) < 0.95 and -0.034 < dz < -0.012: return True            # eye slit (angled look)
        if 0.18 < abs(th) < 0.95 and -0.095 < dz < -0.07 and int(abs(th) / 0.2) % 2 == 1: return True
        return False
    lathe(acc, prof, c, 1.0, 1.12, 36, shape, cut, "plate", 0.007, force=head_force())
    lathe(acc, [(R * 0.9 + 0.003, -0.155 * s), (R * 0.9 + 0.003, -0.14 * s)], c, 1.0, 1.12, 36, None, None, "trim", 0.004, force=head_force())
    add_cone(acc, c + Vector((0, 0.0, 0.147 * s)), Vector((0, 0, 1)), 0.018, 0.07, 8, "trim", force=head_force())
    for sx in (-1, 1):   # swept-back blades
        pts = [Vector((sx * R * 0.95, c.y + 0.02, c.z + 0.04 * s)), Vector((sx * (R + 0.04), c.y + 0.07, c.z + 0.08 * s)), Vector((sx * (R + 0.075), c.y + 0.14, c.z + 0.13 * s)), Vector((sx * (R + 0.085), c.y + 0.21, c.z + 0.2 * s))]
        add_tube(acc, pts, [0.016, 0.014, 0.009, 0.002], 6, "trim", force=head_force())
    for z in (-0.1, -0.03):
        for sx in (-1, 1):
            add_cone(acc, Vector((sx * R * 0.55, c.y - R * 1.12 * 0.8, c.z + z * s)), Vector((sx * 0.4, -0.9, 0)), 0.006, 0.006, 6, "trim", force=head_force())


# ------------------------------------------------------------------ cloth pieces
def surcoat(acc, B, z_top, z_bot, half_w, mat="cloth", flare=0.05, front=True, back=True, point=0.07, trim_mat="trim"):
    """Tabard panels (front/back) with a pointed hem, a trim border and a centre stripe; follows the belly curve."""
    for sign in ((-1,) if front else ()) + ((1,) if back else ()):
        cols = 8; rows = 9; cos = []; faces = []; hem = []
        def prof(z):
            ys = [B.co[i].y for i in range(len(B.co)) if abs(B.co[i].z - z) < 0.035 and abs(B.co[i].x) < half_w * 0.9 and B.dom[i] in (TORSO | {"pelvis"} | set(THIGH))]
            return (min(ys) if sign < 0 else max(ys)) if ys else (-0.12 if sign < 0 else 0.14)
        rows_y = [prof(z_top + (z_bot - z_top) * r / rows) for r in range(rows + 1)]
        def yf(u, t, r): return (rows_y[r] - 0.05 - 0.02 * u * u) if sign < 0 else (rows_y[r] + 0.05 + 0.02 * u * u)
        for r in range(rows + 1):
            t = r / rows
            for cc in range(cols + 1):
                u = cc / cols * 2 - 1
                hw = half_w * (1.0 + flare * 3 * t)
                z = z_top + (z_bot - z_top) * t - point * t * t * (1 - abs(u))
                cos.append(Vector((u * hw, yf(u, t, r), z)))
        for r in range(rows):
            for cc in range(cols):
                a_ = r * (cols + 1) + cc
                faces.append([a_, a_ + 1, a_ + cols + 2, a_ + cols + 1] if sign < 0 else [a_, a_ + cols + 1, a_ + cols + 2, a_ + 1])
        acc.sheet(cos, faces, mat, box_uv(UVS[mat]), 0.004)
        # trim: hem border (last two rows) and a centre stripe
        for rr in ((rows - 1, rows),):
            c2 = []; f2 = []
            for r in range(rr[0], rr[1] + 1):
                for cc in range(cols + 1):
                    c2.append(cos[r * (cols + 1) + cc] + Vector((0, (-1 if sign < 0 else 1) * 0.004, 0)))
            for cc in range(cols):
                a_ = cc; f2.append([a_, a_ + 1, a_ + cols + 2, a_ + cols + 1] if sign < 0 else [a_, a_ + cols + 1, a_ + cols + 2, a_ + 1])
            acc.sheet(c2, f2, trim_mat, box_uv(UVS[trim_mat]), 0.003)
        c3 = []; f3 = []
        for r in range(rows + 1):
            for cc in (cols // 2 - 0, cols // 2 + 1):
                c3.append(cos[r * (cols + 1) + min(cc, cols)] + Vector((0, (-1 if sign < 0 else 1) * 0.004, 0)))
        for r in range(rows):
            a_ = r * 2; f3.append([a_, a_ + 1, a_ + 3, a_ + 2] if sign < 0 else [a_, a_ + 2, a_ + 3, a_ + 1])
        acc.sheet(c3, f3, trim_mat, box_uv(UVS[trim_mat]), 0.003)


def pteruges(acc, B, z_top, strips=20, length=0.24, radius=0.21, mat="leather", rows=1):
    for rw in range(rows):
        for i in range(strips):
            a = 2 * math.pi * (i + 0.5 * rw) / strips; w = math.pi / strips * 0.82
            cos = []; faces = []
            for k in range(4):
                t = k / 3; z = z_top - rw * length * 0.35 - length * t; rad = radius * (1.0 + 0.55 * t) * (0.97 if rw else 1.0)
                for sgn in (-1, 1):
                    aa = a + sgn * w * (1.0 - 0.15 * t)
                    cos.append(Vector((math.sin(aa) * rad * 1.0, B.bone["pelvis"][0].y - math.cos(aa) * rad * 0.85, z)))
            for k in range(3):
                faces.append([2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2])
            acc.sheet(cos, faces, mat, box_uv(UVS[mat]), 0.004)
            add_cone(acc, cos[0] * 0.5 + cos[1] * 0.5 + Vector((0, 0, -0.01)), Vector((0, 0, -1)), 0.006, 0.006, 5, "trim")


# ------------------------------------------------------------------ the five sets
def boots(acc, B, mat="plate", off=0.016, lead=0.0):
    """Closed shoes: loft along ankle->toe axis, capped at the toe, so no toes show."""
    def ax(sd):
        h = B.bone["foot_" + sd][0]; tl = B.bone["ball_" + sd][1]
        d = tl - h
        return h + Vector((0, 0, 0.0)), h + d * 1.0
    limb(acc, B, "foot", -0.05, 0.86, lambda t, th: off, mat, 0.005, 4, 20, ax, True)


def base_legs(acc, B):
    """Linen trousers, leather boots with a turned cuff and a sole (the Ranger ones are baggy and swallow thin plates)."""
    zp = B.bone["pelvis"][0].z
    torso(acc, B, zp - 0.03, zp + 0.07, lambda z, th: 0.014, "pants", 0.005)
    limb(acc, B, "thigh", 0.0, 1.0, lambda t, th: 0.014, "pants", 0.005)
    limb(acc, B, "calf", 0.0, 1.0, lambda t, th: 0.013, "pants", 0.005)
    limb(acc, B, "calf", 0.55, 1.0, lambda t, th: 0.02, "leather", 0.005, 1)          # boot shaft
    limb(acc, B, "calf", 0.5, 0.58, lambda t, th: 0.03, "leather", 0.005)             # turned-down cuff
    limb(acc, B, "calf", 0.55, 0.575, lambda t, th: 0.034, "trim", 0.004)
    boots(acc, B, "leather", 0.014)
    for sd in (-1, 1):                                                                 # dark sole slab
        add_box(acc, Vector((sd * B.bone["foot_l"][0].x, -0.035, 0.007)), (0.047, 0.108, 0.008), "trim")


def common_torso_plate(acc, B, lames=True, ridge=0.012, breast_off=0.03, smooth_it=3):
    zt = zt_chest(B); zl = B.bone["spine_01"][0].z + 0.02
    def chest(z, th):
        o = breast_off
        if z > zl + 0.2: o += ridge * max(0.0, 1 - abs(th) / 0.3)
        return o
    torso(acc, B, zl + 0.1, zt, chest, "plate", 0.007, smooth=smooth_it)
    def belly(z, th):
        sx = ((zl + 0.1 - z) / 0.045) % 1.0
        return 0.024 + 0.013 * sx
    torso(acc, B, B.bone["pelvis"][0].z + 0.05, zl + 0.1, belly, "plate", 0.006, smooth=2)
    return zt, zl


def fauld(acc, B, n=3, off=0.032):
    z1 = B.bone["pelvis"][0].z + 0.06; lam = 0.05
    def f(z, th):
        sx = ((z1 - z) / lam) % 1.0
        return off - 0.006 + 0.012 * sx
    torso(acc, B, z1 - lam * n + 0.02, z1, f, "plate", 0.006, smooth=1)
    limb(acc, B, "thigh", 0.0, 0.24, lambda t, th: 0.04 + 0.012 * ((t / 0.075) % 1.0), "plate", 0.006, 1)


def tunic(acc, B, z_top_extra=0.0, mat="pants"):
    """Padded cloth tunic (hip to collar) + leather belt: the base of every starter set."""
    zt = zt_chest(B); zp = B.bone["pelvis"][0].z
    torso(acc, B, zp - 0.02, zt + z_top_extra, lambda z, th: 0.016, mat, 0.005, smooth=1)
    band(acc, B, None, zp + 0.045, zp + 0.1, 0.026, "leather")
    add_box(acc, Vector((0, -0.145, zp + 0.072)), (0.024, 0.007, 0.024), "trim")
    return zt, zp


def breastplate(acc, B, mat="plate", off=0.03, ridge=0.012):
    zt = zt_chest(B); zl = B.bone["spine_01"][0].z + 0.02
    torso(acc, B, zt - 0.01, zt + 0.045, lambda z, th: 0.016, "plate", 0.005, smooth=1)   # gorget
    band(acc, B, None, zt + 0.04, zt + 0.05, 0.02, "trim")
    def chest(z, th):
        return off + (ridge * max(0.0, 1 - abs(th) / 0.3) if z > zl + 0.18 else 0.0)
    torso(acc, B, zl + 0.08, zt, chest, mat, 0.006, smooth=2, face_ok=lambda zc, thc: abs(thc) < 2.0)   # front + sides; open at the back like a strapped cuirass
    band(acc, B, None, zt - 0.015, zt, off + 0.006, "trim")
    return zt, zl


def vambraces(acc, B, mat="leather", straps=True):
    limb(acc, B, "lowerarm", 0.3, 0.92, lambda t, th: 0.016, mat, 0.005)
    if straps:
        for tt in (0.4, 0.62, 0.84):
            limb(acc, B, "lowerarm", tt - 0.025, tt + 0.01, lambda t, th: 0.024, "leather" if mat != "leather" else "trim", 0.004)


def build_footman(B):
    """Soldado de Leva: gambesón acolchado, cuello de malla, tabardo rojo, yelmo nasal."""
    acc = Acc(B)
    base_legs(acc, B)
    helmet_nasal(acc, B)
    zt, zp = tunic(acc, B, 0.0)
    torso(acc, B, zt - 0.03, zt + 0.04, lambda z, th: 0.028, "mail", 0.005, smooth=1)   # mail collar
    vambraces(acc, B, "leather")
    pauldron_small(acc, B)
    surcoat(acc, B, zt - 0.04, 0.62, 0.13, "cloth", 0.02, True, True, 0.06)
    return acc


def build_knight(B):
    """Escudero de Acero: peto de acero sobre túnica, hombreras pequeñas, brazales, tabardo azul."""
    acc = Acc(B)
    base_legs(acc, B)
    helmet_great(acc, B)
    zt, zp = tunic(acc, B, 0.0)
    breastplate(acc, B, "plate", 0.03, 0.012)
    pauldron_small(acc, B)
    vambraces(acc, B, "plate")
    surcoat(acc, B, zp + 0.03, 0.62, 0.11, "cloth", 0.03, True, True, 0.05)
    return acc


def build_hoplite(B):
    """Panoplia de Bronce: coraza de bronce, pteruges de cuero, hombreras de disco, grebas atadas."""
    acc = Acc(B)
    base_legs(acc, B)
    helmet_corinthian(acc, B)
    zt = zt_chest(B); zp = B.bone["pelvis"][0].z
    torso(acc, B, zp + 0.0, zt, lambda z, th: 0.017, "plate", 0.006, smooth=0)
    torso(acc, B, zt - 0.01, zt + 0.045, lambda z, th: 0.016, "plate", 0.005, smooth=1)
    band(acc, B, None, zt + 0.04, zt + 0.05, 0.02, "trim")
    band(acc, B, None, zt - 0.03, zt, 0.026, "trim")
    band(acc, B, None, zp + 0.03, zp + 0.09, 0.027, "leather")
    band(acc, B, None, zp + 0.092, zp + 0.1, 0.028, "trim")
    pteruges(acc, B, zp + 0.06, 20, 0.18, 0.2, "leather", 2)
    pauldron_disc(acc, B)
    vambraces(acc, B, "leather")
    limb(acc, B, "calf", 0.12, 0.62, lambda t, th: 0.03 + (0.01 if math.cos(th) > 0.35 else 0), "plate", 0.006, 2)   # media greba de bronce
    return acc


def build_norse(B):
    """Cota del Norte: jerkin de cuero con bandolera, cofia de malla, hombreras redondas, yelmo astado."""
    acc = Acc(B)
    base_legs(acc, B)
    helmet_norse(acc, B)
    zt, zp = tunic(acc, B, 0.0, "leather")
    zl = B.bone["spine_01"][0].z + 0.02
    def strap(zc, thc):
        c = math.asin(max(-1.0, min(1.0, -(zc - (zl + 0.18)) * 0.55 / 0.17)))
        return abs(thc) < 1.5 and abs(thc - c) < 0.17
    torso(acc, B, zl, zt, lambda z, th: 0.034, "trim", 0.004, face_ok=strap, segs=120)
    torso(acc, B, zt - 0.025, zt + 0.035, lambda z, th: 0.03, "mail", 0.005, smooth=1)
    vambraces(acc, B, "leather")
    pauldron_round(acc, B, 0.85)
    return acc


def build_dark(B):
    """Hierro Ennegrecido: peto oscuro con púas, hombreras de dos láminas, brazales, faldón rasgado."""
    acc = Acc(B)
    base_legs(acc, B)
    helmet_dark(acc, B)
    zt, zp = tunic(acc, B, 0.0)
    breastplate(acc, B, "plate", 0.032, 0.02)
    pauldron_stack(acc, B, 2, True, True, 0.9)
    vambraces(acc, B, "plate")
    pteruges(acc, B, zp + 0.0, 12, 0.3, 0.19, "cloth", 1)
    return acc


SETS = {"footman": build_footman, "knight": build_knight, "hoplite": build_hoplite, "norse": build_norse, "dark": build_dark}

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(SETS)
    for sex in ("Male", "Female"):
        for name in only:
            B = Body(sex)
            acc = SETS[name](B)
            L.export(acc, f"{sex}_Armor_{name.capitalize()}")
            print("built", sex, name, len(acc.verts), "verts", len(acc.faces), "faces")
    print("armor done")
