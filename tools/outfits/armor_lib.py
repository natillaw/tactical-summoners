"""Geometry helpers to build skinned armor pieces on top of the Quaternius Superhero bodies (Blender, bpy).
Shells are offset copies of body regions (so they keep the body weights and its anatomy); helmets, pauldrons,
horns, tabards... are built from primitives and skinned by nearest body vertex (helmets: Head only)."""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix, kdtree

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
BODY_DIR = os.path.join(ROOT, "assets", "models", "creator", "body")
OUT_DIR = os.path.join(ROOT, "assets", "models", "creator", "armor")
UVS = {"plate": 4.0, "mail": 7.0, "leather": 5.0, "trim": 4.0, "cloth": 3.0, "bone": 5.0}   # texture tiles per metre
MATS = ["plate", "mail", "leather", "trim", "cloth", "bone"]


class Body:
    def __init__(self, sex):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.join(BODY_DIR, f"Superhero_{sex}_FullBody.gltf"))
        for o in [o for o in bpy.data.objects if o.name.startswith("Icosphere")]:
            bpy.data.objects.remove(o)
        self.sex = sex
        self.arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
        self.obj = next(o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith("Super"))
        me = self.obj.data
        bm = bmesh.new(); bm.from_mesh(me); bm.normal_update()
        self.co = [v.co.copy() for v in bm.verts]
        self.nor = [v.normal.copy() for v in bm.verts]
        bm.free()
        names = {g.index: g.name for g in self.obj.vertex_groups}
        self.w = []; self.dom = []
        for v in me.vertices:
            d = {names[g.group]: g.weight for g in v.groups if g.weight > 0.01}
            self.w.append(d); self.dom.append(max(d, key=d.get) if d else "pelvis")
        self.faces = [tuple(p.vertices) for p in me.polygons]
        self.bone = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in self.arm.data.bones}
        self.kd = kdtree.KDTree(len(self.co))
        for i, c in enumerate(self.co):
            self.kd.insert(c, i)
        self.kd.balance()
        self.head = self.bone["Head"][0]
        self.hs = 1.0 if sex == "Male" else 0.94         # head size factor

    def t(self, i, bone):
        h, tl = self.bone[bone]; d = tl - h
        return (self.co[i] - h).dot(d) / d.length_squared

    def nearest_w(self, p):
        _, i, _ = self.kd.find(p)
        return self.w[i]


