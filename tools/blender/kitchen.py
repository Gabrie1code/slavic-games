"""Кухня советской квартиры (лобби): модели в assets/models/kitchen/.
Все вещи стоят на полу (z = 0), лицом к −Y Blender (= +Z Godot), центр — посередине основания.
  kitchen_stove     — газовая плита «как у всех»: эмаль, 4 конфорки, духовка с окошком, ручки;
  kitchen_fridge    — пузатый белый холодильник со скруглённым верхом и хромированной ручкой;
  kitchen_sink      — тумба с мойкой: столешница с вырезом, стальная чаша, смеситель;
  kitchen_cabinet   — навесной шкафчик (низ — в z = 0, вешается кодом на стену);
  kitchen_table     — стол на ножках с клеёнкой (assets/textures/kitchen/oilcloth.png);
  kitchen_kettle    — эмалированный красный чайник со свистком;
  kitchen_glass     — стакан чая в подстаканнике;
  kitchen_radio     — радиоточка на стену (задняя стенка — в y = 0);
  kitchen_lamp      — абажур над столом (верх — в z = 3: крепится к потолку), лампочка KitchenBulb.
Названий брендов нет (только пародийные/без надписей).

Запуск:
    python tools/blender/kitchen.py assets/models/kitchen [--render превью.png]
"""
import math
import os
import sys

import bpy  # noqa: I001
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else "."
RENDER = sys.argv[sys.argv.index("--render") + 1] if "--render" in sys.argv else None
os.makedirs(OUT, exist_ok=True)
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
bpy.ops.wm.read_factory_settings(use_empty=True)
_mats = {}


def mat(name, color, rough=0.5, metal=0.0, emit=0.0, image=None):
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
    if image:
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(os.path.join(ROOT, image))
        m.node_tree.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    _mats[name] = m
    return m


def finish(o, m, bevel=0.0, segs=1, smooth=False):
    o.data.materials.append(m)
    if bevel:
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segs
        mod.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier="Bevel")
    for p in o.data.polygons:
        p.use_smooth = smooth
    return o


