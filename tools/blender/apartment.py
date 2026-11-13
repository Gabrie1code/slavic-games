"""Мебель и вещи советской квартиры для лобби.

Каждый предмет — отдельный .glb в assets/models/apartment/. Стоит на полу (z = 0 в Blender),
лицевой стороной к камере: −Y в Blender = +Z в Godot.

Запуск:
    python tools/blender/apartment.py assets/models/apartment           # .glb
    python tools/blender/apartment.py assets/models/apartment --render  # + превью
"""
import bpy, bmesh, math, sys, os, random
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else "."
RENDER = "--render" in sys.argv
os.makedirs(OUT, exist_ok=True)
random.seed(7)
bpy.ops.wm.read_factory_settings(use_empty=True)
_mats = {}


def mat(name, color, rough=0.6, metal=0.0, alpha=1.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    _mats[name] = m
    return m


def flat(o, m, bevel=0.0, segs=1):
    o.data.materials.append(m)
    if bevel:
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segs
        mod.limit_method = "ANGLE"
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def box(size, loc, m, bevel=0.0, rot=(0, 0, 0), segs=1):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    return flat(o, m, bevel, segs)


def cyl(r, h, loc, m, verts=10, r2=None, rot=(0, 0, 0), scale=(1, 1, 1)):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    return flat(o, m)


def sphere(r, loc, m, scale=(1, 1, 1), segs=10, rings=6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return flat(o, m)


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
    print("EXPORTED", name, sum(len(p.vertices) - 2 for p in obj.data.polygons), "tris")
    obj.location.x += 100  # убрать с дороги (для превью двигаем отдельно)
    return obj


# ---------------- Материалы ----------------
WOOD = mat("WoodPolish", (0.28, 0.12, 0.04), 0.35)
WOOD_L = mat("WoodLight", (0.55, 0.33, 0.14), 0.5)
FABRIC = mat("SofaFabric", (0.42, 0.25, 0.08), 0.9)
FABRIC2 = mat("SofaFabric2", (0.35, 0.2, 0.06), 0.9)
GLASS = mat("Crystal", (0.75, 0.9, 1.0), 0.05, 0.0, 0.45)
JAR_GLASS = mat("JarGlass", (0.8, 0.95, 0.9), 0.05, 0.0, 0.35)
LID = mat("Lid", (0.7, 0.7, 0.72), 0.3, 1.0)
CLAY = mat("Clay", (0.65, 0.3, 0.15), 0.8)
GREEN = mat("Plant", (0.15, 0.45, 0.15), 0.7)
METAL = mat("Brass", (0.75, 0.6, 0.3), 0.3, 1.0)
WHITE = mat("WhitePaint", (0.92, 0.92, 0.9), 0.6)
SHADE = mat("LampShade", (0.95, 0.55, 0.15), 0.8)
LACE = mat("Lace", (0.96, 0.95, 0.9), 0.9)
MIRROR = mat("Mirror", (0.72, 0.8, 0.86), 0.12, 0.15)  # не чистый металл: без отражений был бы чёрным

made = []

# ---------------- Диван ----------------
P = [box((2.2, 0.88, 0.3), (0, 0, 0.3), FABRIC, bevel=0.05)]
P.append(box((2.2, 0.3, 0.75), (0, 0.32, 0.72), FABRIC, bevel=0.06))                   # спинка
for x in (-1.13, 1.13):
    P.append(box((0.2, 0.9, 0.55), (x, 0, 0.5), FABRIC2, bevel=0.06))                  # подлокотники
for x in (-0.55, 0.55):
    P.append(box((1.05, 0.62, 0.14), (x, -0.08, 0.52), FABRIC2, bevel=0.05))           # подушки
for x in (-1.1, 1.1):
    for y in (-0.38, 0.38):
        P.append(cyl(0.035, 0.15, (x, y, 0.075), WOOD, verts=6))
made.append(export("sofa", P))

# ---------------- Сервант (полки на высоте 0.95, 1.35, 1.75) ----------------
# Тумба: левая половина — сплошная, правая — пустое отделение с полкой посередине (дверца
# справа — отдельная модель sideboard_door: открывается в игре, внутри лежит молоток).
INSIDE = mat("SideboardInside", (0.3, 0.15, 0.06), 0.8)
P = [box((1.0, 0.5, 0.9), (-0.5, 0, 0.5), WOOD, bevel=0.02)]                           # левая часть
P.append(box((1.0, 0.5, 0.04), (0.5, 0, 0.07), WOOD))                                   # дно
P.append(box((1.0, 0.5, 0.04), (0.5, 0, 0.93), WOOD))                                   # верх
P.append(box((1.0, 0.03, 0.88), (0.5, 0.235, 0.5), INSIDE))                             # задняя стенка
P.append(box((0.03, 0.5, 0.9), (0.985, 0, 0.5), WOOD))                                  # правый бок
P.append(box((0.94, 0.44, 0.025), (0.5, 0.01, 0.5), INSIDE))                            # полка внутри
P.append(box((0.95, 0.02, 0.8), (-0.5, -0.255, 0.5), WOOD_L, bevel=0.01))               # левая дверца
P.append(cyl(0.02, 0.03, (-0.1, -0.28, 0.55), METAL, verts=6, rot=(math.radians(90), 0, 0)))
# Полки и задняя стенка — между боковинами (раньше были во всю ширину и торчали сквозь боковины).
P.append(box((1.94, 0.42, 0.04), (0, 0.04, 0.95), WOOD))                                # полки
# Полки деревянные (были прозрачным стеклом — смотрелось пусто).
P.append(box((1.94, 0.42, 0.03), (0, 0.04, 1.35), WOOD))
P.append(box((1.94, 0.42, 0.03), (0, 0.04, 1.75), WOOD))
P.append(box((2.0, 0.5, 0.06), (0, 0, 2.17), WOOD, bevel=0.01))                         # крышка
P.append(box((1.94, 0.03, 1.2), (0, 0.235, 1.55), WOOD_L))                              # задняя стенка
for x in (-0.985, 0.985):
    P.append(box((0.03, 0.5, 1.2), (x, 0, 1.55), WOOD))                                 # боковины
for x in (-0.9, 0.9):
    P.append(cyl(0.04, 0.1, (x, 0, 0.05), WOOD, verts=6))
made.append(export("sideboard", P))
# Правая дверца тумбы отдельно: точка поворота — на петле (правый край), открывается наружу.
P = [box((0.95, 0.02, 0.8), (0.5, -0.255, 0.5), WOOD_L, bevel=0.01),
     cyl(0.02, 0.03, (0.1, -0.28, 0.55), METAL, verts=6, rot=(math.radians(90), 0, 0))]
for o in P:
    o.location -= Vector((0.975, -0.255, 0.5))
    bpy.context.view_layer.update()
made.append(export("sideboard_door", P))

# ---------------- Хрусталь и рюмки ----------------
P = [cyl(0.07, 0.04, (0, 0, 0.02), GLASS, verts=8)]
P.append(cyl(0.05, 0.22, (0, 0, 0.15), GLASS, verts=8, r2=0.09))
P.append(cyl(0.09, 0.04, (0, 0, 0.28), GLASS, verts=8, r2=0.11))
made.append(export("crystal_vase", P))
P = [cyl(0.04, 0.01, (0, 0, 0.005), GLASS, verts=8), cyl(0.008, 0.08, (0, 0, 0.05), GLASS, verts=6),
     cyl(0.012, 0.07, (0, 0, 0.12), GLASS, verts=8, r2=0.04)]
made.append(export("wine_glass", P))

# ---------------- Банки ----------------
def jar(name, fill, extra):
    P = [cyl(0.1, 0.27, (0, 0, 0.135), JAR_GLASS, verts=12),
         cyl(0.085, 0.03, (0, 0, 0.285), JAR_GLASS, verts=12),
         cyl(0.088, 0.025, (0, 0, 0.31), LID, verts=12),
         cyl(0.092, 0.2, (0, 0, 0.11), fill, verts=12)]
    P += extra
    made.append(export(name, P))


PICKLE = mat("Pickle", (0.25, 0.4, 0.1), 0.6)
jar("jar_pickles", mat("Brine", (0.55, 0.65, 0.35), 0.3, 0, 0.7),
    [sphere(0.03, (random.uniform(-0.05, 0.05), random.uniform(-0.05, 0.05), z), PICKLE, scale=(1, 1, 2.3))
     for z in (0.07, 0.12, 0.17, 0.09, 0.15)])
jar("jar_jam", mat("Jam", (0.5, 0.04, 0.06), 0.3), [])

# ---------------- Растения ----------------
def pot():
    return [cyl(0.11, 0.16, (0, 0, 0.08), CLAY, verts=10, r2=0.13), cyl(0.135, 0.03, (0, 0, 0.17), CLAY, verts=10)]


P = pot() + [cyl(0.06, 0.32, (0, 0, 0.34), GREEN, verts=8, r2=0.05),
             sphere(0.055, (0, 0, 0.5), GREEN, segs=8, rings=5),
             cyl(0.035, 0.14, (0.08, 0, 0.36), GREEN, verts=6), cyl(0.03, 0.12, (-0.07, 0, 0.3), GREEN, verts=6)]
made.append(export("cactus_pot", P))
P = pot()
for i in range(7):
    a = i * 2 * math.pi / 7
    P.append(cyl(0.03, 0.32, (math.cos(a) * 0.05, math.sin(a) * 0.05, 0.32), GREEN, verts=4, r2=0.0,
                 rot=(math.sin(a) * 0.5, -math.cos(a) * 0.5, 0)))
made.append(export("aloe_pot", P))

# ---------------- Книги ----------------
BOOKS = [mat("Book%d" % i, c, 0.8) for i, c in enumerate(
    [(0.6, 0.1, 0.08), (0.1, 0.25, 0.5), (0.15, 0.4, 0.15), (0.8, 0.6, 0.1), (0.4, 0.15, 0.4)])]
P, z = [], 0.0
for i in range(5):
    h = random.uniform(0.035, 0.06)
    P.append(box((random.uniform(0.24, 0.3), random.uniform(0.17, 0.21), h), (random.uniform(-0.02, 0.02), 0, z + h / 2),
                 BOOKS[i], rot=(0, 0, random.uniform(-0.2, 0.2))))
    z += h
made.append(export("book_stack", P))

# ---------------- Стол, стул ----------------
P = [box((1.4, 0.85, 0.05), (0, 0, 0.75), WOOD, bevel=0.015)]
for x in (-0.62, 0.62):
    for y in (-0.36, 0.36):
        P.append(box((0.06, 0.06, 0.73), (x, y, 0.365), WOOD))
P.append(box((1.0, 0.6, 0.006), (0, 0, 0.778), LACE))                                  # салфетка
made.append(export("table", P))
P = [box((0.45, 0.45, 0.05), (0, 0, 0.47), WOOD_L, bevel=0.01)]
for x in (-0.19, 0.19):
    for y in (-0.19, 0.19):
        P.append(box((0.04, 0.04, 0.45), (x, y, 0.225), WOOD_L))
for x in (-0.19, 0.19):
    P.append(box((0.04, 0.04, 0.5), (x, 0.19, 0.74), WOOD_L))
P.append(box((0.42, 0.03, 0.18), (0, 0.19, 0.88), WOOD_L, bevel=0.01))
made.append(export("chair", P))

# ---------------- Торшер, настольная лампа ----------------
P = [cyl(0.2, 0.04, (0, 0, 0.02), METAL, verts=12), cyl(0.02, 1.45, (0, 0, 0.75), METAL, verts=6),
     cyl(0.3, 0.35, (0, 0, 1.55), SHADE, verts=12, r2=0.17)]
made.append(export("floor_lamp", P))
P = [cyl(0.09, 0.03, (0, 0, 0.015), METAL, verts=10), cyl(0.015, 0.3, (0, 0, 0.16), METAL, verts=6),
     cyl(0.16, 0.18, (0, 0, 0.34), mat("LampShadeGreen", (0.15, 0.45, 0.25), 0.7), verts=12, r2=0.09)]
made.append(export("table_lamp", P))

# ---------------- Ковёр на стену (лежит в плоскости XZ, лицом к −Y) ----------------
RED = mat("CarpetRed", (0.45, 0.04, 0.05), 0.95)
GOLDC = mat("CarpetGold", (0.8, 0.55, 0.15), 0.95)
BLUEC = mat("CarpetBlue", (0.08, 0.12, 0.35), 0.95)
CREAM = mat("CarpetCream", (0.85, 0.78, 0.6), 0.95)
W, H, Z0 = 2.6, 1.7, 0.85
P = [box((W, 0.03, H), (0, 0, Z0), RED)]
P.append(box((W - 0.12, 0.034, H - 0.12), (0, 0, Z0), GOLDC))
P.append(box((W - 0.24, 0.038, H - 0.24), (0, 0, Z0), RED))
for s, c in ((0.62, BLUEC), (0.48, GOLDC), (0.32, RED), (0.16, CREAM)):                # ромб-медальон
    P.append(box((s, 0.04 + (0.7 - s) * 0.01, s), (0, 0, Z0), c, rot=(0, math.radians(45), 0)))
for x in (-0.95, 0.95):                                                                 # угловые ромбы
    for z in (Z0 - 0.5, Z0 + 0.5):
        P.append(box((0.18, 0.042, 0.18), (x, 0, z), BLUEC, rot=(0, math.radians(45), 0)))
for i in range(9):                                                                      # бахрома
    for x in (-1.2 + i * 0.3,):
        P.append(box((0.03, 0.02, 0.08), (x, 0, Z0 - H / 2 - 0.04), CREAM))
        P.append(box((0.03, 0.02, 0.08), (x, 0, Z0 + H / 2 + 0.04), CREAM))
made.append(export("wall_carpet", P))

# ---------------- Шкаф (две одинаковые дверцы, без зеркала) ----------------
P = [box((1.5, 0.6, 2.15), (0, 0, 1.12), WOOD, bevel=0.015)]
P.append(box((1.56, 0.64, 0.06), (0, 0, 2.22), WOOD, bevel=0.01))
P.append(box((0.68, 0.02, 1.85), (-0.36, -0.305, 1.12), WOOD_L))
P.append(box((0.68, 0.02, 1.85), (0.36, -0.305, 1.12), WOOD_L))                         # обе дверцы одинаковые
for x in (-0.06, 0.06):
    P.append(cyl(0.015, 0.12, (x, -0.33, 1.12), METAL, verts=6))
for x in (-0.65, 0.65):
    P.append(cyl(0.04, 0.06, (x, 0, 0.03), WOOD, verts=6))
made.append(export("wardrobe", P))

# ---------------- Кровать, тумбочка ----------------
QUILT = mat("Quilt", (0.2, 0.32, 0.55), 0.9)
QUILT2 = mat("Quilt2", (0.75, 0.6, 0.25), 0.9)
P = [box((1.1, 2.05, 0.3), (0, 0, 0.25), WOOD_L, bevel=0.02)]
P.append(box((1.0, 1.95, 0.18), (0, 0, 0.48), LACE, bevel=0.04))                         # матрас
P.append(box((1.04, 1.4, 0.06), (0, -0.28, 0.6), QUILT, bevel=0.02))                     # одеяло
for y in (-0.7, -0.3, 0.1):
    P.append(box((1.05, 0.05, 0.062), (0, y, 0.6), QUILT2))
P.append(box((0.6, 0.35, 0.14), (0, 0.72, 0.64), LACE, bevel=0.05))                      # подушка
P.append(box((1.1, 0.06, 0.9), (0, 1.0, 0.55), WOOD, bevel=0.02))                        # изголовье
made.append(export("bed", P))
P = [box((0.45, 0.4, 0.55), (0, 0, 0.3), WOOD, bevel=0.01), box((0.4, 0.02, 0.18), (0, -0.205, 0.42), WOOD_L),
     cyl(0.015, 0.02, (0, -0.22, 0.42), METAL, verts=6, rot=(math.radians(90), 0, 0))]
made.append(export("nightstand", P))

# ---------------- Окно с подоконником (в плоскости стены, лицом к −Y) ----------------
FRAME = WHITE
SKY = mat("WindowSky", (0.55, 0.75, 0.95), 0.1, 0, 0.6)
P = [box((1.4, 0.02, 1.5), (0, 0.07, 1.65), SKY)]
P.append(box((1.5, 0.1, 0.07), (0, 0, 0.88), FRAME))
P.append(box((1.5, 0.1, 0.07), (0, 0, 2.42), FRAME))
for x in (-0.72, 0.0, 0.72):
    P.append(box((0.07, 0.1, 1.6), (x, 0, 1.65), FRAME))
P.append(box((1.45, 0.08, 0.06), (0, 0, 2.0), FRAME))
P.append(box((1.7, 0.32, 0.05), (0, -0.14, 0.86), FRAME))                                # подоконник
P.append(box((1.0, 0.1, 0.5), (0, -0.05, 0.45), mat("Radiator", (0.85, 0.85, 0.82), 0.5)))  # батарея
for i in range(8):
    P.append(box((0.08, 0.12, 0.5), (-0.42 + i * 0.12, -0.06, 0.45), mat("Radiator", (0.85, 0.85, 0.82), 0.5)))
made.append(export("window", P))


# ---------------- Кресло ----------------
P = [box((0.85, 0.85, 0.3), (0, 0, 0.3), FABRIC, bevel=0.05)]
P.append(box((0.85, 0.25, 0.65), (0, 0.32, 0.7), FABRIC, bevel=0.06))
for x in (-0.38, 0.38):
    P.append(box((0.14, 0.85, 0.52), (x, 0, 0.48), FABRIC2, bevel=0.05))
P.append(box((0.58, 0.6, 0.12), (0, -0.06, 0.5), FABRIC2, bevel=0.04))
for x in (-0.36, 0.36):
    for y in (-0.36, 0.36):
        P.append(cyl(0.03, 0.15, (x, y, 0.075), WOOD, verts=6))
made.append(export("armchair", P))

# ---------------- Журнальный столик ----------------
P = [box((1.0, 0.55, 0.04), (0, 0, 0.45), WOOD, bevel=0.012)]
P.append(box((0.9, 0.45, 0.02), (0, 0, 0.18), WOOD_L))
for x in (-0.44, 0.44):
    for y in (-0.22, 0.22):
        P.append(cyl(0.022, 0.45, (x, y, 0.22), WOOD, verts=6, r2=0.015))
P.append(box((0.5, 0.3, 0.005), (0, 0, 0.472), LACE))
made.append(export("coffee_table", P))

# ---------------- Книжная секция стенки (полки с книгами, место под радио) ----------------
P = [box((1.3, 0.45, 0.85), (0, 0, 0.475), WOOD, bevel=0.015)]
for x in (-0.32, 0.32):
    P.append(box((0.62, 0.02, 0.75), (x, -0.23, 0.48), WOOD_L, bevel=0.008))
for z in (0.92, 1.4, 1.88):
    P.append(box((1.3, 0.42, 0.03), (0, 0.02, z), WOOD))
P.append(box((1.3, 0.45, 0.06), (0, 0, 2.27), WOOD, bevel=0.01))
P.append(box((1.3, 0.03, 1.4), (0, 0.21, 1.6), WOOD_L))
for x in (-0.635, 0.635):
    P.append(box((0.03, 0.45, 1.4), (x, 0, 1.6), WOOD))
made.append(export("bookshelf", P))
# Ряды книг — отдельно от шкафа, чтобы их можно было разбить (в игре: на полки 1.415 и 1.895).
for row_name in ("book_row_a", "book_row_b"):
    P = []
    x = -0.6
    while x < 0.58:
        w = random.uniform(0.035, 0.07)
        h = random.uniform(0.24, 0.34)
        P.append(box((w, 0.2, h), (x + w / 2, 0.05, h / 2), random.choice(BOOKS)))
        x += w + 0.004
    made.append(export(row_name, P))

# ---------------- Радиоприёмник ----------------
CASE = mat("RadioCase", (0.18, 0.1, 0.06), 0.4)
GRILLE = mat("RadioGrille", (0.75, 0.72, 0.65), 0.6, 0.5)
DIAL = mat("RadioDial", (0.95, 0.85, 0.55), 0.3)
P = [box((0.42, 0.14, 0.24), (0, 0, 0.12), CASE, bevel=0.02)]
P.append(box((0.22, 0.01, 0.17), (-0.08, -0.07, 0.12), GRILLE))
P.append(box((0.12, 0.012, 0.06), (0.12, -0.07, 0.16), DIAL))
for z in (0.07, 0.1):
    P.append(cyl(0.018, 0.02, (0.12 + (z - 0.07) * 1.5, -0.075, z), METAL, verts=8, rot=(math.radians(90), 0, 0)))
# Ручка — дужка на двух стойках, стоит на корпусе (раньше висела в воздухе).
for x in (-0.14, 0.14):
    P.append(box((0.02, 0.03, 0.05), (x, 0, 0.26), METAL))
P.append(box((0.3, 0.03, 0.02), (0, 0, 0.29), METAL))
# Антенна: основание на крыше корпуса, телескоп наклонён влево (центр = основание + 0.25 по оси).
P.append(sphere(0.014, (0.15, 0.03, 0.245), METAL))
# Короткая (0.16 м): верх на ~1.33 м от пола — ниже полки над радио (была 0.3 м и уходила в неё).
P.append(cyl(0.006, 0.16, (0.15 - 0.08 * math.sin(math.radians(25)), 0.03,
                          0.245 + 0.08 * math.cos(math.radians(25))), METAL, verts=4,
             rot=(0, math.radians(-25), 0)))
made.append(export("radio", P))

# ---------------- Гантели ----------------
IRON = mat("Iron", (0.12, 0.12, 0.13), 0.5, 0.7)
P = [cyl(0.018, 0.34, (0, 0, 0.06), METAL, verts=8, rot=(0, math.radians(90), 0))]
for x in (-0.13, -0.09, 0.09, 0.13):
    P.append(cyl(0.06, 0.035, (x, 0, 0.06), IRON, verts=6, rot=(0, math.radians(90), 0)))
made.append(export("dumbbell", P))

# ---------------- Табурет ----------------
P = [box((0.36, 0.36, 0.04), (0, 0, 0.45), WOOD_L, bevel=0.01)]
for x in (-0.14, 0.14):
    for y in (-0.14, 0.14):
        P.append(box((0.04, 0.04, 0.43), (x, y, 0.215), WOOD_L))
P.append(box((0.3, 0.03, 0.03), (0, -0.14, 0.12), WOOD_L))
P.append(box((0.3, 0.03, 0.03), (0, 0.14, 0.12), WOOD_L))
made.append(export("stool", P))

# ---------------- Люстра (крепится к потолку на высоте 3 м: верх в z = 3) ----------------
SHADE_GLASS = mat("ChandelierGlass", (0.98, 0.92, 0.75), 0.3, 0.0, 0.85)
P = [cyl(0.012, 0.5, (0, 0, 2.75), METAL, verts=6), cyl(0.07, 0.04, (0, 0, 2.98), METAL, verts=8),
     sphere(0.06, (0, 0, 2.5), METAL, segs=8, rings=5)]
for i in range(5):
    a = i * 2 * math.pi / 5
    x, y = math.cos(a) * 0.32, math.sin(a) * 0.32
    P.append(box((0.32, 0.02, 0.02), (x / 2, y / 2, 2.5), METAL, rot=(0, 0, a)))
    P.append(cyl(0.09, 0.14, (x, y, 2.54), SHADE_GLASS, verts=8, r2=0.05))
made.append(export("chandelier", P))

# ---------------- Шторы (к окну шириной 1.5 м) ----------------
# Тюль убран: в игре он светился белым и закрывал вид из окна.
DRAPE = mat("Drape", (0.45, 0.12, 0.08), 0.9)
P = [box((2.3, 0.04, 0.04), (0, 0, 2.62), METAL)]                                        # карниз
for x in (-0.95, 0.95):
    for k in range(4):                                                                     # складки штор
        P.append(cyl(0.05, 1.95, (x + (k - 1.5) * 0.09, -0.06, 1.62), DRAPE, verts=6))
made.append(export("curtains", P))

# ---------------- Ковёр на пол (лежит, узором вверх) ----------------
W, D = 3.0, 2.1
P = [box((W, D, 0.02), (0, 0, 0.01), RED)]
P.append(box((W - 0.14, D - 0.14, 0.024), (0, 0, 0.012), GOLDC))
P.append(box((W - 0.28, D - 0.28, 0.028), (0, 0, 0.014), RED))
for sz, c in ((0.8, BLUEC), (0.6, GOLDC), (0.4, RED), (0.2, CREAM)):
    P.append(box((sz, sz, 0.03 + (0.8 - sz) * 0.005), (0, 0, 0.016), c, rot=(0, 0, math.radians(45))))
for x in (-1.1, 1.1):
    for y in (-0.65, 0.65):
        P.append(box((0.2, 0.2, 0.034), (x, y, 0.017), BLUEC, rot=(0, 0, math.radians(45))))
made.append(export("floor_rug", P))

if not RENDER:
    print("DONE")
    sys.exit(0)

# ---------------- Превью ----------------
scene = bpy.context.scene
layout = {
    "wall_carpet": (0, 1.2, 0.6), "sofa": (0, 0.6, 0), "sideboard": (-3.1, 0.7, 0), "floor_lamp": (1.6, 0.6, 0),
    "table": (0, -1.3, 0), "chair": (-1.0, -1.3, 0), "crystal_vase": (-3.5, 0.6, 0.97), "wine_glass": (-2.9, 0.6, 0.97),
    "jar_pickles": (-2.6, -0.9, 0), "jar_jam": (-2.25, -0.9, 0), "cactus_pot": (2.8, -0.4, 0),
    "aloe_pot": (3.2, -0.4, 0), "book_stack": (2.6, -1.3, 0), "wardrobe": (4.6, 0.8, 0), "bed": (6.7, 0.3, 0),
    "nightstand": (5.8, 1.0, 0), "table_lamp": (5.8, 1.0, 0.55), "window": (2.8, 1.25, 0),
    "armchair": (-1.6, -2.6, 0), "coffee_table": (0.2, -2.6, 0), "bookshelf": (8.6, 1.1, 0),
    "radio": (8.6, 1.1, 0.95), "dumbbell": (3.6, -1.2, 0), "stool": (4.2, -1.2, 0),
    "chandelier": (0, -1.0, -0.5), "curtains": (2.8, 1.2, 0), "floor_rug": (0.5, -3.6, 0),
}
for o in made:
    if o.name in layout:
        o.location = layout[o.name]
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
bpy.context.object.data.materials.append(mat("Parquet", (0.42, 0.25, 0.12), 0.6))
bpy.ops.mesh.primitive_cube_add(location=(1.5, 1.45, 1.5))
bpy.context.object.scale = (8, 0.05, 1.5)
bpy.context.object.data.materials.append(mat("Wallpaper", (0.78, 0.7, 0.52), 0.9))
sun = bpy.data.lights.new("Sun", "SUN")
sun.energy = 3
so = bpy.data.objects.new("Sun", sun)
so.rotation_euler = (0.8, 0.2, 0.5)
scene.collection.objects.link(so)
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 28
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (1.6, -8.5, 4.2)
cam.rotation_euler = (Vector((1.6, 0, 0.8)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.engine = "CYCLES"
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1800, 900
scene.view_settings.view_transform = "AgX"
scene.render.filepath = os.path.join(OUT, "_preview_apartment.png")
bpy.ops.render.render(write_still=True)
print("DONE")
