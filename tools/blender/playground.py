"""Детская площадка 90-х для «Морожки»: лавочка, открытая песочница, металлическая горка, качели
(рама и сиденье отдельно), карусель (основание и крутящаяся часть отдельно), секция забора.

Начало координат — на земле. Горка лежит вдоль X: лесенка на +X, скат вниз к −X.
Качели: рама вдоль X, сиденье висит на цепях — точка подвеса в начале координат модели сиденья.

Запуск:
    python tools/blender/playground.py assets/models/playground [--render превью.png]
"""
import bpy, bmesh, math, sys, os
from mathutils import Vector

args = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = args[0] if args else "."
RENDER = sys.argv[sys.argv.index("--render") + 1] if "--render" in sys.argv else None
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.cursor.location = (0, 0, 0)
_mats = {}
KEEP = []


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


def cyl(r, h, loc, m, verts=12, r2=None, rot=(0, 0, 0)):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc,
                                        rotation=rot)
    bpy.ops.object.transform_apply(rotation=True)
    return flat(bpy.context.object, m)


def rod(a, b, r, m, verts=8):
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


WOOD = mat("Wood", (0.55, 0.36, 0.18), 0.8)
CONCRETE = mat("Concrete", (0.62, 0.6, 0.56), 0.95)
RED = mat("PaintRed", (0.75, 0.15, 0.1), 0.6, 0.2)
BLUE = mat("PaintBlue", (0.15, 0.35, 0.7), 0.6, 0.2)
YELLOW = mat("PaintYellow", (0.9, 0.72, 0.12), 0.6, 0.2)
GREEN = mat("PaintGreen", (0.18, 0.45, 0.25), 0.6, 0.2)
STEEL = mat("Steel", (0.7, 0.72, 0.74), 0.3, 0.9)
SAND = mat("Sand", (0.86, 0.76, 0.52), 1.0)
CHAIN = mat("Chain", (0.35, 0.35, 0.37), 0.5, 0.8)

# ---------------- Лавочка (лицом к −Y) ----------------
P = []
for x in (-0.75, 0.75):
    P.append(box((0.12, 0.45, 0.42), (x, 0, 0.21), CONCRETE))
    P.append(box((0.1, 0.08, 0.5), (x, 0.2, 0.67), CONCRETE))
for k in range(3):
    P.append(box((1.8, 0.12, 0.04), (0, -0.15 + k * 0.14, 0.44), GREEN))
for k in range(2):
    P.append(box((1.8, 0.04, 0.12), (0, 0.24, 0.62 + k * 0.17), GREEN))
export("bench", [join("Bench", P)])

# ---------------- Открытая песочница 3×3 с «грибком» в углу ----------------
# Песок неровный (горка посередине, ямки, следы), борта — крашеные доски с щелями и широкой
# доской-сиденьем сверху, угловые столбики. «Грибок»: гладкая куполом шляпка с толщиной и светлым
# исподом, белые пятна лежат на шляпке (повторяют её изгиб), ножка — деревянная.
SAND_DARK = mat("SandDamp", (0.66, 0.55, 0.36), 1.0)
BOARD = mat("BoardGreen", (0.2, 0.46, 0.3), 0.75)
BOARD_EDGE = mat("BoardYellow", (0.86, 0.68, 0.2), 0.7)
CAP = mat("MushroomRed", (0.78, 0.13, 0.1), 0.45)
CAP_UNDER = mat("MushroomUnder", (0.5, 0.1, 0.08), 0.7)
DOT = mat("Dot", (0.96, 0.95, 0.9), 0.5)


