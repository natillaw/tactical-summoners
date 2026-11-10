"""Five sword designs edited from the Quaternius Medieval Weapons Pack swords already in the game (assets/models/weapons/*.fbx).
Each one is a copy of a base sword with the blade reshaped, parts added and the palette changed.
    blender -b -P tools/weapons/make_swords.py
Output: assets/models/weapons/custom/<id>.glb  (blade along +Y, same origin convention as the base swords)."""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(ROOT, "assets", "models", "weapons")
OUT = os.path.join(SRC, "custom")
os.makedirs(OUT, exist_ok=True)


def load(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(SRC, name + ".fbx"))
    ob = [o for o in bpy.data.objects if o.type == 'MESH'][0]
    return ob


def mat_color(ob, name, rgb, metal=None, rough=None):
    m = bpy.data.materials.get(name) if name in [x.name for x in ob.data.materials] else None
    if m is None:
        m = bpy.data.materials.new(name); m.use_nodes = True
        ob.data.materials.append(m)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    if metal is not None: bsdf.inputs["Metallic"].default_value = metal
    if rough is not None: bsdf.inputs["Roughness"].default_value = rough
    return [x.name for x in ob.data.materials].index(m.name)


def verts_of(ob, names):
    idx = {i for i, m in enumerate(ob.data.materials) if m.name in names}
    return {v for p in ob.data.polygons if p.material_index in idx for v in p.vertices}


def edit_verts(ob, vset, fn):
    for i in vset:
        v = ob.data.vertices[i]; v.co = fn(v.co.copy())
    ob.data.update()


def span(ob, vset):
    zs = [ob.data.vertices[i].co.z for i in vset]
    return min(zs), max(zs)


def bm_open(ob):
    bm = bmesh.new(); bm.from_mesh(ob.data); return bm


def bm_close(ob, bm):
    bm.to_mesh(ob.data); bm.free(); ob.data.update()


def add_prism(bm, pts2d, y0, y1, mi, plane="xz"):
    """Extrude a 2D outline (in the XZ plane) between y0 and y1."""
    a = [bm.verts.new((x, y0, z)) for x, z in pts2d]; b = [bm.verts.new((x, y1, z)) for x, z in pts2d]
    f = [bm.faces.new(a[::-1]), bm.faces.new(b)]
    n = len(pts2d)
    for i in range(n):
        j = (i + 1) % n; f.append(bm.faces.new((a[i], a[j], b[j], b[i])))
    for face in f: face.material_index = mi; face.smooth = False
    bmesh.ops.recalc_face_normals(bm, faces=f)


def add_cone(bm, base, direction, r1, r2, length, mi, seg=6):
    d = Vector(direction).normalized(); q = d.to_track_quat('Z', 'Y')
    m = Matrix.Translation(Vector(base) + d * length / 2) @ q.to_matrix().to_4x4()
    r = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=length, matrix=m)
    for v in r["verts"]:
        for f in v.link_faces: f.material_index = mi


def add_box(bm, c, half, mi):
    x, y, z = c; hx, hy, hz = half
    r = bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((x, y, z)) @ Matrix.Diagonal((2 * hx, 2 * hy, 2 * hz, 1.0)))
    for v in r["verts"]:
        for f in v.link_faces: f.material_index = mi


def finish(ob, name):
    ob.name = name; ob.data.name = name
    for m in ob.data.materials:   # FBX import leaves alpha 0 on some materials: export them opaque
        b = m.node_tree.nodes.get("Principled BSDF")
        if b is not None: b.inputs["Alpha"].default_value = 1.0
        try: m.blend_method = 'OPAQUE'
        except Exception: pass
    for p in ob.data.polygons: p.use_smooth = False if False else p.use_smooth
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format='GLB', use_selection=True, export_yup=True)
    vs = [ob.matrix_world @ v.co for v in ob.data.vertices]
    print("SWORD", name, len(vs), "verts", "z", round(min(v.z for v in vs), 2), round(max(v.z for v in vs), 2))


STEEL = {"Steel": 0.6, "LightSteel": 0.62, "DarkSteel": 0.55}


def paint(ob, table):
    for name, (rgb, metal, rough) in table.items():
        if name in [m.name for m in ob.data.materials]:
            mat_color(ob, name, rgb, metal, rough)


# ---------------------------------------------------------------- 1. Espada de Recluta (plain iron, short)
def recluta():
    ob = load("sword")
    bl = verts_of(ob, {"Steel", "LightSteel"}); z0, z1 = span(ob, bl)
    edit_verts(ob, bl, lambda v: Vector((v.x * 0.94, v.y, z0 + (v.z - z0) * 0.9)))
    paint(ob, {"Steel": ((0.40, 0.42, 0.45), 0.5, 0.55), "LightSteel": ((0.53, 0.55, 0.58), 0.5, 0.5), "DarkSteel": ((0.27, 0.25, 0.24), 0.4, 0.6),
               "LightWood": ((0.33, 0.2, 0.11), 0.0, 0.85), "DarkWood": ((0.2, 0.12, 0.07), 0.0, 0.9)})
    finish(ob, "espada_recluta")


