"""Hood variants edited from the Quaternius Ranger hood (run: blender -b -P tools/outfits/make_rogue_geometry.py).
  Ranger_HoodShort  short cowl (cut above the shoulders)     Ranger_HoodPeak  peaked hood with a tail"""
import bpy, bmesh, os, json, math
D = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "creator", "outfits"))


def load(src):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(D, src + ".gltf"))
    for o in [o for o in bpy.data.objects if o.name.startswith("Icosphere")]: bpy.data.objects.remove(o)
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    hood = next(o for o in bpy.data.objects if o.type == 'MESH' and "Hood" in o.name)
    for o in [o for o in bpy.data.objects if o.type == 'MESH' and o is not hood]: bpy.data.objects.remove(o)
    return arm, hood


def edit(ob, fn):
    bm = bmesh.new(); bm.from_mesh(ob.data); fn(bm); bm.to_mesh(ob.data); bm.free(); ob.data.update()


def short(zc):
    def fn(bm):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, zc), plane_no=(0, -0.5, 1), clear_inner=True)
    return fn


def peak(z0, up, back):
    def fn(bm):
        for v in bm.verts:
            if v.co.z > z0:
                k = (v.co.z - z0)
                v.co.z += k * up; v.co.y += k * k * back * 8
    return fn


def fit(zc, sx=0.96, sz=0.8):
    """Hug the head: shrink the hood about the head centre (the stock hood sits well above the skull)."""
    def fn(bm):
        for v in bm.verts:
            v.co.x *= sx; v.co.y = 0.015 + (v.co.y - 0.015) * sx; v.co.z = zc + (v.co.z - zc) * sz - 0.012
    return fn


def export(arm, ob, name, src):
    ob.name = name; ob.data.name = name
    head = ob.vertex_groups.get("Head") or ob.vertex_groups.new(name="Head")
    for v in ob.data.vertices:
        if sum(g.weight for g in v.groups) < 1e-4: head.add([v.index], 1.0, 'REPLACE')
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); arm.select_set(True)
    path = os.path.join(D, name + ".gltf")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLTF_SEPARATE', use_selection=True, export_image_format='NONE',
                              export_materials='NONE', export_skins=True, export_animations=False, export_yup=True)
    g = json.load(open(path)); o = json.load(open(os.path.join(D, src + ".gltf")))
    for k in ("materials", "textures", "images", "samplers"):
        if k in o: g[k] = o[k]
    for m in g["meshes"]:
        for p in m["primitives"]: p["material"] = 0
    json.dump(g, open(path, "w"), indent=2)


for sex in ("Male", "Female"):
    src = f"{sex}_Ranger"
    for name, fn in (("HoodShort", short(1.60 if sex == "Male" else 1.56)), ("HoodPeak", peak(1.72 if sex == "Male" else 1.68, 0.55, 0.02))):
        arm, hood = load(src)
        edit(hood, fn)
        if name == "HoodPeak": edit(hood, fit(1.70 if sex == "Male" else 1.66))
        export(arm, hood, f"{sex}_Ranger_{name}", src)
print("rogue geometry done")