def grid_surface(nx, ny, size, height, m):
    """Поверхность песка: сетка nx × ny на квадрате size, высота height(x, y)."""
    verts, faces = [], []
    for j in range(ny + 1):
        for i in range(nx + 1):
            x = -size / 2 + size * i / nx
            y = -size / 2 + size * j / ny
            verts.append((x, y, height(x, y)))
    for j in range(ny):
        for i in range(nx):
            a = j * (nx + 1) + i
            faces.append((a, a + 1, a + nx + 2, a + nx + 1))
    me = bpy.data.meshes.new("Sand")
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("Sand", me)
    bpy.context.scene.collection.objects.link(o)
    flat(o, m)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def sand_h(x, y):
    h = 0.25 + 0.025 * math.sin(x * 2.3) * math.cos(y * 1.9)
    h += 0.07 * math.exp(-((x + 0.5) ** 2 + (y + 0.6) ** 2) / 0.15)       # горка
    h -= 0.04 * math.exp(-((x - 0.7) ** 2 + (y - 0.3) ** 2) / 0.05)       # ямка
    # У бортов песок поднимается под доску-сиденье — без щели между песком и бортом.
    edge = max(abs(x), abs(y))
    if edge > 1.1:
        k = min(1.0, (edge - 1.1) / 0.2)
        h += (0.33 - h) * k
    return h


def lathe_mesh(profile, m, n=28, smooth=True):
    """Тело вращения по профилю [(r, z)] (замкнутый контур идёт по кругу — без крышек)."""
    verts, faces = [], []
    for r, z in profile:
        for k in range(n):
            a = k / n * math.tau
            verts.append((math.cos(a) * r, math.sin(a) * r, z))
    for i in range(len(profile) - 1):
        for k in range(n):
            a, b = i * n + k, i * n + (k + 1) % n
            faces.append((a, b, b + n, a + n))
    me = bpy.data.meshes.new("Lathe")
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("Lathe", me)
    bpy.context.scene.collection.objects.link(o)
    flat(o, m)
    for p in o.data.polygons:
        p.use_smooth = smooth
    return o


P = [box((2.8, 2.8, 0.2), (0, 0, 0.1), SAND), grid_surface(28, 28, 2.8, sand_h, SAND)]
for x, y, r in ((0.4, -0.9, 0.22), (-0.9, 0.6, 0.18)):                     # влажные пятна
    P.append(cyl(r, 0.004, (x, y, sand_h(x, y) + 0.003), SAND_DARK, verts=14))
# Борта: по две доски на сторону со щелью, сверху широкая доска-сиденье с жёлтой кромкой.
for s in (-1, 1):
    for z in (0.09, 0.25):
        P.append(box((2.9, 0.06, 0.13), (0, s * 1.4, z), BOARD))
        P.append(box((0.06, 2.74, 0.13), (s * 1.4, 0, z), BOARD))
    P.append(box((3.04, 0.22, 0.04), (0, s * 1.41, 0.34), WOOD))
    P.append(box((0.22, 2.6, 0.04), (s * 1.41, 0, 0.34), WOOD))
    P.append(box((3.06, 0.025, 0.045), (0, s * 1.525, 0.34), BOARD_EDGE))
    P.append(box((0.025, 3.06, 0.045), (s * 1.525, 0, 0.34), BOARD_EDGE))
for sx in (-1, 1):                                                          # угловые столбики
    for sy in (-1, 1):
        P.append(box((0.12, 0.12, 0.42), (sx * 1.44, sy * 1.44, 0.21), WOOD))
# «Грибок» в углу.
MX, MY = 1.2, 1.2
P.append(cyl(0.06, 2.05, (MX, MY, 1.03), WOOD, verts=14))                  # деревянная ножка
P.append(cyl(0.085, 0.06, (MX, MY, 0.32), WOOD, verts=14))                 # хомут у песка
cap_top = [(0.0, 2.52), (0.25, 2.5), (0.5, 2.42), (0.72, 2.28), (0.88, 2.12), (0.95, 2.02)]
cap = lathe_mesh(cap_top + [(0.95, 1.99)], CAP)
# Изнанка — тонкая оболочка по форме шляпки (как у зонтика, без «заливки»), тёмно-красная;
# снизу видны спицы-рёбра от ножки к краю.
under = lathe_mesh([(r, z - 0.03) for r, z in reversed(cap_top)][:-1] + [(0.0, cap_top[0][1] - 0.03)],
                   CAP_UNDER)
for o in (cap, under):
    o.location = (MX, MY, 0)
    bpy.context.view_layer.update()
