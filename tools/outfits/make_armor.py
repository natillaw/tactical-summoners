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


def limb(acc, B, bone, t0, t1, off, mat, thick=0.006, smooth=0):
    """Shell around a limb segment (bone base name e.g. 'upperarm'); off(i, t) -> offset along the body normal."""
    bl, br = bone + "_l", bone + "_r"
    def pred(i):
        d = B.dom[i]
        if d != bl and d != br: return False
        t = B.t(i, d); return t0 <= t <= t1
    shell(acc, pred, lambda i: off(i, B.t(i, B.dom[i])), mat, thick, limb_uv(B, bone, mat), None, smooth)


def torso(acc, B, z0, z1, off, mat, thick=0.006, bones=TORSO, face_pred=None, smooth=0):
    def pred(i):
        c = B.co[i]; return B.dom[i] in bones and z0 <= c.z <= z1
    shell(acc, pred, lambda i: off(i), mat, thick, torso_uv(B, mat), face_pred, smooth)


def band(acc, B, bones, z0, z1, off, mat="trim", thick=0.005):
    """Thin horizontal strip of the body (trim at hems/collars), slightly proud of the armor under it."""
    torso(acc, B, z0, z1, lambda i: off, mat, thick, bones)


def zt_chest(B):
    return B.bone["clavicle_l"][0].z + 0.045


