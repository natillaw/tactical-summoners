"""Builds extra outfit pieces from the Quaternius parts (run: blender -b -P tools/outfits/make_geometry.py):
  {Sex}_Warrior_Acc_PauldronR  mirrored copy of the ranger pauldron (a pair), slightly scaled up
  {Sex}_Mage_Robe              pleated A-line robe skirt with a leather hem trim, painted from the tunic atlas
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

import numpy as np

def _uv_of(face, uvl):
    n = len(face.loops); return (sum(l[uvl].uv.x for l in face.loops) / n, sum(l[uvl].uv.y for l in face.loops) / n)

def uv_patches(body, legs):
    """Cloth patch (back of the chest, no buttons) and a leather UV (belt) from the peasant tunic."""
    bm = bmesh.new(); bm.from_mesh(body.data); uvl = bm.loops.layers.uv.active
    lb = bmesh.new(); lb.from_mesh(legs.data); luv = lb.loops.layers.uv.active; legs_faces = lb.faces
    im = bpy.data.images.load(os.path.join(D, "T_Peasant_BaseColor_mage.png")); w, h = im.size
    px = np.empty(w * h * 4, np.float32); im.pixels.foreach_get(px); px = px.reshape(h, w, 4)
    def pix(u, v): return px[min(h - 1, int(v * h)), min(w - 1, int(u * w))]
    # trouser faces whose texel really is the dark indigo cloth (no leather/gold bits) -> the robe skirt paint
    c = []
    for f in legs_faces:
        if 0.62 < f.calc_center_median().z < 0.95:
            u, v = _uv_of(f, luv); p = pix(u, v)
            if p[2] > p[0] + 0.01 and p[2] > p[1]: c.append(f)
    us = sorted(_uv_of(f, luv)[0] for f in c); vs = sorted(_uv_of(f, luv)[1] for f in c)
    mu, mv = us[len(us) // 2], vs[len(vs) // 2]
    # grow the biggest rectangle around (mu, mv) whose texels are all indigo cloth (no gold/leather)
    cm = (px[..., 2] > px[..., 0] + 0.01) & (px[..., 2] > px[..., 1])
    x0 = x1 = int(mu * w); y0 = y1 = int(mv * h); st = 6
    grown = True
    while grown:
        grown = False
        if x1 + st < w and cm[y0:y1 + 1, x1 + 1:x1 + st + 1].mean() > 0.985: x1 += st; grown = True
        if x0 - st >= 0 and cm[y0:y1 + 1, x0 - st:x0].mean() > 0.985: x0 -= st; grown = True
        if y1 + st < h and cm[y1 + 1:y1 + st + 1, x0:x1 + 1].mean() > 0.985: y1 += st; grown = True
        if y0 - st >= 0 and cm[y0 - st:y0, x0:x1 + 1].mean() > 0.985: y0 -= st; grown = True
    mx_, my_ = (x1 - x0) * 0.1, (y1 - y0) * 0.06
    cloth = ((x0 + mx_) / w, (x1 - mx_) / w, (y0 + my_) / h, (y1 - my_) / h)
    print("ROBE PATCH", cloth, (x1 - x0), (y1 - y0))
    lea = []
    for f in bm.faces:
        cc = f.calc_center_median()
        if 0.97 < cc.z < 1.2 and abs(cc.x) < 0.25:
            u, v = _uv_of(f, uvl); p = px[min(h - 1, int(v * h)), min(w - 1, int(u * w))]
            if p[0] > p[2] + 0.02 and p[0] < 0.5: lea.append((u, v))
    lea = lea or [(mu, mv)]
    lea.sort(); trim = lea[len(lea) // 2]
    bm.free()
    return cloth, trim

def build_robe2(arm, name, rx, ry, cy, top, length, flare, cloth, trim, n=48, rings=10, pleats=7):
    thigh_x = {s: arm.data.bones["thigh_" + s].head_local.x for s in ("l", "r")}
    me = bpy.data.meshes.new(name); ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    for g in arm.data.bones: ob.vertex_groups.new(name=g.name)
    verts, faces, uvs, wts = [], [], [], []
    def ring(t, kscale=1.0, dz=0.0, amp_mul=1.0):
        out = []
        for i in range(n):
            a = 2 * math.pi * i / n
            s = 1 + flare * t ** 1.5
            amp = 0.06 * (t ** 1.1) * amp_mul
            s *= 1 + amp * math.cos(pleats * a) + amp * 0.35 * math.cos(2 * pleats * a + 1.0)
            x = math.cos(a) * rx * s * kscale; y = cy + math.sin(a) * ry * s * kscale
            z = top - length * t + dz
            z -= 0.03 * t * (0.5 + 0.5 * math.cos(pleats * a + math.pi))      # wavy hem
            z -= 0.06 * t * max(0.0, math.sin(a)) ** 2                          # slightly longer at the back (+y)
            out.append((x, y, z, a, t))
        return out
    body_rings = [ring(k / (rings - 1)) for k in range(rings)]
    cu0, cu1, cv0, cv1 = cloth
    def cloth_uv(a, t):   # mirrored around the circle so there is no seam; v follows height
        tri = abs(((a / (2 * math.pi)) * 2) % 2 - 1)
        return (cu0 + (cu1 - cu0) * tri, cv1 - (cv1 - cv0) * t)
    def add_ring(r, uvf):
        base = len(verts)
        for (x, y, z, a, t) in r:
            verts.append((x, y, z)); uvs.append(uvf(a, t))
            side = "l" if x * thigh_x["l"] >= 0 else "r"
            b = min(1.0, abs(x) / 0.12) * min(1.0, t * 2.5)
            wts.append((side, b))
        return base
    bases = [add_ring(r, cloth_uv) for r in body_rings]
    for k in range(rings - 1):
        for i in range(n):
            j = (i + 1) % n
            faces.append((bases[k] + i, bases[k] + j, bases[k + 1] + j, bases[k + 1] + i))
    # leather hem trim: a thin band, a little wider than the cloth, folding with the same pleats
    th = 0.065
    hem = body_rings[-1]
    def trim_ring(dz, grow):
        return [(x * grow + (x - 0.0) * 0, cy + (y - cy) * grow, z + dz, a, t) for (x, y, z, a, t) in [(r[0] - 0.0, r[1], r[2], r[3], r[4]) for r in hem]]
    top_t = trim_ring(th, 1.012); bot_t = trim_ring(-0.035, 1.03)
    def tuv(a, t): return trim
    b0 = add_ring(top_t, tuv); b1 = add_ring(bot_t, tuv)
    for i in range(n):
        j = (i + 1) % n
        faces.append((b0 + i, b0 + j, b1 + j, b1 + i))
    me.from_pydata(verts, [], faces); me.update()
    uvl = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        for li, vi in zip(p.loop_indices, p.vertices): uvl.data[li].uv = uvs[vi]
    for vi, (side, b) in enumerate(wts):
        ob.vertex_groups["pelvis"].add([vi], 1.0 - b, 'REPLACE')
        if b > 0: ob.vertex_groups["thigh_" + side].add([vi], b, 'REPLACE')
    for p in me.polygons: p.use_smooth = True
    # outward normals
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    f0 = bm.faces[0]; c = f0.calc_center_median()
    if f0.normal.dot(Vector((c.x, c.y - cy, 0))) < 0: bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.to_mesh(me); bm.free()
    ob.parent = arm; mod = ob.modifiers.new("Armature", 'ARMATURE'); mod.object = arm
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
    if sex == "Male": PATCH = uv_patches(body, next(o for o in objs if o.type == "MESH" and o.name.endswith("Legs")))   # the female tunic is paneled differently: reuse the male cloth
    cloth, trim = PATCH
    if sex == "Male":
        robe = build_robe2(arm, f"{sex}_Mage_Robe", 0.17, 0.125, 0.03, 0.97, 0.66, 0.85, cloth, trim)
    else:
        robe = build_robe2(arm, f"{sex}_Mage_Robe", 0.185, 0.13, 0.02, 1.03, 0.72, 0.7, cloth, trim)
    export([robe], arm, f"{sex}_Mage_Robe")
print("geometry done")