P += [cap, under]
for k in range(8):
    a = k * math.tau / 8
    for (r0, z0), (r1, z1) in zip(cap_top[1:], cap_top[2:]):
        P.append(rod((MX + math.cos(a) * r0, MY + math.sin(a) * r0, z0 - 0.045),
                     (MX + math.cos(a) * r1, MY + math.sin(a) * r1, z1 - 0.045), 0.012, WOOD, verts=5))
    P.append(rod((MX, MY, 2.08), (MX + math.cos(a) * 0.25, MY + math.sin(a) * 0.25, 2.455), 0.012, WOOD, verts=5))
P.append(cyl(0.075, 0.04, (MX, MY, 2.08), WOOD, verts=14))                 # шляпка садится на ножку


def cap_z(r):
    for (r0, z0), (r1, z1) in zip(cap_top, cap_top[1:]):
        if r0 <= r <= r1:
            return z0 + (z1 - z0) * (r - r0) / (r1 - r0)
    return cap_top[-1][1]


for i, (rr, a) in enumerate(((0.0, 0.0), (0.45, 0.3), (0.5, 1.9), (0.47, 3.4), (0.48, 4.9),
                             (0.75, 1.1), (0.74, 2.6), (0.76, 4.1), (0.73, 5.6))):
    z = cap_z(rr)
    slope = math.atan2(cap_z(max(0.0, rr - 0.05)) - cap_z(rr + 0.05), 0.1) if rr > 0 else 0.0
    bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=6, radius=1.0,
                                         location=(MX + math.cos(a) * rr, MY + math.sin(a) * rr, z + 0.004))
    dot = bpy.context.object
    size = 0.1 if i == 0 else (0.08 if rr < 0.6 else 0.065)
    dot.scale = (size, size * 0.85, 0.012)
    dot.rotation_euler = (0, slope, a)                                     # по наклону шляпки
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    flat(dot, DOT)
    for p in dot.data.polygons:
        p.use_smooth = True
    P.append(dot)
# Игрушки на песке (стоят по его высоте): ведёрко, лопатка, формочки и куличики.
TOY_RED = mat("ToyRed", (0.78, 0.14, 0.12), 0.45)
TOY_BLUE = mat("ToyBlue", (0.2, 0.42, 0.8), 0.45)
TOY_YELLOW = mat("ToyYellow", (0.95, 0.78, 0.2), 0.45)
WET_SAND = mat("SandCake", (0.78, 0.66, 0.44), 1.0)
bx, by = 0.6, 0.4                                                           # ведёрко (наклонное дно)
bz = sand_h(bx, by)
P.append(lathe_mesh([(0.0, bz), (0.09, bz), (0.125, bz + 0.2), (0.135, bz + 0.21), (0.135, bz + 0.225),
                     (0.122, bz + 0.225), (0.112, bz + 0.03), (0.0, bz + 0.03)], TOY_RED, n=20))
bpy.ops.mesh.primitive_torus_add(major_radius=0.13, minor_radius=0.006, major_segments=20, minor_segments=5,
                                 location=(bx, by, bz + 0.21), rotation=(math.pi / 2, 0, 0.4))
bpy.ops.object.transform_apply(rotation=True)
handle = flat(bpy.context.object, TOY_YELLOW)
bm = bmesh.new(); bm.from_mesh(handle.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.005], context="VERTS")
bm.to_mesh(handle.data); bm.free()
P.append(handle)
P[-2].location = (bx, by, 0)
# Лопатка: черенок с ручкой-перекладиной и вогнутый совок, лежит наискосок.
sx, sy = -0.4, -0.2
sz = sand_h(sx, sy) + 0.015
P.append(rod((sx - 0.18, sy - 0.14, sz), (sx + 0.06, sy + 0.05, sz), 0.012, TOY_BLUE, verts=8))
P.append(rod((sx - 0.22, sy - 0.1, sz), (sx - 0.14, sy - 0.18, sz), 0.014, TOY_BLUE, verts=8))
scoop = lathe_mesh([(0.0, 0.0), (0.06, 0.006), (0.075, 0.025)], TOY_BLUE, n=14)
scoop.scale = (1.0, 1.3, 1.0)
scoop.rotation_euler = (0, 0, math.atan2(0.19, 0.24) - math.pi / 2)
scoop.location = (sx + 0.13, sy + 0.1, sz - 0.012)
P.append(scoop)
# Формочки и куличики: формочка-«звезда» вверх дном и два ребристых куличика.
fx, fy = 0.1, 0.6
P.append(lathe_mesh([(0.0, 0.0), (0.09, 0.0), (0.075, 0.07), (0.0, 0.07)], TOY_YELLOW, n=10))
P[-1].location = (fx, fy, sand_h(fx, fy))
for cx, cy, h in ((0.35, 0.5, 0.06), (0.32, 0.75, 0.05)):
    cake = lathe_mesh([(0.0, 0.0), (0.075, 0.0), (0.06, h), (0.0, h)], WET_SAND, n=16)
    cake.location = (cx, cy, sand_h(cx, cy))
    P.append(cake)
