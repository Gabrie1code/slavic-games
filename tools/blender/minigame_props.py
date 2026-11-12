"""Модели для мини-игр: ларёк, колбаса, бита, улучшенная бита, банка энергетика.

Запуск (нужен модуль bpy, см. tools/blender/README.md):
    python tools/blender/minigame_props.py assets/models/props           # только .glb
    python tools/blender/minigame_props.py assets/models/props --render  # + превью
"""
import bpy, math, sys, os
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else "."
RENDER = "--render" in sys.argv
os.makedirs(OUT, exist_ok=True)

_mats = {}


def mat(name, color, rough=0.6, metal=0.0):
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


def finish(o, m, bevel=0.0, segs=1):
    o.data.materials.append(m)
    if bevel:
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segs
        mod.limit_method = "ANGLE"
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def box(size, loc, m, bevel=0.0, segs=1):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, bevel, segs)


def cyl(r, depth, loc, m, verts=8, rot=(0, 0, 0), r2=None, bevel=0.0):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
    return finish(bpy.context.object, m, bevel)


def sphere(r, loc, m, scale=(1, 1, 1), segs=8, rings=5):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m)


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
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True,
                              export_format="GLB", export_draco_mesh_compression_enable=False)
    print(f"EXPORTED {name}: {tris} tris")
    return obj


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


bpy.ops.wm.read_factory_settings(use_empty=True)

# ---------------- Бита (рукоять в начале координат, бита уходит вниз по -Z) ----------------
WOOD = mat("BatWood", (0.62, 0.38, 0.17), 0.55)
GRIP = mat("Grip", (0.08, 0.07, 0.07), 0.8)
P = []
P.append(cyl(0.03, 0.035, (0, 0, 0.02), WOOD, verts=8))                       # навершие
P.append(cyl(0.05, 0.62, (0, 0, -0.31), WOOD, verts=8, r2=0.02))             # конус: толще книзу
P.append(sphere(0.05, (0, 0, -0.62), WOOD, scale=(1, 1, 0.5)))                # закруглённый торец
P.append(cyl(0.023, 0.2, (0, 0, -0.1), GRIP, verts=8))                        # обмотка рукояти
export("bat", P)
clear()

# ---------------- Улучшенная бита: алюминиевая, красная с жёлтыми полосами ----------------
RED = mat("BatRed", (0.75, 0.08, 0.06), 0.3, 0.6)
GOLD = mat("BatGold", (0.95, 0.72, 0.15), 0.3, 0.8)
STEEL = mat("Steel", (0.8, 0.8, 0.82), 0.25, 1.0)
P = []
P.append(cyl(0.04, 0.04, (0, 0, 0.02), GOLD, verts=10))
P.append(cyl(0.068, 0.8, (0, 0, -0.4), RED, verts=10, r2=0.024))
P.append(sphere(0.068, (0, 0, -0.8), STEEL, scale=(1, 1, 0.45), segs=10))
P.append(cyl(0.027, 0.24, (0, 0, -0.12), GRIP, verts=10))
for z, r in [(-0.5, 0.054), (-0.62, 0.06), (-0.74, 0.066)]:
    P.append(cyl(r + 0.004, 0.025, (0, 0, z), GOLD, verts=10))               # полосы
export("bat_super", P)
clear()

# ---------------- Банка энергетика «Ягуарр» ----------------
CAN = mat("CanBlack", (0.05, 0.06, 0.05), 0.35, 0.4)
STRIPE = mat("CanOrange", (0.95, 0.45, 0.05), 0.4, 0.3)
YELLOW = mat("CanYellow", (0.98, 0.82, 0.1), 0.4, 0.3)
P = []
P.append(cyl(0.03, 0.15, (0, 0, 0.08), CAN, verts=12))
P.append(cyl(0.0305, 0.04, (0, 0, 0.085), STRIPE, verts=12))
P.append(cyl(0.0306, 0.008, (0, 0, 0.112), YELLOW, verts=12))
P.append(cyl(0.0306, 0.008, (0, 0, 0.058), YELLOW, verts=12))
P.append(cyl(0.028, 0.012, (0, 0, 0.161), STEEL, verts=12, r2=0.024))         # верхняя кромка
P.append(cyl(0.026, 0.01, (0, 0, 0.003), STEEL, verts=12))
P.append(box((0.012, 0.022, 0.003), (0, 0.006, 0.168), STEEL))                # язычок
export("energy_can", P)
clear()

