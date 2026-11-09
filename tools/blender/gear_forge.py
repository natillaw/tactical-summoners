"""GEAR FORGE - generador de espadas (2 manos) y armaduras de Warrior de inicio de juego.

Estilo objetivo: Quaternius (Universal Base Characters / Modular Outfits Fantasy):
formas redondeadas y "gorditas", poligonos bajos suavizados, bordes biselados, paleta
apagada y plana (sin texturas). Las piezas de armadura son rigidas y comparten el
esqueleto de warrior.glb, asi que van al mismo Skeleton3D.

    blender -b --factory-startup --python tools/blender/gear_forge.py -- [opciones]

Opciones:
  --warrior PATH   warrior.glb (esqueleto)       [assets/models/characters/warrior.glb]
  --out DIR        carpeta de salida             [assets/models/gear]
  --swords N       espadas aleatorias a generar  [12]
  --armors N       sets aleatorios de armadura   [6]
  --seed N         semilla (misma semilla = mismo resultado) [1]
  --preview PNG    contact sheet con todo lo generado

Siempre se generan los presets con nombre (PRESET_ARMORS). Cada pieza sale con
catalog.json (parametros usados) para poder regenerar o ajustar. Para ampliar el
catalogo, anade entradas a BLADES / GUARDS / POMMELS / METALS / STYLES al principio.
"""
import bpy, bmesh, math, sys, os, json, random
from mathutils import Vector, Matrix

# ------------------------------------------------------------------ CLI
def arg(name, default):
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return a[a.index(name) + 1] if name in a else default

WARRIOR = arg("--warrior", "assets/models/characters/warrior.glb")
OUT = arg("--out", "assets/models/gear")
N_SWORDS = int(arg("--swords", 12))
N_ARMORS = int(arg("--armors", 6))
SEED = int(arg("--seed", 1))
PREVIEW = arg("--preview", None)
os.makedirs(OUT, exist_ok=True)

# -------------------------------------------------------------- CATALOGO
# Paleta apagada estilo Quaternius. (hex, metalico, rugosidad)
METALS = {  # solo materiales de inicio de juego: nada de mithril/oro/etc.
    "rusty":  ("#8a6e5a", 0.2, 0.7),
    "iron":   ("#8f98a3", 0.5, 0.5),
    "steel":  ("#b4bcc6", 0.6, 0.4),
    "bronze": ("#b9813c", 0.5, 0.5),
}
SOFT = {
    "leather":   ("#8a5a3b", 0, 0.9), "leather_d": ("#4e3626", 0, 0.9),
    "cloth":     ("#bcab8c", 0, 1.0), "cloth_red":  ("#8f3a34", 0, 1.0),
    "cloth_blue": ("#3f5f86", 0, 1.0), "cloth_grey": ("#6d6a66", 0, 1.0),
    "wood":      ("#6b4a2e", 0, 0.9),
}
# Hoja: [(t 0..1, semiancho rel, grosor rel)], n-gono de la seccion
BLADES = {
    "broad":   dict(ngon=4, prof=[(0, .55, 1), (.07, 1, 1.2), (.72, .95, 1), (.94, .55, .7), (1, 0, .2)], w=.050, L=(.95, 1.10)),
    "long":    dict(ngon=4, prof=[(0, .6, 1), (.06, 1, 1.2), (.80, .85, 1), (.96, .5, .6), (1, 0, .2)], w=.040, L=(1.05, 1.25)),
    "fuller":  dict(ngon=6, prof=[(0, .6, 1), (.06, 1, 1.1), (.78, .92, 1), (.95, .55, .7), (1, 0, .25)], w=.046, L=(1.0, 1.15)),
    "cleaver": dict(ngon=4, prof=[(0, .7, 1.2), (.05, 1, 1.4), (.85, 1, 1.2), (.97, .8, .8), (1, .15, .3)], w=.060, L=(.85, .98)),
}
GUARDS = ["bar", "winged", "drooped", "round"]
POMMELS = ["round", "disc", "spike", "cap"]
GRIP_WRAPS = ["leather_d", "leather", "cloth_red", "wood"]

