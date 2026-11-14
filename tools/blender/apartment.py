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


ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def mat(name, color, rough=0.6, metal=0.0, alpha=1.0, image=None):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if image:
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(os.path.join(ROOT, image))
        m.node_tree.links.new(tex.outputs["Color"], b.inputs["Base Color"])
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
# Крышки — не «металл» (в игре металл без отражений выглядел чёрным): лакированная жесть.
LID = mat("Lid", (0.85, 0.66, 0.25), 0.35, 0.2)
LID_RED = mat("LidRed", (0.7, 0.1, 0.08), 0.4, 0.15)
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
# Подлокотники до низа дивана (0.15): ножки стоят под ними, а раньше низ подлокотника был на
# 0.225 — между ножкой и диваном была щель 7.5 см, ножки «отставали» от дивана.
for x in (-1.13, 1.13):
    P.append(box((0.2, 0.9, 0.625), (x, 0, 0.4625), FABRIC2, bevel=0.06))              # подлокотники
for x in (-0.55, 0.55):
    P.append(box((1.05, 0.62, 0.14), (x, -0.08, 0.52), FABRIC2, bevel=0.05))           # подушки
# Ножки — под подлокотниками, чуть внутрь от скруглённых краёв и выше низа дивана на 3 см:
# верх ножки входит в корпус (раньше упирался в скос фаски — была щель).
for x in (-1.08, 1.08):
    for y in (-0.34, 0.34):
        P.append(cyl(0.035, 0.18, (x, y, 0.09), WOOD, verts=6))
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
# Дверцы тумбы сходятся посередине с зазором 6 мм (раньше между ними была щель 5 см).
P.append(box((0.982, 0.02, 0.8), (-0.494, -0.255, 0.5), WOOD_L, bevel=0.01))            # левая дверца
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
for x in (-0.9, 0.9):                                                                  # ножки (ниже дна —
    P.append(cyl(0.04, 0.05, (x, 0, 0.025), WOOD, verts=6))                           # не торчат внутрь)
made.append(export("sideboard", P))
# Правая дверца тумбы отдельно: точка поворота — на петле (правый край), открывается наружу.
P = [box((0.982, 0.02, 0.8), (0.494, -0.255, 0.5), WOOD_L, bevel=0.01),
     cyl(0.02, 0.03, (0.1, -0.28, 0.55), METAL, verts=6, rot=(math.radians(90), 0, 0))]
for o in P:
    o.location -= Vector((0.975, -0.255, 0.5))
    bpy.context.view_layer.update()
made.append(export("sideboard_door", P))

# ---------------- Хрусталь и рюмки ----------------
P = [cyl(0.07, 0.04, (0, 0, 0.02), GLASS, verts=8)]
P.append(cyl(0.05, 0.22, (0, 0, 0.15), GLASS, verts=8, r2=0.09))
P.append(cyl(0.09, 0.04, (0, 0, 0.28), GLASS, verts=8, r2=0.11))
# Внутри налита вода до 2/3 (голубоватая, чтобы было видно, что это ваза с водой).
# Вода непрозрачная (светло-голубая): две прозрачные поверхности (стекло и вода) Godot
# сортирует по ракурсу — ваза меняла цвет, когда обходишь её.
WATER = mat("VaseWater", (0.62, 0.78, 0.84), 0.05)
P.append(cyl(0.045, 0.15, (0, 0, 0.115), WATER, verts=8, r2=0.075))
made.append(export("crystal_vase", P))

