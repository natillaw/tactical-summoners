"""Derives extra hair styles by editing copies of the Quaternius hair meshes (run: blender -b -P tools/outfits/make_hair.py).
Each style is exported as its own glTF in assets/models/creator/hair/ keeping the original material/textures
(the glTF material/texture tables are copied from the source file). Male-fit sources are shifted for the female head
(and vice versa) so every style has a `_F` / `_M` fitted file."""
import bpy, bmesh, os, math, json, shutil
from mathutils import Vector
D = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "creator", "hair"))
HEAD = Vector((0.0, 0.02, 1.72))      # rough head centre (male); the female head sits 0.04 lower
FEMALE_DROP = 0.04

def noise(p, seed=0.0):
    return (math.sin(p.x * 91.7 + p.y * 37.1 + seed) * math.cos(p.z * 83.3 - p.x * 21.9 + seed * 1.7) +
            math.sin(p.z * 57.3 + p.y * 71.9 + seed * 2.3)) * 0.5

def load(src):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(D, src + ".gltf"))
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    ob = next(o for o in bpy.data.objects if o.type == 'MESH' and not o.name.startswith("Icosphere"))
    for o in [o for o in bpy.data.objects if o.name.startswith("Icosphere")]: bpy.data.objects.remove(o)
    return arm, ob

def edit(ob, fn):
    bm = bmesh.new(); bm.from_mesh(ob.data)
    fn(bm); bm.to_mesh(ob.data); bm.free(); ob.data.update()
    for p in ob.data.polygons: p.use_smooth = True

def cut_below(z, tilt=0.0):
    def fn(bm):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z), plane_no=(0, -tilt, 1), clear_inner=True, use_snap_center=False)
    return fn

def export(arm, ob, name, src, dz=0.0):
    ob.name = name; ob.data.name = name
    head = ob.vertex_groups.get("Head") or ob.vertex_groups.new(name="Head")
    for v in ob.data.vertices:   # unweighted vertices (from cuts/mirrors) make the exporter add a 'neutral_bone'
        if sum(g.weight for g in v.groups) < 1e-4: head.add([v.index], 1.0, 'REPLACE')
    if dz:
        for v in ob.data.vertices: v.co.z += dz
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); arm.select_set(True)
    path = os.path.join(D, name + ".gltf")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLTF_SEPARATE', use_selection=True, export_image_format='NONE',
                              export_materials='NONE', export_skins=True, export_animations=False, export_yup=True)
    # copy the original material + texture tables so Godot imports the same textured hair material
    g = json.load(open(path)); o = json.load(open(os.path.join(D, src + ".gltf")))
    for k in ("materials", "textures", "images", "samplers"):
        if k in o: g[k] = o[k]
    for m in g["meshes"]:
        for p in m["primitives"]: p["material"] = 0
    json.dump(g, open(path, "w"), indent=2)

def style(name, src, ops, fit):
    """fit: 'M' if the source sits on the male head, 'F' for female. Exports both fitted variants."""
    for sex in ("M", "F"):
        arm, ob = load(src)
        for op in ops: edit(ob, op)
        dz = 0.0 if sex == fit else (-FEMALE_DROP if sex == "F" else FEMALE_DROP)
        export(arm, ob, f"Hair_{name}_{sex}", src, dz)

# ---------- operations ----------
def scale_about(c, s):
    def fn(bm):
        for v in bm.verts: v.co = c + (v.co - c) * s
    return fn

def wavy(amp, freq):
    def fn(bm):
        for v in bm.verts:
            w = max(0.0, (1.72 - v.co.z)) * 4.0     # more wave towards the tips
            v.co.x += amp * math.sin(v.co.z * freq + v.co.y * 18) * min(1.0, w)
            v.co.y += amp * 0.6 * math.cos(v.co.z * freq * 0.8) * min(1.0, w)
    return fn

def messy(amp, seed):
    def fn(bm):
        for v in bm.verts:
            h = max(0.0, v.co.z - 1.62) / 0.2
            d = Vector((noise(v.co, seed), noise(v.co, seed + 3.1), abs(noise(v.co, seed + 7.7)))) * amp * (0.4 + h)
            v.co += d
    return fn

def pompadour(rise, push):
    def fn(bm):
        for v in bm.verts:
            if v.co.y < 0.0 and v.co.z > 1.72:
                w = min(1.0, (-v.co.y) / 0.08) * min(1.0, (v.co.z - 1.72) / 0.08)
                v.co.z += rise * w; v.co.y -= push * w
    return fn

def mohawk(half, grow):
    def fn(bm):
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if any(abs(v.co.x) > half for v in f.verts)], context='FACES')
        for v in [v for v in bm.verts if not v.link_faces]: bm.verts.remove(v)
        for v in bm.verts:
            if v.co.z > 1.68:
                k = (v.co.z - 1.68)
                v.co.z += k * grow; v.co.y -= 0.004 * (1 - abs(v.co.x) / half)
    return fn

def squash_z(top, k):
    def fn(bm):
        for v in bm.verts:
            if v.co.z < top: v.co.z = top - (top - v.co.z) * k
    return fn

def keep_region(pred):
    def fn(bm):
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if not pred(f.calc_center_median())], context='FACES')
        for v in [v for v in bm.verts if not v.link_faces]: bm.verts.remove(v)
    return fn

def stretch_beard(chin_z, k, push):
    def fn(bm):
        for v in bm.verts:
            if v.co.z < chin_z:
                d = chin_z - v.co.z
                v.co.z = chin_z - d * k; v.co.y -= push * min(1.0, d / 0.05)
    return fn

def mirror_join():
    def fn(bm):
        src = bm.faces[:]
        vmap = {}
        for f in src:
            nv = []
            for v in f.verts:
                if v not in vmap: vmap[v] = bm.verts.new((-v.co.x, v.co.y, v.co.z))
                nv.append(vmap[v])
            nf = bm.faces.new(nv[::-1])
            for lo_new, lo_old in zip(nf.loops, list(f.loops)[::-1]):
                for uvl in bm.loops.layers.uv.values(): lo_new[uvl].uv = lo_old[uvl].uv
    return fn

style("Bob", "Hair_Long", [cut_below(1.585, 0.45)], "F")
style("Shoulder", "Hair_Long", [cut_below(1.53), wavy(0.012, 55)], "F")
style("Wavy", "Hair_Long", [wavy(0.02, 48)], "F")
style("Pompadour", "Hair_SimpleParted", [pompadour(0.045, 0.02), scale_about(HEAD, 1.03)], "M")
style("Messy", "Hair_SimpleParted", [messy(0.016, 1.3), scale_about(HEAD, 1.07)], "M")
style("Poof", "Hair_SimpleParted", [scale_about(HEAD, 1.28), messy(0.02, 5.2)], "M")
style("Crop", "Hair_Buzzed", [scale_about(HEAD, 1.1), messy(0.006, 9.0)], "M")
style("TwinBuns", "Hair_Buns", [mirror_join()], "F")
style("LongBeard", "Hair_Beard", [stretch_beard(1.62, 2.4, 0.02)], "M")
style("Goatee", "Hair_Beard", [keep_region(lambda c: abs(c.x) < 0.045 and c.z < 1.66)], "M")
print("hair done")
