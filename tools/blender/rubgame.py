"""Игровая комната в квартире: стол рулетки (без сукна — сукно и колесо — текстуры в Godot),
чаша колеса с крестовиной, игровой автомат 90-х, лампа над столом.

Стол лежит вдоль X: слева (x −1.95..−0.75) чаша колеса, справа (x −0.7..1.9) поле ставок.
Верх стола — на высоте 0.92.

Запуск:
    python tools/blender/rubgame.py assets/models/rubgame
"""
import bpy, math, sys, os
from mathutils import Vector

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
_mats = {}


def mat(name, color, rough=0.5, metal=0.0, emit=0.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*color, 1)
        b.inputs["Emission Strength"].default_value = emit
    _mats[name] = m
    return m


def flat(o, m, bevel=0.0):
    o.data.materials.append(m)
    if bevel:
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.limit_method = "ANGLE"
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def box(size, loc, m, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    return flat(o, m, bevel)


def cyl(r, h, loc, m, verts=24, r2=None, rot=(0, 0, 0)):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    return flat(bpy.context.object, m)


def export(name, parts):
    for o in parts:
        for mod in list(o.modifiers):
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True,
                              export_format="GLB", export_draco_mesh_compression_enable=False)
    print("EXPORTED", name)
    bpy.ops.object.delete()


WOOD = mat("TableWood", (0.32, 0.14, 0.05), 0.35)
WOOD_D = mat("TableWoodDark", (0.18, 0.07, 0.02), 0.4)
# Золото светлее и не полностью металл: в игре нечему отражаться, и «настоящий» металл выглядит тёмным.
BRASS = mat("Brass", (1.0, 0.74, 0.18), 0.3, 0.3)
FELT = mat("FeltUnder", (0.08, 0.35, 0.18), 0.9)

# ---------------- Стол ----------------
P = [box((3.9, 1.25, 0.12), (0, 0, 0.84), WOOD, bevel=0.02)]                       # столешница
P.append(box((2.62, 1.08, 0.02), (0.6, 0, 0.905), FELT))                           # под сукном
for y in (-0.6, 0.6):                                                              # бортики
    P.append(box((3.9, 0.06, 0.06), (0, y, 0.93), WOOD_D, bevel=0.02))
for x in (-1.92, 1.92):
    P.append(box((0.06, 1.25, 0.06), (x, 0, 0.93), WOOD_D, bevel=0.02))
P.append(box((0.05, 1.12, 0.05), (-0.72, 0, 0.925), WOOD_D))                       # перегородка
for x in (-1.75, 1.75):
    for y in (-0.48, 0.48):
        P.append(box((0.12, 0.12, 0.78), (x, y, 0.39), WOOD, bevel=0.02))
P.append(box((3.6, 1.0, 0.04), (0, 0, 0.12), WOOD_D))                              # полка снизу
export("roulette_table", P)

# ---------------- Чаша колеса (центр в начале координат, низ на столе z = 0) ----------------
P = [cyl(0.55, 0.12, (0, 0, 0.06), WOOD, verts=32)]
# Внутренний бортик — кольцо: колесо (текстура в Godot) лежит внутри на высоте 0.125.
bpy.ops.mesh.primitive_torus_add(major_radius=0.495, minor_radius=0.03, major_segments=32, minor_segments=6,
                                 location=(0, 0, 0.13))
P.append(flat(bpy.context.object, WOOD_D))
bpy.ops.mesh.primitive_torus_add(major_radius=0.545, minor_radius=0.02, major_segments=32, minor_segments=6,
                                 location=(0, 0, 0.13))
P.append(flat(bpy.context.object, BRASS))
for i in range(8):                                                                 # ромбики-отбойники
    a = i * math.pi / 4
    P.append(box((0.03, 0.03, 0.02), (math.cos(a) * 0.495, math.sin(a) * 0.495, 0.165), BRASS))
export("wheel_bowl", P)

# Крестовина в центре колеса (вращается вместе с колесом).
P = [cyl(0.03, 0.18, (0, 0, 0.09), BRASS, verts=10)]
for a in (0, math.pi / 2):
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.012, depth=0.3, location=(0, 0, 0.16),
                                        rotation=(0, math.pi / 2, a))
    P.append(flat(bpy.context.object, BRASS))
for i in range(4):
    a = i * math.pi / 2
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, radius=0.022,
                                         location=(math.cos(a) * 0.15, math.sin(a) * 0.15, 0.16))
    P.append(flat(bpy.context.object, BRASS))
bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, radius=0.03, location=(0, 0, 0.2))
P.append(flat(bpy.context.object, BRASS))
export("wheel_turret", P)

# ---------------- Игровой автомат 90-х ----------------
CASE = mat("ArcadeCase", (0.12, 0.2, 0.45), 0.5)
SCREEN = mat("ArcadeScreen", (0.1, 0.55, 0.65), 0.2, 0, 1.2)
PANEL = mat("ArcadePanel", (0.85, 0.75, 0.2), 0.4)
BTN = mat("ArcadeBtn", (0.85, 0.1, 0.08), 0.4)
P = [box((0.7, 0.6, 1.7), (0, 0, 0.85), CASE, bevel=0.02)]
P.append(box((0.5, 0.04, 0.4), (0, -0.31, 1.3), SCREEN))
P.append(box((0.66, 0.3, 0.06), (0, -0.4, 0.95), PANEL, bevel=0.01))
for x in (-0.15, 0.0, 0.15):
    P.append(cyl(0.03, 0.03, (x, -0.42, 0.99), BTN, verts=10))
# Козырёк чуть шире корпуса (0.74 > 0.7): иначе бока совпадают и мерцают жёлтым по синему.
P.append(box((0.74, 0.14, 0.2), (0, -0.26, 1.65), PANEL, bevel=0.01))
export("arcade_cabinet", P)

# ---------------- Лампа над столом (верх в z = 3: крепится к потолку) ----------------
SHADE = mat("RubgameShade", (0.1, 0.4, 0.2), 0.5)
BULB = mat("RubgameBulb", (1.0, 0.9, 0.6), 0.3, 0, 2.0)
P = [cyl(0.008, 1.0, (0, 0, 2.5), BRASS, verts=6)]
P.append(cyl(0.6, 0.18, (0, 0, 1.95), SHADE, verts=6, r2=0.25))
P.append(cyl(0.18, 0.04, (0, 0, 1.86), BULB, verts=12))
export("rubgame_lamp", P)
print("DONE")
