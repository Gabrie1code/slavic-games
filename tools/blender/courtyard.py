"""Двор 90-х: хрущёвка, деревья, фонарь, «гелик» (без эмблем) и его фары отдельно, «копейка» на кирпичах,
бочка, ящик, лестница, мусорный бак, замок, голубь и собака (части с суставами).

Здания и машины смотрят «лицом» в −Y Blender (= к камере, +Z в Godot). Голубь и собака смотрят в +Y
Blender (= вперёд, −Z в Godot), как персонажи. Начало координат — на земле.

Запуск:
    python tools/blender/courtyard.py assets/models/courtyard [--render превью.png]
"""
import bpy, math, sys, os, random
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


def mat(name, color, rough=0.6, metal=0.0, emit=0.0):
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
    [(0.9, 0.2, 0.2), (0.95, 0.95, 0.9), (0.25, 0.45, 0.85), (0.95, 0.8, 0.2), (0.4, 0.75, 0.4)])]
cols = 12
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
            P.append(box((0.06, 0.1, 1.2), (x, y, z), FRAME))
        # Балконы на лицевой стороне через окно, начиная со 2-го этажа.
        if f >= 1 and c % 2 == 1:
            y = -D / 2 - 0.55
            P.append(box((2.0, 1.1, 0.12), (x + 0.3, y, z - 1.0), SEAM))
            P.append(box((2.0, 0.05, 0.95), (x + 0.3, y - 0.53, z - 0.5), PANEL))
            for s in (-1, 1):
                P.append(box((0.05, 1.1, 0.95), (x + 0.3 + s * 0.98, y, z - 0.5), PANEL))
            if random.random() < 0.5:                                              # бельё на верёвке
                P.append(rod((x - 0.6, y - 0.45, z + 0.6), (x + 1.2, y - 0.45, z + 0.6), 0.01, WHITE, verts=4))
                for k in range(random.randint(2, 4)):
                    P.append(box((0.3, 0.02, random.uniform(0.3, 0.6)),
                                 (x - 0.4 + k * 0.45, y - 0.45, z + 0.35), random.choice(LAUNDRY)))
            if random.random() < 0.3:                                              # тарелка
                P.append(cyl(0.32, 0.12, (x + 1.1, y - 0.6, z + 0.1), METAL, verts=12, r2=0.05,
                             rot=(math.radians(-70), 0, math.radians(20))))
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
P = [box((1.5, 1.0, 1.0), (0, 0, 0.6), BIN)]
P.append(box((1.55, 1.05, 0.08), (0, 0.05, 1.14), mat("BinLid", (0.15, 0.3, 0.2), 0.7, 0.3),
             rot=(math.radians(-8), 0, 0)))
for x in (-0.55, 0.55):
    for y in (-0.35, 0.35):
        P.append(cyl(0.07, 0.06, (x, y, 0.07), DARK, verts=8, rot=(math.pi / 2, 0, 0)))
P.append(box((1.0, 0.02, 0.25), (0, -0.51, 0.75), mat("BinStripe", (0.95, 0.85, 0.2), 0.6)))
for k in range(3):                                                               # мусор сверху
    P.append(box((0.3, 0.25, 0.2), (-0.4 + k * 0.4, 0.1, 1.2 + k * 0.03),
                 random.choice([WHITE, mat("Bag", (0.1, 0.1, 0.1), 0.4)]), rot=(0, 0, k)))
export("trash_bin", [join("TrashBin", P)])
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
             "pigeon": (0.5, -6, 0), "dog": (-0.5, -6, 0)}
    for name, objs in KEEP:
        for o in objs:
            o.location += Vector(place[name])
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (0, -20, 9)
    cam.rotation_euler = (Vector((0, 2, 2.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = RENDER
    bpy.ops.render.render(write_still=True)
print("DONE")