# ---------------------------------------------------------------- 2. Xifos de Bronce (leaf blade)
def xifos():
    ob = load("sword_2")
    bl = verts_of(ob, {"Steel", "LightSteel"}); z0, z1 = span(ob, bl)
    L = (z1 - z0) * 0.86
    def leaf(v):
        t = (v.z - z0) / (z1 - z0)
        bell = math.sin(math.pi * min(1.0, t * 1.0)) ** 1.1
        return Vector((v.x * (1.0 + 0.55 * bell), v.y * (1.0 + 0.5 * bell), z0 + t * L))
    edit_verts(ob, bl, leaf)
    paint(ob, {"Steel": ((0.6, 0.38, 0.17), 0.55, 0.45), "LightSteel": ((0.8, 0.57, 0.27), 0.55, 0.4), "DarkSteel": ((0.5, 0.33, 0.13), 0.5, 0.5),
               "LightWood": ((0.5, 0.09, 0.07), 0.0, 0.9), "DarkWood": ((0.3, 0.05, 0.04), 0.0, 0.9)})
    finish(ob, "espada_xifos")


# ---------------------------------------------------------------- 3. Alfanje del Desierto (curved, widening)
def alfanje():
    ob = load("sword")
    bl = verts_of(ob, {"Steel", "LightSteel"}); z0, z1 = span(ob, bl)
    L = (z1 - z0) * 0.86
    def curve(v):
        t = (v.z - z0) / (z1 - z0)
        w = 1.0 + 0.75 * math.sin(min(1.0, t) * math.pi * 0.62) ** 1.2          # belly widens towards the tip, then closes
        return Vector((v.x * w + 0.95 * t * t - 0.0, v.y, z0 + t * L - 0.0 * t))
    edit_verts(ob, bl, curve)
    bm = bm_open(ob)
    mi = mat_color(ob, "DarkSteel", (0.72, 0.52, 0.18), 0.6, 0.4)
    add_box(bm, (0.0, 0.0, z0 - 0.06), (0.28, 0.07, 0.07), mi)                                 # flat guard disc
    bm_close(ob, bm)
    paint(ob, {"Steel": ((0.68, 0.7, 0.74), 0.6, 0.35), "LightSteel": ((0.83, 0.85, 0.89), 0.6, 0.3),
               "LightWood": ((0.14, 0.28, 0.5), 0.0, 0.9), "DarkWood": ((0.08, 0.17, 0.32), 0.0, 0.9)})
    finish(ob, "espada_alfanje")


# ---------------------------------------------------------------- 4. Espada Larga de Acero (fuller, big pommel)
def larga():
    ob = load("sword_golden")
    bl = verts_of(ob, {"Gold", "LightGold"}); z0, z1 = span(ob, bl)
    edit_verts(ob, bl, lambda v: Vector((v.x * 0.9, v.y, z0 + (v.z - z0) * 1.06)))
    pm = verts_of(ob, {"DarkSteel"})
    edit_verts(ob, {i for i in pm if ob.data.vertices[i].co.z < 0.0}, lambda v: Vector((v.x * 1.35, v.y * 1.35, v.z)))
    bm = bm_open(ob)
    mi = mat_color(ob, "Fuller", (0.34, 0.37, 0.43), 0.6, 0.45)
    L = (z1 - z0) * 1.06
    add_prism(bm, [(-0.05, z0 + 0.1 * L), (0.05, z0 + 0.1 * L), (0.05, z0 + 0.78 * L), (0.0, z0 + 0.84 * L), (-0.05, z0 + 0.78 * L)], -0.042, 0.042, mi)
    bm_close(ob, bm)
    paint(ob, {"Gold": ((0.52, 0.56, 0.63), 0.6, 0.38), "LightGold": ((0.74, 0.78, 0.85), 0.6, 0.32), "DarkSteel": ((0.58, 0.54, 0.46), 0.55, 0.45),
               "LightWood": ((0.17, 0.1, 0.07), 0.0, 0.9), "DarkWood": ((0.11, 0.07, 0.05), 0.0, 0.9)})
    finish(ob, "espada_larga")


# ---------------------------------------------------------------- 5. Colmillo de Sangre (serrated claymore, spiked guard)
def colmillo():
    ob = load("claymore")
    bl = verts_of(ob, {"Red", "LightRed"}); z0, z1 = span(ob, bl)
    bm = bm_open(ob)
    mi = mat_color(ob, "Black", (0.16, 0.14, 0.15), 0.5, 0.5)
    n = 9; step = (z1 - z0 - 0.7) / n
    for k in range(n):
        z = z0 + 0.5 + k * step
        for side in (-1, 1):
            x0 = side * 0.22; x1 = side * (0.36 - 0.012 * k)
            add_prism(bm, [(x0, z), (x1, z + 0.33 * step), (x0, z + 0.9 * step)][::side], -0.026, 0.026, mi)
    for side in (-1, 1):                                                                         # guard horns
        add_cone(bm, (side * 0.47, 0.0, 1.86), (side * 0.35, 0.0, 1.0), 0.075, 0.012, 0.62, mi, 6)
    bm_close(ob, bm)
    paint(ob, {"Red": ((0.17, 0.15, 0.17), 0.55, 0.4), "LightRed": ((0.58, 0.08, 0.1), 0.45, 0.45), "DarkSteel": ((0.3, 0.28, 0.29), 0.5, 0.5),
               "DarkBrown": ((0.28, 0.05, 0.05), 0.0, 0.9), "Black": ((0.14, 0.12, 0.13), 0.4, 0.6)})
    finish(ob, "espada_colmillo")


if __name__ == "__main__":
    for fn in (recluta, xifos, alfanje, larga, colmillo):
        fn()
    print("swords done")
