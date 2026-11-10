"""Builds extra outfit pieces from the Quaternius parts (run: blender -b -P tools/outfits/make_geometry.py):
  {Sex}_Warrior_Acc_PauldronR  mirrored copy of the ranger pauldron (a pair), slightly scaled up
  {Sex}_Mage_Robe              long skirt extruded from the peasant tunic hem
Exported without textures; the game assigns the material of a sibling mesh."""
import bpy, bmesh, os, math
from mathutils import Vector
D = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "creator", "outfits"))

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def imp(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(D, name + ".gltf"))
    new = [o for o in bpy.data.objects if o not in before]
    for o in list(new):
        if o.type == 'MESH' and o.name.startswith('Icosphere'):
            new.remove(o); bpy.data.objects.remove(o)
    return new

def swap_side(n):
    if n.endswith("_l"): return n[:-2] + "_r"
    if n.endswith("_r"): return n[:-2] + "_l"
    return n

def mirror_object(src, name, scale):
    me = src.data.copy(); me.name = name
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    ob.parent = src.parent; ob.matrix_parent_inverse = src.matrix_parent_inverse.copy(); ob.matrix_world = src.matrix_world.copy()
    # vertex groups with swapped sides
    for g in src.vertex_groups: ob.vertex_groups.new(name=swap_side(g.name))
    for v in src.data.vertices:
        for ge in v.groups:
            ob.vertex_groups[ge.group].add([v.index], ge.weight, 'REPLACE')
    m = ob.modifiers.new("Armature", 'ARMATURE'); m.object = src.parent
    bm = bmesh.new(); bm.from_mesh(me)
    c = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
    for v in bm.verts:
        p = v.co - c; p *= scale; v.co = p + c
        v.co.x = -v.co.x
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.to_mesh(me); bm.free()
    return ob

def build_robe(body, name, drops, flares):
    me = body.data
    bm = bmesh.new(); bm.from_mesh(me)
    bm.verts.ensure_lookup_table(); bm.edges.ensure_lookup_table()
    uv = bm.loops.layers.uv.active
    deform = bm.verts.layers.deform.verify()
    # boundary loops
    bnd = [e for e in bm.edges if e.is_boundary]
    seen, loops = set(), []
    for e in bnd:
        if e in seen: continue
        stack, comp = [e], []
        while stack:
            x = stack.pop()
            if x in seen: continue
            seen.add(x); comp.append(x)
            for v in x.verts:
                for ne in v.link_edges:
                    if ne.is_boundary and ne not in seen: stack.append(ne)
        loops.append(comp)
    def mean_z(comp): return sum(v.co.z for x in comp for v in x.verts) / (2 * len(comp))
    hem = min(loops, key=mean_z)
    # order the loop
    verts_in = {v for x in hem for v in x.verts}
    start = next(iter(verts_in)); order = [start]; prev = None; cur = start
    while True:
        nxt = None
        for e in cur.link_edges:
            if e in hem:
                o = e.other_vert(cur)
                if o is not prev and o not in order: nxt = o; break
        if nxt is None: break
        order.append(nxt); prev, cur = cur, nxt
    n = len(order)
    uvs = []
    for v in order:
        l = v.link_loops[0]; uvs.append(l[uv].uv.copy())
    cx = 0.0; cy = sum(v.co.y for v in order) / n
    out = bmesh.new(); ouv = out.loops.layers.uv.new(); odef = out.verts.layers.deform.verify()
    base_z = sum(v.co.z for v in order) / n
    rings = []
    for k in range(len(drops) + 1):
        ring = []
        for i, v in enumerate(order):
            p = v.co.copy()
            if k > 0:
                p.z = v.co.z - drops[k - 1]
                f = flares[k - 1]
                p.x = cx + (p.x - cx) * f; p.y = cy + (p.y - cy) * f
            nv = out.verts.new(p)
            for g, w in v[deform].items(): nv[odef][g] = w
            ring.append(nv)
        rings.append(ring)
    for k in range(len(rings) - 1):
        a, b = rings[k], rings[k + 1]
        for i in range(n):
            j = (i + 1) % n
            f = out.faces.new((a[i], a[j], b[j], b[i]))
            for lo, uvc in zip(f.loops, (uvs[i], uvs[j], uvs[j], uvs[i])): lo[ouv].uv = uvc
    bmesh.ops.recalc_face_normals(out, faces=out.faces[:])
    # normals should point away from the body axis
    f0 = out.faces[0]; c = f0.calc_center_median()
    if f0.normal.dot(Vector((c.x - cx, c.y - cy, 0))) < 0: bmesh.ops.reverse_faces(out, faces=out.faces[:])
    nm = bpy.data.meshes.new(name); out.to_mesh(nm); out.free(); bm.free()
    ob = bpy.data.objects.new(name, nm); bpy.context.scene.collection.objects.link(ob)
    ob.parent = body.parent; ob.matrix_parent_inverse = body.matrix_parent_inverse.copy(); ob.matrix_world = body.matrix_world.copy()
    for g in body.vertex_groups: ob.vertex_groups.new(name=g.name)
    for v in nm.vertices: pass
    # copy weights stored in deform layer -> vertex groups already by index through to_mesh
    mod = ob.modifiers.new("Armature", 'ARMATURE'); mod.object = body.parent
    for p in nm.polygons: p.use_smooth = True
    return ob

def export(objs, arm, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs + [arm]: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(D, name + ".gltf"), export_format='GLTF_SEPARATE', use_selection=True,
        export_image_format='NONE', export_materials='NONE', export_skins=True, export_animations=False, export_yup=True)

for sex in ("Male", "Female"):
    clear(); objs = imp(f"{sex}_Ranger")
    arm = next(o for o in objs if o.type == 'ARMATURE')
    paul = [o for o in objs if o.type == 'MESH' and "Pauldron" in o.name]
    if sex == "Male":   # the female set already ships both pauldrons
        mir = mirror_object(paul[0], f"{sex}_Warrior_Acc_PauldronR", 1.0)
        for o in [o for o in objs if o.type == 'MESH' and o not in (mir,)]: o.hide_set(True)
        export([mir], arm, f"{sex}_Warrior_Acc_PauldronR")
    clear(); objs = imp(f"{sex}_Peasant")
    arm = next(o for o in objs if o.type == 'ARMATURE')
    body = next(o for o in objs if o.type == 'MESH' and o.name.endswith("Body"))
    robe = build_robe(body, f"{sex}_Mage_Robe", [0.16, 0.34, 0.50], [1.06, 1.14, 1.2])
    export([robe], arm, f"{sex}_Mage_Robe")
print("geometry done")