# Ваза с водой и букетом (на журнальном столике): та же хрустальная ваза, вода непрозрачная,
# из неё — стебли, 3 красные гвоздики, 3 белые ромашки, листья на стеблях.
STEM = mat("FlowerStem", (0.16, 0.42, 0.12), 0.7)
CARNATION = mat("Carnation", (0.78, 0.06, 0.1), 0.7)
DAISY = mat("Daisy", (0.95, 0.95, 0.92), 0.7)
DAISY_MID = mat("DaisyMid", (0.95, 0.72, 0.1), 0.6)
P = [cyl(0.07, 0.04, (0, 0, 0.02), GLASS, verts=8)]
P.append(cyl(0.05, 0.22, (0, 0, 0.15), GLASS, verts=8, r2=0.09))
P.append(cyl(0.09, 0.04, (0, 0, 0.28), GLASS, verts=8, r2=0.11))
P.append(cyl(0.045, 0.15, (0, 0, 0.115), WATER, verts=8, r2=0.075))
# 6 цветов: чётные — красные гвоздики, нечётные — белые ромашки. Листья растут из стеблей.
heads = [(0.0, 0.0, 0.56), (1.05, 0.1, 0.5), (2.1, 0.11, 0.52), (3.15, 0.1, 0.49), (4.2, 0.11, 0.51),
         (5.25, 0.1, 0.48)]
for i, (a, r, h) in enumerate(heads):
    top = Vector((math.cos(a) * r, math.sin(a) * r, h))
    base = Vector((math.cos(a) * 0.015, math.sin(a) * 0.015, 0.1))
    d = top - base
    P.append(cyl(0.005, d.length, tuple((top + base) / 2), STEM, verts=5,
                 rot=tuple(d.to_track_quat("Z", "Y").to_euler())))
    if i % 2 == 0:                                                                        # гвоздика
        P.append(cyl(0.012, 0.03, tuple(top + Vector((0, 0, -0.01))), STEM, verts=6, r2=0.02))
        for k in range(3):
            P.append(cyl(0.034 - k * 0.008, 0.016, tuple(top + Vector((0, 0, 0.012 + k * 0.012))),
                         CARNATION, verts=7, r2=0.026 - k * 0.006, rot=(0, 0, k * 0.5)))
    else:                                                                                 # ромашка
        for k in range(10):
            pa = k * math.tau / 10
            P.append(box((0.036, 0.012, 0.004),
                         tuple(top + Vector((math.cos(pa) * 0.024, math.sin(pa) * 0.024, 0))), DAISY,
                         rot=(0, math.radians(-12), pa)))
        P.append(sphere(0.014, tuple(top + Vector((0, 0, 0.003))), DAISY_MID, scale=(1, 1, 0.6), segs=8, rings=4))
    if i == 0:
        continue
    # Лист: основание на стебле над горлышком вазы, кончик — наружу и чуть вверх.
    p0 = base + d * ((0.36 - base.z) / d.z)
    out = Vector((math.cos(a + 0.5), math.sin(a + 0.5), 0.45)).normalized()
    side = out.cross(Vector((0, 0, 1))).normalized() * 0.019
    tip = p0 + out * 0.1
    mid = p0 + out * 0.045
    me = bpy.data.meshes.new("Leaf")
    me.from_pydata([tuple(p0), tuple(mid + side), tuple(tip), tuple(mid - side)], [], [(0, 1, 2, 3)])
    lf = bpy.data.objects.new("Leaf", me)
    bpy.context.scene.collection.objects.link(lf)
    P.append(flat(lf, STEM))
made.append(export("vase_bouquet", P))
P = [cyl(0.04, 0.01, (0, 0, 0.005), GLASS, verts=8), cyl(0.008, 0.08, (0, 0, 0.05), GLASS, verts=6),
     cyl(0.012, 0.07, (0, 0, 0.12), GLASS, verts=8, r2=0.04)]
made.append(export("wine_glass", P))

# ---------------- Банки ----------------
def lathe(profile, m, n=32):
    """Тело вращения по профилю [(r, z)] снизу вверх (r = 0 — закрыто), сглаженное по углу:
    круглые бока гладкие, донышко и верх — с чёткой гранью."""
    verts, faces = [], []
    for r, z in profile:
        for k in range(n):
            a = k / n * math.tau
            verts.append((math.cos(a) * r, math.sin(a) * r, z))
    for i in range(len(profile) - 1):
        for k in range(n):
            a, b = i * n + k, i * n + (k + 1) % n
            faces.append((a, b, b + n, a + n))
    faces.append(tuple(range(n))[::-1])
    top = (len(profile) - 1) * n
    faces.append(tuple(range(top, top + n)))
    me = bpy.data.meshes.new("Lathe")
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("Lathe", me)
    bpy.context.scene.collection.objects.link(o)
    flat(o, m)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    return o


