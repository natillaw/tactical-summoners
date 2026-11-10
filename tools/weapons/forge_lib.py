"""forge_lib — piezas para construir armas low-poly al estilo Quaternius desde cero (Blender, bmesh).

Reglas del estilo (ver docs/ASSETS_GUIA.md):
  - Siluetas gruesas y legibles desde lejos; nada más fino que ~2 cm a escala real.
  - Sombreado plano, aristas biseladas con 1 segmento, sin subdivisión.
  - Colores planos de la paleta PAL (apagados); como mucho 5 materiales por arma; sin texturas.
  - Una sola malla por arma, sin piezas flotando, eje largo +Z en Blender (+Y en el .glb), origen en el agarre.

Uso: w = Weapon("id"); w.cyl(...); w.plate(...); w.export(grip_z)
"""
import bpy, bmesh, math, os
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "models", "weapons", "custom")

# Paleta: (color sRGB lineal aproximado, metallic, roughness). El juego no tiene reflejos: metallic bajo.
PAL = {
    "steel": ((0.58, 0.60, 0.64), 0.30, 0.45),
    "iron": ((0.23, 0.24, 0.27), 0.30, 0.55),
    "bronze": ((0.62, 0.40, 0.17), 0.30, 0.50),
    "gold": ((0.80, 0.60, 0.22), 0.30, 0.45),
    "wood": ((0.36, 0.23, 0.13), 0.0, 0.85),
    "wood_dark": ((0.22, 0.14, 0.09), 0.0, 0.85),
    "wood_pale": ((0.55, 0.42, 0.27), 0.0, 0.85),
    "leather": ((0.30, 0.17, 0.10), 0.0, 0.80),
    "cloth_red": ((0.50, 0.11, 0.09), 0.0, 0.90),
    "cloth_blue": ((0.14, 0.24, 0.42), 0.0, 0.90),
    "bone": ((0.80, 0.74, 0.60), 0.0, 0.75),
    "stone": ((0.42, 0.42, 0.40), 0.0, 0.90),
    "gem_arcane": ((0.52, 0.30, 0.82), 0.0, 0.25),
    "gem_ice": ((0.55, 0.82, 0.92), 0.0, 0.20),
    "gem_fire": ((0.95, 0.42, 0.10), 0.0, 0.30),
    "gem_nature": ((0.40, 0.70, 0.28), 0.0, 0.30),
}
EMISSIVE = {"gem_arcane": 0.6, "gem_ice": 0.5, "gem_fire": 0.9, "gem_nature": 0.4}


def material(name):
    key = "W_" + name
    m = bpy.data.materials.get(key)
    if m:
        return m
    color, metal, rough = PAL[name]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if name in EMISSIVE:
        b.inputs["Emission Color"].default_value = (*color, 1.0)
        b.inputs["Emission Strength"].default_value = EMISSIVE[name]
    return m


