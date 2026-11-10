"""Pase de acabado sobre las armas editadas a partir de modelos Quaternius (espadas, hachas, mazas, dagas, arcos).

  blender -b --factory-startup --python tools/weapons/finish_weapons.py [-- id1 id2 ...]

Arregla en lote, sin cambiar la forma:
  1. Suelda vértices duplicados y recalcula normales hacia fuera.
  2. Borra piezas flotantes: islas pequeñas cuya caja no toca la de ninguna otra isla.
  3. Paleta: limita la saturación (0.62; gemas y runas 0.8) y el metallic (0.3), y da nombre real a los
     materiales (los heredados se llamaban "LightWood" aunque fueran azules).
  4. Sombreado plano y una sola malla.
No toca lanzas ni bastones: esos se generan con forge_polearms_staves.py.
"""
import bpy, bmesh, sys, os, colorsys
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "models", "weapons", "custom")
SKIP = ("lanza", "pica", "tridente", "alabarda", "baston", "cayado", "vara")
SAT_MAX = 0.62
SAT_MAX_GEM = 0.80


def islands(bm):
    seen = set()
    out = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]
        group = []
        seen.add(v.index)
        while stack:
            cur = stack.pop()
            group.append(cur)
            for e in cur.link_edges:
                o = e.other_vert(cur)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        out.append(group)
    return out


def bbox(verts):
    lo = Vector((min(v.co.x for v in verts), min(v.co.y for v in verts), min(v.co.z for v in verts)))
    hi = Vector((max(v.co.x for v in verts), max(v.co.y for v in verts), max(v.co.z for v in verts)))
    return lo, hi


def touches(a, b, eps):
    return all(a[0][i] - eps <= b[1][i] and b[0][i] - eps <= a[1][i] for i in range(3))


def describe(color):
    h, s, v = colorsys.rgb_to_hsv(*color)
    if s < 0.16:
        return "Steel" if v > 0.45 else "Iron"
    if h < 0.04 or h > 0.93:
        return "Red"
    if h < 0.12:
        return ("Wood" if v < 0.5 else "Bronze") if s > 0.35 else "Bone"
    if h < 0.19:
        return "Gold" if v > 0.6 else "Wood"
    if h < 0.45:
        return "Green"
    if h < 0.56:
        return "Teal"
    if h < 0.72:
        return "Blue"
    return "Purple"


def finish(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path = os.path.join(SRC, name + ".glb")
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.verts.index_update()
    groups = islands(bm)
    removed = 0
    if len(groups) > 1:
        total = len(bm.verts)
        boxes = [bbox(g) for g in groups]
        length = max(max(b[1][i] for b in boxes) - min(b[0][i] for b in boxes) for i in range(3))
        doomed = []
        for i, g in enumerate(groups):
            if len(g) > total * 0.25:
                continue
            if not any(touches(boxes[i], boxes[j], length * 0.004) for j in range(len(groups)) if j != i):
                doomed.extend(g)
                removed += 1
        if doomed:
            bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = False
    bm.to_mesh(ob.data)
    bm.free()
    recolored = 0
    for m in ob.data.materials:
        if m is None or not m.use_nodes:
            continue
        b = m.node_tree.nodes.get("Principled BSDF")
        if b is None:
            continue
        gem = any(k in m.name for k in ("Gem", "Rune"))
        r, g, bl, a = b.inputs["Base Color"].default_value
        h, s, v = colorsys.rgb_to_hsv(r, g, bl)
        cap = SAT_MAX_GEM if gem else SAT_MAX
        if s > cap:
            r, g, bl = colorsys.hsv_to_rgb(h, cap, v)
            b.inputs["Base Color"].default_value = (r, g, bl, a)
            recolored += 1
        b.inputs["Metallic"].default_value = min(b.inputs["Metallic"].default_value, 0.3)
        m.name = "W_%s_%s" % (name, ("Gem" if gem else describe((r, g, bl))))
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True)
    print("OK %-20s islas %2d  flotantes borradas %d  recoloreados %d" % (name, len(groups), removed, recolored))


only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for f in sorted(os.listdir(SRC)):
    n = f[:-4]
    if f.endswith(".glb") and not n.startswith(SKIP) and (not only or n in only):
        finish(n)