def label_band(r, z0, z1, m, n=24, span=math.radians(150)):
    """Этикетка спереди банки (дуга span вокруг −Y Blender = к смотрящему): одна картинка."""
    verts, faces = [], []
    for k in range(n + 1):
        a = -math.pi / 2 + span / 2 - k / n * span                   # слева направо, если смотреть спереди
        verts += [(math.cos(a) * r, math.sin(a) * r, z0), (math.cos(a) * r, math.sin(a) * r, z1)]
    for k in range(n):
        i = 2 * k
        faces.append((i, i + 1, i + 3, i + 2))
    me = bpy.data.meshes.new("Label")
    me.from_pydata(verts, [], faces)
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            uv.data[li].uv = ((vi // 2) / n, vi % 2)
    o = bpy.data.objects.new("Label", me)
    bpy.context.scene.collection.objects.link(o)
    flat(o, m)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def jar(name, fill, extra, lid=LID, label=None):
    """Круглая банка: скруглённое дно, плечики, горлышко, крышка; этикетка спереди (−Y)."""
    P = [lathe([(0, 0.0), (0.085, 0.0), (0.097, 0.008), (0.1, 0.025), (0.1, 0.235), (0.096, 0.258),
                (0.088, 0.272), (0.084, 0.28), (0.084, 0.298)], JAR_GLASS),
         lathe([(0, 0.293), (0.089, 0.293), (0.091, 0.298), (0.091, 0.318), (0.086, 0.324),
                (0, 0.326)], lid),
         lathe([(0, 0.006), (0.084, 0.006), (0.092, 0.02), (0.092, 0.21), (0, 0.21)], fill)]
    if label:
        P.append(label_band(0.102, 0.07, 0.19, mat("Label_" + name, (1, 1, 1), 0.8, image=label), n=16))
    P += extra
    made.append(export(name, P))


PICKLE = mat("Pickle", (0.25, 0.4, 0.1), 0.6)
# Рассол непрозрачный: полупрозрачное внутри стеклянной банки меняло цвет с расстояния
# (Godot путает порядок прозрачных слоёв). Огурцы выступают из рассола — видны сквозь стекло.
jar("jar_pickles", mat("Brine", (0.55, 0.62, 0.32), 0.3),
    [sphere(0.024, (0.074 * math.cos(a), 0.074 * math.sin(a), z), PICKLE, scale=(1, 1, 2.6))
     for a, z in ((0.3, 0.08), (1.4, 0.14), (2.5, 0.09), (3.6, 0.15), (4.6, 0.08), (5.6, 0.13))],
    label="assets/textures/apartment/jar_label_pickles.png")
jar("jar_jam", mat("Jam", (0.5, 0.04, 0.06), 0.3), [], lid=LID_RED,
    label="assets/textures/apartment/jar_label_jam.png")

# ---------------- Растения ----------------
SOIL = mat("PotSoil", (0.06, 0.035, 0.02), 1.0)


def pot():
    """Горшок с ободком и тёмной землёй сверху (раньше сверху была глиняная «крышка»)."""
    return [cyl(0.11, 0.16, (0, 0, 0.08), CLAY, verts=10, r2=0.13), cyl(0.135, 0.03, (0, 0, 0.17), CLAY, verts=10),
            cyl(0.118, 0.006, (0, 0, 0.187), SOIL, verts=10)]


# Кактус-«шар» (эхинокактус): приплюснутый ребристый шар, рядом малыш-детка, сверху розовый
# цветок. Раньше был высокий столбик с отростками — выглядел двусмысленно.
P = pot()
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1.0, location=(0, 0, 0))
barrel = bpy.context.object
for v in barrel.data.vertices:
    a = math.atan2(v.co.y, v.co.x)
    rib = 1.0 + 0.09 * math.cos(a * 12)                                  # 12 рёбер
    v.co.x *= 0.1 * rib
    v.co.y *= 0.1 * rib
    v.co.z = v.co.z * 0.085 + 0.27
P.append(flat(barrel, GREEN))
P.append(sphere(0.04, (0.085, 0.05, 0.215), GREEN, segs=12, rings=6))       # детка
FLOWER = mat("CactusFlower", (0.95, 0.3, 0.55), 0.5)
for k in range(6):
    a = 2 * math.pi * k / 6
    P.append(sphere(0.018, (math.cos(a) * 0.02, math.sin(a) * 0.02, 0.36), FLOWER, scale=(1.2, 1.2, 0.5),
                    segs=8, rings=5))
P.append(sphere(0.012, (0, 0, 0.365), mat("CactusFlowerMid", (0.98, 0.85, 0.3), 0.5), segs=8, rings=5))
made.append(export("cactus_pot", P))
P = pot()
for i in range(7):
    a = i * 2 * math.pi / 7
    P.append(cyl(0.03, 0.32, (math.cos(a) * 0.05, math.sin(a) * 0.05, 0.32), GREEN, verts=4, r2=0.0,
                 rot=(math.sin(a) * 0.5, -math.cos(a) * 0.5, 0)))
made.append(export("aloe_pot", P))

# ---------------- Книги ----------------
# 20 цветов корешков — книги в квартире не повторяются одними и теми же пятью цветами.
BOOKS = [mat("Book%d" % i, c, 0.8) for i, c in enumerate(
    [(0.6, 0.1, 0.08), (0.1, 0.25, 0.5), (0.15, 0.4, 0.15), (0.8, 0.6, 0.1), (0.4, 0.15, 0.4),
     (0.9, 0.85, 0.75), (0.15, 0.15, 0.18), (0.75, 0.35, 0.1), (0.3, 0.55, 0.6), (0.55, 0.05, 0.2),
     (0.05, 0.35, 0.35), (0.85, 0.75, 0.45), (0.35, 0.2, 0.08), (0.2, 0.45, 0.75), (0.75, 0.45, 0.55),
     (0.45, 0.5, 0.15), (0.6, 0.6, 0.62), (0.9, 0.3, 0.2), (0.1, 0.1, 0.35), (0.95, 0.9, 0.35)])]
P, z = [], 0.0
for i in range(5):
    h = random.uniform(0.035, 0.06)
    P.append(box((random.uniform(0.24, 0.3), random.uniform(0.17, 0.21), h), (random.uniform(-0.02, 0.02), 0, z + h / 2),
                 BOOKS[(i * 7 + 3) % len(BOOKS)], rot=(0, 0, random.uniform(-0.2, 0.2))))
    z += h
made.append(export("book_stack", P))

# ---------------- Стол, стул ----------------
P = [box((1.4, 0.85, 0.05), (0, 0, 0.75), WOOD, bevel=0.015)]
for x in (-0.62, 0.62):
    for y in (-0.36, 0.36):
        P.append(box((0.06, 0.06, 0.73), (x, y, 0.365), WOOD))
# Скатерть-салфетка: тёмно-зелёная, по краю кремовая строчка, в углах вышитые красные ромбики.
CLOTH = mat("TableClothGreen", (0.06, 0.2, 0.12), 0.95)
CLOTH_TRIM = mat("TableClothCream", (0.9, 0.82, 0.62), 0.95)
CLOTH_RED = mat("TableClothRed", (0.62, 0.06, 0.06), 0.95)
P.append(box((1.0, 0.6, 0.004), (0, 0, 0.777), CLOTH))
for y in (-0.27, 0.27):
    P.append(box((0.92, 0.01, 0.0045), (0, y, 0.77725), CLOTH_TRIM))
for x in (-0.46, 0.46):
    P.append(box((0.01, 0.55, 0.0045), (x, 0, 0.77725), CLOTH_TRIM))
for x in (-0.39, 0.39):
    for y in (-0.2, 0.2):
        P.append(box((0.05, 0.05, 0.0045), (x, y, 0.77725), CLOTH_RED, rot=(0, 0, math.radians(45))))
        P.append(box((0.02, 0.02, 0.005), (x, y, 0.7775), CLOTH_TRIM, rot=(0, 0, math.radians(45))))
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
# Абажур — полый (стенка 8 мм, открыт сверху и снизу): снизу видно патрон и лампочку
# (саму лампочку в игре добавляет код — она горит/гаснет). Раньше был сплошной конус.
SHADE_IN = mat("LampShadeInside", (1.0, 0.85, 0.55), 0.8)
P = [cyl(0.2, 0.04, (0, 0, 0.02), METAL, verts=12), cyl(0.02, 1.45, (0, 0, 0.75), METAL, verts=6)]
bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.3, radius2=0.17, depth=0.35,
                                location=(0, 0, 1.55), end_fill_type="NOTHING")
