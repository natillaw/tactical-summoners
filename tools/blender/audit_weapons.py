"""Auditoría de las armas con diseño propio (assets/models/weapons/custom/*.glb).

  blender -b --factory-startup --python tools/blender/audit_weapons.py -- [--sheet out.png] [--json out.json] [--side]

Por cada arma: triángulos, dimensiones, materiales (nombre, color base, metallic, roughness), caras sin material,
vértices sueltos, aristas no-manifold, caras degeneradas, normales invertidas (estimación) y posición del origen
respecto a la caja. Con --sheet renderiza una hoja de contacto (todas a la misma altura, vista frontal o lateral).
"""
import bpy, bmesh, sys, os, json, math
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "models", "weapons", "custom")
ORDER = ["espada", "hacha", "tomahawk", "maza", "mazo", "martillo", "garrote", "lanza", "pica", "tridente", "alabarda", "daga", "cuchillo", "punal", "arco", "baston", "cayado", "vara"]


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"sheet": "", "json": "", "side": "--side" in a}
    for k in ("sheet", "json"):
        if "--" + k in a:
            out[k] = a[a.index("--" + k) + 1]
    return out


def key(name):
    for i, p in enumerate(ORDER):
        if name.startswith(p):
            return (i, name)
    return (99, name)


def load(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def audit(name, objs):
    meshes = [o for o in objs if o.type == "MESH"]
    tris = loose = nonman = degen = nomat = flipped = faces = 0
    lo = Vector((1e9, 1e9, 1e9)); hi = Vector((-1e9, -1e9, -1e9))
    mats = {}
    for o in meshes:
        bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
        bm.normal_update()
        center = sum((v.co for v in bm.verts), Vector()) / max(len(bm.verts), 1)
        for v in bm.verts:
            lo = Vector((min(lo.x, v.co.x), min(lo.y, v.co.y), min(lo.z, v.co.z)))
            hi = Vector((max(hi.x, v.co.x), max(hi.y, v.co.y), max(hi.z, v.co.z)))
            if not v.link_faces:
                loose += 1
        for e in bm.edges:
            if len(e.link_faces) != 2:
                nonman += 1
        for f in bm.faces:
            faces += 1
            tris += len(f.verts) - 2
            if f.calc_area() < 1e-9:
                degen += 1
            if f.material_index >= len(o.data.materials) or o.data.materials[f.material_index] is None:
                nomat += 1
        bm.free()
        for m in o.data.materials:
            if m is None:
                continue
            info = {"color": None, "metallic": None, "roughness": None, "texture": False}
            if m.use_nodes:
                for n in m.node_tree.nodes:
                    if n.type == "BSDF_PRINCIPLED":
                        info["color"] = [round(c, 3) for c in n.inputs["Base Color"].default_value[:3]]
                        info["metallic"] = round(n.inputs["Metallic"].default_value, 2)
                        info["roughness"] = round(n.inputs["Roughness"].default_value, 2)
                        info["texture"] = bool(n.inputs["Base Color"].links)
            mats[m.name] = info
    size = hi - lo
    return {
        "name": name, "objects": len(meshes), "tris": tris, "size": [round(s, 3) for s in size],
        "origin_from_bottom": round(-lo.z, 3), "origin_side_offset": [round((lo.x + hi.x) / 2, 3), round((lo.y + hi.y) / 2, 3)],
        "materials": mats, "faces_without_material": nomat, "loose_verts": loose, "non_manifold_edges": nonman, "degenerate_faces": degen,
    }, lo, hi


def main():
    a = args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    names = sorted([f[:-4] for f in os.listdir(SRC) if f.endswith(".glb")], key=key)
    report = []
    cols = 9
    for i, name in enumerate(names):
        objs = load(os.path.join(SRC, name + ".glb"))
        info, lo, hi = audit(name, objs)
        report.append(info)
        roots = [o for o in objs if o.parent is None]
        height = max(hi.z - lo.z, 1e-3)
        s = 1.0 / height
        col, row = i % cols, i // cols
        for r in roots:
            r.scale = r.scale * s
            r.location = (r.location - Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))) * s
            if a["side"]:
                r.rotation_euler.rotate_axis("Z", math.radians(90))
                r.location = Vector((-r.location.y, r.location.x, r.location.z))
            r.location += Vector((col * 0.62, 0.0, -row * 1.18))
    for info in report:
        m = info["materials"]
        print("%-20s tris %5d  size %s  origin_z %.2f  mats %d  nomat %d  loose %d  nonman %d  degen %d" % (
            info["name"], info["tris"], info["size"], info["origin_from_bottom"], len(m), info["faces_without_material"],
            info["loose_verts"], info["non_manifold_edges"], info["degenerate_faces"]))
    if a["json"]:
        json.dump(report, open(a["json"], "w"), indent=1)
    if a["sheet"]:
        rows = (len(names) + cols - 1) // cols
        scene = bpy.context.scene
        cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"
        w, h = cols * 0.62, rows * 1.18
        cam_data.ortho_scale = max(w, h * 1600 / 1150) + 0.1
        cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam)
        cam.location = ((cols - 1) * 0.62 / 2, -10, -(rows - 1) * 1.18 / 2 + 0.5)
        cam.rotation_euler = (math.radians(90), 0, 0)
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "TEXTURE"
        scene.display.shading.show_cavity = True
        scene.display.shading.show_object_outline = True
        scene.render.resolution_x, scene.render.resolution_y = 1600, 1150
        scene.render.film_transparent = False
        scene.world = bpy.data.worlds.new("w"); scene.world.color = (0.32, 0.34, 0.38)
        scene.render.filepath = a["sheet"]
        bpy.ops.render.render(write_still=True)


main()
