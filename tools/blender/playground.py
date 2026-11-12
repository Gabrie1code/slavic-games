"""Детская площадка 90-х для «Морожки»: лавочка, открытая песочница, металлическая горка, качели
(рама и сиденье отдельно), карусель (основание и крутящаяся часть отдельно), секция забора.

Начало координат — на земле. Горка лежит вдоль X: лесенка на +X, скат вниз к −X.
Качели: рама вдоль X, сиденье висит на цепях — точка подвеса в начале координат модели сиденья.

Запуск:
    python tools/blender/playground.py assets/models/playground [--render превью.png]
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
P = [box((2.8, 2.8, 0.18), (0, 0, 0.09), SAND)]
for s in (-1, 1):
    P.append(box((3.0, 0.15, 0.3), (0, s * 1.425, 0.15), WOOD))
    P.append(box((0.15, 2.7, 0.29), (s * 1.425, 0, 0.145), WOOD))
P.append(cyl(0.05, 2.0, (1.25, 1.25, 1.0), WOOD, verts=8))
P.append(cyl(0.9, 0.45, (1.25, 1.25, 2.1), RED, verts=10, r2=0.05))
for i in range(6):                                                            # белые точки на шляпке
    a = i * math.pi / 3
    P.append(cyl(0.09, 0.02, (1.25 + math.cos(a) * 0.5, 1.25 + math.sin(a) * 0.5, 2.06),
                 mat("Dot", (0.95, 0.95, 0.9), 0.6), verts=8, rot=(0, -0.45 * math.sin(a), 0.45 * math.cos(a))))
P.append(box((0.5, 0.3, 0.25), (-0.7, -0.6, 0.3), SAND))                      # куличики
P.append(cyl(0.12, 0.2, (0.5, -0.8, 0.28), BLUE, verts=8, r2=0.08))           # ведёрко
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
P = [cyl(1.3, 0.08, (0, 0, 0.3), mat("CarouselDeck", (0.5, 0.52, 0.55), 0.5, 0.6), verts=24)]
for i in range(6):                                                            # цветные сектора
    a = i * math.pi / 3
    P.append(box((1.1, 0.25, 0.01), (math.cos(a) * 0.65, math.sin(a) * 0.65, 0.345),
                 [RED, YELLOW, BLUE][i % 3], rot=(0, 0, a)))
P.append(cyl(0.06, 0.9, (0, 0, 0.75), STEEL, verts=8))
for i in range(4):                                                            # поручни
    a = i * math.pi / 2 + math.pi / 4
    x, y = math.cos(a), math.sin(a)
    P.append(rod((x * 1.1, y * 1.1, 0.34), (x * 1.1, y * 1.1, 0.95), 0.03, YELLOW))
    P.append(rod((x * 1.1, y * 1.1, 0.95), (0, 0, 1.15), 0.03, YELLOW))
bpy.ops.mesh.primitive_torus_add(major_radius=1.1, minor_radius=0.03, major_segments=24, minor_segments=5,
                                 location=(0, 0, 0.95))
P.append(flat(bpy.context.object, YELLOW))
export("carousel_top", [join("CarouselTop", P)])

# ---------------- Забор: секция 2 м (вдоль X), низкий металлический ----------------
P = [rod((-1.0, 0, 0.85), (1.0, 0, 0.85), 0.03, GREEN), rod((-1.0, 0, 0.2), (1.0, 0, 0.2), 0.03, GREEN)]
for k in range(9):
    x = -0.9 + k * 0.225
    P.append(rod((x, 0, 0.0), (x, 0, 1.0), 0.018, GREEN, verts=6))
    P.append(cyl(0.035, 0.08, (x, 0, 1.03), GREEN, verts=4, r2=0.0))
P.append(cyl(0.05, 1.1, (-1.0, 0, 0.55), GREEN, verts=8))
export("fence", [join("Fence", P)])

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
             "carousel_top": (-6, 4, 0), "fence": (2, -2, 0)}
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