shade = bpy.context.object
shade.data.materials.append(SHADE)
shade.data.materials.append(SHADE_IN)
solid = shade.modifiers.new("Solidify", "SOLIDIFY")
solid.thickness = 0.008
solid.offset = -1.0
solid.material_offset = 1                                # внутренняя сторона — светлая подкладка
bpy.ops.object.modifier_apply(modifier="Solidify")
for poly in shade.data.polygons:
    poly.use_smooth = False
P.append(shade)
P.append(cyl(0.028, 0.06, (0, 0, 1.5), METAL, verts=8))                                 # патрон
for k in range(3):                                       # проволочки от патрона к абажуру
    a = math.radians(90 + k * 120)
    r_in, r_out = 0.028, 0.222                           # радиус абажура на высоте 1.58
    mid = ((r_in + r_out) / 2 * math.cos(a), (r_in + r_out) / 2 * math.sin(a), 1.58)
    P.append(box((r_out - r_in, 0.006, 0.006), mid, METAL, rot=(0, 0, a)))
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
# Одеяло заправлено: одним куском со скруглёнными углами накрывает матрас и свисает по бокам и
# в ногах до рамы (раньше — отдельные плиты, на углах были щели). Доходит до конца отворота
# простыни у подушки; полоски — такие же скруглённые «обручи» поверх.
QY0, QY1 = -0.995, 0.62                                  # от изножья до конца отворота
QL, QC = QY1 - QY0, (QY0 + QY1) / 2
P.append(box((1.07, QL, 0.235), (0, QC, 0.4925), QUILT, bevel=0.045, segs=5))
for y in (-0.62, -0.2, 0.22):                                                            # полоски
    P.append(box((1.078, 0.05, 0.243), (0, y, 0.4925), QUILT2, bevel=0.045, segs=5))