# ------------------------------------------------------------------ pauldrons / joints (left side then mirrored)
def pauldron_stack(acc, B, lames=4, spike=False, trim=True, scale=1.0, mat="plate"):
    v0, f0 = len(acc.verts), len(acc.faces)
    h = B.bone["upperarm_l"][0]
    r0 = (0.088 if B.sex == "Male" else 0.075) * scale
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
    r = (0.1 if B.sex == "Male" else 0.088) * scale
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
    h = B.bone["upperarm_l"][0]; r = 0.082 if B.sex == "Male" else 0.07
    dome(acc, h + Vector((0.015, 0, 0.01)), (r * 1.05, r * 1.1, r * 0.8), "plate", lat1=math.pi / 2 + 0.2, seg=16, rings=6, thick=0.006)
    arc_band(acc, h + Vector((0.0, 0, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), r * 0.98, r * 0.92, 0.05, -2.0, 2.0, "leather", steps=14, rings=3, thick=0.006)
    arc_band(acc, h + Vector((0.048, 0, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), r * 0.93, r * 0.93, 0.012, -2.0, 2.0, "trim", steps=14, rings=2, thick=0.004)
    acc.mirror_from(v0, f0)


def pauldron_disc(acc, B):
    """Hoplite shoulder guards: two stacked bronze lames."""
    v0, f0 = len(acc.verts), len(acc.faces)
    h = B.bone["upperarm_l"][0]; r = 0.085 if B.sex == "Male" else 0.073
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
    c = Vector((0.0, B.head.y - 0.002, B.head.z + 0.12))
    return c, B.hs


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
    def rim(th): return 0.012 - 0.13 * (max(0.0, min(1.0, (abs(th) - 0.6) / 2.2)) ** 1.2)
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
    add_box(acc, Vector((0, front_y, c.z - 0.025 * s)), (0.009 * s, 0.005, 0.045 * s), "trim", force=head_force())
    for sx in (-1, 1):
        add_cone(acc, Vector((sx * R * 0.98 * 0.78, c.y - R * 1.12 * 0.62, c.z + 0.012 * s)), Vector((sx * 0.6, -0.8, 0)), 0.007, 0.006, 6, "trim", force=head_force())
    add_cone(acc, c + Vector((0, 0, 0.128 * s)), Vector((0, 0, 1)), 0.014, 0.02, 8, "trim", force=head_force())


def helmet_great(acc, B):
    c, s = head_frame(B); R = 0.123 * s
    zs = [-0.155, -0.12, -0.085, -0.055, -0.034, -0.012, 0.012, 0.045, 0.075]
    prof = [(R * (0.95 + 0.05 * sstep(-0.16, -0.05, z)), z * s) for z in zs]
    prof += [(R * 0.985, 0.093 * s), (R * 0.93, 0.108 * s), (R * 0.78, 0.117 * s), (R * 0.5, 0.123 * s), (R * 0.2, 0.126 * s), (0.0, 0.127 * s)]
    def cut(th, dz):
        dz /= s
        if abs(th) < 1.0 and -0.034 < dz < -0.012: return True                  # eye slit
        if abs(th) < 0.1 and -0.12 < dz < -0.012: return True                   # vertical slit (cross)
        if 0.12 < abs(th) < 0.75 and -0.12 < dz < -0.085 and int(abs(th) / 0.17) % 2 == 0: return True   # breathing holes
        return False
    lathe(acc, prof, c, 1.0, 1.1, 36, None, cut, "plate", 0.007, force=head_force())
    for z in (-0.152, 0.07):    # trim hoops
        lathe(acc, [(R * (0.955 if z < 0 else 0.99) + 0.003, z * s), (R * (0.955 if z < 0 else 0.99) + 0.003, (z + 0.014) * s)], c, 1.0, 1.1, 36, None,
              lambda th, dz: abs(th) < 1.0 and z > 0 and False, "trim", 0.004, force=head_force())
    # top ridge
    add_box(acc, c + Vector((0, 0.0, 0.128 * s)), (0.008, 0.1 * s, 0.01), "trim", force=head_force())
    # rivets along the front
    for z in (-0.1, -0.04, 0.03, 0.07):
        for sx in (-1, 1):
            add_cone(acc, Vector((sx * R * 0.5, c.y - R * 1.1 * 0.86 - 0.002, c.z + z * s)), Vector((sx * 0.4, -0.9, 0)), 0.006, 0.006, 6, "trim", force=head_force())


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
        def yf(u, t): return (-0.128 - 0.035 * t - 0.025 * u * u) if sign < 0 else (0.142 + 0.03 * t + 0.025 * u * u)
        for r in range(rows + 1):
            t = r / rows
            for cc in range(cols + 1):
                u = cc / cols * 2 - 1
                hw = half_w * (1.0 + flare * 3 * t)
                z = z_top + (z_bot - z_top) * t - point * t * t * (1 - abs(u))
                cos.append(Vector((u * hw, yf(u, t), z)))
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
def common_torso_plate(acc, B, lames=True, ridge=0.012, breast_off=0.03, smooth_it=6):
    zt = zt_chest(B); zl = B.bone["spine_01"][0].z + 0.02
    def chest(i):
        c = B.co[i]; n = B.nor[i]; o = breast_off
        if n.y < -0.2 and c.z > zl + 0.1: o += ridge * max(0.0, 1 - abs(c.x) / 0.045)
        return o
    torso(acc, B, zl + 0.1, zt, chest, "plate", 0.007, smooth=int(smooth_it))
    def belly(i):
        c = B.co[i]; sx = ((zl + 0.1 - c.z) / 0.045) % 1.0
        return 0.024 + 0.013 * sx
    torso(acc, B, B.bone["pelvis"][0].z + 0.05, zl + 0.1, belly, "plate", 0.006, bones=TORSO | {"pelvis"}, smooth=3)
    return zt, zl


def fauld(acc, B, n=3, off=0.032):
    z1 = B.bone["pelvis"][0].z + 0.06; lam = 0.05
    def f(i):
        c = B.co[i]; sx = ((z1 - c.z) / lam) % 1.0
        return off - 0.006 + 0.012 * sx
    torso(acc, B, z1 - lam * n, z1, f, "plate", 0.006, bones={"pelvis", "spine_01"} | set(THIGH))
    # thigh tassets
    limb(acc, B, "thigh", 0.0, 0.24, lambda i, t: 0.03 + 0.012 * ((t / 0.075) % 1.0), "plate", 0.006)


def build_knight(B):
    acc = Acc(B)
    helmet_great(acc, B)
    zt, zl = common_torso_plate(acc, B)
    fauld(acc, B)
    band(acc, B, TORSO, zt - 0.02, zt, 0.036, "trim")
    pauldron_stack(acc, B, 4, False, True, 1.0)
    elbow_and_knee(acc, B)
    limb(acc, B, "upperarm", 0.45, 0.8, lambda i, t: 0.022, "plate", 0.006)
    limb(acc, B, "lowerarm", 0.12, 0.88, lambda i, t: 0.02 + 0.012 * (1 - t) * 0.8, "plate", 0.006)
    limb(acc, B, "thigh", 0.26, 0.62, lambda i, t: 0.026, "plate", 0.006)
    limb(acc, B, "calf", 0.1, 0.95, lambda i, t: 0.024 + (0.01 if B.nor[i].y < -0.3 else 0), "plate", 0.006)
    shell(acc, lambda i: B.dom[i] in FOOT and B.co[i].z < 0.1 and B.co[i].y < 0.05, lambda i: 0.016, "plate", 0.005, box_uv(UVS["plate"]))
    surcoat(acc, B, B.bone["pelvis"][0].z + 0.02, 0.58, 0.11, "cloth", 0.05, True, True)
    return acc


def build_footman(B):
    acc = Acc(B)
    helmet_nasal(acc, B)
    zt = zt_chest(B); zl = B.bone["spine_01"][0].z
    torso(acc, B, B.bone["pelvis"][0].z + 0.04, zt, lambda i: 0.022, "mail", 0.006, bones=TORSO | {"pelvis"})
    limb(acc, B, "thigh", 0.0, 0.3, lambda i, t: 0.026 + 0.01 * t, "mail", 0.006)
    limb(acc, B, "upperarm", 0.0, 0.92, lambda i, t: 0.018, "mail", 0.006)
    limb(acc, B, "lowerarm", 0.0, 0.18, lambda i, t: 0.017, "mail", 0.006)
    limb(acc, B, "lowerarm", 0.3, 0.9, lambda i, t: 0.016, "plate", 0.005)
    band(acc, B, TORSO | {"pelvis"}, B.bone["pelvis"][0].z + 0.05, B.bone["pelvis"][0].z + 0.115, 0.034, "leather")
    add_box(acc, Vector((0, B.co[0].y * 0 - 0.15, B.bone["pelvis"][0].z + 0.085)), (0.025, 0.008, 0.026), "trim")
    limb(acc, B, "calf", 0.12, 0.88, lambda i, t: 0.02, "leather", 0.005)
    for tt in (0.2, 0.5, 0.78):
        limb(acc, B, "calf", tt - 0.02, tt + 0.02, lambda i, t: 0.026, "trim", 0.004)
    pauldron_small(acc, B)
    elbow_and_knee(acc, B, True, False)
    surcoat(acc, B, zt - 0.03, 0.55, 0.115, "cloth", 0.03, True, True)
    return acc


def build_hoplite(B):
    acc = Acc(B)
    helmet_corinthian(acc, B)
    zt = zt_chest(B); zp = B.bone["pelvis"][0].z
    torso(acc, B, zp + 0.03, zt, lambda i: 0.013, "plate", 0.006, bones=TORSO | {"pelvis"})
    band(acc, B, TORSO, zt - 0.035, zt, 0.021, "trim")
    band(acc, B, TORSO | {"pelvis"}, zp + 0.03, zp + 0.075, 0.02, "trim")
    pteruges(acc, B, zp + 0.06, 20, 0.2, 0.2, "leather", 2)
    pauldron_disc(acc, B)
    limb(acc, B, "upperarm", 0.0, 0.3, lambda i, t: 0.016, "leather", 0.005)
    limb(acc, B, "lowerarm", 0.15, 0.9, lambda i, t: 0.018, "plate", 0.006)
    limb(acc, B, "lowerarm", 0.12, 0.17, lambda i, t: 0.024, "trim", 0.004)
    limb(acc, B, "calf", 0.04, 0.96, lambda i, t: 0.02 + (0.013 if B.nor[i].y < -0.3 else 0), "plate", 0.006)
    limb(acc, B, "calf", 0.04, 0.09, lambda i, t: 0.028, "trim", 0.004)
    elbow_and_knee(acc, B, False, True)
    return acc


def build_norse(B):
    acc = Acc(B)
    helmet_norse(acc, B)
    zt = zt_chest(B); zp = B.bone["pelvis"][0].z
    torso(acc, B, zp + 0.04, zt, lambda i: 0.02, "mail", 0.006, bones=TORSO | {"pelvis"})
    # scale chest plates (rows of small lames) over the mail
    zl = B.bone["spine_01"][0].z + 0.02
    torso(acc, B, zl, zt - 0.015, lambda i: 0.03 + 0.012 * (((zt - B.co[i].z) / 0.032) % 1.0), "plate", 0.005, face_pred=lambda f: B.nor[f[0]].y < 0.45)
    limb(acc, B, "thigh", 0.0, 0.3, lambda i, t: 0.026, "mail", 0.006)
    limb(acc, B, "upperarm", 0.0, 0.95, lambda i, t: 0.018, "mail", 0.006)
    limb(acc, B, "lowerarm", 0.0, 0.2, lambda i, t: 0.017, "mail", 0.006)
    limb(acc, B, "lowerarm", 0.25, 0.92, lambda i, t: 0.016, "leather", 0.005)
    for tt in (0.35, 0.6, 0.85):
        limb(acc, B, "lowerarm", tt - 0.03, tt + 0.01, lambda i, t: 0.024, "trim", 0.004)
    # diagonal leather bandolier + belt
    def strap(f):
        c = sum((B.co[i] for i in f), Vector()) / len(f)
        return abs(c.x * 1.0 + (c.z - (zl + 0.18)) * 0.55) < 0.026
    torso(acc, B, zl, zt, lambda i: 0.043, "leather", 0.004, face_pred=strap)
    band(acc, B, TORSO | {"pelvis"}, zp + 0.045, zp + 0.11, 0.036, "leather")
    add_box(acc, Vector((0, -0.158, zp + 0.078)), (0.03, 0.008, 0.03), "trim")
    limb(acc, B, "calf", 0.1, 0.9, lambda i, t: 0.02, "leather", 0.005)
    for tt in (0.25, 0.55, 0.82):
        limb(acc, B, "calf", tt - 0.025, tt + 0.025, lambda i, t: 0.028, "trim", 0.004)
    pauldron_round(acc, B)
    return acc


def build_dark(B):
    acc = Acc(B)
    helmet_dark(acc, B)
    zt, zl = common_torso_plate(acc, B, ridge=0.02, breast_off=0.032)
    fauld(acc, B, 4, 0.034)
    band(acc, B, TORSO, zt - 0.02, zt, 0.038, "trim")
    pauldron_stack(acc, B, 5, True, True, 1.12)
    elbow_and_knee(acc, B, True, True, True)
    limb(acc, B, "upperarm", 0.5, 0.82, lambda i, t: 0.024, "plate", 0.006)
    limb(acc, B, "lowerarm", 0.1, 0.9, lambda i, t: 0.022 + 0.012 * (1 - t), "plate", 0.006)
    limb(acc, B, "thigh", 0.26, 0.64, lambda i, t: 0.028, "plate", 0.006)
    limb(acc, B, "calf", 0.1, 0.95, lambda i, t: 0.026 + (0.012 if B.nor[i].y < -0.3 else 0), "plate", 0.006)
    shell(acc, lambda i: B.dom[i] in FOOT and B.co[i].z < 0.1 and B.co[i].y < 0.05, lambda i: 0.018, "plate", 0.005, box_uv(UVS["plate"]))
    # tattered tassets
    pteruges(acc, B, B.bone["pelvis"][0].z + 0.0, 12, 0.3, 0.19, "cloth", 1)
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