bpy.context.view_layer.update()
export("sandbox", [join("Sandbox", P)])

# ---------------- Горка: лесенка на +X, площадка, скат к −X ----------------
TOP = 1.6
P = []
for y in (-0.32, 0.32):                                                       # лесенка
    P.append(rod((1.9, y, 0), (1.5, y, TOP), 0.035, BLUE))
for k in range(5):
    t = (k + 1) / 6
    P.append(rod((1.9 - 0.4 * t, -0.32, TOP * t), (1.9 - 0.4 * t, 0.32, TOP * t), 0.022, STEEL))
P.append(box((0.7, 0.7, 0.06), (1.2, 0, TOP), YELLOW))                        # площадка
for x in (0.88, 1.52):
    for y in (-0.32, 0.32):
        P.append(rod((x, y, 0), (x, y, TOP), 0.03, BLUE))
for y in (-0.35, 0.35):                                                       # перила
    P.append(rod((1.52, y, TOP), (1.52, y, TOP + 0.6), 0.025, BLUE))
    P.append(rod((0.88, y, TOP), (0.88, y, TOP + 0.6), 0.025, BLUE))
    P.append(rod((0.88, y, TOP + 0.6), (1.52, y, TOP + 0.6), 0.025, BLUE))
chute_len = math.hypot(2.4, TOP - 0.25)
angle = math.atan2(TOP - 0.25, 2.4)
P.append(box((chute_len, 0.6, 0.04), (0.85 - 1.2, 0, (TOP + 0.25) / 2), STEEL, rot=(0, -angle, 0)))
for y in (-0.31, 0.31):
    P.append(box((chute_len, 0.04, 0.14), (0.85 - 1.2, y, (TOP + 0.25) / 2 + 0.06), RED, rot=(0, -angle, 0)))
P.append(box((0.5, 0.6, 0.04), (-1.55 - 0.1, 0, 0.25), STEEL))                # конец ската
P.append(rod((-1.7, -0.25, 0), (-1.7, -0.25, 0.25), 0.03, BLUE))
P.append(rod((-1.7, 0.25, 0), (-1.7, 0.25, 0.25), 0.03, BLUE))
export("slide", [join("Slide", P)])

# ---------------- Качели: рама на 2 сиденья (вдоль X), перекладина на высоте 2.4 ----------------
BEAM = 2.4
P = [rod((-1.6, 0, BEAM), (1.6, 0, BEAM), 0.06, BLUE)]
for x in (-1.5, 1.5):
    for y in (-0.7, 0.7):
        P.append(rod((x, y, 0), (x, 0, BEAM), 0.05, BLUE))
export("swing_frame", [join("SwingFrame", P)])
# Сиденье: подвес в начале координат, висит вниз на 1.9 м.
P = [box((0.6, 0.3, 0.05), (0, 0, -1.9), WOOD)]
for x in (-0.27, 0.27):
    P.append(rod((x, 0, 0), (x, 0, -1.88), 0.012, CHAIN, verts=4))
export("swing_seat", [join("SwingSeat", P)])

