"""Двор 90-х: хрущёвка, деревья, фонарь, «гелик» (без эмблем) и его фары отдельно, «копейка» на кирпичах,
бочка, ящик, лестница, мусорный бак, замок, голубь и собака (части с суставами).

Здания и машины смотрят «лицом» в −Y Blender (= к камере, +Z в Godot). Голубь и собака смотрят в +Y
Blender (= вперёд, −Z в Godot), как персонажи. Начало координат — на земле.

Запуск:
    python tools/blender/courtyard.py assets/models/courtyard [--render превью.png]
"""
import bpy, bmesh, math, sys, os, random
from mathutils import Vector

args = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = args[0] if args else "."
RENDER = sys.argv[sys.argv.index("--render") + 1] if "--render" in sys.argv else None
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.cursor.location = (0, 0, 0)
random.seed(7)
_mats = {}
KEEP = []


ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def mat(name, color, rough=0.6, metal=0.0, emit=0.0, image=None):
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
    if emit:
        b.inputs["Emission Color"].default_value = (*color, 1)
        b.inputs["Emission Strength"].default_value = emit
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


def sphere(r, loc, m, scale=(1, 1, 1), segs=10, rings=6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return flat(o, m)


def ico(r, loc, m, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return flat(o, m)


def rod(a, b, r, m, verts=6):
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


WHITE = mat("White", (0.9, 0.9, 0.88), 0.6)
DARK = mat("Dark", (0.05, 0.05, 0.06), 0.5)
METAL = mat("Metal", (0.55, 0.56, 0.58), 0.4, 0.8)
RUST = mat("Rust", (0.45, 0.22, 0.1), 0.85)
WOOD = mat("Wood", (0.45, 0.3, 0.16), 0.8)

# ---------------- Хрущёвка: 5 этажей, 3 подъезда (28 × 11 × ~14.5 м) ----------------
PANEL = mat("Panel", (0.72, 0.7, 0.64), 0.9)
SEAM = mat("Seam", (0.45, 0.43, 0.4), 0.9)
GLASS = mat("WindowGlass", (0.22, 0.3, 0.38), 0.15)
FRAME = mat("WindowFrame", (0.85, 0.83, 0.78), 0.6)
W, D, FLOOR, FLOORS = 28.0, 11.0, 2.7, 5
H = FLOOR * FLOORS + 0.6
P = [box((W, D, H), (0, 0, H / 2), PANEL)]
P.append(box((W + 0.3, D + 0.3, 0.3), (0, 0, H + 0.15), SEAM))                   # край крыши
for f in range(1, FLOORS + 1):                                                     # межэтажные швы
    P.append(box((W + 0.04, D + 0.04, 0.06), (0, 0, f * FLOOR + 0.3), SEAM))
LAUNDRY = [mat("L%d" % i, c, 0.9) for i, c in enumerate(
    [tuple((v / 255) ** 2.2 for v in c) for c in (                         # пастельные цвета 80–90-х (sRGB)
        (226, 132, 128), (240, 170, 160), (232, 196, 120), (150, 196, 150), (120, 176, 196),
        (160, 150, 210), (214, 150, 196), (120, 160, 220), (238, 168, 104), (176, 214, 120),
        (110, 190, 176), (200, 120, 150))])]

# Семейства похожих оттенков (индексы в LAUNDRY): на одной верёвке вещи из РАЗНЫХ семейств,
# чтобы не висели подряд два бирюзовых или три голубых.
LAUNDRY_FAMILIES = [(0, 11), (1, 6), (2, 8), (3, 9), (4, 7, 10), (5,)]


def laundry_set(n, rnd):
    """n разных по цвету вещей для одной верёвки (n <= 6)."""
    return [LAUNDRY[rnd.choice(fam)] for fam in rnd.sample(LAUNDRY_FAMILIES, n)]
# Картинка за стеклом (tools/textures/khrush_glass.py: тюль, шторы, кот, фольга…), 8 вариантов.
# Чуть впереди стекла, но позади переплёта и «горящего» стекла ночью (window_view.gd).
KHRUSH_GLASS = mat("KhrushGlass", (1, 1, 1), 0.15, image="assets/textures/city/khrush_glass.png")


def glass_pic(x, y, z, side, w=1.1, h=1.2):
    """Квадрат с картинкой окна: side −1 — лицом в −Y, +1 — в +Y."""
    k = random.randrange(8)
    u0, v0 = (k % 4) * 0.25, (k // 4) * 0.5
    xs = (x - w / 2, x + w / 2) if side < 0 else (x + w / 2, x - w / 2)
    verts = [(xs[0], y, z - h / 2), (xs[1], y, z - h / 2), (xs[1], y, z + h / 2), (xs[0], y, z + h / 2)]
    me = bpy.data.meshes.new("Pic")
    me.from_pydata(verts, [], [(0, 1, 2, 3)])
    me.materials.append(KHRUSH_GLASS)
    uv = me.uv_layers.new(name="UVMap")
    for li, c in zip(me.polygons[0].loop_indices, ((u0, v0), (u0 + 0.25, v0), (u0 + 0.25, v0 + 0.5),
                                                    (u0, v0 + 0.5))):
        uv.data[li].uv = c
    o = bpy.data.objects.new("Pic", me)
    bpy.context.scene.collection.objects.link(o)
    return o


cols = 12
dish_spots = []
for f in range(FLOORS):
    z = 0.6 + f * FLOOR + 1.45
    for c in range(cols):
        x = -W / 2 + 1.2 + c * (W - 2.4) / (cols - 1)
        for side in (-1, 1):
            y = side * (D / 2 + 0.02)
            if f == 0 and side == -1 and c in (2, 6, 10):
                continue                                                           # подъезды
            P.append(box((1.3, 0.06, 1.4), (x, y, z), FRAME))
            P.append(box((1.1, 0.08, 1.2), (x, y, z), GLASS))
            P.append(glass_pic(x, side * (D / 2 + 0.065), z, side))
            P.append(box((0.06, 0.1, 1.2), (x, y, z), FRAME))
        # Балконы на лицевой стороне через окно, начиная со 2-го этажа.
        if f >= 1 and c % 2 == 1:
            y = -D / 2 - 0.55
            P.append(box((2.0, 1.1, 0.12), (x + 0.3, y, z - 1.0), SEAM))
            P.append(box((2.0, 0.05, 0.95), (x + 0.3, y - 0.53, z - 0.5), PANEL))
            for s in (-1, 1):
                P.append(box((0.05, 1.1, 0.95), (x + 0.3 + s * 0.98, y, z - 0.5), PANEL))
            hangs = random.random() < 0.5
            if hangs:                                                              # бельё на верёвке
                P.append(rod((x - 0.6, y - 0.45, z + 0.6), (x + 1.2, y - 0.45, z + 0.6), 0.01, WHITE, verts=4))
                for k, cloth in enumerate(laundry_set(random.randint(2, 4), random)):
                    P.append(box((0.3, 0.02, random.uniform(0.3, 0.6)),
                                 (x - 0.4 + k * 0.45, y - 0.45, z + 0.35), cloth))
            if random.random() < 0.3 and not hangs:                                # тарелка (не на бельё)
                dish_spots.append((x + 1.1, y - 0.6, z + 0.1))
for c in (2, 6, 10):                                                               # подъезды
    x = -W / 2 + 1.2 + c * (W - 2.4) / (cols - 1)
    P.append(box((1.3, 0.1, 2.2), (x, -D / 2 - 0.02, 1.1), mat("DoorBrown", (0.35, 0.2, 0.1), 0.7)))
    P.append(box((2.2, 1.4, 0.15), (x, -D / 2 - 0.7, 2.6), SEAM))
    P.append(box((2.4, 1.5, 0.3), (x, -D / 2 - 0.75, 0.15), SEAM))
for x in (-9, -2, 5, 11):                                                          # антенны на крыше
    P.append(rod((x, 0, H + 0.3), (x, 0, H + 2.6), 0.04, METAL))
    for k in range(3):
        P.append(rod((x - 0.6 + k * 0.1, 0, H + 1.8 + k * 0.3), (x + 0.6 - k * 0.1, 0, H + 1.8 + k * 0.3),
                     0.02, METAL, verts=4))
# Спутниковые тарелки «ДВУКОЛОР» (как на новых домах, city.py): овальная вогнутая чаша с
# логотипом (tools/textures/dish_logo.py), светлая изнанка, штанга с конвертером, кронштейн к
# перилам. Не металл (металл в игре чёрный — были «чёрные круги»). Тарелок вдвое меньше.
DISH_FACE = mat("DishFace", (1, 1, 1), 0.45, image="assets/textures/city/dish_logo.png")
DISH_BACK = mat("DishBack", (0.8, 0.81, 0.82), 0.5)


def dish(cx, cy, cz, ax=0.34, az=0.38, depth=0.07, tilt=0.25):
    """Тарелка лицом в −Y (на улицу), чуть вверх; центр чаши в (cx, cy, cz)."""
    n, rings = 20, 4
    ct, st = math.cos(tilt), math.sin(tilt)

    def pt(u, v, back=False):
        x, z = u * ax, v * az
        y = depth * (1 - (u * u + v * v)) + (0.012 if back else 0.0)    # вогнутая к стене
        return (cx + x, cy + y * ct + z * st, cz + z * ct - y * st)

    verts, faces, uvs = [], [], []
    for side in (False, True):
        base = len(verts)
        verts.append(pt(0, 0, side))
        uvs.append((0.5, 0.5))
        for r in range(1, rings + 1):
            for k in range(n):
                a = k * math.tau / n
                u, v = math.cos(a) * r / rings, math.sin(a) * r / rings
                verts.append(pt(u, v, side))
                uvs.append((0.5 + u * 0.5, 0.5 + v * 0.5))
        for r in range(rings):
            for k in range(n):
                k2 = (k + 1) % n
                if r == 0:
                    f = (base, base + 1 + k2, base + 1 + k)
                else:
                    o0, o1 = base + 1 + (r - 1) * n, base + 1 + r * n
                    f = (o0 + k, o0 + k2, o1 + k2, o1 + k)
                faces.append(f[::-1] if side else f)
    me = bpy.data.meshes.new("Dish")
    me.from_pydata(verts, [], faces)
    me.materials.append(DISH_FACE)
    me.materials.append(DISH_BACK)
    half = len(faces) // 2
    uv = me.uv_layers.new(name="UVMap")
    for i, poly in enumerate(me.polygons):
        poly.material_index = 0 if i < half else 1
        for li in poly.loop_indices:
            uv.data[li].uv = uvs[me.loops[li].vertex_index]
    o = bpy.data.objects.new("Dish", me)
    bpy.context.scene.collection.objects.link(o)
    focus = (cx + 0.12, cy - 0.42, cz - 0.02)
    return [o, rod((cx, cy + 0.03, cz - az * 0.95), (cx + 0.08, cy - 0.3, cz - az * 0.9), 0.012, DISH_BACK,
                   verts=4),
            rod((cx + 0.08, cy - 0.3, cz - az * 0.9), focus, 0.012, DISH_BACK, verts=4),
            box((0.07, 0.09, 0.07), focus, WHITE)]


for i, (dx, dy, dz) in enumerate(dish_spots):
    if i % 2:
        continue
    # Снаружи перил балкона, над ними; кронштейн — к перилам.
    P += dish(dx - 0.1, dy - 0.25, dz + 0.15)
    P.append(rod((dx - 0.1, dy - 0.2, dz - 0.15), (dx - 0.1, dy + 0.05, dz - 0.4), 0.02, METAL, verts=4))
export("khrushchevka", [join("Khrushchevka", P)])

# ---------------- Деревья: тополь и берёза ----------------
BARK = mat("Bark", (0.35, 0.25, 0.17), 0.9)
BIRCH = mat("Birch", (0.9, 0.88, 0.82), 0.8)
LEAF = mat("Leaf", (0.28, 0.5, 0.2), 0.9)
LEAF2 = mat("Leaf2", (0.36, 0.58, 0.22), 0.9)
P = [cyl(0.25, 5.0, (0, 0, 2.5), BARK, verts=8, r2=0.15)]
for (x, y, z, r) in [(0, 0, 5.2, 1.8), (0.8, 0.3, 4.2, 1.3), (-0.7, -0.4, 4.4, 1.4), (0.1, 0.2, 6.4, 1.2)]:
    P.append(ico(r, (x, y, z), LEAF, scale=(1, 1, 1.25)))
export("tree_poplar", [join("TreePoplar", P)])
P = [cyl(0.15, 4.5, (0, 0, 2.25), BIRCH, verts=8, r2=0.09)]
for k in range(6):
    P.append(box((0.16, 0.16, 0.06), (0, 0, 0.6 + k * 0.6), DARK, rot=(0, 0, k)))
for (x, y, z, r) in [(0, 0, 4.4, 1.3), (0.6, -0.2, 3.6, 1.0), (-0.6, 0.3, 3.7, 1.0)]:
    P.append(ico(r, (x, y, z), LEAF2, scale=(1, 1, 1.3)))
export("tree_birch", [join("TreeBirch", P)])

# ---------------- Кусты: два вида (шаровидный и раскидистый) ----------------
BUSH = mat("Bush", (0.22, 0.45, 0.17), 0.9)
BUSH2 = mat("Bush2", (0.3, 0.55, 0.2), 0.9)
BERRY = mat("Berry", (0.75, 0.12, 0.12), 0.6)


def inside(o, p):
    """Точка p (мир) внутри замкнутой сетки o?"""
    local = o.matrix_world.inverted() @ p
    ok, near, normal, _ = o.closest_point_on_mesh(local)
    return ok and (local - near).dot(normal) < 0


def berries_on(blobs, seed, clusters):
    """Гроздья ягод ПРЯМО на поверхности шаров куста (луч снаружи к центру шара — точка
    попадания), наполовину утоплены. Раньше ягоды ставились «на глаз» и висели в воздухе:
    у грубого многогранника поверхность местами глубже, чем радиус."""
    rnd = random.Random(seed)
    out = []
    for _ in range(clusters * 12):
        if len(out) >= clusters * 3:
            break
        o = rnd.choice(blobs)
        a = rnd.uniform(0, math.tau)
        d = Vector((math.cos(a), math.sin(a), rnd.uniform(-0.1, 0.6))).normalized()
        centre = sum((v.co for v in o.data.vertices), Vector()) / len(o.data.vertices)
        hit, loc, normal, _ = o.ray_cast(centre + d * 3.0, -d)
        if not hit:
            continue
        p = o.matrix_world @ loc
        if p.z < 0.12 or any(inside(b, p + d * 0.03) for b in blobs if b is not o):
            continue                                                            # у земли или в соседнем шаре
        side = Vector((-d.y, d.x, 0)).normalized()
        for off in (Vector((0, 0, 0)), side * 0.05 + Vector((0, 0, 0.03)), side * -0.04 + Vector((0, 0, -0.03))):
            q = p + off
            # вторую и третью ягоду тоже прижать к поверхности
            hit2, loc2, _, _ = o.ray_cast(o.matrix_world.inverted() @ (q + d * 0.5), -d)
            if hit2:
                q = o.matrix_world @ loc2
            out.append(sphere(0.04, tuple(q - d * 0.005), BERRY, segs=6, rings=4))
    return out


P = []
for (x, y, z, r) in [(0, 0, 0.45, 0.55), (0.4, 0.15, 0.35, 0.4), (-0.38, -0.1, 0.35, 0.42), (0.1, -0.3, 0.3, 0.35)]:
    P.append(ico(r, (x, y, z), BUSH if r > 0.4 else BUSH2, scale=(1, 1, 0.8)))
P += berries_on(P, 7, 4)
export("bush_round", [join("BushRound", P)])
P = []
for (x, y, z, r) in [(-0.5, 0, 0.3, 0.38), (0, 0.05, 0.38, 0.45), (0.5, -0.05, 0.3, 0.38), (0.25, 0.3, 0.25, 0.3)]:
    P.append(ico(r, (x, y, z), BUSH2 if x > 0 else BUSH, scale=(1, 0.8, 0.75)))
P += berries_on(P, 21, 5)
export("bush_wide", [join("BushWide", P)])

# ---------------- Фонарь ----------------
P = [cyl(0.09, 6.0, (0, 0, 3.0), mat("PoleGrey", (0.45, 0.47, 0.45), 0.6), verts=8, r2=0.06)]
P.append(rod((0, 0, 5.9), (0, -1.2, 6.1), 0.05, METAL))
P.append(box((0.35, 0.6, 0.15), (0, -1.35, 6.05), mat("PoleGrey", (0.45, 0.47, 0.45), 0.6)))
P.append(box((0.28, 0.5, 0.03), (0, -1.35, 5.96), mat("LampGlow", (1.0, 0.85, 0.55), 0.3, 0, 3.0)))
export("lamp_post", [join("LampPost", P)])

# ---------------- «Гелик»: чёрный угловатый внедорожник без эмблем (вдоль X) ----------------
BLACK_PAINT = mat("BlackPaint", (0.02, 0.02, 0.025), 0.2, 0.6)
TINT = mat("Tint", (0.05, 0.07, 0.09), 0.05)
TIRE = mat("Tire", (0.04, 0.04, 0.04), 0.9)
CHROME = mat("Chrome", (0.8, 0.8, 0.82), 0.15, 1.0)
LAMP_OFF = mat("LampOff", (0.75, 0.75, 0.7), 0.2)
P = [box((4.6, 1.9, 0.95), (0, 0, 0.95), BLACK_PAINT)]
P.append(box((2.9, 1.8, 0.85), (-0.35, 0, 1.85), BLACK_PAINT))                  # кабина
for y in (-0.905, 0.905):                                                        # окна по бокам
    P.append(box((2.6, 0.02, 0.6), (-0.35, y, 1.88), TINT))
P.append(box((0.02, 1.6, 0.62), (1.115, 0, 1.88), TINT))                         # лобовое
P.append(box((0.02, 1.4, 0.55), (-1.805, 0, 1.88), TINT))
for x in (-1.45, 1.45):
    for y in (-0.82, 0.82):
        P.append(cyl(0.42, 0.32, (x, y, 0.42), TIRE, verts=14, rot=(math.pi / 2, 0, 0)))
        P.append(cyl(0.22, 0.34, (x, y, 0.42), METAL, verts=10, rot=(math.pi / 2, 0, 0)))
        P.append(box((1.05, 0.2, 0.12), (x, y * 1.08, 0.88), BLACK_PAINT))      # расширители арок
P.append(cyl(0.4, 0.25, (-2.42, 0, 1.15), TIRE, verts=14, rot=(0, math.pi / 2, 0)))  # запаска
P.append(cyl(0.3, 0.27, (-2.42, 0, 1.15), BLACK_PAINT, verts=12, rot=(0, math.pi / 2, 0)))
for x in (2.35, -2.35):                                                          # бамперы
    P.append(box((0.15, 1.95, 0.25), (x, 0, 0.6), DARK))
P.append(box((0.04, 1.0, 0.4), (2.31, 0, 1.15), DARK))                           # решётка (без эмблем)
for k in range(5):
    P.append(box((0.05, 0.9, 0.03), (2.33, 0, 1.0 + k * 0.08), CHROME))
for y in (-0.7, 0.7):                                                            # фары (выключены)
    P.append(cyl(0.13, 0.05, (2.31, y, 1.15), LAMP_OFF, verts=12, rot=(0, math.pi / 2, 0)))
    P.append(box((0.05, 0.2, 0.3), (-2.31, y, 1.15), mat("TailOff", (0.4, 0.05, 0.05), 0.3)))
    P.append(box((0.15, 0.06, 0.12), (1.0, y * 1.32, 1.95), BLACK_PAINT))        # зеркала
P.append(box((0.9, 1.5, 0.08), (-0.6, 0, 2.31), BLACK_PAINT))                     # багажник на крыше
export("gelik", [join("Gelik", P)])
# Горящие фары и поворотники — отдельной моделью (мигают в игре).
ON_W = mat("LightOnWhite", (1.0, 0.95, 0.8), 0.2, 0, 6.0)
ON_R = mat("LightOnRed", (1.0, 0.1, 0.05), 0.2, 0, 5.0)
ON_O = mat("LightOnOrange", (1.0, 0.55, 0.05), 0.2, 0, 6.0)
P = []
for y in (-0.7, 0.7):
    P.append(cyl(0.135, 0.06, (2.33, y, 1.15), ON_W, verts=12, rot=(0, math.pi / 2, 0)))
    P.append(box((0.06, 0.21, 0.31), (-2.33, y, 1.15), ON_R))
    P.append(box((0.08, 0.15, 0.08), (2.31, y * 1.15, 0.85), ON_O))
    P.append(box((0.08, 0.15, 0.08), (-2.31, y * 1.15, 0.85), ON_O))
export("gelik_lights", [join("GelikLights", P)])

# ---------------- «Копейка» на кирпичах (вдоль X), без колёс ----------------
FADED = mat("FadedBlue", (0.55, 0.68, 0.72), 0.7)
BRICK = mat("Brick", (0.6, 0.25, 0.15), 0.9)
LIFT = 0.42
P = [box((4.05, 1.6, 0.62), (0, 0, LIFT + 0.31), FADED)]
P.append(box((2.0, 1.45, 0.58), (-0.2, 0, LIFT + 0.9), FADED))
P.append(box((1.6, 1.25, 0.04), (-0.2, 0, LIFT + 1.19), FADED))
for y in (-0.73, 0.73):
    P.append(box((1.8, 0.02, 0.42), (-0.2, y, LIFT + 0.92), GLASS))
P.append(box((0.02, 1.3, 0.42), (0.81, 0, LIFT + 0.9), GLASS))
P.append(box((0.02, 1.3, 0.4), (-1.21, 0, LIFT + 0.9), GLASS))
for x in (-1.3, 1.3):
    for y in (-0.72, 0.72):
        P.append(box((0.7, 0.18, 0.36), (x, y, LIFT + 0.12), DARK))              # пустые арки
        for k in range(3):                                                       # стопка кирпичей
            P.append(box((0.25, 0.12, 0.13), (x, y * 0.85, 0.07 + k * 0.135), BRICK,
                         rot=(0, 0, (k % 2) * math.pi / 2)))
for x in (2.05, -2.05):
    P.append(box((0.08, 1.65, 0.14), (x, 0, LIFT + 0.18), CHROME))
for y in (-0.55, 0.55):
    P.append(cyl(0.09, 0.04, (2.03, y, LIFT + 0.45), LAMP_OFF, verts=10, rot=(0, math.pi / 2, 0)))
    P.append(box((0.04, 0.3, 0.12), (-2.03, y, LIFT + 0.45), mat("TailOff", (0.4, 0.05, 0.05), 0.3)))
P.append(box((0.03, 0.6, 0.1), (2.03, 0, LIFT + 0.42), CHROME))                  # решётка без эмблем
export("kopeyka", [join("Kopeyka", P)])

# ---------------- «Жигуль» на колёсах (вдоль X, перед — +X): вишнёвый, у гаражей ----------------
CHERRY = mat("ZhiguliCherry", (0.42, 0.06, 0.08), 0.5)
TYRE = mat("Tyre", (0.06, 0.06, 0.06), 0.9)
HUB = mat("Hubcap", (0.75, 0.76, 0.78), 0.35, 0.2)
LIFT = 0.3
P = [box((4.05, 1.6, 0.62), (0, 0, LIFT + 0.31), CHERRY)]
P.append(box((2.0, 1.45, 0.58), (-0.2, 0, LIFT + 0.9), CHERRY))
P.append(box((1.6, 1.25, 0.04), (-0.2, 0, LIFT + 1.19), CHERRY))
for y in (-0.73, 0.73):
    P.append(box((1.8, 0.02, 0.42), (-0.2, y, LIFT + 0.92), GLASS))
    P.append(box((3.9, 0.02, 0.04), (0, y * 1.1, LIFT + 0.5), CHROME))          # молдинг
P.append(box((0.02, 1.3, 0.42), (0.81, 0, LIFT + 0.9), GLASS))
P.append(box((0.02, 1.3, 0.4), (-1.21, 0, LIFT + 0.9), GLASS))
for x in (-1.3, 1.3):
    for y in (-0.74, 0.74):
        P.append(cyl(0.3, 0.2, (x, y, 0.3), TYRE, verts=16, rot=(math.pi / 2, 0, 0)))
        P.append(cyl(0.17, 0.21, (x, y, 0.3), HUB, verts=12, rot=(math.pi / 2, 0, 0)))
for x in (2.05, -2.05):
    P.append(box((0.08, 1.65, 0.14), (x, 0, LIFT + 0.18), CHROME))
for y in (-0.55, 0.55):
    P.append(cyl(0.09, 0.04, (2.03, y, LIFT + 0.45), LAMP_OFF, verts=10, rot=(0, math.pi / 2, 0)))
    P.append(box((0.04, 0.3, 0.12), (-2.03, y, LIFT + 0.45), mat("TailOff", (0.4, 0.05, 0.05), 0.3)))
P.append(box((0.03, 0.6, 0.1), (2.03, 0, LIFT + 0.42), CHROME))                  # решётка без эмблем
P.append(box((0.03, 0.42, 0.11), (-2.06, 0, LIFT + 0.2), WHITE))               # номер
export("zhiguli", [join("Zhiguli", P)])

# ---------------- Бочка, ящик, лестница, бак, замок ----------------
P = [cyl(0.32, 0.9, (0, 0, 0.45), RUST, verts=12)]
for z in (0.15, 0.45, 0.75):
    P.append(cyl(0.335, 0.05, (0, 0, z), mat("RustDark", (0.3, 0.14, 0.06), 0.85), verts=12))
P.append(cyl(0.3, 0.02, (0, 0, 0.9), mat("RustDark", (0.3, 0.14, 0.06), 0.85), verts=12))
export("barrel", [join("Barrel", P)])
P = [box((0.6, 0.6, 0.55), (0, 0, 0.275), WOOD)]
for z in (0.1, 0.275, 0.45):
    for y in (-0.305, 0.305):
        P.append(box((0.62, 0.02, 0.12), (0, y, z), mat("WoodDark", (0.3, 0.19, 0.09), 0.8)))
export("crate", [join("Crate", P)])
P = []
for x in (-0.22, 0.22):
    P.append(box((0.06, 0.06, 3.6), (x, 0, 1.8), WOOD))
for k in range(11):
    P.append(box((0.44, 0.04, 0.04), (0, 0, 0.25 + k * 0.32), WOOD))
export("ladder", [join("Ladder", P)])
BIN = mat("BinGreen", (0.2, 0.38, 0.25), 0.7, 0.3)
BIN_LID = mat("BinLid", (0.15, 0.3, 0.2), 0.7, 0.3)
TRASH_MASS = mat("TrashMass", (0.16, 0.14, 0.11), 0.95)
PAPER = mat("TrashPaper", (0.78, 0.76, 0.68), 0.9)
CARDBOARD = mat("Cardboard", (0.5, 0.36, 0.2), 0.9)
BOTTLE = mat("BottleGreen", (0.12, 0.35, 0.15), 0.3)
BANANA = mat("Banana", (0.85, 0.72, 0.2), 0.7)



# Шина на крыше гаражей (лежит плашмя): профиль покрышки вращением, протектор блоками по
# кругу, боковина с ободком, в середине — дыра. R 0.6, высота 0.28, начало координат — на крыше.
RUBBER = mat("Rubber", (0.035, 0.035, 0.038), 0.88)
RUBBER_SIDE = mat("RubberSide", (0.06, 0.06, 0.062), 0.8)


def roof_tire(name, seed):
    rnd = random.Random(seed)
    n = 36
    prof = [(0.31, 0.03), (0.36, 0.0), (0.5, 0.0), (0.57, 0.03), (0.6, 0.08), (0.6, 0.2), (0.57, 0.25),
            (0.5, 0.28), (0.36, 0.28), (0.31, 0.25)]                    # сечение (r, z) по кругу
    verts, faces = [], []
    for k in range(n):
        a = k * math.tau / n
        for r, z in prof:
            verts.append((r * math.cos(a), r * math.sin(a), z))
    m = len(prof)
    for k in range(n):
        k2 = (k + 1) % n
        for j in range(m):
            j2 = (j + 1) % m
            faces.append((k * m + j, k2 * m + j, k2 * m + j2, k * m + j2))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.materials.append(RUBBER_SIDE)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    for poly in o.data.polygons:
        poly.use_smooth = True
    parts = [o]
    for k in range(n):                                                  # протектор
        a = (k + 0.5) * math.tau / n
        for z, sh in ((0.09, 0.08), (0.19, -0.08)):
            parts.append(box((0.03, 0.08, 0.075), (0.605 * math.cos(a), 0.605 * math.sin(a), z), RUBBER,
                             rot=(0, 0, a + sh)))
    for z in (0.002, 0.278):                                            # ободок на боковине
        bpy.ops.mesh.primitive_torus_add(major_radius=0.45, minor_radius=0.008, major_segments=36,
                                         minor_segments=3, location=(0, 0, z))
        parts.append(flat(bpy.context.object, RUBBER))
    t = join(name, parts)
    t.rotation_euler = (rnd.uniform(-0.03, 0.03), rnd.uniform(-0.03, 0.03), rnd.uniform(0, math.tau))
    export(name, [t])


roof_tire("roof_tire", 1)
# ---------------- Мусорные мешки (два вида) и канализационный люк ----------------
# Мешок: «мешковатая» форма — плоское осевшее дно, неровные бока со складками, сверху
# перетянутое горлышко и два завязанных «ушка». Матовый полиэтилен (не блестит, не металл).
BAG = mat("TrashBag", (0.028, 0.03, 0.034), 0.62)


def bag_parts(seed, rx, ry, h, at=(0, 0, 0), tilt=(0, 0, 0)):
    """Части мешка (форма как у trash_bag), сдвинутые в точку at и наклонённые на tilt."""
    rnd = random.Random(seed)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=12, radius=1.0, location=(0, 0, 0))
    o = bpy.context.object
    folds = [(rnd.uniform(0, math.tau), rnd.uniform(0.05, 0.12)) for _ in range(7)]
    for v in o.data.vertices:
        x, y, z = v.co
        a = math.atan2(y, x)
        k = 1.0
        for fa, depth in folds:                                                 # вертикальные складки
            d = math.atan2(math.sin(a - fa), math.cos(a - fa))
            k -= depth * math.exp(-(d / 0.18) ** 2) * (1 - abs(z))
        k += 0.04 * math.sin(a * 3 + seed) * (1 - z * z) + rnd.uniform(-0.02, 0.02)
        if z < 0:                                                               # осевшее широкое дно
            k *= 1.0 + 0.18 * (-z)
            z = max(z, -0.6)                                                    # плоско лежит на земле
        if z > 0.55:                                                            # стянуто к горлышку
            k *= 1.0 - (z - 0.55) * 1.35
        v.co = (x * k * rx, y * k * ry, (z + 0.6) * h / 1.6)
    flat(o, BAG)
    for p_ in o.data.polygons:
        p_.use_smooth = True
    top = h * 0.98
    parts = [o, cyl(0.06, 0.12, (0, 0, top + 0.03), BAG, verts=8, r2=0.035)]  # горлышко
    for s_ in (-1, 1):                                                          # «ушки» узла
        ear = box((0.05, 0.02, 0.13), (s_ * 0.06, 0, top + 0.12), BAG, rot=(0, s_ * 0.7, rnd.uniform(-0.3, 0.3)))
        parts.append(ear)
    bag = join("Bag%d" % seed, parts)
    bag.rotation_euler = tilt
    bag.location = at
    return bag


def trash_bag(name, seed, rx, ry, h):
    export(name, [join(name, [bag_parts(seed, rx, ry, h)])])


trash_bag("trash_bag", 3, 0.3, 0.27, 0.62)
trash_bag("trash_bag_fat", 8, 0.38, 0.33, 0.52)

# Мусорный бак (как настоящие контейнеры): корпус с наклонной передней стенкой (сверху шире),
# борт-окантовка, поручень спереди, карманы по бокам, колёсики. Крышка — две чёрные пластиковые
# половинки с рёбрами и бортиком (не плоская доска). Лицом в −Y, ширина 1.5 м, высота ~1.2 м.
LID_PLASTIC = mat("BinLidPlastic", (0.025, 0.026, 0.028), 0.55)
TRASH_FILL = mat("TrashFill", (1, 1, 1), 0.9, image="assets/textures/garage/trash_fill.png")
BIN_TOP = 1.1


def bin_body():
    verts = [(-0.75, -0.38, 0.12), (0.75, -0.38, 0.12), (0.75, 0.45, 0.12), (-0.75, 0.45, 0.12),
             (-0.75, -0.55, BIN_TOP), (0.75, -0.55, BIN_TOP), (0.75, 0.45, BIN_TOP), (-0.75, 0.45, BIN_TOP)]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    me = bpy.data.meshes.new("BinBody")
    me.from_pydata(verts, [], faces)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)                      # все грани наружу
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("BinBody", me)
    bpy.context.scene.collection.objects.link(o)
    P = [flat(o, BIN)]
    for (sx, sy, cx, cy) in ((1.56, 0.06, 0, -0.56), (1.56, 0.06, 0, 0.46), (0.06, 1.08, -0.77, -0.05),
                             (0.06, 1.08, 0.77, -0.05)):                    # борт-окантовка
        P.append(box((sx, sy, 0.08), (cx, cy, BIN_TOP - 0.02), BIN))
    P.append(rod((-0.8, -0.6, 0.98), (0.8, -0.6, 0.98), 0.018, mat("BinRail", (0.55, 0.56, 0.55), 0.4, 0.3)))
    for s_ in (-1, 1):
        P.append(box((0.04, 0.04, 0.12), (s_ * 0.8, -0.57, 0.98), BIN))      # крепления поручня
        P.append(box((0.1, 0.45, 0.16), (s_ * 0.8, 0.0, 0.7), BIN))          # карманы для погрузчика
        P.append(box((0.11, 0.35, 0.08), (s_ * 0.81, 0.0, 0.7), DARK))
    for z in (0.45, 0.8):                                                  # рёбра жёсткости спереди
        y = -0.38 - (z - 0.12) / (BIN_TOP - 0.12) * 0.17
        P.append(box((1.5, 0.03, 0.04), (0, y - 0.015, z), BIN, rot=(-0.17, 0, 0)))
    P.append(box((0.9, 0.02, 0.18), (0, -0.46, 0.62), mat("BinStripe", (0.95, 0.85, 0.2), 0.6),
                 rot=(-0.17, 0, 0)))                                       # жёлтая полоса
    for x in (-0.6, 0.6):                                                  # колёсики
        for y in (-0.3, 0.35):
            P.append(box((0.06, 0.06, 0.06), (x, y, 0.1), DARK))
            P.append(cyl(0.05, 0.04, (x, y, 0.05), DARK, verts=10, rot=(0, math.pi / 2, 0)))
    return P


def bin_lid(x0, open_angle):
    """Половинка крышки от x0 до x0 + 0.76: пластина, бортик, 4 ребра; на петлях сзади."""
    cx = x0 + 0.38
    parts = [box((0.74, 1.04, 0.04), (cx, -0.05, BIN_TOP + 0.04), LID_PLASTIC)]
    parts.append(box((0.76, 0.05, 0.08), (cx, -0.58, BIN_TOP + 0.02), LID_PLASTIC))   # передний бортик
    for k in range(4):                                                    # рёбра (выше к середине)
        x = cx - 0.27 + k * 0.18
        parts.append(box((0.08, 0.86, 0.05), (x, -0.07, BIN_TOP + 0.08), LID_PLASTIC))
    parts.append(box((0.6, 0.06, 0.03), (cx, -0.5, BIN_TOP + 0.075), LID_PLASTIC))     # ручка-выступ
    lid = join("Lid", parts, pivot=(cx, 0.47, BIN_TOP + 0.04))
    lid.rotation_euler = (-open_angle, 0, 0)
    return lid


def trash_bin(open_lid):
    P = bin_body()
    if open_lid:
        P.append(bin_lid(-0.76, math.radians(62)))                         # обе половинки приоткрыты
        P.append(bin_lid(0.0, math.radians(62)))
        # Горка мусора с картинкой мусора (tools/textures/trash_fill.py) — бугристая, выше борта;
        # поверх — вещи, каждая положена прямо на поверхность горки.
        rnd = random.Random(5)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0, location=(0, -0.04, 1.08))
        heap = bpy.context.object
        for v in heap.data.vertices:
            x, y, z = v.co
            bump = 1.0 + rnd.uniform(-0.12, 0.12)
            v.co = (x * 0.73, y * 0.49, max(z, -0.2) * 0.3 * bump)
        while heap.data.uv_layers:                                          # своя развёртка — сверху
            heap.data.uv_layers.remove(heap.data.uv_layers[0])
        uv = heap.data.uv_layers.new(name="UVMap")
        for poly in heap.data.polygons:
            for li in poly.loop_indices:
                co = heap.data.vertices[heap.data.loops[li].vertex_index].co
                uv.data[li].uv = ((co.x + 0.75) / 1.5 * 1.6, (co.y + 0.5) * 1.1)
        P.append(flat(heap, TRASH_FILL))

        def on_heap(x, y):
            hit, loc, _, _ = heap.ray_cast(Vector((x, y + 0.04, 2.0)) - heap.location, Vector((0, 0, -1)))
            return (heap.location + loc).z if hit else 1.12

        for (seed, x, y, sc, tilt, m) in ((31, -0.4, 0.1, 1.0, (0.3, -0.2, 0.5), None),
                                          (32, 0.35, 0.12, 0.9, (-0.4, 0.3, 1.2), "BagBlue"),
                                          (34, 0.05, -0.15, 0.8, (0.2, 0.4, 2.0), "BagWhite")):
            bag = bag_parts(seed, 0.17 * sc, 0.15 * sc, 0.3 * sc, at=(x, y, on_heap(x, y) - 0.06), tilt=tilt)
            if m == "BagBlue":
                bag.data.materials[0] = mat("BagBlue", (0.12, 0.2, 0.42), 0.6)
            elif m == "BagWhite":
                bag.data.materials[0] = mat("BagWhite", (0.8, 0.8, 0.78), 0.6)
            P.append(bag)
        P.append(box((0.3, 0.22, 0.14), (0.5, -0.2, on_heap(0.5, -0.2) + 0.03), CARDBOARD,
                     rot=(0.25, 0.15, 0.4)))                                                  # коробка
        for (x, y, r) in ((-0.15, -0.3, 0.3), (0.62, 0.15, 1.9), (-0.6, -0.2, 0.9)):            # газеты
            P.append(box((0.22, 0.17, 0.012), (x, y, on_heap(x, y) + 0.005), PAPER, rot=(0.2, -0.25, r)))
        P.append(cyl(0.04, 0.26, (0.2, -0.3, on_heap(0.2, -0.3) + 0.03), BOTTLE, verts=8,
                     rot=(1.3, 0, 0.6)))                                                     # бутылка
        z = on_heap(-0.35, -0.35)
        P.append(rod((-0.35, -0.38, z), (-0.27, -0.3, z + 0.04), 0.022, BANANA, verts=5))   # кожура
        P.append(rod((-0.35, -0.38, z), (-0.43, -0.3, z + 0.03), 0.02, BANANA, verts=5))
    else:
        P.append(bin_lid(-0.76, 0.0))
        P.append(bin_lid(0.0, 0.0))
        # Сверху: мешок, который не влез, и сплющенная картонная коробка.
        P.append(bag_parts(33, 0.2, 0.18, 0.34, at=(-0.35, 0.05, BIN_TOP + 0.1), tilt=(0, 0.25, 0.4)))
        P.append(box((0.55, 0.4, 0.04), (0.32, 0.0, BIN_TOP + 0.15), CARDBOARD, rot=(0.05, -0.1, 0.3)))
        P.append(box((0.5, 0.012, 0.06), (0.3, -0.19, BIN_TOP + 0.17), mat("Tape", (0.75, 0.65, 0.45), 0.5),
                     rot=(0.05, -0.1, 0.3)))
    return P