P.append(box((1.085, 0.2, 0.06), (0, 0.52, 0.6), LACE, bevel=0.03, segs=4))             # отворот
P.append(box((0.6, 0.35, 0.14), (0, 0.76, 0.64), LACE, bevel=0.05))                      # подушка
P.append(box((1.1, 0.06, 0.9), (0, 1.0, 0.55), WOOD, bevel=0.02))                        # изголовье
for x in (-0.49, 0.49):                                  # ножки: рама начинается на 0.1 — без них висела
    for y in (-0.96, 0.96):
        P.append(box((0.07, 0.07, 0.1), (x, y, 0.05), WOOD))
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
for x in (-0.38, 0.38):                                         # подлокотники до низа (0.15)
    P.append(box((0.14, 0.87, 0.59), (x, 0, 0.445), FABRIC2, bevel=0.05))  # глубже сиденья: без щели
P.append(box((0.58, 0.6, 0.12), (0, -0.06, 0.5), FABRIC2, bevel=0.04))
for x in (-0.34, 0.34):                                   # ножки входят в корпус (без щели)
    for y in (-0.32, 0.32):
        P.append(cyl(0.03, 0.18, (x, y, 0.09), WOOD, verts=6))
made.append(export("armchair", P))

# ---------------- Журнальный столик ----------------
P = [box((1.0, 0.55, 0.04), (0, 0, 0.45), WOOD, bevel=0.012)]
P.append(box((0.9, 0.45, 0.02), (0, 0, 0.18), WOOD_L))
for x in (-0.44, 0.44):
    for y in (-0.22, 0.22):
        P.append(cyl(0.022, 0.45, (x, y, 0.22), WOOD, verts=6, r2=0.015))
