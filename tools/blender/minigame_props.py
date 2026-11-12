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

# ---------------- Ларёк (перед смотрит в -Y Blender = +Z Godot) ----------------
W, D, H = 3.0, 2.0, 2.5
WALL = mat("KioskBlue", (0.12, 0.33, 0.55), 0.6)
FRAME = mat("KioskWhite", (0.92, 0.9, 0.84), 0.6)
ROOF = mat("KioskRoof", (0.25, 0.25, 0.27), 0.7)
SIGN = mat("KioskSign", (0.5, 0.03, 0.02), 0.5)
INNER = mat("KioskInner", (0.75, 0.68, 0.55), 0.8)
SHELF = mat("Shelf", (0.45, 0.3, 0.18), 0.7)
JAR = mat("Jar", (0.55, 0.7, 0.45), 0.2)
T = 0.08
FY = -D / 2
P = []
P.append(box((W, T, H), (0, D / 2 - T / 2, H / 2), WALL))                     # задняя стена
P.append(box((T, D - 0.02, H), (-W / 2 + T / 2, 0.01, H / 2), WALL))                    # левая
P.append(box((T, D - 0.02, H), (W / 2 - T / 2, 0.01, H / 2), WALL))                     # правая
P.append(box((W, T, 1.0), (0, FY + T / 2, 0.5), WALL))                        # низ фасада (прилавок)
P.append(box((W, T, 0.45), (0, FY + T / 2, H - 0.225), WALL))                 # над окном
P.append(box((W - 2 * T, D - 2 * T, 0.02), (0, 0, 0.01), INNER))              # пол
P.append(box((W + 0.5, D + 0.5, 0.12), (0, 0, H + 0.06), ROOF, bevel=0.03))   # крыша
P.append(box((W + 0.2, 0.08, 0.5), (0, FY - 0.15, H + 0.3), SIGN, bevel=0.02))  # вывеска
P.append(box((W + 0.1, 0.45, 0.06), (0, FY - 0.15, 1.0), FRAME, bevel=0.01))  # полка-прилавок
for x in (-W / 2 + 0.06, -0.5, 0.5, W / 2 - 0.06):                             # рамы окна
    P.append(box((0.08, 0.1, 0.98), (x, FY - 0.005, 1.53), FRAME))
P.append(box((W, 0.1, 0.07), (0, FY, 2.05), FRAME))
P.append(box((W, 0.12, 0.07), (0, FY - 0.01, 1.0), FRAME))
for z in (1.2, 1.7):                                                           # полки внутри
    P.append(box((W - 0.3, 0.3, 0.04), (0, D / 2 - 0.25, z), SHELF))
    for i in range(7):
        P.append(cyl(0.07, 0.18, (-1.1 + i * 0.36, D / 2 - 0.25, z + 0.11), JAR, verts=8))
# Колбасы висят под потолком
for i, x in enumerate([-1.0, -0.6, -0.2, 0.2, 0.6, 1.0]):
    P.append(cyl(0.006, 0.5, (x, D / 2 - 0.7, H - 0.25), STRING, verts=4))
    P.append(cyl(0.05, 0.38, (x, D / 2 - 0.7, H - 0.69), SAUSAGE, verts=8))
    P.append(sphere(0.05, (x, D / 2 - 0.7, H - 0.88), SAUSAGE, scale=(1, 1, 0.6)))
# Полосы на стенах
P.append(box((W + 0.02, D + 0.02, 0.12), (0, 0, 0.3), FRAME))
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
cam.location = (2.5, -8.5, 3.2)
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