export("trash_bin", [join("TrashBin", trash_bin(False))])
export("trash_bin_open", [join("TrashBinOpen", trash_bin(True))])

# Люк: чугунная крышка с узором (кольца, лучи, сетка в середине) в кольце-обойме, вокруг —
# заплатка тёмного асфальта. Лицом вверх, начало координат — на земле.
IRON = mat("ManholeIron", (0.09, 0.09, 0.095), 0.75, 0.3)
IRON_TOP = mat("ManholeIronTop", (0.16, 0.155, 0.15), 0.55, 0.3)
P = [cyl(0.62, 0.02, (0, 0, 0.01), mat("AsphaltPatch", (0.11, 0.11, 0.115), 0.95), verts=24),
     cyl(0.43, 0.04, (0, 0, 0.02), IRON, verts=28),                            # обойма
     cyl(0.38, 0.045, (0, 0, 0.023), IRON_TOP, verts=28)]                       # крышка
for r in (0.355, 0.27, 0.17):                                                  # рельефные кольца
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=0.011, major_segments=32,
                                     minor_segments=4, location=(0, 0, 0.046))
    P.append(flat(bpy.context.object, IRON))
for k in range(16):                                                            # лучи
    a = k * math.tau / 16
    m = Vector((math.cos(a), math.sin(a), 0))
    P.append(box((0.08, 0.016, 0.012), tuple(m * 0.31 + Vector((0, 0, 0.046))), IRON, rot=(0, 0, a)))