class Weapon:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def _slot(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _commit(self, part, mat, mods=()):
        """Añade `part` (bmesh) a la malla final con su material; `mods` = modificadores a aplicar antes."""
        me = bpy.data.meshes.new("tmp")
        part.to_mesh(me)
        part.free()
        if mods:
            ob = bpy.data.objects.new("tmp", me)
            bpy.context.scene.collection.objects.link(ob)
            for kind, props in mods:
                mod = ob.modifiers.new(kind, kind)
                for k, v in props.items():
                    setattr(mod, k, v)
            dg = bpy.context.evaluated_depsgraph_get()
            me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
            bpy.data.objects.remove(ob)
            me = me2
        n0 = len(self.bm.faces)
        self.bm.from_mesh(me)
        self.bm.faces.ensure_lookup_table()
        idx = self._slot(mat)
        for f in self.bm.faces[n0:]:
            f.material_index = idx
            f.smooth = False

    # --- piezas ---
    def cyl(self, z0, z1, r0, r1=None, mat="wood", sides=8, x=0.0, y=0.0, tilt=None):
        """Tronco de cono entre z0 y z1 (radios r0 abajo, r1 arriba). `tilt` = (eje, grados) alrededor de su base."""
        r1 = r0 if r1 is None else r1
        p = bmesh.new()
        bmesh.ops.create_cone(p, cap_ends=True, segments=sides, radius1=r0, radius2=max(r1, 1e-4), depth=z1 - z0)
        bmesh.ops.translate(p, verts=p.verts, vec=(0, 0, (z1 - z0) / 2))
        if tilt:
            bmesh.ops.rotate(p, verts=p.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(tilt[1]), 3, tilt[0]))
        bmesh.ops.translate(p, verts=p.verts, vec=(x, y, z0))
        self._commit(p, mat)

    def gem(self, center, r, mat, squash=1.0, sub=1):
        p = bmesh.new()
        bmesh.ops.create_icosphere(p, subdivisions=sub, radius=r)
        bmesh.ops.scale(p, verts=p.verts, vec=(1, 1, squash))
        bmesh.ops.translate(p, verts=p.verts, vec=center)
        self._commit(p, mat)

    def crystal(self, base, r, h, mat, sides=5, tilt=None):
        """Cristal: punta larga arriba y punta corta abajo. `base` = centro del cinturón."""
        p = bmesh.new()
        bmesh.ops.create_cone(p, cap_ends=False, segments=sides, radius1=r, radius2=1e-4, depth=h * 0.75)
        bmesh.ops.translate(p, verts=p.verts, vec=(0, 0, h * 0.375))
        q = bmesh.new()
        bmesh.ops.create_cone(q, cap_ends=False, segments=sides, radius1=1e-4, radius2=r, depth=h * 0.25)
        bmesh.ops.translate(q, verts=q.verts, vec=(0, 0, -h * 0.125))
        tmp = bpy.data.meshes.new("q"); q.to_mesh(tmp); q.free(); p.from_mesh(tmp)
        bmesh.ops.remove_doubles(p, verts=p.verts, dist=1e-4)
        if tilt:
            bmesh.ops.rotate(p, verts=p.verts, cent=(0, 0, -h * 0.25), matrix=Matrix.Rotation(math.radians(tilt[1]), 3, tilt[0]))
        bmesh.ops.translate(p, verts=p.verts, vec=base)
        self._commit(p, mat)

    def plate(self, points, thickness, mat, bevel=0.0, mirror=False, y=0.0):
        """Placa plana (hoja de arma) a partir de un contorno [(x, z), ...] en sentido antihorario.
        `mirror` añade el contorno reflejado en x (dar solo la mitad derecha, de abajo arriba)."""
        pts = list(points)
        if mirror:
            pts = pts + [(-px, pz) for px, pz in reversed(pts) if abs(px) > 1e-6]
        p = bmesh.new()
        verts = [p.verts.new((px, y, pz)) for px, pz in pts]
        p.faces.new(verts)
        bmesh.ops.triangulate(p, faces=p.faces)
        mods = [("SOLIDIFY", {"thickness": thickness, "offset": 0.0})]
        if bevel > 0.0:
            mods.append(("BEVEL", {"width": bevel, "segments": 1, "limit_method": "ANGLE", "angle_limit": math.radians(50)}))
        self._commit(p, mat, mods)

    def box(self, center, size, mat, bevel=0.0, rot_y=0.0):
        p = bmesh.new()
        bmesh.ops.create_cube(p, size=1.0)
        bmesh.ops.scale(p, verts=p.verts, vec=size)
        if rot_y:
            bmesh.ops.rotate(p, verts=p.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(rot_y), 3, "Y"))
        bmesh.ops.translate(p, verts=p.verts, vec=center)
        mods = [("BEVEL", {"width": bevel, "segments": 1})] if bevel > 0.0 else ()
        self._commit(p, mat, mods)

    def wrap(self, z0, z1, r, mat="leather", bands=3, sides=8):
        """Vendaje: varias bandas un poco más anchas que el asta."""
        step = (z1 - z0) / bands
        for i in range(bands):
            self.cyl(z0 + i * step + step * 0.08, z0 + (i + 1) * step - step * 0.08, r, r, mat, sides)

    # --- salida ---
    def export(self, grip_z):
        """Guarda custom/<name>.glb con el origen en `grip_z` (punto de agarre sobre el eje)."""
        bmesh.ops.translate(self.bm, verts=self.bm.verts, vec=(0, 0, -grip_z))
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for name in self.mats:
            me.materials.append(material(name))
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        path = os.path.join(OUT, self.name + ".glb")
        for attempt in range(3):
            try:
                bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True)
                break
            except Exception as err:  # el editor de Godot puede tener el archivo bloqueado
                print("reintento export", self.name, err)
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        print("OK %-18s tris %4d  mats %d" % (self.name, tris, len(self.mats)))
        bpy.data.objects.remove(ob)
