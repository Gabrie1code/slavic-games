"""Уют для квартиры: настенные полки и комнатные растения (низкополигонально).

  wall_shelf_books.glb  — полка на кронштейнах: книги, матрёшка, слоник-статуэтка;
  wall_shelf_plants.glb — полка: два горшка, традесканция свисает вниз, баночка;
  plant_ficus.glb       — фикус в кадке (~1.5 м);
  plant_snake.glb       — «тёщин язык» (сансевиерия) в горшке (~0.8 м);
  plant_palm.glb        — пальма в кадке (~1.3 м);
  wall_carpet_green.glb — второй ковёр на стену (зелёно-бежевый с рядами «гёлей»), как wall_carpet
                          по размеру (2.6 × 1.7, лежит в плоскости XZ лицом к −Y);
  floor_rug_oval.glb    — овальный плетёный половик (кольца разных цветов);
  floor_runner.glb      — ковровая дорожка 3 × 0.8 с полосами по краям.
Полки: задняя сторона у стены в y = 0 (смотрят на −Y, в Godot +Z), низ полки на z = 0.

Запуск:
    python tools/blender/decor.py assets/models/apartment
    python tools/blender/decor.py assets/models/apartment --render   # + docs/previews/decor.png
"""
import bpy, math, os, random, sys
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else "."
RENDER = "--render" in sys.argv
os.makedirs(OUT, exist_ok=True)
random.seed(5)
bpy.ops.wm.read_factory_settings(use_empty=True)
_mats = {}


def mat(name, color, rough=0.6):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    _mats[name] = m
    return m


WOOD = mat("WoodPolish", (0.28, 0.12, 0.04), 0.4)
IRON = mat("Bracket", (0.15, 0.15, 0.15), 0.5)
CLAY = mat("Clay", (0.65, 0.3, 0.15), 0.8)
TUB = mat("Tub", (0.35, 0.2, 0.1), 0.7)
SOIL = mat("Soil", (0.18, 0.11, 0.06), 0.9)
LEAF = mat("Leaf", (0.15, 0.42, 0.15), 0.7)
LEAF2 = mat("Leaf2", (0.25, 0.55, 0.2), 0.7)
LEAF3 = mat("LeafStripe", (0.55, 0.65, 0.2), 0.7)
TRUNK = mat("Trunk", (0.35, 0.24, 0.12), 0.8)
BOOKS = [mat("Book%d" % i, c, 0.8) for i, c in enumerate(
    [(0.6, 0.1, 0.08), (0.1, 0.25, 0.5), (0.15, 0.4, 0.15), (0.8, 0.6, 0.1), (0.4, 0.15, 0.4)])]
MATR_RED = mat("MatrRed", (0.8, 0.1, 0.08), 0.4)
MATR_FACE = mat("MatrFace", (0.95, 0.85, 0.7), 0.5)
MATR_GOLD = mat("MatrGold", (0.9, 0.7, 0.2), 0.4)
WHITE = mat("Porcelain", (0.92, 0.92, 0.9), 0.3)
GLASS = mat("JarGlass", (0.75, 0.85, 0.8), 0.2)


def flat(o, m, smooth=False):
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = smooth
    return o


def box(size, loc, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    return flat(o, m)


def cyl(r, h, loc, m, verts=10, r2=None, rot=(0, 0, 0)):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc,
                                        rotation=rot)
    return flat(bpy.context.object, m)