for i in range(-2, 3):                                                         # сетка в середине
    P.append(box((0.26, 0.014, 0.012), (0, i * 0.05, 0.046), IRON))
    P.append(box((0.014, 0.26, 0.012), (i * 0.05, 0, 0.046), IRON))
for a in (0.4, 3.5):                                                           # пазы для лома
    P.append(box((0.07, 0.025, 0.01), (math.cos(a) * 0.37, math.sin(a) * 0.37, 0.047), DARK, rot=(0, 0, a)))
export("manhole", [join("Manhole", P)])

P = [box((0.12, 0.05, 0.12), (0, 0, 0), METAL)]
bpy.ops.mesh.primitive_torus_add(major_radius=0.045, minor_radius=0.012, major_segments=10,
                                 minor_segments=4, location=(0, 0, 0.07), rotation=(math.pi / 2, 0, 0))
P.append(flat(bpy.context.object, METAL))
export("padlock", [join("Padlock", P)])

# ---------------- Голубь (смотрит в +Y; крылья отдельно, сустав у плеча) ----------------
PIGEON = mat("Pigeon", (0.5, 0.52, 0.58), 0.7)
NECK = mat("PigeonNeck", (0.3, 0.45, 0.42), 0.4, 0.4)
pigeon = []
P = [sphere(0.1, (0, 0, 0.12), PIGEON, scale=(0.75, 1.3, 0.8))]
P.append(sphere(0.065, (0, 0.1, 0.2), NECK))
P.append(sphere(0.05, (0, 0.14, 0.27), PIGEON))
P.append(cyl(0.015, 0.05, (0, 0.2, 0.26), mat("Beak", (0.3, 0.25, 0.2), 0.5), verts=6, r2=0.0,
             rot=(-math.pi / 2, 0, 0)))