# ---------------- Колбаса (держат за середину) ----------------
SAUSAGE = mat("Sausage", (0.28, 0.06, 0.035), 0.45)
STRING = mat("String", (0.85, 0.8, 0.65), 0.9)
P = []
P.append(cyl(0.045, 0.4, (0, 0, 0), SAUSAGE, verts=10, rot=(0, math.pi / 2, 0)))
P.append(sphere(0.045, (0.2, 0, 0), SAUSAGE, scale=(0.7, 1, 1), segs=10))
P.append(sphere(0.045, (-0.2, 0, 0), SAUSAGE, scale=(0.7, 1, 1), segs=10))
P.append(cyl(0.012, 0.05, (0.25, 0, 0), STRING, verts=6, rot=(0, math.pi / 2, 0)))
P.append(cyl(0.012, 0.05, (-0.25, 0, 0), STRING, verts=6, rot=(0, math.pi / 2, 0)))
for x in (-0.12, 0.0, 0.12):
    P.append(cyl(0.0465, 0.012, (x, 0, 0), STRING, verts=10, rot=(0, math.pi / 2, 0)))  # перевязки
export("sausage", P)
clear()

# ---------------- Ларёк «Колбаса» (перед смотрит в -Y Blender = +Z Godot) ----------------
# Голубой ларёк с белыми полосами, полосатый козырёк над окном, на прилавке весы со стрелкой
# и счёты, внутри полки с банками, сыром и хлебом, под потолком гирлянды колбас и «колечки»,
# сбоку доска с ценами. Вывеска «КОЛБАСА» — надпись в сцене над крышей.
W, D, H = 3.0, 2.0, 2.5
WALL = mat("KioskBlue", (0.2, 0.45, 0.68), 0.6)
FRAME = mat("KioskWhite", (0.95, 0.94, 0.9), 0.6)
ROOF = mat("KioskRoof", (0.3, 0.3, 0.33), 0.7)
SIGN = mat("KioskSign", (0.62, 0.05, 0.04), 0.5)
INNER = mat("KioskInner", (0.86, 0.8, 0.66), 0.8)
SHELF = mat("Shelf", (0.55, 0.36, 0.2), 0.7)
COUNTER = mat("CounterWood", (0.6, 0.4, 0.22), 0.6)
JAR = mat("Jar", (0.55, 0.72, 0.45), 0.25)
JAR2 = mat("JarRed", (0.75, 0.2, 0.15), 0.3)
LID = mat("JarLid", (0.8, 0.75, 0.3), 0.3, 0.6)
CHEESE = mat("Cheese", (0.98, 0.8, 0.3), 0.6)
BREAD = mat("Bread", (0.72, 0.45, 0.18), 0.8)
STRIPE_R = mat("AwningRed", (0.82, 0.12, 0.1), 0.7)
STRIPE_W = mat("AwningWhite", (0.97, 0.95, 0.9), 0.7)
METAL = mat("ScaleMetal", (0.75, 0.77, 0.8), 0.3, 0.7)
DIAL = mat("ScaleDial", (0.98, 0.97, 0.92), 0.5)
BLACK = mat("Black", (0.05, 0.05, 0.05), 0.5)
BOARD = mat("Chalkboard", (0.12, 0.2, 0.15), 0.9)
CHALK = mat("Chalk", (0.95, 0.95, 0.9), 0.9)
SAUSAGE_L = mat("SausageLight", (0.62, 0.22, 0.18), 0.5)
FONT = bpy.data.fonts.load("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")