def blob(r, loc, m, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return flat(o, m)


def leaf(base, length, width, yaw, pitch, m):
    """Плоский вытянутый лист из точки base: направление — yaw (вокруг Z), наклон pitch от вертикали."""
    me = bpy.data.meshes.new("Leaf")
    d = Vector((math.sin(pitch) * math.cos(yaw), math.sin(pitch) * math.sin(yaw), math.cos(pitch)))
    side = Vector((-math.sin(yaw), math.cos(yaw), 0)) * width / 2
    b = Vector(base)
    tip = b + d * length
    mid = b + d * length * 0.45
    me.from_pydata([b, mid + side, tip, mid - side], [], [(0, 1, 2, 3)])
    o = bpy.data.objects.new("Leaf", me)
    bpy.context.collection.objects.link(o)
    return flat(o, m)


def pot(r, h, m=CLAY):
    return [cyl(r, h, (0, 0, h / 2), m, verts=10, r2=r * 1.25), cyl(r * 1.15, 0.02, (0, 0, h - 0.01), SOIL)]


def export(name, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True,
                              export_format="GLB")
    print("EXPORTED", name)
    return obj


def shelf_base(length=0.9):
    parts = [box((length, 0.22, 0.03), (0, -0.11, 0.015), WOOD)]
    for x in (-length / 2 + 0.12, length / 2 - 0.12):
        parts.append(box((0.025, 0.02, 0.16), (x, -0.01, -0.08), IRON))
        parts.append(box((0.025, 0.16, 0.02), (x, -0.09, -0.01), IRON))
    return parts


def matryoshka(x, y, s):
    return [cyl(0.045 * s, 0.08 * s, (x, y, 0.03 + 0.04 * s), MATR_RED, verts=10, r2=0.04 * s),
            blob(0.035 * s, (x, y, 0.03 + 0.11 * s), MATR_RED),
            blob(0.024 * s, (x, y - 0.02 * s, 0.03 + 0.11 * s), MATR_FACE, scale=(1, 0.6, 1)),
            cyl(0.046 * s, 0.012 * s, (x, y, 0.03 + 0.06 * s), MATR_GOLD, verts=10)]


# ---- Полка с книгами ----
P = shelf_base()
x = -0.4
for i in range(7):
    h = random.uniform(0.16, 0.21)
    tilt = 0.25 if i == 6 else 0.0
    P.append(box((0.035, 0.15, h), (x, -0.1, 0.03 + h / 2), BOOKS[i % 5], rot=(0, tilt, 0)))
    x += 0.04
P += matryoshka(0.05, -0.1, 1.0) + matryoshka(0.15, -0.1, 0.75) + matryoshka(0.23, -0.1, 0.55)
P.append(blob(0.05, (0.36, -0.1, 0.09), WHITE, scale=(1.3, 0.8, 0.9)))              # слоник
P.append(cyl(0.012, 0.05, (0.42, -0.1, 0.1), WHITE, verts=6, r2=0.008, rot=(0, 0.9, 0)))
for lx in (0.31, 0.41):
    P.append(cyl(0.012, 0.05, (lx, -0.1, 0.055), WHITE, verts=6))
export("wall_shelf_books", P)

# ---- Полка с растениями ----
P = shelf_base()
for px in (-0.28, 0.2):
    for o in pot(0.055, 0.1):
        o.location += Vector((px, -0.11, 0.03))
        P.append(o)
for k in range(9):                                                        # традесканция свисает
    a = k / 9 * math.tau
    P.append(leaf((-0.28, -0.11, 0.13), random.uniform(0.15, 0.3), 0.06, a, random.uniform(1.6, 2.4),
                  LEAF2 if k % 2 else LEAF3))
for k in range(6):                                                        # кактус-«мышка» справа
    P.append(blob(0.035, (0.2 + random.uniform(-0.03, 0.03), -0.11, 0.15 + k * 0.025), LEAF,
                  scale=(1, 1, 1.3)))
P.append(cyl(0.035, 0.09, (-0.02, -0.1, 0.075), GLASS, verts=10))           # баночка с пуговицами
P.append(cyl(0.037, 0.015, (-0.02, -0.1, 0.125), MATR_RED, verts=10))
export("wall_shelf_plants", P)

# ---- Фикус ----
P = pot(0.18, 0.32, TUB)
P.append(cyl(0.025, 0.9, (0, 0, 0.75), TRUNK, verts=6, r2=0.015))
for k in range(14):
    z = random.uniform(0.75, 1.45)
    a = random.uniform(0, math.tau)
    r = random.uniform(0.12, 0.32)
    P.append(blob(random.uniform(0.12, 0.18), (math.cos(a) * r, math.sin(a) * r, z),
                  LEAF if k % 2 else LEAF2, scale=(1, 1, 0.7)))
export("plant_ficus", P)

# ---- Тёщин язык ----
P = pot(0.12, 0.22)
for k in range(11):
    a = k / 11 * math.tau + random.uniform(-0.2, 0.2)
    P.append(leaf((math.cos(a) * 0.04, math.sin(a) * 0.04, 0.2), random.uniform(0.4, 0.62), 0.07,
                  a, random.uniform(0.05, 0.3), LEAF if k % 3 else LEAF3))
export("plant_snake", P)

# ---- Пальма ----
P = pot(0.16, 0.3, TUB)
P.append(cyl(0.04, 0.55, (0, 0, 0.57), TRUNK, verts=7, r2=0.03))
for k in range(9):
    a = k / 9 * math.tau
    P.append(leaf((0, 0, 0.82), random.uniform(0.45, 0.6), 0.16, a, random.uniform(0.9, 1.3),
                  LEAF if k % 2 else LEAF2))
export("plant_palm", P)

# ---- Ковёр на стену №2: зелёный, ряды восьмиугольников ----
GREEN = mat("CarpetGreen", (0.1, 0.28, 0.18), 0.95)
BEIGE = mat("CarpetBeige", (0.82, 0.72, 0.52), 0.95)
BROWN = mat("CarpetBrown", (0.4, 0.16, 0.08), 0.95)
ORANGE = mat("CarpetOrange", (0.8, 0.4, 0.1), 0.95)
W, H, Z0 = 2.6, 1.7, 0.85
P = [box((W, 0.03, H), (0, 0, Z0), BROWN), box((W - 0.14, 0.034, H - 0.14), (0, 0, Z0), BEIGE),
     box((W - 0.3, 0.038, H - 0.3), (0, 0, Z0), GREEN)]
for row in range(2):
    for col in range(4):
        x = -0.84 + col * 0.56
        z = Z0 - 0.3 + row * 0.6
        for size, c in ((0.36, BEIGE), (0.26, BROWN), (0.14, ORANGE)):
            bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=size / 2, depth=0.04 + (0.4 - size) * 0.02,
                                                location=(x, 0, z), rotation=(math.pi / 2, math.pi / 8, 0))
            P.append(flat(bpy.context.object, c))