# ---------------- Карусель: основание (неподвижное) и крутящаяся часть ----------------
P = [cyl(0.2, 0.15, (0, 0, 0.075), CONCRETE, verts=10)]
export("carousel_base", [join("CarouselBase", P)])
# Крутящаяся часть: крашеный диск (не металл) из «долек» двух сдержанных цветов с тёмными швами, стальной обод, центральная стойка с колпаком, поручни —
# трубки, сходящиеся к центру, с резиновыми ручками.
DECK = mat("CarouselDeckPaint", (0.3, 0.32, 0.33), 0.7)               # тёмные швы между дольками
DECK_A = mat("CarouselDeckA", (0.42, 0.55, 0.62), 0.75)                   # выцветший синий
DECK_B = mat("CarouselDeckB", (0.72, 0.68, 0.56), 0.75)                   # выцветший бежевый
RIM = mat("CarouselRim", (0.35, 0.36, 0.38), 0.5)
GRIP = mat("CarouselGrip", (0.12, 0.12, 0.13), 0.8)
P = [cyl(1.3, 0.08, (0, 0, 0.3), DECK, verts=36)]
n = 12
for i in range(n):                                                            # «дольки»
    a0, a1 = i * math.tau / n + 0.03, (i + 1) * math.tau / n - 0.03
    pts = [(0.0, 0.0, 0.343)]
    for k in range(5):
        a = a0 + (a1 - a0) * k / 4
        pts.append((math.cos(a) * 1.18, math.sin(a) * 1.18, 0.343))
    me = bpy.data.meshes.new("Slice")
    me.from_pydata(pts, [], [tuple(range(len(pts)))])
    o = bpy.data.objects.new("Slice", me)
    bpy.context.scene.collection.objects.link(o)
    P.append(flat(o, [DECK_A, DECK_B][i % 2]))
bpy.ops.mesh.primitive_torus_add(major_radius=1.28, minor_radius=0.045, major_segments=36, minor_segments=6,
                                 location=(0, 0, 0.32))
P.append(flat(bpy.context.object, RIM))                                       # обод
P.append(cyl(0.14, 0.05, (0, 0, 0.36), RIM, verts=16))                        # ступица
P.append(cyl(0.05, 0.85, (0, 0, 0.78), YELLOW, verts=12))                     # стойка
P.append(cyl(0.1, 0.08, (0, 0, 1.2), RED, verts=16, r2=0.04))                 # колпак
for i in range(4):                                                            # поручни
    a = i * math.pi / 2 + math.pi / 4
    x, y = math.cos(a), math.sin(a)
    P.append(rod((x * 1.1, y * 1.1, 0.34), (x * 1.1, y * 1.1, 0.95), 0.03, BLUE))
    P.append(rod((x * 1.1, y * 1.1, 0.95), (x * 0.08, y * 0.08, 1.12), 0.028, BLUE))
    P.append(rod((x * 0.75, y * 0.75, 0.99), (x * 0.45, y * 0.45, 1.04), 0.04, GRIP))   # ручка
bpy.ops.mesh.primitive_torus_add(major_radius=1.1, minor_radius=0.03, major_segments=36, minor_segments=6,
                                 location=(0, 0, 0.95))
P.append(flat(bpy.context.object, BLUE))
export("carousel_top", [join("CarouselTop", P)])

# ---------------- Забор: секция 2 м (вдоль X), низкий металлический ----------------
P = [rod((-1.0, 0, 0.85), (1.0, 0, 0.85), 0.03, GREEN), rod((-1.0, 0, 0.2), (1.0, 0, 0.2), 0.03, GREEN)]
for k in range(9):
    x = -0.9 + k * 0.225
    P.append(rod((x, 0, 0.0), (x, 0, 1.0), 0.018, GREEN, verts=6))
    P.append(cyl(0.035, 0.08, (x, 0, 1.03), GREEN, verts=4, r2=0.0))
P.append(cyl(0.05, 1.1, (-1.0, 0, 0.55), GREEN, verts=8))
export("fence", [join("Fence", P)])

# ---------------- Металлические снаряды-препятствия (по краям площадки) ----------------
# Окрашенные трубы пастельных цветов, как во дворах 80-х: шведская стенка, «глобус», дуга.
SKY = mat("PaintSky", (0.3, 0.68, 0.85), 0.55, 0.2)
PINK = mat("PaintPink", (0.85, 0.52, 0.58), 0.55, 0.2)
MINT = mat("PaintMint", (0.42, 0.72, 0.48), 0.55, 0.2)
ORANGE = mat("PaintOrange", (0.92, 0.6, 0.25), 0.55, 0.2)