def rbox(size, loc, m, rot=(0, 0, 0), bevel=0.0):
    """Коробка с поворотом вокруг своего центра. Поворот и сдвиг пишутся прямо в вершины:
    box() «применяет» положение, и точка опоры объекта оказывается в начале координат."""
    from mathutils import Euler, Matrix
    o = box(size, (0, 0, 0), m, bevel)
    o.data.transform(Matrix.Translation(loc) @ Euler(rot).to_matrix().to_4x4())
    return o


def scallop(r, loc, m):
    """Фестон козырька: приплюснутый полукруг, висит под краем (толщина 3 см)."""
    from mathutils import Matrix
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=r, depth=0.03, location=(0, 0, 0))
    o = finish(bpy.context.object, m)
    o.data.transform(Matrix.Translation(loc) @ Matrix.Diagonal((1, 1, 0.5, 1))
                     @ Matrix.Rotation(math.radians(90), 4, "X"))
    return o


def text(body, loc, size, m, rot=(math.radians(90), 0, 0), align="CENTER"):
    """Надпись, выдавленная в 3D (по умолчанию лицом к −Y, т. е. к покупателям)."""
    curve = bpy.data.curves.new("T", "FONT")
    curve.body = body
    curve.font = FONT
    curve.size = size
    curve.align_x = align
    curve.align_y = "CENTER"
    curve.extrude = 0.003
    curve.resolution_u = 2                                                      # меньше треугольников
    o = bpy.data.objects.new("T", curve)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target="MESH")
    return finish(bpy.context.object, m)


T = 0.08
FY = -D / 2
P = []
# Корпус: стены, фасад с окном, пол, крыша, вывеска.
P.append(box((W, T, H), (0, D / 2 - T / 2, H / 2), WALL))
P.append(box((T, D - 0.02, H), (-W / 2 + T / 2, 0.01, H / 2), WALL))
P.append(box((T, D - 0.02, H), (W / 2 - T / 2, 0.01, H / 2), WALL))
P.append(box((W, T, 1.0), (0, FY + T / 2, 0.5), WALL))
P.append(box((W, T, 0.45), (0, FY + T / 2, H - 0.225), WALL))
P.append(box((W - 2 * T, D - 2 * T, 0.02), (0, 0, 0.01), INNER))
P.append(box((W - 2 * T, 0.02, H - 0.1), (0, D / 2 - T - 0.011, H / 2), INNER))                 # обои внутри
P.append(box((W + 0.5, D + 0.5, 0.12), (0, 0, H + 0.06), ROOF, bevel=0.03))
P.append(box((W + 0.2, 0.08, 0.5), (0, FY - 0.15, H + 0.3), SIGN, bevel=0.02))
P.append(box((W + 0.26, 0.06, 0.56), (0, FY - 0.12, H + 0.3), FRAME, bevel=0.02))                # рамка вывески
for z in (0.3, 0.8):                                                     # белые полосы — только снаружи
    P.append(box((W + 0.02, 0.02, 0.1), (0, FY - 0.005, z), FRAME))
    P.append(box((W + 0.02, 0.02, 0.1), (0, D / 2 + 0.005, z), FRAME))
    for sx in (-1, 1):
        P.append(box((0.02, D + 0.02, 0.1), (sx * (W / 2 + 0.005), 0, z), FRAME))
# Окно: рамы.
for x in (-W / 2 + 0.06, W / 2 - 0.06):
    P.append(box((0.08, 0.1, 1.05), (x, FY - 0.005, 1.55), FRAME))
P.append(box((W, 0.1, 0.07), (0, FY, 2.06), FRAME))
# Полосатый козырёк над окном (наклонный, с фестонами).
n = 10
for k in range(n):
    x = -W / 2 - 0.1 + (k + 0.5) * (W + 0.2) / n
    m = STRIPE_R if k % 2 == 0 else STRIPE_W
    P.append(rbox(((W + 0.2) / n, 0.75, 0.03), (x, FY - 0.33, 2.2), m, rot=(math.radians(22), 0, 0)))
    P.append(scallop((W + 0.2) / n / 2, (x, FY - 0.68, 2.08), m))