# Салфетка-дорожка: бордовая, по краю кремовая кайма, в середине ромбики, на концах кисточки.
RUNNER = mat("RunnerWine", (0.42, 0.06, 0.08), 0.95)
RUNNER_TRIM = mat("RunnerCream", (0.93, 0.85, 0.66), 0.95)
P.append(box((0.6, 0.32, 0.004), (0, 0, 0.472), RUNNER))
for y in (-0.14, 0.14):
    P.append(box((0.56, 0.012, 0.0045), (0, y, 0.4725), RUNNER_TRIM))
for x in (-0.28, 0.28):
    P.append(box((0.012, 0.29, 0.0045), (x, 0, 0.4725), RUNNER_TRIM))
    for k in range(7):                                                                    # кисточки
        P.append(box((0.03, 0.008, 0.003), (x + (0.025 if x > 0 else -0.025), -0.12 + k * 0.04, 0.4715),
                     RUNNER_TRIM))
for x in (-0.16, 0.0, 0.16):                                                              # ромбики
    P.append(box((0.05, 0.05, 0.0045), (x, 0, 0.4725), RUNNER_TRIM, rot=(0, 0, math.radians(45))))
    P.append(box((0.024, 0.024, 0.005), (x, 0, 0.47275), RUNNER, rot=(0, 0, math.radians(45))))
made.append(export("coffee_table", P))

# ---------------- Книжная секция стенки (полки с книгами, место под радио) ----------------
P = [box((1.3, 0.45, 0.85), (0, 0, 0.475), WOOD, bevel=0.015)]
P.append(box((1.24, 0.4, 0.05), (0, 0.01, 0.025), WOOD))                                   # цоколь до пола
for x in (-0.32, 0.32):
    P.append(box((0.62, 0.02, 0.75), (x, -0.23, 0.48), WOOD_L, bevel=0.008))
# Полки и задняя стенка — между боковинами (1.24), крышка чуть шире шкафа: раньше всё было
# ровно 1.3, грани совпадали с боковинами и мерцали — светлая задняя стенка «лезла» сквозь бок.
for z in (0.92, 1.4, 1.88):
    P.append(box((1.24, 0.42, 0.03), (0, 0.02, z), WOOD))
P.append(box((1.33, 0.47, 0.06), (0, 0, 2.27), WOOD, bevel=0.01))
P.append(box((1.24, 0.03, 1.4), (0, 0.21, 1.6), WOOD_L))
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
# Шестигранные блины лежат гранью на полу: центр на высоте апофемы 0.06·cos30° ≈ 0.052
# (было 0.06 — гантели висели над полом на 8 мм).
GZ = 0.06 * math.cos(math.radians(30))
P = [cyl(0.018, 0.34, (0, 0, GZ), METAL, verts=8, rot=(0, math.radians(90), 0))]
for x in (-0.13, -0.09, 0.09, 0.13):
    P.append(cyl(0.06, 0.035, (x, 0, GZ), IRON, verts=6, rot=(0, math.radians(90), 0)))
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
# Потолочный карниз (как в хрущёвках): доска под потолком от стены до планки-бленды, за
# блендой — металлическая шина, на ней шторы. Начало координат — у окна (стена в y = +0.08).
# Шторы висят в 37 см перед окном — перед подоконником (он выступает на 30 см), поэтому
# задёрнутые не проходят сквозь подоконник и кактус.
DRAPE = mat("Drape", (0.45, 0.12, 0.08), 0.9)
CURTAIN_BOTTOM = 0.14                       # низ штор чуть выше пола
EDGE = 1.15                                 # внешний край полотна (от середины окна)


def strip(pts, z0, z1, m, thick):
    """Вертикальная лента по точкам плана pts [(x, y)] от высоты z0 до z1 (с толщиной)."""
    verts = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    n = len(pts)
    faces = [(i, i + 1, i + 1 + n, i + n) for i in range(n - 1)]
    me = bpy.data.meshes.new("Strip")
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("Strip", me)
    bpy.context.scene.collection.objects.link(o)
    mod = o.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = thick
    mod.offset = 0
    return flat(o, m)


