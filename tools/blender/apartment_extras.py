"""Живые вещи квартиры: дисковый телефон (корпус, трубка, диск — отдельно), тумбочка под телефон,
граммофон, часы с кукушкой (маятник отдельно), кот (части с суставами) и лежанка.

Мебель смотрит в −Y Blender (= к камере в Godot). Кот смотрит в +Y Blender (= вперёд, −Z в Godot).

Запуск:
    python tools/blender/apartment_extras.py assets/models/apartment [--render превью.png]
"""
import bpy, math, sys, os
from mathutils import Vector

args = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = args[0] if args else "."
RENDER = sys.argv[sys.argv.index("--render") + 1] if "--render" in sys.argv else None
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.cursor.location = (0, 0, 0)
_mats = {}
KEEP = []  # для превью: (имя, объекты)


def mat(name, color, rough=0.5, metal=0.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    _mats[name] = m
    return m


def flat(o, m):
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def box(size, loc, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    return flat(o, m)


def cyl(r, h, loc, m, verts=16, r2=None, rot=(0, 0, 0)):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc,
                                        rotation=rot)
    o = bpy.context.object
    bpy.ops.object.transform_apply(rotation=True)
    return flat(o, m)


def sphere(r, loc, m, scale=(1, 1, 1), segs=12, rings=7):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return flat(o, m)


def rod(a, b, r, m, verts=8):
    """Цилиндр от точки a до точки b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(rotation=True)
    return flat(o, m)


def join(name, parts, pivot=(0, 0, 0)):
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    bpy.context.scene.cursor.location = pivot
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.context.scene.cursor.location = (0, 0, 0)
    return o


def export(name, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True,
                              export_format="GLB", export_draco_mesh_compression_enable=False)
    print("EXPORTED", name)
    KEEP.append((name, objs))


WOOD = mat("Wood", (0.35, 0.18, 0.08), 0.5)
WOOD_D = mat("WoodDark", (0.2, 0.09, 0.03), 0.5)
# Золото светлое и почти не металл: в комнате нечему отражаться, металл в Godot выходит тёмным.
BRASS = mat("Brass", (1.0, 0.76, 0.25), 0.35, 0.3)
HORN = mat("Horn", (1.0, 0.74, 0.22), 0.3, 0.3)
BLACK = mat("Black", (0.03, 0.03, 0.03), 0.3)
WHITE = mat("White", (0.93, 0.92, 0.88), 0.4)

# ---------------- Тумбочка под телефон (верх на 0.6) ----------------
P = [box((0.45, 0.4, 0.04), (0, 0, 0.58), WOOD)]
P.append(box((0.41, 0.36, 0.3), (0, 0, 0.4), WOOD))
P.append(box((0.3, 0.01, 0.08), (0, -0.181, 0.45), WOOD_D))        # ящик
P.append(cyl(0.015, 0.02, (0, -0.19, 0.45), BRASS, verts=8, rot=(math.pi / 2, 0, 0)))
for x in (-0.19, 0.19):
    for y in (-0.16, 0.16):
        P.append(box((0.04, 0.04, 0.26), (x, y, 0.13), WOOD_D))
P.append(box((0.41, 0.36, 0.02), (0, 0, 0.12), WOOD))              # нижняя полка
P.append(box((0.3, 0.22, 0.03), (0.0, 0.0, 0.145), mat("Paper", (0.85, 0.82, 0.7), 0.8)))  # телефонная книга
export("phone_table", [join("PhoneTable", P)])

# ---------------- Дисковый телефон: корпус ----------------
RED = mat("PhoneRed", (0.65, 0.08, 0.06), 0.35)
P = [box((0.22, 0.24, 0.05), (0, 0, 0.025), RED)]
P.append(box((0.2, 0.2, 0.06), (0, 0.0, 0.07), RED, rot=(math.radians(16), 0, 0)))  # скат вперёд
for x in (-0.085, 0.085):                                           # рычаги под трубку (сзади)
    P.append(box((0.035, 0.05, 0.05), (x, 0.07, 0.12), RED))
# Подложка диска на переднем скате (сам диск — отдельная модель, точка DIAL_POS).
P.append(cyl(0.064, 0.006, (0, -0.045, 0.103), WHITE, verts=24, rot=(math.radians(16), 0, 0)))
# Упор диска (чёрный «клювик») — на корпусе, а не на диске: он не крутится.
P.append(box((0.006, 0.022, 0.014), (0.045, -0.0899, 0.1051), BLACK, rot=(math.radians(16), 0, 0)))
export("phone_base", [join("PhoneBase", P)])

# Диск (крутится вокруг своей оси Z; в Godot — вокруг Y, наклон задаёт узел).
P = [cyl(0.058, 0.008, (0, 0, 0), mat("DialClear", (0.85, 0.85, 0.82), 0.3), verts=24)]
for i in range(10):
    a = math.radians(60 + i * 26)
    P.append(cyl(0.009, 0.01, (math.cos(a) * 0.043, math.sin(a) * 0.043, 0.002), BLACK, verts=8))
P.append(cyl(0.018, 0.012, (0, 0, 0.002), RED, verts=12))
export("phone_dial", [join("PhoneDial", P)])

# Трубка: вдоль X, центр в начале координат.
P = [box((0.17, 0.035, 0.03), (0, 0, 0), RED)]
for x in (-0.085, 0.085):
    P.append(cyl(0.032, 0.035, (x, 0, -0.015), RED, verts=12))
export("phone_handset", [join("PhoneHandset", P)])
# В Godot: диск — в (0, 0.108, 0.047) с наклоном 16° по X; трубка — в (0, 0.16, -0.07).

# ---------------- Граммофон (ставится на стол) ----------------
P = [box((0.34, 0.34, 0.12), (0, 0, 0.06), WOOD)]
P.append(box((0.36, 0.36, 0.015), (0, 0, 0.125), WOOD_D))
P.append(cyl(0.14, 0.008, (0, 0, 0.137), BLACK, verts=28))          # пластинка
P.append(cyl(0.04, 0.009, (0, 0, 0.138), mat("Label", (0.75, 0.1, 0.1), 0.6), verts=12))
P.append(cyl(0.012, 0.06, (0.13, 0.12, 0.16), BRASS, verts=8))      # стойка тонарма
P.append(rod((0.13, 0.12, 0.19), (0.04, -0.02, 0.15), 0.008, BRASS))
P.append(cyl(0.02, 0.03, (0.04, -0.02, 0.145), BRASS, verts=10))
P.append(cyl(0.012, 0.05, (-0.17, 0.0, 0.08), BRASS, verts=8, rot=(0, math.pi / 2, 0)))  # ручка
# Труба: изогнутая трубка сзади и раструб вперёд-вверх.
path = [(0.13, 0.15, 0.17), (0.12, 0.18, 0.3), (0.06, 0.15, 0.45), (0.0, 0.05, 0.55)]
for a, b in zip(path, path[1:]):
    P.append(rod(a, b, 0.025, BRASS))
# Раструб — полая труба (без крышек) с толщиной: изнутри тоже золотой, без «рваных» граней.
bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.025, radius2=0.22, depth=0.32, end_fill_type="NOTHING",
                                location=(0, 0, 0))
horn = flat(bpy.context.object, HORN)
mod = horn.modifiers.new("Thick", "SOLIDIFY")
mod.thickness = 0.008
bpy.context.view_layer.objects.active = horn
bpy.ops.object.modifier_apply(modifier="Thick")
horn.rotation_euler = (math.radians(-60), 0, 0)
horn.location = (0, -0.08, 0.63)
bpy.ops.object.transform_apply(location=True, rotation=True)
P.append(horn)
bpy.ops.mesh.primitive_torus_add(major_radius=0.22, minor_radius=0.012, major_segments=24, minor_segments=5,
                                 location=(0, 0, 0))                          # кант по краю раструба
rim = flat(bpy.context.object, HORN)
rim.rotation_euler = (math.radians(-60), 0, 0)
# Сдвиг края раструба (0, 0, 0.16) после поворота на −60° по X + положение раструба.
rim.location = Vector((0, -0.08, 0.63)) + Vector((0, 0.16 * math.sin(math.radians(60)), 0.16 * 0.5))
bpy.ops.object.transform_apply(location=True, rotation=True)
bpy.context.view_layer.objects.active = rim
P.append(rim)
export("gramophone", [join("Gramophone", P)])

# ---------------- Часы с кукушкой (висят на стене, задняя стенка в y = 0) ----------------
P = [box((0.3, 0.14, 0.34), (0, -0.07, 0), WOOD)]
for s in (-1, 1):                                                   # крыша
    P.append(box((0.24, 0.18, 0.025), (s * 0.08, -0.08, 0.215), WOOD_D, rot=(0, s * math.radians(35), 0)))
P.append(box((0.08, 0.01, 0.07), (0, -0.142, 0.12), WOOD_D))        # дверца кукушки
P.append(sphere(0.025, (0, -0.15, 0.125), mat("Bird", (0.9, 0.75, 0.2), 0.6), scale=(1, 1.3, 1)))
P.append(cyl(0.09, 0.01, (0, -0.145, -0.03), WHITE, verts=24, rot=(math.pi / 2, 0, 0)))
P.append(box((0.008, 0.004, 0.065), (0, -0.152, 0.0), BLACK))      # стрелки
P.append(box((0.05, 0.004, 0.008), (0.022, -0.152, -0.03), BLACK))
for i in range(12):
    a = i * math.pi / 6
    P.append(box((0.008, 0.003, 0.008), (math.cos(a) * 0.075, -0.151, -0.03 + math.sin(a) * 0.075), BLACK))
for i in range(5):                                                  # резные листья внизу
    P.append(box((0.04, 0.02, 0.06), (-0.12 + i * 0.06, -0.12, -0.19), WOOD_D,
                 rot=(0, math.radians(30 * (1 if i % 2 else -1)), 0)))
for x in (-0.06, 0.06):                                             # гири-шишки на цепочках
    P.append(rod((x, -0.07, -0.17), (x, -0.07, -0.55), 0.003, BRASS, verts=4))
    P.append(cyl(0.022, 0.1, (x, -0.07, -0.6), BRASS, verts=8, r2=0.012))
export("cuckoo_clock", [join("CuckooClock", P)])

# Маятник: точка подвеса в начале координат, висит вниз.
P = [rod((0, 0, 0), (0, 0, -0.3), 0.004, BRASS, verts=6)]
P.append(cyl(0.035, 0.008, (0, 0, -0.32), BRASS, verts=16, rot=(math.pi / 2, 0, 0)))
export("cuckoo_pendulum", [join("CuckooPendulum", P)])

# ---------------- Кот: части с суставами (смотрит в +Y) ----------------
FUR = mat("CatFur", (0.85, 0.45, 0.15), 0.8)
FUR_D = mat("CatFurDark", (0.6, 0.27, 0.06), 0.8)
CREAM = mat("CatCream", (0.95, 0.85, 0.7), 0.8)
PINK = mat("CatPink", (0.95, 0.55, 0.6), 0.5)
EYE = mat("CatEye", (0.55, 0.8, 0.2), 0.3)
cat = []
P = [sphere(0.13, (0, 0, 0.25), FUR, scale=(0.95, 1.9, 0.9))]
for y in (-0.12, 0.0, 0.12):                                        # полоски
    P.append(sphere(0.131, (0, y, 0.255), FUR_D, scale=(0.96, 0.18, 0.9)))
P.append(sphere(0.1, (0, 0.12, 0.2), CREAM, scale=(0.8, 1.2, 0.7)))  # грудка
cat.append(join("CatBody", P, (0, 0, 0.25)))
P = [sphere(0.1, (0, 0.33, 0.37), FUR, scale=(1.1, 1, 0.95))]
for s in (-1, 1):
    P.append(cyl(0.035, 0.07, (s * 0.055, 0.32, 0.47), FUR, verts=4, r2=0.0))
    P.append(cyl(0.02, 0.05, (s * 0.055, 0.325, 0.465), PINK, verts=4, r2=0.0))
    P.append(sphere(0.02, (s * 0.04, 0.415, 0.39), EYE, scale=(1, 0.5, 1.2), segs=8, rings=5))
    P.append(sphere(0.009, (s * 0.04, 0.425, 0.39), BLACK, scale=(0.6, 0.5, 1.6), segs=6, rings=4))
    for k in (-1, 1):                                               # усы
        P.append(rod((s * 0.04, 0.42, 0.345), (s * 0.12, 0.41, 0.345 + k * 0.02), 0.002, WHITE, verts=4))
P.append(sphere(0.045, (0, 0.4, 0.34), CREAM, scale=(1.1, 0.7, 0.7)))
P.append(sphere(0.012, (0, 0.43, 0.36), PINK))
cat.append(join("CatHead", P, (0, 0.24, 0.32)))
P = []
pts = [(0, -0.22, 0.28), (0, -0.33, 0.33), (0, -0.4, 0.43), (0, -0.4, 0.55)]
for i, (a, b) in enumerate(zip(pts, pts[1:])):
    P.append(rod(a, b, 0.024, FUR_D if i == 2 else FUR))
P.append(sphere(0.025, pts[-1], FUR_D))
cat.append(join("CatTail", P, pts[0]))
for name, x, y in (("LegFL", -0.065, 0.14), ("LegFR", 0.065, 0.14), ("LegBL", -0.07, -0.15),
                   ("LegBR", 0.07, -0.15)):
    P = [cyl(0.032, 0.2, (x, y, 0.1), FUR, verts=8)]
    P.append(sphere(0.036, (x, y + 0.015, 0.02), CREAM, scale=(1, 1.3, 0.6), segs=8, rings=5))
    cat.append(join(name, P, (x, y, 0.2)))
export("cat", cat)

# ---------------- Лежанка кота ----------------
P = [cyl(0.32, 0.06, (0, 0, 0.03), mat("BedBase", (0.45, 0.2, 0.3), 0.9), verts=20)]
bpy.ops.mesh.primitive_torus_add(major_radius=0.3, minor_radius=0.07, major_segments=20, minor_segments=8,
                                 location=(0, 0, 0.1))
P.append(flat(bpy.context.object, mat("BedRim", (0.6, 0.25, 0.35), 0.9)))
P.append(cyl(0.25, 0.04, (0, 0, 0.07), mat("BedPillow", (0.9, 0.8, 0.6), 0.9), verts=20))
P.append(box((0.1, 0.03, 0.1), (0.0, -0.32, 0.16), mat("BedName", (0.95, 0.9, 0.5), 0.6)))  # табличка
export("cat_bed", [join("CatBed", P)])

if RENDER:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1400, 800
    scene.world = bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.78, 0.72, 1)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (0.6, 0.2, -0.5)
    scene.collection.objects.link(sun)
    xs = {"phone_table": -1.5, "phone_base": -1.5, "phone_dial": -1.5, "phone_handset": -1.5,
          "gramophone": -0.75, "cuckoo_clock": 0.0, "cuckoo_pendulum": 0.0, "cat": 0.8, "cat_bed": 1.6}
    for name, objs in KEEP:
        for o in objs:
            o.location.x += xs[name]
            if name == "phone_base":
                o.location.z += 0.6
            elif name == "phone_dial":
                o.location += Vector((0, -0.047, 0.708)); o.rotation_euler.x = math.radians(16)
            elif name == "phone_handset":
                o.location += Vector((0, 0.07, 0.76))
            elif name == "cuckoo_clock":
                o.location.z += 1.0
            elif name == "cuckoo_pendulum":
                o.location += Vector((0, -0.075, 0.82))
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (0.0, -3.6, 1.6)
    cam.rotation_euler = (Vector((0, 0, 0.45)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = RENDER
    bpy.ops.render.render(write_still=True)
print("DONE")