def polyline(pts, r, m, closed=False, verts=6):
    """Труба по точкам (кольца и дуги — отрезками)."""
    out = []
    n = len(pts)
    for i in range(n if closed else n - 1):
        out.append(rod(pts[i], pts[(i + 1) % n], r, m, verts=verts))
    for p in pts:                                                  # шарики на стыках — без щелей
        bpy.ops.mesh.primitive_uv_sphere_add(segments=verts, ring_count=4, radius=r, location=p)
        out.append(flat(bpy.context.object, m))
    return out


# Шведская стенка: две стойки 2.6 м, 9 перекладин, сверху перекладина пошире.
P = []
for x in (-0.5, 0.5):
    P.append(rod((x, 0, 0), (x, 0, 2.6), 0.045, SKY, verts=10))
    P.append(cyl(0.08, 0.06, (x, 0, 0.03), CONCRETE, verts=10))
for k in range(9):
    P.append(rod((-0.5, 0, 0.3 + k * 0.27), (0.5, 0, 0.3 + k * 0.27), 0.022, SKY, verts=8))
P.append(rod((-0.5, 0, 2.6), (0.5, 0, 2.6), 0.04, PINK, verts=8))
export("wall_bars", [join("WallBars", P)])

# «Глобус»: шар из труб (меридианы и параллели) на шести ножках.
P = []
R, CZ = 1.05, 1.45
for k in range(6):                                                 # меридианы
    a = k * math.pi / 6
    pts = [(R * math.sin(t) * math.cos(a), R * math.sin(t) * math.sin(a), CZ + R * math.cos(t))
           for t in [i * math.pi / 12 for i in range(25)]]
    P += polyline(pts[:-1], 0.025, SKY, closed=True)
for z, m in ((0.55, PINK), (0.0, MINT), (-0.55, ORANGE)):          # параллели
    rr = R * math.sqrt(1 - (z / R) ** 2)
    pts = [(rr * math.cos(i * math.tau / 24), rr * math.sin(i * math.tau / 24), CZ + z * R / R) for i in range(24)]
    P += polyline(pts, 0.025, m, closed=True)
for k in range(6):                                                 # ножки
    a = k * math.tau / 6 + 0.3
    top = (0.55 * math.cos(a), 0.55 * math.sin(a), CZ - 0.88)
    P.append(rod(top, (1.0 * math.cos(a), 1.0 * math.sin(a), 0.0), 0.03, SKY))
export("climbing_globe", [join("ClimbingGlobe", P)])

# Дуга-лесенка: две полуокружности (радиус 1.1 м) и перекладины между ними.
P = []
RA, W2 = 1.1, 0.35
for y in (-W2, W2):
    pts = [(RA * math.cos(t), y, RA * math.sin(t)) for t in [i * math.pi / 14 for i in range(15)]]
    P += polyline(pts, 0.035, SKY)
for i in range(1, 14):
    t = i * math.pi / 14
    P.append(rod((RA * math.cos(t), -W2, RA * math.sin(t)), (RA * math.cos(t), W2, RA * math.sin(t)),
                 0.02, MINT if i % 2 else ORANGE))
export("arch_ladder", [join("ArchLadder", P)])

if RENDER:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1600, 900
    scene.world = bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.82, 0.9, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.5
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (0.7, 0.2, -0.6)
    scene.collection.objects.link(sun)
    place = {"bench": (-6, -1, 0), "sandbox": (-3, 2, 0), "slide": (1.5, 1, 0),
             "swing_frame": (5.5, 2, 0), "swing_seat": (5.5 - 0.6, 2, 2.4), "carousel_base": (-6, 4, 0),
             "carousel_top": (-6, 4, 0), "fence": (2, -2, 0),
             "wall_bars": (-1, -4, 0), "climbing_globe": (2, -4.5, 0), "arch_ladder": (5.5, -4, 0)}
    for name, objs in KEEP:
        for o in objs:
            o.location += Vector(place[name])
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (0, -11, 7)
    cam.rotation_euler = (Vector((0, 1.5, 0.8)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = RENDER
    bpy.ops.render.render(write_still=True)
print("DONE")