# Прилавок: деревянная полка снаружи окна, белая столешница.
P.append(box((W + 0.1, 0.5, 0.06), (0, FY - 0.17, 1.0), FRAME, bevel=0.01))
P.append(box((W + 0.1, 0.04, 0.12), (0, FY - 0.41, 0.95), COUNTER, bevel=0.01))
# Весы со стрелкой (слева на прилавке).
SX = -0.95
P.append(box((0.36, 0.26, 0.08), (SX, FY - 0.17, 1.07), METAL, bevel=0.015))
P.append(cyl(0.15, 0.015, (SX, FY - 0.17, 1.12), METAL, verts=20))                             # чаша
P.append(box((0.08, 0.06, 0.2), (SX, FY - 0.08, 1.2), METAL))
P.append(cyl(0.11, 0.04, (SX, FY - 0.1, 1.38), METAL, verts=20, rot=(math.radians(90), 0, 0)))  # корпус шкалы
P.append(cyl(0.095, 0.042, (SX, FY - 0.105, 1.38), DIAL, verts=20, rot=(math.radians(90), 0, 0)))
P.append(rbox((0.008, 0.01, 0.08), (SX + 0.02, FY - 0.13, 1.4), SIGN, rot=(0, math.radians(-30), 0)))
# Счёты (справа на прилавке): рамка, прутья, костяшки.
AX = 0.95
for x in (AX - 0.2, AX + 0.2):
    P.append(box((0.03, 0.18, 0.03), (x, FY - 0.17, 1.045), COUNTER))
for y in (FY - 0.25, FY - 0.09):
    P.append(box((0.43, 0.03, 0.03), (AX, y, 1.045), COUNTER))
for r in range(4):
    y = FY - 0.23 + r * 0.04
    P.append(cyl(0.004, 0.4, (AX, y, 1.05), METAL, verts=4, rot=(0, math.radians(90), 0)))
    for b in range(5):
        x = AX - 0.15 + b * 0.04 + (0.08 if b > 2 - r % 2 else 0)
        P.append(sphere(0.016, (x, y, 1.05), BLACK if b % 4 == 0 else CHEESE, scale=(0.6, 1, 1)))
# Полки внутри: банки, сыр, хлеб.
for z in (1.15, 1.6):
    P.append(box((W - 0.3, 0.32, 0.04), (0, D / 2 - 0.26, z), SHELF))
    for i in range(8):
        x = -1.15 + i * 0.33
        if z > 1.3 and i in (2, 5):
            P.append(cyl(0.13, 0.1, (x, D / 2 - 0.26, z + 0.07), CHEESE, verts=14))             # сыр
            P.append(box((0.08, 0.06, 0.08), (x + 0.04, D / 2 - 0.26 - 0.07, z + 0.07), CHEESE))
        elif z < 1.3 and i in (1, 6):
            P.append(sphere(0.12, (x, D / 2 - 0.26, z + 0.08), BREAD, scale=(1.5, 0.8, 0.6), segs=10))
        else:
            m = JAR if (i + int(z * 10)) % 2 else JAR2
            P.append(cyl(0.065, 0.17, (x, D / 2 - 0.26, z + 0.105), m, verts=10))
            P.append(cyl(0.068, 0.025, (x, D / 2 - 0.26, z + 0.2), LID, verts=10))