def arc(side, x0, y0, rx, y1, n, wave=0.0):
    """Плавный загиб к стене: четверть эллипса от (side*x0, y0) наружу и назад к стене (y1).
    wave — складки (ткань), 0 — гладко (дерево)."""
    pts = []
    for i in range(n + 1):
        t = i / n * math.pi / 2
        x = x0 + rx * math.sin(t)
        y = y0 + (y1 - y0) * (1 - math.cos(t))
        if wave and 0 < i < n:
            x += wave if i % 2 else -wave
        pts.append((side * x, y))
    return pts


# Доска под потолком: прямоугольник + скруглённые концы (повторяют загиб бленды к стене).
board = [(-EDGE, 0.08)]
board += arc(-1, EDGE, -0.45, 0.1, 0.08, 8)[::-1]
board += arc(1, EDGE, -0.45, 0.1, 0.08, 8)
board.append((EDGE, 0.08))
outline = [(x, y) for x, y in board]
me = bpy.data.meshes.new("Board")
me.from_pydata([(x, y, 2.973) for x, y in outline] + [(x, y, 2.998) for x, y in outline], [],
               [tuple(range(len(outline))), tuple(range(len(outline) * 2 - 1, len(outline) - 1, -1))] +
               [(i, (i + 1) % len(outline), (i + 1) % len(outline) + len(outline), i + len(outline))
                for i in range(len(outline))])
board_o = bpy.data.objects.new("Board", me)
bpy.context.scene.collection.objects.link(board_o)
P = [flat(board_o, WOOD_L)]
# Бленда: прямая спереди и скругления по бокам до самой стены — сбоку не видно пустоты.
front = [(-EDGE, -0.45), (EDGE, -0.45)]
P.append(strip(front, 2.84, 2.973, WOOD_L, 0.025))
P.append(strip([(-EDGE - 0.005, -0.462), (EDGE + 0.005, -0.462)], 2.845, 2.87, WOOD, 0.012))   # кант
for side in (-1, 1):
    P.append(strip(arc(side, EDGE, -0.45, 0.1, 0.08, 8), 2.84, 2.973, WOOD_L, 0.025))
    P.append(strip(arc(side, EDGE + 0.005, -0.462, 0.1, 0.08, 8), 2.845, 2.87, WOOD, 0.012))
    # Загиб шторы к стене (не двигается): от края полотна назад к стене, со складками.
    P.append(strip(arc(side, EDGE, -0.37, 0.07, 0.07, 8, wave=0.012), CURTAIN_BOTTOM, 2.88, DRAPE, 0.012))
P.append(box((2.3, 0.02, 0.012), (0, -0.37, 2.93), METAL))                                # шина
made.append(export("curtain_cornice", P))


def curtain_panel(sign):
    """Полотно шторы со складками: от внешнего края (x = 0) к середине окна (x = sign * 1.14).
    В игре сжимается по X, когда шторы раздвинуты (складки собираются гармошкой)."""
    n = 20
    verts, faces = [], []
    rows = ((CURTAIN_BOTTOM, 0.036), (1.4, 0.032), (2.88, 0.024))  # (высота, глубина складки)
    for z, amp in rows:
        for i in range(n + 1):
            y = 0.0 if i in (0, n) else (amp if i % 2 else -amp)
            verts.append((sign * 1.14 * i / n, y, z))
    for r in range(len(rows) - 1):
        for i in range(n):
            a = r * (n + 1) + i
            faces.append((a, a + 1, a + n + 2, a + n + 1) if sign > 0 else (a + 1, a, a + n + 1, a + n + 2))
    me = bpy.data.meshes.new("Curtain")
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("Curtain", me)
    bpy.context.scene.collection.objects.link(o)
    mod = o.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = 0.012
    mod.offset = 0
    return [flat(o, DRAPE)]