for s in (-1, 1):
    P.append(sphere(0.012, (s * 0.035, 0.17, 0.285), mat("PigeonEye", (0.9, 0.4, 0.1), 0.3)))
P.append(box((0.1, 0.12, 0.02), (0, -0.16, 0.12), PIGEON, rot=(math.radians(15), 0, 0)))
for s in (-1, 1):
    P.append(cyl(0.007, 0.07, (s * 0.03, 0.0, 0.035), mat("Feet", (0.8, 0.3, 0.3), 0.6), verts=4))
pigeon.append(join("PigeonBody", P, (0, 0, 0)))
for name, s in (("WingL", -1), ("WingR", 1)):
    # Сложенное крыло — пластина вдоль бока, висит от плеча вниз. В полёте Godot поворачивает
    # его вокруг оси «вперёд» наружу — крыло раскрывается в сторону.
    P = [box((0.02, 0.22, 0.15), (s * 0.08, -0.03, 0.12), mat("PigeonWing", (0.42, 0.44, 0.5), 0.7))]
    P.append(box((0.021, 0.2, 0.03), (s * 0.08, -0.04, 0.06), DARK))
    pigeon.append(join(name, P, (s * 0.07, 0.0, 0.19)))
export("pigeon", pigeon)

# ---------------- Собака-дворняга (смотрит в +Y; лапы, голова, хвост — с суставами) ----------------
DOG = mat("DogFur", (0.45, 0.3, 0.18), 0.85)
DOG_D = mat("DogFurDark", (0.15, 0.1, 0.07), 0.85)
DOG_L = mat("DogFurLight", (0.85, 0.75, 0.6), 0.85)
dog = []
P = [sphere(0.2, (0, 0, 0.5), DOG, scale=(0.85, 1.8, 0.85))]
P.append(sphere(0.18, (0, -0.1, 0.55), DOG_D, scale=(0.8, 0.9, 0.6)))           # тёмное пятно
P.append(sphere(0.15, (0, 0.2, 0.45), DOG_L, scale=(0.8, 1.2, 0.8)))
dog.append(join("DogBody", P, (0, 0, 0.5)))
P = [sphere(0.14, (0, 0.47, 0.72), DOG, scale=(1, 1.05, 0.95))]
P.append(sphere(0.08, (0, 0.6, 0.68), DOG_L, scale=(0.9, 1.4, 0.8)))            # морда
P.append(sphere(0.03, (0, 0.71, 0.7), DARK))
for s in (-1, 1):
    P.append(box((0.08, 0.04, 0.16), (s * 0.12, 0.44, 0.74), DOG_D, rot=(0, s * math.radians(25), 0)))
    P.append(sphere(0.022, (s * 0.06, 0.585, 0.77), DARK))