# Колбасы под потолком: перекладина, разные палки и «колечки».
RAIL_Z = H - 0.5                                                                # видно в окне
P.append(cyl(0.02, W - 0.3, (0, D / 2 - 0.65, RAIL_Z), METAL, verts=8, rot=(0, math.radians(90), 0)))
for i in range(11):
    x = -1.2 + i * 0.24
    length = 0.32 + (i * 37 % 5) * 0.06
    m = SAUSAGE if i % 3 else SAUSAGE_L
    P.append(cyl(0.005, 0.12, (x, D / 2 - 0.65, RAIL_Z - 0.07), STRING, verts=4))
    if i % 4 == 2:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.12, minor_radius=0.035, major_segments=14,
                                         minor_segments=6, location=(x, D / 2 - 0.65, RAIL_Z - 0.25),
                                         rotation=(math.radians(90), 0, 0))
        P.append(finish(bpy.context.object, m))
    else:
        P.append(cyl(0.045, length, (x, D / 2 - 0.65, RAIL_Z - 0.13 - length / 2), m, verts=10))
        P.append(sphere(0.045, (x, D / 2 - 0.65, RAIL_Z - 0.13 - length), m, scale=(1, 1, 0.6)))
        P.append(cyl(0.047, 0.012, (x, D / 2 - 0.65, RAIL_Z - 0.2 - length / 3), STRING, verts=10))
# Лампочка над прилавком внутри.
P.append(cyl(0.004, 0.25, (0, -0.2, H - 0.12), BLACK, verts=4))
P.append(sphere(0.06, (0, -0.2, H - 0.27), mat("Bulb", (1.0, 0.95, 0.7), 0.3), segs=10))
# Доска с ценами на правой стене снаружи.
BX = W / 2 + 0.012
P.append(box((0.02, 0.85, 0.7), (BX, -0.2, 1.55), FRAME))
P.append(box((0.025, 0.78, 0.63), (BX + 0.003, -0.2, 1.55), BOARD))
side = (math.radians(90), 0, math.radians(90))
P.append(text("ЦЕНЫ", (BX + 0.017, -0.2, 1.78), 0.09, CHALK, rot=side))
for k, line in enumerate(["Докторская  2-20", "Любительская  2-90", "Сыр  3-10", "Хлеб  0-16"]):
    P.append(text(line, (BX + 0.017, -0.2, 1.63 - k * 0.1), 0.055, CHALK, rot=side))
# Табличка у окна.
P.append(box((0.4, 0.015, 0.16), (0.95, FY - 0.01, 0.6), FRAME))
P.append(text("ОДИН БАТОН\nВ ОДНИ РУКИ", (0.95, FY - 0.02, 0.6), 0.04, SIGN))
kiosk = export("kiosk", P)

if not RENDER:
    print("DONE")
    sys.exit(0)

# ---------------- Превью: все модели рядом ----------------
clear()
scene = bpy.context.scene
for f, loc, rot, s in [("kiosk", (0, 0, 0), 0, 1), ("sausage", (-2.4, -1.6, 0.6), 0.4, 3),
                       ("bat", (2.2, -1.8, 1.2), 0.0, 1.6), ("bat_super", (2.8, -1.8, 1.5), 0.0, 1.6),
                       ("energy_can", (1.4, -2.0, 0), 0.3, 5)]:
    bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, f + ".glb"))
    o = bpy.context.selected_objects[0]
    o.location = loc
    o.rotation_euler.z = rot
    o.scale = (s, s, s)
bpy.ops.mesh.primitive_plane_add(size=30)
bpy.context.object.data.materials.append(mat("Ground", (0.4, 0.42, 0.4), 0.9))


def light(kind, loc, energy, color=(1, 1, 1), size=1.0):
    d = bpy.data.lights.new(kind, kind)
    d.energy = energy
    d.color = color
    if kind == "AREA":
        d.size = size
    o = bpy.data.objects.new(kind, d)
    o.location = loc
    scene.collection.objects.link(o)
    o.rotation_euler = (Vector((0, 0, 1)) - o.location).to_track_quat("-Z", "Y").to_euler()


light("AREA", (-4, -6, 6), 1500, (1, 0.92, 0.8), 5)
light("AREA", (5, -4, 3), 400, (0.7, 0.8, 1), 3)
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.6, 0.7, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.5
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 35
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (3.2, -6.5, 3.4)
cam.rotation_euler = (Vector((0.2, 0, 1.1)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.engine = "CYCLES"
scene.cycles.samples = 80
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1400, 900
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.render.filepath = os.path.join(OUT, "_preview_minigame_props.png")
bpy.ops.render.render(write_still=True)
print("DONE")