for i in range(9):
    for zz in (Z0 - H / 2 - 0.04, Z0 + H / 2 + 0.04):
        P.append(box((0.03, 0.02, 0.08), (-1.2 + i * 0.3, 0, zz), BEIGE))
export("wall_carpet_green", P)

# ---- Овальный плетёный половик ----
P = []
colors = [mat("Rag%d" % i, c, 0.95) for i, c in enumerate(
    [(0.55, 0.15, 0.1), (0.2, 0.35, 0.55), (0.85, 0.7, 0.35), (0.3, 0.5, 0.25), (0.7, 0.45, 0.55)])]
for k in range(7):
    r = 1.0 - k * 0.13
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=r, depth=0.012 + k * 0.002, location=(0, 0, 0.006 + k * 0.001))
    o = bpy.context.object
    o.scale = (1.0, 0.68, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    P.append(flat(o, colors[k % 5]))
export("floor_rug_oval", P)

# ---- Ковровая дорожка ----
RUN = mat("RunnerRed", (0.5, 0.06, 0.06), 0.95)
P = [box((3.0, 0.8, 0.012), (0, 0, 0.006), RUN)]
for y in (-0.3, 0.3):
    P.append(box((3.0, 0.07, 0.015), (0, y, 0.0075), mat("RunnerGreen", (0.12, 0.35, 0.18), 0.95)))
    P.append(box((3.0, 0.025, 0.016), (0, y * 0.82, 0.008), BEIGE))
for i in range(8):
    P.append(box((0.12, 0.12, 0.016), (-1.3 + i * 0.37, 0, 0.008), BEIGE, rot=(0, 0, math.radians(45))))
export("floor_runner", P)

if not RENDER:
    sys.exit(0)
scene = bpy.context.scene
for i, name in enumerate(["wall_shelf_books", "wall_shelf_plants", "plant_ficus", "plant_snake", "plant_palm"]):
    o = bpy.data.objects[name]
    o.location = (i * 1.0 - 2.0, 0, 1.0 if name.startswith("wall") else 0)
bpy.data.objects["wall_carpet_green"].location = (2.6, -0.02, 0.4)
bpy.data.objects["floor_rug_oval"].location = (-1.0, -1.6, 0.0)
bpy.data.objects["floor_runner"].location = (1.6, -1.8, 0.0)
bpy.ops.mesh.primitive_plane_add(size=10)
flat(bpy.context.object, mat("Floor", (0.4, 0.28, 0.17), 0.8))
bpy.ops.mesh.primitive_plane_add(size=10, location=(0, 0.01, 2), rotation=(math.pi / 2, 0, 0))
flat(bpy.context.object, mat("Wall", (0.75, 0.68, 0.5), 0.9))
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1400, 700
scene.view_settings.view_transform = "Standard"
scene.world = bpy.data.worlds.new("W")
scene.world.color = (0.35, 0.35, 0.37)
sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN"))
sun.data.energy = 2.5
sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (0.6, -7.5, 2.6)
cam.rotation_euler = (Vector((0.6, -0.5, 0.75)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.filepath = os.path.abspath("docs/previews/decor.png")
bpy.ops.render.render(write_still=True)