def box(size, loc, m, bevel=0.0, segs=1, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    return finish(o, m, bevel, segs)


def cyl(r, h, loc, m, verts=16, r2=None, rot=(0, 0, 0), smooth=False):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    o = bpy.context.object
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    return finish(o, m, smooth=smooth)


def sphere(r, loc, m, scale=(1, 1, 1), segs=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True, location=False)
    return finish(o, m, smooth=True)


def shell_cone(r1, r2, h, z, m_out, m_in, verts=24, thick=0.008):
    """Полый конус (абажур): стенка thick, открыт сверху и снизу, внутри — другой материал."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=h,
                                    location=(0, 0, z), end_fill_type="NOTHING")
    o = bpy.context.object
    o.data.materials.append(m_out)
    o.data.materials.append(m_in)
    mod = o.modifiers.new("S", "SOLIDIFY")
    mod.thickness = thick
    mod.offset = -1.0
    mod.material_offset = 1
    bpy.ops.object.modifier_apply(modifier="S")
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def export(name, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")                # начало — на полу, в центре
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True,
                              export_format="GLB")
    print("EXPORTED", name)
    return obj


ENAMEL = mat("Enamel", (0.92, 0.91, 0.86), 0.25)
BLACK = mat("BlackIron", (0.06, 0.06, 0.07), 0.6)
CHROME = mat("Chrome", (0.75, 0.77, 0.8), 0.15, 0.8)
GLASS_DARK = mat("OvenGlass", (0.08, 0.07, 0.06), 0.1)
BADGE = mat("BadgeRed", (0.75, 0.1, 0.08), 0.4)
CABINET = mat("CabinetCream", (0.93, 0.87, 0.68), 0.5)
CAB_EDGE = mat("CabinetEdge", (0.62, 0.45, 0.28), 0.6)
WORKTOP = mat("Worktop", (0.6, 0.62, 0.6), 0.45)
STEEL = mat("SinkSteel", (0.62, 0.64, 0.66), 0.25, 0.6)
WOOD = mat("TableWood", (0.55, 0.36, 0.2), 0.6)
OILCLOTH = mat("Oilcloth", (1, 1, 1), 0.35, image="assets/textures/kitchen/oilcloth.png")
KETTLE = mat("KettleRed", (0.72, 0.1, 0.08), 0.2)
WHITE = mat("EnamelWhite", (0.95, 0.95, 0.92), 0.25)
TEA = mat("Tea", (0.35, 0.14, 0.04), 0.1)
GLASS = mat("TeaGlass", (0.85, 0.92, 0.95), 0.05)
NICKEL = mat("Nickel", (0.7, 0.66, 0.55), 0.25, 0.7)
BAKELITE = mat("Bakelite", (0.35, 0.2, 0.12), 0.35)
IVORY = mat("Ivory", (0.9, 0.85, 0.72), 0.4)
SHADE = mat("KitchenShade", (0.85, 0.42, 0.12), 0.8)
SHADE_IN = mat("KitchenShadeInside", (1.0, 0.85, 0.6), 0.8)
BULB = mat("KitchenBulb", (1.0, 0.9, 0.6), 0.3, 0, 2.0)
CORD = mat("Cord", (0.1, 0.1, 0.1), 0.6)

# ---------------- Плита ----------------
P = [box((0.5, 0.58, 0.84), (0, 0, 0.42), ENAMEL, bevel=0.012, segs=2)]
P.append(box((0.48, 0.56, 0.012), (0, 0.005, 0.846), mat("Cooktop", (0.85, 0.84, 0.8), 0.3)))
for x in (-0.12, 0.12):
    for y in (-0.12, 0.14):
        P.append(cyl(0.055, 0.012, (x, y, 0.857), BLACK, verts=16))              # конфорка
        P.append(cyl(0.032, 0.016, (x, y, 0.86), mat("Burner", (0.25, 0.25, 0.27), 0.4, 0.5), verts=12))
        for a in (0, 90):                                                         # решётка
            P.append(box((0.15, 0.012, 0.012), (x, y, 0.872), BLACK, rot=(0, 0, math.radians(a))))
P.append(box((0.5, 0.03, 0.14), (0, 0.29, 0.92), ENAMEL, bevel=0.006))            # задний щиток
P.append(box((0.46, 0.02, 0.07), (0, -0.295, 0.79), ENAMEL))                      # панель ручек
for k in range(4):
    P.append(cyl(0.018, 0.03, (-0.15 + k * 0.1, -0.31, 0.79), BLACK, verts=12, rot=(math.radians(90), 0, 0)))
P.append(box((0.05, 0.022, 0.02), (0.19, -0.3, 0.79), BADGE))                    # шильдик
P.append(box((0.44, 0.02, 0.5), (0, -0.295, 0.42), ENAMEL, bevel=0.01))           # дверца духовки
P.append(box((0.28, 0.022, 0.16), (0, -0.3, 0.44), GLASS_DARK))                   # окошко
P.append(cyl(0.01, 0.36, (0, -0.33, 0.645), CHROME, verts=8, rot=(0, math.radians(90), 0)))
for x in (-0.17, 0.17):
    P.append(box((0.02, 0.04, 0.02), (x, -0.315, 0.645), CHROME))
P.append(box((0.46, 0.02, 0.1), (0, -0.295, 0.08), mat("Plinth", (0.3, 0.3, 0.32), 0.6)))
export("kitchen_stove", P)

# ---------------- Холодильник ----------------
P = [box((0.6, 0.6, 1.5), (0, 0.01, 0.75), ENAMEL, bevel=0.07, segs=4)]
P.append(box((0.58, 0.04, 1.36), (0, -0.29, 0.79), ENAMEL, bevel=0.05, segs=4))  # дверь
P.append(box((0.03, 0.06, 0.26), (0.22, -0.33, 1.0), CHROME, bevel=0.01, segs=2))  # ручка-рычаг
P.append(box((0.22, 0.012, 0.03), (0, -0.312, 1.36), CHROME, bevel=0.004))       # хромовая полоса
P.append(box((0.5, 0.02, 0.08), (0, -0.28, 0.06), mat("FridgeGrille", (0.35, 0.35, 0.37), 0.5)))
export("kitchen_fridge", P)

# ---------------- Тумба с мойкой ----------------
P = [box((1.0, 0.56, 0.82), (0, 0.02, 0.41), CABINET, bevel=0.006)]
for x in (-0.25, 0.25):
    P.append(box((0.47, 0.02, 0.66), (x, -0.265, 0.45), CABINET, bevel=0.008))
    P.append(box((0.02, 0.025, 0.12), (x + (0.18 if x < 0 else -0.18), -0.285, 0.62), CAB_EDGE))
P.append(box((0.96, 0.02, 0.08), (0, -0.255, 0.05), CAB_EDGE))                   # цоколь
# Столешница вокруг выреза под чашу (чаша: x −0.36..0.06, y −0.2..0.16).
SX0, SX1, SY0, SY1 = -0.36, 0.06, -0.2, 0.16
TZ = 0.845
P.append(box((SX0 + 0.51, 0.62, 0.03), ((SX0 - 0.51) / 2, 0.0, TZ), WORKTOP))
P.append(box((0.51 - SX1, 0.62, 0.03), ((SX1 + 0.51) / 2, 0.0, TZ), WORKTOP))
P.append(box((SX1 - SX0, SY0 + 0.31, 0.03), ((SX0 + SX1) / 2, (SY0 - 0.31) / 2, TZ), WORKTOP))
P.append(box((SX1 - SX0, 0.31 - SY1, 0.03), ((SX0 + SX1) / 2, (SY1 + 0.31) / 2, TZ), WORKTOP))
# Чаша: дно и стенки из стали, ниже столешницы.
P.append(box((SX1 - SX0, SY1 - SY0, 0.01), ((SX0 + SX1) / 2, (SY0 + SY1) / 2, 0.69), STEEL))
for x in (SX0 + 0.005, SX1 - 0.005):
    P.append(box((0.01, SY1 - SY0, 0.16), (x, (SY0 + SY1) / 2, 0.77), STEEL))
for y in (SY0 + 0.005, SY1 - 0.005):
    P.append(box((SX1 - SX0, 0.01, 0.16), ((SX0 + SX1) / 2, y, 0.77), STEEL))
P.append(cyl(0.022, 0.004, ((SX0 + SX1) / 2, 0.0, 0.697), BLACK, verts=12))     # слив
# Смеситель: стойка сзади, «гусак» вперёд, два вентиля.
TX = (SX0 + SX1) / 2
P.append(cyl(0.016, 0.2, (TX, 0.24, 0.96), CHROME, verts=12))
P.append(cyl(0.012, 0.2, (TX, 0.14, 1.06), CHROME, verts=12, rot=(math.radians(90), 0, 0)))
P.append(cyl(0.012, 0.05, (TX, 0.045, 1.04), CHROME, verts=12))
for dx in (-0.07, 0.07):
    P.append(cyl(0.01, 0.06, (TX + dx, 0.24, 0.89), CHROME, verts=8))
    P.append(box((0.05, 0.012, 0.012), (TX + dx, 0.24, 0.925), CHROME))
export("kitchen_sink", P)

# ---------------- Навесной шкафчик ----------------
P = [box((1.0, 0.3, 0.6), (0, 0.0, 0.3), CABINET, bevel=0.006)]
for x in (-0.25, 0.25):
    P.append(box((0.47, 0.02, 0.56), (x, -0.155, 0.3), CABINET, bevel=0.008))
    P.append(box((0.02, 0.025, 0.1), (x + (0.18 if x < 0 else -0.18), -0.175, 0.1), CAB_EDGE))
P.append(box((1.02, 0.32, 0.02), (0, 0.0, 0.61), CAB_EDGE))                      # карниз
export("kitchen_cabinet", P)

# ---------------- Стол с клеёнкой ----------------
def cloth(size, loc):
    """Кусок клеёнки: клетка мельче (UV ×4 — иначе на весь стол 2×2 огромные клетки)."""
    o = box(size, loc, OILCLOTH)
    for loop in o.data.uv_layers.active.data:
        loop.uv = loop.uv * 4.0
    return o


P = [cloth((1.0, 0.7, 0.03), (0, 0, 0.735))]
for x in (-0.505, 0.505):                                                          # свес по бокам
    P.append(cloth((0.012, 0.72, 0.09), (x, 0, 0.7)))
for y in (-0.355, 0.355):
    P.append(cloth((1.022, 0.012, 0.09), (0, y, 0.7)))
P.append(box((0.92, 0.62, 0.06), (0, 0, 0.69), WOOD))                             # царга
for x in (-0.44, 0.44):
    for y in (-0.29, 0.29):
        P.append(box((0.045, 0.045, 0.69), (x, y, 0.345), WOOD))
export("kitchen_table", P)

# ---------------- Чайник ----------------
P = [cyl(0.095, 0.13, (0, 0, 0.065), KETTLE, verts=24, r2=0.07, smooth=True)]
P.append(cyl(0.07, 0.02, (0, 0, 0.14), KETTLE, verts=24, r2=0.05, smooth=True))
P.append(sphere(0.016, (0, 0, 0.158), BLACK))
P.append(cyl(0.022, 0.13, (0, -0.11, 0.1), KETTLE, verts=12, r2=0.009,
             rot=(math.radians(-55), 0, 0), smooth=True))                         # носик
P.append(cyl(0.006, 0.02, (0, -0.165, 0.142), BLACK, verts=8, rot=(math.radians(-55), 0, 0)))
for y0, y1 in ((0.06, 0.06), (-0.04, -0.04)):
    P.append(cyl(0.007, 0.08, (0, y0, 0.18), BLACK, verts=8))                      # стойки ручки
P.append(cyl(0.009, 0.12, (0, 0.01, 0.22), BLACK, verts=8, rot=(math.radians(90), 0, 0)))
for k in range(5):                                                                 # белые горошины
    a = math.radians(30 + k * 72)
    P.append(sphere(0.012, (0.088 * math.cos(a), 0.088 * math.sin(a), 0.06), WHITE, scale=(1, 1, 0.5)))
export("kitchen_kettle", P)

# ---------------- Стакан в подстаканнике ----------------
P = [cyl(0.032, 0.11, (0, 0, 0.065), GLASS, verts=16)]
P.append(cyl(0.029, 0.08, (0, 0, 0.055), TEA, verts=16))
P.append(cyl(0.036, 0.075, (0, 0, 0.045), NICKEL, verts=16, r2=0.034))
P.append(cyl(0.024, 0.01, (0, 0, 0.005), NICKEL, verts=16))
bpy.ops.mesh.primitive_torus_add(major_radius=0.022, minor_radius=0.004, major_segments=16,
                                 minor_segments=6, location=(0.05, 0, 0.05), rotation=(math.radians(90), 0, 0))
P.append(finish(bpy.context.object, NICKEL))
P.append(box((0.003, 0.004, 0.12), (0.012, 0.0, 0.115), NICKEL, rot=(0, math.radians(-12), 0)))  # ложечка
export("kitchen_glass", P)

# ---------------- Радиоточка ----------------
P = [box((0.24, 0.08, 0.16), (0, -0.04, 0.08), IVORY, bevel=0.012, segs=2)]
P.append(box((0.15, 0.01, 0.1), (-0.03, -0.083, 0.08), BAKELITE))
for k in range(6):
    P.append(box((0.13, 0.012, 0.006), (-0.03, -0.086, 0.04 + k * 0.016), IVORY))
P.append(cyl(0.018, 0.02, (0.085, -0.088, 0.08), BAKELITE, verts=12, rot=(math.radians(90), 0, 0)))
P.append(cyl(0.004, 0.2, (0.1, -0.02, -0.1), CORD, verts=6))                      # провод вниз
export("kitchen_radio", P)

# ---------------- Абажур над столом ----------------
P = [cyl(0.005, 0.6, (0, 0, 2.7), CORD, verts=6)]                                  # шнур
P.append(cyl(0.04, 0.012, (0, 0, 2.994), IVORY, verts=12))                         # розетка на потолке
P.append(shell_cone(0.3, 0.1, 0.22, 2.31, SHADE, SHADE_IN))
for k in range(36):                                                                # бахрома
    a = 2 * math.pi * k / 36
    P.append(box((0.008, 0.008, 0.06), (0.298 * math.cos(a), 0.298 * math.sin(a), 2.17), SHADE))
P.append(cyl(0.025, 0.05, (0, 0, 2.39), BAKELITE, verts=12))                       # патрон
P.append(sphere(0.05, (0, 0, 2.33), BULB))
export("kitchen_lamp", P)

print("DONE")
if not RENDER:
    sys.exit(0)

# ---------------- Превью ----------------
layout = {"kitchen_fridge": (-1.6, 0), "kitchen_stove": (-0.95, 0), "kitchen_sink": (-0.1, 0),
          "kitchen_table": (1.3, -0.3), "kitchen_lamp": (1.3, -0.3)}
for o in list(bpy.context.scene.objects):
    if o.name in layout:
        o.location = (*layout[o.name], 0)  # начало моделей — на полу
    elif o.name == "kitchen_cabinet":
        o.location = (-0.1, 0.12, 1.45)
    elif o.name == "kitchen_kettle":
        o.location = (-1.07, -0.12, 0.88)
    elif o.name == "kitchen_glass":
        o.location = (1.1, -0.4, 0.75)
    elif o.name == "kitchen_radio":
        o.location = (0.8, 0.3, 1.4)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.samples = 32
sc.render.resolution_x, sc.render.resolution_y = 1200, 700
w = bpy.data.worlds.new("W")
sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[1].default_value = 1.2
bpy.ops.mesh.primitive_plane_add(size=12)
sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(45), 0, math.radians(25))
sc.collection.objects.link(sun)
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.location = (0.0, -4.2, 2.0)
cam.rotation_euler = (Vector((0.0, 0, 0.9)) - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 28
sc.render.filepath = RENDER
bpy.ops.render.render(write_still=True)