dog.append(join("DogHead", P, (0, 0.33, 0.62)))
P = [rod((0, -0.34, 0.6), (0, -0.52, 0.75), 0.035, DOG), rod((0, -0.52, 0.75), (0, -0.6, 0.72), 0.03, DOG_L)]
dog.append(join("DogTail", P, (0, -0.34, 0.6)))
for name, x, y in (("LegFL", -0.1, 0.22), ("LegFR", 0.1, 0.22), ("LegBL", -0.1, -0.22),
                   ("LegBR", 0.1, -0.22)):
    P = [cyl(0.045, 0.42, (x, y, 0.21), DOG, verts=8)]
    P.append(sphere(0.05, (x, y + 0.02, 0.03), DOG_L, scale=(1, 1.3, 0.6)))
    dog.append(join(name, P, (x, y, 0.42)))
export("dog", dog)

if RENDER:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1600, 900
    scene.world = bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.7, 0.8, 0.9, 1)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (0.7, 0.2, -0.6)
    scene.collection.objects.link(sun)
    place = {"khrushchevka": (0, 14, 0), "tree_poplar": (-12, 4, 0), "tree_birch": (12, 4, 0),
             "lamp_post": (-9, -1, 0), "gelik": (3, -3, 0), "gelik_lights": (3, -3, 0),
             "kopeyka": (-3.5, -3, 0), "barrel": (7, -2, 0), "crate": (7.8, -2.5, 0),
             "ladder": (9, 0, 0), "trash_bin": (-7.5, -3, 0), "padlock": (6, -5, 0.5),
             "pigeon": (0.5, -6, 0), "dog": (-0.5, -6, 0), "bush_round": (-10, 0, 0), "bush_wide": (10, 0, 0)}
    for name, objs in KEEP:
        for o in objs:
            o.location += Vector(place.get(name, (0, -8, 0)))
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (0, -20, 9)
    cam.rotation_euler = (Vector((0, 2, 2.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = RENDER
    bpy.ops.render.render(write_still=True)
print("DONE")
