"""Construye el modelo 3D del Warrior a partir de los packs CC0 de Quaternius.

Uso (Blender 5.x en modo background):

    blender -b --factory-startup --python tools/blender/build_warrior.py -- \
        <Superhero_Male_FullBody.gltf> <Male_Ranger.gltf> <carpeta pelo "Rigged to Head Bone"> \
        <Sword_Bronze.gltf> <carpeta de salida>

Salida:
  - warrior.glb : esqueleto "Armature" + cabeza del cuerpo base + outfit Ranger
                  (sin capucha) + pelo rapado + barba. Sin animaciones: las
                  animaciones vienen de las librerías UAL1/UAL2, que comparten
                  exactamente los mismos 65 huesos.
  - sword.glb   : la espada de bronce, sin rig (se ancla a hand_r en Godot).

El cuerpo base se recorta a cabeza + cuello: el outfit Ranger ya trae brazos,
torso, piernas y botas, y debajo solo generaría clipping.
"""
import bpy
import bmesh
import os
import sys

argv = sys.argv[sys.argv.index("--") + 1:]
BASE_GLTF, OUTFIT_GLTF, HAIR_DIR, SWORD_GLTF, OUT_DIR = argv[:5]
os.makedirs(OUT_DIR, exist_ok=True)

KEEP_BODY_BONES = {"Head", "neck_01"}
SKIP_OUTFIT_PARTS = ("Hood",)
HAIR_FILES = ("Hair_Buzzed.gltf", "Hair_Beard.gltf")


MAX_TEXTURE = 1024


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def shrink_textures() -> None:
    """Los packs vienen con texturas de 2-4K; con cámara cenital sobra con 1K."""
    for img in bpy.data.images:
        w, h = img.size
        if max(w, h) > MAX_TEXTURE:
            k = MAX_TEXTURE / max(w, h)
            img.scale(max(1, int(w * k)), max(1, int(h * k)))


def import_gltf(path: str) -> list:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def remove(obj) -> None:
    bpy.data.objects.remove(obj, do_unlink=True)


def strip_helpers(objs: list) -> list:
    """Los glTF de Quaternius traen una Icosphere suelta (sonda de luz): fuera."""
    out = []
    for o in objs:
        if o.type == "MESH" and o.name.startswith("Icosphere"):
            remove(o)
        else:
            out.append(o)
    return out


def adopt(meshes: list, armature) -> None:
    """Mueve mallas skinneadas de otro import al esqueleto principal."""
    for m in meshes:
        m.parent = armature
        m.matrix_parent_inverse.identity()
        for mod in m.modifiers:
            if mod.type == "ARMATURE":
                mod.object = armature


def cut_body_to_head(mesh_obj) -> None:
    groups = {g.index: g.name for g in mesh_obj.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(mesh_obj.data)
    deform = bm.verts.layers.deform.verify()
    doomed = []
    for v in bm.verts:
        weights = v[deform]
        if not weights:
            doomed.append(v)
            continue
        best = max(weights.items(), key=lambda kv: kv[1])[0]
        if groups.get(best) not in KEEP_BODY_BONES:
            doomed.append(v)
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    bm.to_mesh(mesh_obj.data)
    bm.free()
    print("body cut: removed %d verts, kept %d" % (len(doomed), len(mesh_obj.data.vertices)))


# --- warrior.glb ------------------------------------------------------------
reset()
base = strip_helpers(import_gltf(BASE_GLTF))
arm = next(o for o in base if o.type == "ARMATURE")
arm.name = "Armature"
arm.data.name = "Armature"
for o in base:
    if o.type == "MESH" and o.name.startswith("SuperHero"):
        cut_body_to_head(o)

outfit = strip_helpers(import_gltf(OUTFIT_GLTF))
outfit_arm = next(o for o in outfit if o.type == "ARMATURE")
outfit_meshes = []
for o in outfit:
    if o.type != "MESH":
        continue
    if any(tag in o.name for tag in SKIP_OUTFIT_PARTS):
        remove(o)
        continue
    outfit_meshes.append(o)
adopt(outfit_meshes, arm)
remove(outfit_arm)

for hair_file in HAIR_FILES:
    hair = strip_helpers(import_gltf(os.path.join(HAIR_DIR, hair_file)))
    hair_meshes = [o for o in hair if o.type == "MESH"]
    hair_arms = [o for o in hair if o.type == "ARMATURE"]
    adopt(hair_meshes, arm)
    for o in hair_arms:
        remove(o)

# Limpia empties huérfanos que pudieran quedar de los imports.
for o in list(bpy.data.objects):
    if o.type == "EMPTY" and not o.children:
        remove(o)

print("warrior meshes:", sorted(o.name for o in bpy.data.objects if o.type == "MESH"))
shrink_textures()
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=os.path.join(OUT_DIR, "warrior.glb"),
    export_format="GLB",
    use_selection=True,
    export_animations=False,
    export_skins=True,
    export_yup=True,
)

# --- sword.glb --------------------------------------------------------------
reset()
strip_helpers(import_gltf(SWORD_GLTF))
shrink_textures()
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=os.path.join(OUT_DIR, "sword.glb"),
    export_format="GLB",
    use_selection=True,
    export_animations=False,
    export_yup=True,
)
print("BUILD OK ->", OUT_DIR)