class Acc:
    """Accumulates sheets/solids with per-face material + per-loop UV + optional forced weights."""
    def __init__(self, body):
        self.B = body; self.verts = []; self.faces = []; self.mat = []; self.uv = []; self.smooth = []; self.force = {}

    def _add(self, cos, faces, mat, uvs, smooth=True, force=None):
        base = len(self.verts); self.verts += cos
        for f, uv in zip(faces, uvs):
            self.faces.append([base + i for i in f]); self.mat.append(mat); self.uv.append(uv); self.smooth.append(smooth)
        if force:
            for i in range(len(cos)):
                self.force[base + i] = force
        return base

    def sheet(self, cos, faces, mat, uvf, thick=0.007, normals=None, smooth=True, force=None, close=True):
        """Open surface -> thick shell (outer faces + inner faces + rim). uvf(co, normal)->(u, v) per vertex."""
        n = len(cos)
        if normals is None:
            normals = [Vector() for _ in cos]
            for f in faces:
                pts = [cos[i] for i in f]; fn = (pts[1] - pts[0]).cross(pts[-1] - pts[0])
                for i in f:
                    normals[i] += fn
            normals = [v.normalized() if v.length > 1e-9 else Vector((0, 0, 1)) for v in normals]
        uvv = [uvf(cos[i], normals[i]) for i in range(n)]
        out_faces, out_uv = [], []
        for f in faces:
            out_faces.append(list(f)); out_uv.append(self._cont([uvv[i] for i in f]))
        verts = list(cos)
        if thick > 0 and close:
            verts += [cos[i] - normals[i] * thick for i in range(n)]
            for f in faces:
                rf = [i + n for i in reversed(f)]; out_faces.append(rf); out_uv.append(self._cont([uvv[i - n] for i in rf]))
            edges = {}
            for f in faces:
                for a, b in zip(f, list(f[1:]) + [f[0]]):
                    edges.setdefault((min(a, b), max(a, b)), []).append((a, b))
            for lst in edges.values():
                if len(lst) == 1:
                    a, b = lst[0]
                    out_faces.append([b, a, a + n, b + n]); out_uv.append(self._cont([uvv[b], uvv[a], uvv[a], uvv[b]]))
        return self._add(verts, out_faces, mat, out_uv, smooth, force)

    @staticmethod
    def _cont(uvs):
        return list(uvs)

    def mirror_from(self, v0, f0):
        """Append an X-mirrored copy of everything added since (v0, f0)."""
        base = len(self.verts); n_v = base - v0
        for i in range(v0, base):
            c = self.verts[i]; self.verts.append(Vector((-c.x, c.y, c.z)))
            if i in self.force:
                self.force[len(self.verts) - 1] = self.force[i]
        n_f = len(self.faces)
        for k in range(f0, n_f):
            self.faces.append([base + (i - v0) for i in reversed(self.faces[k])]); self.mat.append(self.mat[k])
            self.uv.append(list(reversed(self.uv[k]))); self.smooth.append(self.smooth[k])

    def to_object(self, name):
        B = self.B
        me = bpy.data.meshes.new(name); ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
        me.from_pydata([tuple(v) for v in self.verts], [], self.faces); me.update()
        uvl = me.uv_layers.new(name="UVMap")
        for p, uv in zip(me.polygons, self.uv):
            for li, (u, v) in zip(p.loop_indices, uv):
                uvl.data[li].uv = (u, v)
        for m in MATS:
            mt = bpy.data.materials.new(m); mt.use_nodes = True; me.materials.append(mt)
        for p, m, s in zip(me.polygons, self.mat, self.smooth):
            p.material_index = MATS.index(m); p.use_smooth = s
        for g in B.arm.data.bones:
            ob.vertex_groups.new(name=g.name)
        for i, c in enumerate(self.verts):
            w = self.force.get(i) or B.nearest_w(c)
            tot = sum(w.values()) or 1.0
            for g, val in w.items():
                ob.vertex_groups[g].add([i], val / tot, 'REPLACE')
        ob.parent = B.arm; mod = ob.modifiers.new("Armature", 'ARMATURE'); mod.object = B.arm
        return ob


def cyl_uv(origin, axis, scale, ntiles):
    """Cylindrical UV around an axis: u = angle * ntiles (integer, so it tiles), v = along-axis * scale."""
    a = axis.normalized(); e1 = a.cross(Vector((0, 0, 1)) if abs(a.z) < 0.9 else Vector((1, 0, 0))).normalized(); e2 = a.cross(e1)
    def f(co, n):
        d = co - origin
        return (math.atan2(d.dot(e2), d.dot(e1)) / (2 * math.pi) * ntiles, d.dot(a) * scale)
    return f


def box_uv(scale):
    def f(co, n):
        ax = max(range(3), key=lambda k: abs(n[k]))
        c = [co.x, co.y, co.z]; r = [i for i in range(3) if i != ax]
        return (c[r[0]] * scale, c[r[1]] * scale)
    return f


def shell(acc, pred, off, mat, thick=0.007, uvf=None, face_pred=None, smooth=0):
    """Offset copy of the body faces whose vertices all satisfy pred(i)."""
    B = acc.B
    inc = [pred(i) for i in range(len(B.co))]
    faces = [f for f in B.faces if sum(1 for i in f if inc[i]) >= len(f) - 1 and (face_pred is None or face_pred(f))]
    if not faces:
        return
    vm = {}; cos = []; nor = []
    for f in faces:
        for i in f:
            if i not in vm:
                vm[i] = len(cos); cos.append(B.co[i] + B.nor[i] * off(i)); nor.append(B.nor[i])
    nf = [[vm[i] for i in f] for f in faces]
    if smooth:
        # Laplacian-smooth the interior so plates read as designed pieces rather than anatomy; the rim stays pinned
        edges = {}
        for f in nf:
            for a, b in zip(f, f[1:] + f[:1]):
                edges.setdefault((min(a, b), max(a, b)), 0); edges[(min(a, b), max(a, b))] += 1
        nb = [set() for _ in cos]; pinned = set()
        for (a, b), c in edges.items():
            nb[a].add(b); nb[b].add(a)
            if c == 1: pinned.update((a, b))
        for _ in range(smooth):
            new = [Vector(c) for c in cos]
            for i, c in enumerate(cos):
                if i in pinned or not nb[i]: continue
                avg = sum((cos[j] for j in nb[i]), Vector()) / len(nb[i]); new[i] = c.lerp(avg, 0.6)
            cos = new
        nor = [None] * len(cos)
        nrm = [Vector() for _ in cos]
        for f in nf:
            pts = [cos[i] for i in f]; fn = (pts[1] - pts[0]).cross(pts[-1] - pts[0])
            for i in f: nrm[i] += fn
        nor = [v.normalized() if v.length > 1e-9 else Vector((0, 0, 1)) for v in nrm]
    acc.sheet(cos, nf, mat, uvf or box_uv(UVS[mat]), thick, normals=nor)