# Estilos de armadura: cada pieza elige uno (None = no lleva)
CHESTS = {  # perfil (z, semiancho, semifondo) de cintura a hombros
    "tunic":   [(.86, .20, .14), (1.0, .19, .13), (1.2, .19, .12), (1.4, .215, .13), (1.5, .17, .11)],
    "leather": [(1.03, .175, .12), (1.25, .19, .13), (1.43, .22, .135), (1.5, .17, .11)],
    "plate":   [(1.04, .175, .12), (1.18, .195, .135), (1.38, .24, .15), (1.50, .19, .115)],
}
PAULDRONS = ["none", "leather", "plate", "layered"]
ARMS = ["none", "bracer", "vambrace"]
LEGS = ["boots", "greaves", "boots_wrap"]
HELMS = ["none", "cap", "open", "nasal"]

PRESET_ARMORS = {
    "recluta": dict(chest="tunic", chest_mat="cloth", trim="leather_d", pauldrons="leather", pauld_mat="leather",
                    arms="bracer", arm_mat="leather", legs="boots", leg_mat="leather", helm="none", helm_mat="iron", skirt="cloth_grey"),
    "soldado": dict(chest="leather", chest_mat="leather", trim="leather_d", pauldrons="plate", pauld_mat="iron",
                    arms="bracer", arm_mat="leather_d", legs="boots", leg_mat="leather_d", helm="cap", helm_mat="iron", skirt="cloth_red"),
    "hierro":  dict(chest="plate", chest_mat="iron", trim="leather_d", pauldrons="layered", pauld_mat="iron",
                    arms="vambrace", arm_mat="iron", legs="greaves", leg_mat="iron", helm="open", helm_mat="iron", skirt="cloth_grey"),
    "bronce":  dict(chest="plate", chest_mat="bronze", trim="leather", pauldrons="plate", pauld_mat="bronze",
                    arms="vambrace", arm_mat="bronze", legs="greaves", leg_mat="bronze", helm="nasal", helm_mat="bronze", skirt="cloth_blue"),
}

# --------------------------------------------------------------- BASICOS
def mat(key):
    h, m, r = {**METALS, **SOFT}[key]
    mt = bpy.data.materials.get(key)
    if mt: return mt
    mt = bpy.data.materials.new(key); mt.use_nodes = True
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    b = mt.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = [x ** 2.2 for x in c] + [1]
    b.inputs["Metallic"].default_value = m
    b.inputs["Roughness"].default_value = r
    mt.diffuse_color = [x ** 2.2 for x in c] + [1]
    return mt