made.append(export("curtain_left", curtain_panel(1)))
made.append(export("curtain_right", curtain_panel(-1)))

# ---------------- Ковёр на пол (лежит, узором вверх) ----------------
# Тёмно-синее поле с ромбической решёткой кремовыми линиями, по центру — ступенчатый бордовый
# ромб с кремовой серединкой, кайма кремовая с синим зигзагом, по углам — бордовые квадраты.
RUG_NAVY = mat("RugNavy", (0.02, 0.04, 0.12), 0.95)
RUG_CREAM = mat("RugCream", (0.75, 0.66, 0.48), 0.95)
RUG_WINE = mat("RugWine", (0.32, 0.03, 0.05), 0.95)
W, D = 3.0, 2.1
P = [box((W, D, 0.02), (0, 0, 0.01), RUG_CREAM)]
P.append(box((W - 0.34, D - 0.34, 0.024), (0, 0, 0.012), RUG_NAVY))
for k in range(40):                                                      # зигзаг по длинной кайме
    x = -W / 2 + 0.13 + k * (W - 0.26) / 39
    for y in (-D / 2 + 0.085, D / 2 - 0.085):
        P.append(box((0.06, 0.012, 0.024), (x, y, 0.012), RUG_NAVY, rot=(0, 0, math.radians(45 if k % 2 else -45))))
for k in range(28):                                                      # и по короткой
    y = -D / 2 + 0.13 + k * (D - 0.26) / 27
    for x in (-W / 2 + 0.085, W / 2 - 0.085):
        P.append(box((0.012, 0.06, 0.024), (x, y, 0.012), RUG_NAVY, rot=(0, 0, math.radians(45 if k % 2 else -45))))
# Решётка ромбов — короткими отрезками между узлами сетки, только внутри поля.
FX, FY = (W - 0.44) / 2, (D - 0.44) / 2
SX, SY = 0.24, 0.17
nodes = {}
for i in range(-6, 7):
    for j in range(-6, 7):
        if (i + j) % 2 == 0 and abs(i * SX) <= FX + 1e-6 and abs(j * SY) <= FY + 1e-6:
            nodes[(i, j)] = (i * SX, j * SY)
for (i, j), (x0, y0) in nodes.items():
    for di, dj in ((1, 1), (1, -1)):
        if (i + di, j + dj) in nodes:
            x1, y1 = nodes[(i + di, j + dj)]
            ln = math.hypot(x1 - x0, y1 - y0)
            P.append(box((ln, 0.012, 0.026), ((x0 + x1) / 2, (y0 + y1) / 2, 0.013), RUG_CREAM,
                         rot=(0, 0, math.atan2(y1 - y0, x1 - x0))))
for sz, c, h in ((1.0, RUG_CREAM, 0.032), (0.9, RUG_WINE, 0.034), (0.66, RUG_CREAM, 0.036),
                 (0.56, RUG_WINE, 0.038), (0.3, RUG_CREAM, 0.04), (0.16, RUG_NAVY, 0.042)):  # ромб
    P.append(box((sz, sz * 0.7, h), (0, 0, h / 2), c, rot=(0, 0, math.radians(45))))
for x in (-W / 2 + 0.35, W / 2 - 0.35):                                  # угловые квадраты
    for y in (-D / 2 + 0.35, D / 2 - 0.35):
        P.append(box((0.2, 0.2, 0.034), (x, y, 0.017), RUG_WINE))
        P.append(box((0.09, 0.09, 0.036), (x, y, 0.018), RUG_CREAM, rot=(0, 0, math.radians(45))))
for k in range(24):                                                      # бахрома
    y = -D / 2 + 0.06 + k * (D - 0.12) / 23
    for x in (-W / 2 - 0.04, W / 2 + 0.04):
        P.append(box((0.08, 0.012, 0.006), (x, y, 0.003), RUG_CREAM))
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
    "chandelier": (0, -1.0, -0.5), "curtain_cornice": (2.8, 1.2, 0), "curtain_left": (1.6, 1.2, 0), "curtain_right": (4.0, 1.2, 0), "floor_rug": (0.5, -3.6, 0),
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