def lathe(acc, profile, center, ax=1.0, ay=1.12, n=32, shape=None, cut=None, mat="plate", thick=0.006, uvs=4.0, force=None, smooth=True):
    """Surface of revolution around Z. profile = [(radius, dz)] bottom->top. Front is -Y (theta=0 at the face).
    shape(theta, k, r, dz) -> (r, dz);  cut(theta, dz_mid) -> True deletes that quad."""
    cos = []; rows = len(profile)
    for k, (r, dz) in enumerate(profile):
        for i in range(n):
            th = 2 * math.pi * i / n
            th = th - 2 * math.pi if th > math.pi else th
            rr, zz = shape(th, k, r, dz) if shape else (r, dz)
            cos.append(Vector((center.x + math.sin(th) * rr * ax, center.y - math.cos(th) * rr * ay, center.z + zz)))
    faces = []
    for k in range(rows - 1):
        for i in range(n):
            j = (i + 1) % n
            th = 2 * math.pi * (i + 0.5) / n
            th = th - 2 * math.pi if th > math.pi else th
            if cut and cut(th, (profile[k][1] + profile[k + 1][1]) / 2):
                continue
            a, b, c, d = k * n + i, k * n + j, (k + 1) * n + j, (k + 1) * n + i
            faces.append([a, d, c, b])
    used = sorted({v for f in faces for v in f}); mp = {v: i for i, v in enumerate(used)}
    cos2 = [cos[v] for v in used]; faces2 = [[mp[v] for v in f] for f in faces]
    acc.sheet(cos2, faces2, mat, box_uv(uvs), thick, force=force, smooth=smooth)


def add_box(acc, center, half, mat="plate", rot=None, uvs=4.0, force=None, smooth=False):
    sx, sy, sz = half; R = rot or Matrix.Identity(3)
    def P(x, y, z):
        return center + R @ Vector((x * sx, y * sy, z * sz))
    quads = [([P(-1, -1, -1), P(-1, 1, -1), P(-1, 1, 1), P(-1, -1, 1)], Vector((-1, 0, 0))),
             ([P(1, -1, -1), P(1, -1, 1), P(1, 1, 1), P(1, 1, -1)], Vector((1, 0, 0))),
             ([P(-1, -1, -1), P(-1, -1, 1), P(1, -1, 1), P(1, -1, -1)], Vector((0, -1, 0))),
             ([P(-1, 1, -1), P(1, 1, -1), P(1, 1, 1), P(-1, 1, 1)], Vector((0, 1, 0))),
             ([P(-1, -1, -1), P(1, -1, -1), P(1, 1, -1), P(-1, 1, -1)], Vector((0, 0, -1))),
             ([P(-1, -1, 1), P(-1, 1, 1), P(1, 1, 1), P(1, -1, 1)], Vector((0, 0, 1)))]
    uvf = box_uv(uvs)
    allc, allf, alluv = [], [], []
    for pts, nv in quads:
        b = len(allc); allc += pts; wn = R @ nv
        allf.append([b, b + 1, b + 2, b + 3]); alluv.append([uvf(p, wn) for p in pts])
    acc._add(allc, allf, mat, alluv, smooth, force)