def finish(name, bm, key, smooth=False, subsurf=0, bevel=0.0):
    """bmesh -> objeto con bisel/subsurf YA aplicados (el glTF sale limpio)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if bevel:
        m = ob.modifiers.new("b", "BEVEL"); m.width = bevel; m.segments = 2; m.limit_method = "ANGLE"
    if subsurf:
        m = ob.modifiers.new("s", "SUBSURF"); m.levels = subsurf; m.render_levels = subsurf
    if ob.modifiers:
        dg = bpy.context.evaluated_depsgraph_get()
        new = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        ob.modifiers.clear(); ob.data = new
    for p in ob.data.polygons: p.use_smooth = smooth
    ob.data.materials.append(mat(key))
    return ob

def loft(rings, axis="Y", ngon=8, cap=True, rot=0.0):
    """rings: [(t, semiancho, semialto, desplazamiento)] a lo largo de axis."""
    bm = bmesh.new(); rv = []
    for t, hw, ht, off in rings:
        ring = []
        for i in range(ngon):
            a = 2 * math.pi * i / ngon + rot
            u, v = math.cos(a) * hw, math.sin(a) * ht
            ring.append(bm.verts.new((u + off, t, v) if axis == "Y" else (u + off, v, t)))
        rv.append(ring)
    for r in range(len(rv) - 1):
        for i in range(ngon):
            bm.faces.new((rv[r][i], rv[r][(i + 1) % ngon], rv[r + 1][(i + 1) % ngon], rv[r + 1][i]))
    if cap:
        for r in (rv[0], rv[-1]):
            if len({v.co.to_tuple() for v in r}) > 2: bm.faces.new(r)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    return bm

def box(c, s, rot=None):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts: v.co = Vector((v.co.x * s[0], v.co.y * s[1], v.co.z * s[2]))
    if rot: bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(rot[1], 3, rot[0]))
    bmesh.ops.translate(bm, verts=bm.verts, vec=c)
    return bm

def sphere(c, r, sc=(1, 1, 1), seg=10, rings=6):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1)
    for v in bm.verts: v.co = Vector((v.co.x * r * sc[0] + c[0], v.co.y * r * sc[1] + c[1], v.co.z * r * sc[2] + c[2]))
    return bm

def join(*bms):
    out = bmesh.new()
    for b in bms:
        me = bpy.data.meshes.new("_"); b.to_mesh(me); b.free(); out.from_mesh(me); bpy.data.meshes.remove(me)
    return out

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def export(fname, apply_mods=False):
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, fname), export_format="GLB",
                              export_animations=False, export_yup=True)

# --------------------------------------------------------------- ESPADAS
def make_sword(name, p):
    """Espadon a 2 manos. Origen = centro del agarre, hoja hacia +Y."""
    B = BLADES[p["blade"]]
    g = p["grip_len"]; g0, g1 = -g / 2, g / 2
    y0 = g1 + .035; L = p["blade_len"]; w = B["w"] * p["width"]; th = .011
    prof = [(y0 + t * L, w * hw, th * ht, 0) for t, hw, ht in B["prof"]]
    parts = [finish(name + "_Blade", loft(prof, "Y", B["ngon"], rot=math.pi / 4 if B["ngon"] == 4 else 0), p["metal"], bevel=.003)]
    # guarda
    gy = g1 + .018; gw = p["guard_w"]; tag = p["guard"]
    if tag == "bar":
        gm = join(box((0, gy, 0), (gw, .03, .034)), box((-gw / 2, gy, 0), (.026, .045, .048)), box((gw / 2, gy, 0), (.026, .045, .048)))
    elif tag == "winged":
        gm = join(box((0, gy, 0), (gw * .5, .03, .034)),
                  box((-gw * .3, gy + .012, 0), (gw * .5, .026, .03), ("Z", .35)),
                  box((gw * .3, gy + .012, 0), (gw * .5, .026, .03), ("Z", -.35)))
    elif tag == "drooped":
        gm = join(box((0, gy, 0), (gw * .4, .03, .036)),
                  box((-gw * .3, gy - .014, 0), (gw * .5, .026, .03), ("Z", -.4)),
                  box((gw * .3, gy - .014, 0), (gw * .5, .026, .03), ("Z", .4)))
    else:  # round: disco
        gm = loft([(gy - .012, gw * .32, gw * .32, 0), (gy + .012, gw * .32, gw * .32, 0)], "Y", 12)
    parts.append(finish(name + "_Guard", gm, p["guard_mat"], smooth=False, bevel=.004))
    # empunadura (ligeramente abombada) + vueltas
    grip = loft([(g0, .015, .015, 0), (0, .019, .019, 0), (g1, .015, .015, 0)], "Y", 10)
    parts.append(finish(name + "_Grip", grip, p["grip"], smooth=True))
    # pomo
    py = g0 - .02; pk = p["pommel"]
    if pk == "round": pm = sphere((0, py, 0), .034, seg=10, rings=6)
    elif pk == "disc": pm = loft([(py - .012, .04, .04, 0), (py + .012, .04, .04, 0)], "Y", 12)
    elif pk == "spike": pm = loft([(py + .02, .028, .028, 0), (py - .02, .02, .02, 0), (py - .07, 0, 0, 0)], "Y", 8)
    else: pm = loft([(py + .02, .02, .02, 0), (py - .03, .036, .036, 0), (py - .05, .03, .03, 0)], "Y", 10)
    parts.append(finish(name + "_Pommel", pm, p["guard_mat"], smooth=True))
    return parts

def random_sword(rng, i):
    metal = rng.choice(list(METALS))
    bl = rng.choice(list(BLADES))
    lo, hi = BLADES[bl]["L"]
    return dict(blade=bl, metal=metal, blade_len=round(rng.uniform(lo, hi), 3), width=round(rng.uniform(.9, 1.15), 2),
                grip_len=round(rng.uniform(.30, .38), 3), guard=rng.choice(GUARDS), guard_w=round(rng.uniform(.20, .30), 3),
                guard_mat=rng.choice(["leather_d", "iron", "bronze", metal]), grip=rng.choice(GRIP_WRAPS),
                pommel=rng.choice(POMMELS))

# --------------------------------------------------------------- ARMADURA
def bone(arm, n):
    b = arm.data.bones[n]; return Vector(b.head_local), Vector(b.tail_local)

def skin(ob, arm, bn):
    ob.vertex_groups.new(name=bn).add([v.index for v in ob.data.vertices], 1.0, "REPLACE")
    ob.parent = arm; ob.modifiers.new("Armature", "ARMATURE").object = arm

def tube(arm, bn, f0, f1, r0, r1, ngon=10, stretch=1.1):
    h, t = bone(arm, bn); d = t - h; z = d.normalized()
    x = Vector((1, 0, 0)) if abs(z.x) < .9 else Vector((0, 1, 0))
    x = (x - z * x.dot(z)).normalized(); y = z.cross(x)
    bm = bmesh.new(); rv = []
    for f, r in ((f0, r0), (f1, r1)):
        c = h + d * f
        rv.append([bm.verts.new(c + x * math.cos(a) * r + y * math.sin(a) * r * stretch)
                   for a in (2 * math.pi * i / ngon for i in range(ngon))])
    for i in range(ngon):
        bm.faces.new((rv[0][i], rv[0][(i + 1) % ngon], rv[1][(i + 1) % ngon], rv[1][i]))
    bm.faces.new(rv[0]); bm.faces.new(rv[1][::-1])
    return bm

def make_armor(name, p):
    clear(); bpy.ops.import_scene.gltf(filepath=WARRIOR)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in list(bpy.data.objects):
        if o.type != "ARMATURE": bpy.data.objects.remove(o, do_unlink=True)
    parts = []
    def add(nm, bm, key, bn, **kw): parts.append((finish(nm, bm, key, **kw), bn))

    prof = CHESTS[p["chest"]]
    add("Chest", loft([(z, hw, hd, 0) for z, hw, hd in prof], "Z", 12), p["chest_mat"], "spine_02", smooth=True, subsurf=1)
    if p["chest"] == "plate":
        add("Gorget", loft([(1.48, .115, .11, 0), (1.58, .09, .09, 0)], "Z", 10), p["chest_mat"], "spine_03", smooth=True, subsurf=1)
    add("Belt", join(loft([(.97, .18, .125, 0), (1.07, .182, .127, 0)], "Z", 12),
                     box((0, -.13, 1.02), (.06, .03, .07))), p["trim"], "pelvis", smooth=True, bevel=.004)
    if p["skirt"]:
        add("Tasset", loft([(.74, .23, .15, 0), (.98, .185, .13, 0)], "Z", 12, cap=False), p["skirt"], "pelvis", smooth=True, subsurf=1)

    for s, sd in ((1, "l"), (-1, "r")):
        h, _ = bone(arm, f"upperarm_{sd}"); S = sd.upper()
        pa = p["pauldrons"]
        if pa != "none":
            k = {"leather": (.105, .55), "plate": (.125, .62), "layered": (.13, .7)}[pa]
            bm = sphere((h.x + s * .02, h.y, h.z + .04), k[0], (1.05, 1.0, k[1]), 10, 6)
            if pa == "layered":
                bm = join(bm, sphere((h.x + s * .06, h.y, h.z - .005), k[0] * .95, (1.05, 1.0, .5), 10, 6))
            add(f"Pauldron_{S}", bm, p["pauld_mat"], f"clavicle_{sd}", smooth=True, subsurf=1)
        if p["arms"] != "none":
            v = p["arms"] == "vambrace"
            add(f"Vambrace_{S}", tube(arm, f"lowerarm_{sd}", .2 if v else .45, .96, .06, .048), p["arm_mat"],
                f"lowerarm_{sd}", smooth=True, subsurf=1)
        add(f"Cuisse_{S}", tube(arm, f"thigh_{sd}", .05, .42, .105, .09), p["skirt"] or p["trim"], f"thigh_{sd}", smooth=True, subsurf=1)
        lg = p["legs"]
        top = .9 if lg != "greaves" else .85
        add(f"Shin_{S}", tube(arm, f"calf_{sd}", .1 if lg == "greaves" else .2, .93, .085, .062), p["leg_mat"],
            f"calf_{sd}", smooth=True, subsurf=1)
        fh = arm.data.bones[f"foot_{sd}"].head_local
        boot = loft([(-.075, .055, .04, 0), (-.03, .062, .06, 0), (.07, .06, .055, 0), (.15, .05, .035, 0), (.19, .03, .02, 0)], "Y", 10)
        boot.transform(Matrix.Translation((fh.x, .035, .05)))
        add(f"Boot_{S}", boot, p["leg_mat"] if lg != "greaves" else p["trim"], f"foot_{sd}", smooth=True, subsurf=1)

    hm = p["helm"]
    if hm != "none":
        hh, _ = bone(arm, "Head"); top = hh.z + .1; cy = hh.y + .02
        if hm == "cap":
            bm = sphere((0, cy, top - .02), .125, (1, 1.1, .8), 12, 6)
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < top - .045], context="VERTS")
        else:
            bm = loft([(top - .11, .115, .125, 0), (top - .02, .12, .13, 0), (top + .06, .095, .105, 0), (top + .11, .02, .025, 0)], "Z", 12)
            if hm in ("open", "nasal"):
                bm = join(bm, box((0, cy - .115, top - .08), (.022, .02, .1)))  # protector de nariz
        bm.transform(Matrix.Translation((0, cy if hm != "cap" else 0, 0))) if hm != "cap" else None
        add("Helmet", bm, p["helm_mat"], "Head", smooth=True, subsurf=1)

    for ob, bn in parts: skin(ob, arm, bn)
    export(f"armor_{name}.glb")

def random_armor(rng, i):
    metal = rng.choice(["iron", "bronze", "rusty"])
    metalish = rng.random() < .5
    soft = lambda: rng.choice(["leather", "leather_d", "cloth", "cloth_red", "cloth_blue", "cloth_grey"])
    chest = rng.choice(list(CHESTS))
    heavy = chest == "plate"
    return dict(chest=chest, chest_mat=metal if heavy else rng.choice(["leather", "cloth", "cloth_blue", "cloth_red"]),
                trim=rng.choice(["leather", "leather_d"]), pauldrons=rng.choice(PAULDRONS),
                pauld_mat=metal if metalish else "leather", arms=rng.choice(ARMS), arm_mat=metal if metalish else "leather",
                legs=rng.choice(LEGS), leg_mat=metal if metalish else "leather_d", helm=rng.choice(HELMS), helm_mat=metal,
                skirt=rng.choice([None, soft()]))

# ------------------------------------------------------------------ MAIN
rng = random.Random(SEED)
catalog = {"swords": {}, "armors": {}}
for i in range(N_SWORDS):
    p = random_sword(rng, i); n = f"{i + 1:02d}_{p['blade']}_{p['metal']}"
    clear(); make_sword(n, p); export(f"greatsword_{n}.glb"); catalog["swords"][n] = p
for n, p in PRESET_ARMORS.items():
    make_armor(n, p); catalog["armors"][n] = p
for i in range(N_ARMORS):
    p = random_armor(rng, i); n = f"rnd{i + 1:02d}_{p['chest']}"
    make_armor(n, p); catalog["armors"][n] = p
json.dump(catalog, open(os.path.join(OUT, "catalog.json"), "w"), indent=1)

if PREVIEW:
    clear()
    for i, (n, p) in enumerate(catalog["swords"].items()):
        for o in make_sword(n, p):
            o.location = (-4 + (i % 12) * .3, 0, 1.9 - (i // 12) * 1.7); o.rotation_euler = (math.pi / 2, 0, 0)
    for k, n in enumerate(catalog["armors"]):
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, f"armor_{n}.glb"))
        for o in bpy.context.selected_objects:
            if o.parent is None: o.location.x = -4 + (k % 5) * 1.9; o.location.z = -(k // 5) * 2.0 - .3
    sc = bpy.context.scene; sc.render.engine = "BLENDER_WORKBENCH"; sc.world = bpy.data.worlds.new("w"); sc.world.color = (.85, .87, .9)
    sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "MATERIAL"
    sc.render.resolution_x, sc.render.resolution_y = 1800, 1100
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 12
    cam.location = (0.4, -8, -.2); cam.rotation_euler = (math.pi / 2, 0, 0)
    sc.render.filepath = PREVIEW; bpy.ops.render.render(write_still=True)