def add_cone(acc, base, direction, radius, height, seg=10, mat="trim", uvs=4.0, force=None, smooth=True, r_top=0.0):
    a = direction.normalized(); e1 = a.cross(Vector((0, 0, 1)) if abs(a.z) < 0.9 else Vector((1, 0, 0))).normalized(); e2 = a.cross(e1)
    tip = base + a * height
    ring0 = [base + (e1 * math.cos(2 * math.pi * i / seg) + e2 * math.sin(2 * math.pi * i / seg)) * radius for i in range(seg)]
    ring1 = [tip + (e1 * math.cos(2 * math.pi * i / seg) + e2 * math.sin(2 * math.pi * i / seg)) * r_top for i in range(seg)]
    cos = ring0 + ring1 + [base, tip]; faces = []
    for i in range(seg):
        j = (i + 1) % seg
        faces.append([i, j, seg + j, seg + i]); faces.append([j, i, 2 * seg]); faces.append([seg + i, seg + j, 2 * seg + 1])
    uvf = box_uv(uvs)
    uvl = [[uvf(cos[v], cos[v] - base) for v in f] for f in faces]
    acc._add(cos, faces, mat, uvl, smooth, force)


def add_tube(acc, path, radii, seg=8, mat="trim", uvs=4.0, force=None):
    """Tube along a polyline with per-point radius (horns, spikes)."""
    cos = []; faces = []
    for k, p in enumerate(path):
        t = (path[min(k + 1, len(path) - 1)] - path[max(k - 1, 0)]).normalized()
        e1 = t.cross(Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))).normalized(); e2 = t.cross(e1)
        for i in range(seg):
            a = 2 * math.pi * i / seg; cos.append(p + (e1 * math.cos(a) + e2 * math.sin(a)) * radii[k])
    for k in range(len(path) - 1):
        for i in range(seg):
            j = (i + 1) % seg; faces.append([k * seg + i, k * seg + j, (k + 1) * seg + j, (k + 1) * seg + i])
    cos.append(path[0]); cos.append(path[-1]); c0 = len(cos) - 2
    for i in range(seg):
        j = (i + 1) % seg
        faces.append([j, i, c0]); faces.append([(len(path) - 1) * seg + i, (len(path) - 1) * seg + j, c0 + 1])
    uvf = box_uv(uvs); uvl = [[uvf(cos[v], cos[v] - path[0]) for v in f] for f in faces]
    acc._add(cos, faces, mat, uvl, True, force)


def arc_band(acc, origin, axis, up, r0, r1, length, a0, a1, mat="plate", steps=14, rings=3, thick=0.006, uvs=4.0):
    """Curved lame around an axis (pauldron plates). Angles measured from 'up' around the axis."""
    ax = axis.normalized(); u = (up - ax * up.dot(ax)).normalized(); w = ax.cross(u)
    cos = []; faces = []
    for k in range(rings):
        t = k / (rings - 1)
        for i in range(steps + 1):
            a = a0 + (a1 - a0) * i / steps
            r = r0 + (r1 - r0) * t
            cos.append(origin + ax * (length * t) + (u * math.cos(a) + w * math.sin(a)) * r)
    for k in range(rings - 1):
        for i in range(steps):
            a = k * (steps + 1) + i; faces.append([a, a + 1, a + steps + 2, a + steps + 1])
    acc.sheet(cos, faces, mat, box_uv(uvs), thick)


def dome(acc, center, radii, mat="plate", rot=None, lat0=0.0, lat1=math.pi / 2, seg=16, rings=6, thick=0.006, uvs=4.0, force=None):
    """Spherical cap (z up) scaled by radii; lat from 0 (pole) to lat1."""
    R = rot or Matrix.Identity(3); cos = []; faces = []
    for k in range(rings + 1):
        lat = lat0 + (lat1 - lat0) * k / rings
        for i in range(seg):
            a = 2 * math.pi * i / seg
            p = Vector((math.sin(lat) * math.cos(a) * radii[0], math.sin(lat) * math.sin(a) * radii[1], math.cos(lat) * radii[2]))
            cos.append(center + R @ p)
    for k in range(rings):
        for i in range(seg):
            j = (i + 1) % seg; faces.append([k * seg + i, (k + 1) * seg + i, (k + 1) * seg + j, k * seg + j])
    acc.sheet(cos, faces, mat, box_uv(uvs), thick, force=force)


def export(acc, name):
    ob = acc.to_object(name)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); acc.B.arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_DIR, name + ".gltf"), export_format='GLTF_SEPARATE', use_selection=True,
        export_image_format='NONE', export_materials='EXPORT', export_skins=True, export_animations=False, export_yup=True)
