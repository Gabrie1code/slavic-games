"""Кухня советской квартиры (лобби): модели в assets/models/kitchen/.
Все вещи стоят на полу (z = 0), лицом к −Y Blender (= +Z Godot), центр — посередине основания.
  kitchen_stove     — газовая плита «как у всех»: эмаль, 4 конфорки, духовка с окошком, ручки;
  kitchen_fridge    — пузатый белый холодильник со скруглённым верхом и хромированной ручкой;
  kitchen_sink      — тумба с мойкой: глубокая стальная чаша с сеточкой слива, смеситель;
                      отдельные объекты TapHot / TapCold / SinkWater (как у рукомойника Sink);
  kitchen_cabinet   — навесной шкафчик (низ — в z = 0), полый: внутри стопки и батон;
  kitchen_cabinet_door — его правая дверца (начало — на петле), открывается в игре;
  kitchen_window    — рама окна 1.0 × 1.1 с подоконником;
  kitchen_table     — стол на ножках с клеёнкой (assets/textures/kitchen/oilcloth.png);
  kitchen_kettle    — эмалированный красный чайник со свистком;
  kitchen_bottle    — тёмно-зелёная бутылка (без надписей);
  kitchen_tumbler / kitchen_tumbler_wine — гранёный стакан, пустой / с тёмно-бордовым;
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
import bmesh
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


def join(name, parts, origin=(0, 0, 0)):
    """Склеить части в один объект name с началом в точке origin (для подвижных частей —
    на оси вращения / в центре)."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.context.scene.cursor.location = origin
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return obj


def export_objects(name, objs):
    """Несколько отдельных объектов (с именами) — в один .glb: в игре их находят по имени."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True,
                              export_format="GLB")
    print("EXPORTED", name)


def tube_pts(pts, radius, m, taper=None):
    """Гладкая трубка по точкам с сужением (taper — доли радиуса по точкам)."""
    curve = bpy.data.curves.new("T", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 4
    spline = curve.splines.new("NURBS")
    spline.points.add(len(pts) - 1)
    for k, (p, pt) in enumerate(zip(spline.points, pts)):
        p.co = (*pt, 1)
        p.radius = taper[k] if taper else 1.0
    spline.use_endpoint_u = True
    spline.order_u = 3
    o = bpy.data.objects.new("T", curve)
    bpy.context.scene.collection.objects.link(o)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.object
    o.data.materials.clear()
    return finish(o, m, smooth=True)


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
KETTLE = mat("KettleRed", (0.85, 0.24, 0.07), 0.12)                # оранжево-красная эмаль
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
# Духовка полая: внутри тёмная эмаль, решётка, стеклянное блюдо с запечённой курицей и лампочка
# OvenBulb. Дверца — отдельная модель kitchen_oven_door (петля снизу), откидывается вниз.
OVEN_IN = mat("OvenInside", (0.16, 0.16, 0.18), 0.4)
DISH = mat("DishGlass", (0.75, 0.88, 0.92), 0.05)
CHICKEN = mat("RoastChicken", (0.45, 0.13, 0.04), 0.25)
CHICKEN_DARK = mat("RoastCrust", (0.16, 0.04, 0.015), 0.35)
BONE = mat("Bone", (0.95, 0.92, 0.84), 0.5)
OVEN_BULB = mat("OvenBulb", (1.0, 0.85, 0.5), 0.3, 0, 2.0)
OZ0, OZ1 = 0.17, 0.67                                                              # проём духовки
P = [box((0.5, 0.03, 0.84), (0, 0.275, 0.42), ENAMEL)]                              # задняя стенка
for x in (-0.24, 0.24):
    P.append(box((0.02, 0.58, 0.84), (x, 0.0, 0.42), ENAMEL, bevel=0.006))         # бока
P.append(box((0.5, 0.58, OZ0), (0, 0.0, OZ0 / 2), ENAMEL, bevel=0.006))           # низ
P.append(box((0.5, 0.58, 0.84 - OZ1), (0, 0.0, (OZ1 + 0.84) / 2), ENAMEL, bevel=0.006))  # верх
# Внутри духовки — тёмная эмаль.
P.append(box((0.46, 0.01, OZ1 - OZ0), (0, 0.255, (OZ0 + OZ1) / 2), OVEN_IN))
for x in (-0.225, 0.225):
    P.append(box((0.01, 0.53, OZ1 - OZ0), (x, -0.01, (OZ0 + OZ1) / 2), OVEN_IN))
for z in (OZ0 + 0.005, OZ1 - 0.005):
    P.append(box((0.46, 0.53, 0.01), (0, -0.01, z), OVEN_IN))
for k in range(9):                                                                 # решётка
    P.append(box((0.44, 0.006, 0.006), (0, -0.23 + k * 0.058, 0.3), CHROME))
for x in (-0.2, 0.2):
    P.append(box((0.006, 0.5, 0.006), (x, -0.01, 0.3), CHROME))
# Стеклянное блюдо (овальное) и курица.
bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=1.0, depth=1.0, location=(0, 0.0, 0.32))
dish = bpy.context.object
dish.scale = (0.15, 0.11, 0.03)
bpy.ops.object.transform_apply(scale=True, location=False)
P.append(finish(dish, DISH, smooth=True))
# Курица как на фото владельца: пухлая тушка (грудка выше и шире к хвосту, низ плоский),
# толстые окорочка по бокам, ножки торчат вверх-назад и сужаются к тёмным косточкам, крылышки
# прижаты к бокам, корочка красно-коричневая с подпалинами (несколько тёмных пятен).
CX, CY, CZ = 0.0, 0.01, 0.335                                          # низ тушки (на блюде)
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=18, radius=1.0, location=(CX, CY, CZ))
body = bpy.context.object
for v in body.data.vertices:
    x, y, z = v.co
    wide = 1.0 + 0.18 * x                                              # к хвосту (+x) шире
    v.co = Vector((x * 0.125, y * 0.085 * wide, max(z, -0.35) * 0.075 * (1.0 + 0.12 * (1 - abs(y)))))
    v.co.z += 0.075 * 0.35                                              # плоский низ — на z = CZ
bpy.ops.object.shade_smooth()
P.append(finish(body, CHICKEN, smooth=True))
for (dx, dy, sx, sy) in ((0.02, 0.0, 0.06, 0.035), (0.06, 0.025, 0.025, 0.02), (-0.03, -0.03, 0.03, 0.02),
                         (0.07, -0.03, 0.02, 0.015)):                    # подпалины
    P.append(sphere(1.0, (CX + dx, CY + dy, CZ + 0.072), CHICKEN_DARK, scale=(sx, sy, 0.012)))
for side in (-1, 1):
    y = CY + side * 0.06
    P.append(sphere(1.0, (CX - 0.06, y, CZ + 0.04), CHICKEN, scale=(0.055, 0.035, 0.04)))  # окорочок
    P.append(tube_pts([(CX - 0.085, y, CZ + 0.055), (CX - 0.12, y * 0.8, CZ + 0.085),
                       (CX - 0.14, y * 0.7, CZ + 0.11)], 0.022, CHICKEN, [1.0, 0.7, 0.35]))  # голень
    P.append(sphere(0.011, (CX - 0.142, y * 0.7, CZ + 0.115), CHICKEN_DARK, scale=(1, 1, 1.2)))  # косточка
    P.append(sphere(1.0, (CX + 0.04, CY + side * 0.075, CZ + 0.045), CHICKEN_DARK,
                    scale=(0.045, 0.012, 0.025)))                         # крылышко
P.append(sphere(0.022, (0.17, 0.2, OZ1 - 0.04), OVEN_BULB))                         # лампочка
# Варочная поверхность, щиток, ручки (как было).
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
P.append(box((0.46, 0.02, 0.1), (0, -0.295, 0.08), mat("Plinth", (0.3, 0.3, 0.32), 0.6)))
export("kitchen_stove", P)
# Дверца духовки: петля — нижний передний край (z = OZ0 − 0.005, y = −0.3), откидывается вниз.
# Дверца перекрывает проём с запасом (0.48 × 0.51) — раньше по краям были щели внутрь.
# Задняя грань дверцы — на 5 мм впереди корпуса (раньше совпадала с ним и мерцала полосами).
# Дверца выше проёма на 2.5 см сверху: в щель 5 мм между дверцей и корпусом сверху раньше
# было видно освещённую духовку.
P = [box((0.48, 0.02, OZ1 - OZ0 + 0.03), (0, -0.305, (OZ0 + OZ1) / 2 + 0.01), ENAMEL, bevel=0.006),
     box((0.28, 0.022, 0.16), (0, -0.31, 0.44), GLASS_DARK),                          # окошко
     cyl(0.01, 0.36, (0, -0.335, 0.645), CHROME, verts=8, rot=(0, math.radians(90), 0))]
for x in (-0.17, 0.17):
    P.append(box((0.02, 0.04, 0.02), (x, -0.32, 0.645), CHROME))
for o in P:
    o.location -= Vector((0, -0.305, OZ0 - 0.005))
    bpy.context.view_layer.update()
export("kitchen_oven_door", P)

# ---------------- Холодильник ----------------
P = [box((0.6, 0.6, 1.5), (0, 0.01, 0.75), ENAMEL, bevel=0.07, segs=4)]
P.append(box((0.58, 0.04, 1.36), (0, -0.29, 0.79), ENAMEL, bevel=0.05, segs=4))  # дверь
P.append(box((0.03, 0.06, 0.26), (0.22, -0.33, 1.0), CHROME, bevel=0.01, segs=2))  # ручка-рычаг
P.append(box((0.22, 0.012, 0.03), (0, -0.312, 1.36), CHROME, bevel=0.004))       # хромовая полоса
P.append(box((0.5, 0.02, 0.08), (0, -0.28, 0.06), mat("FridgeGrille", (0.35, 0.35, 0.37), 0.5)))
export("kitchen_fridge", P)

# ---------------- Тумба с мойкой ----------------
# Как рукомойник в туалете (Sink): отдельные объекты TapHot / TapCold (вентили, крутятся вокруг
# вертикальной оси), SinkWater (вода, поднимается в чаше) и KitchenSinkBody (всё остальное).
RED_CAP = mat("TapRed", (0.85, 0.1, 0.08), 0.3)
BLUE_CAP = mat("TapBlue", (0.1, 0.3, 0.85), 0.3)
WATER = mat("SinkWater", (0.55, 0.75, 0.9), 0.05)
# Корпус тумбы — до 0.62, выше только стенки по краям: раньше сплошной корпус доходил до 0.82
# и «заливал» чашу изнутри — дно казалось у самого верха, слива не было видно.
P = [box((1.0, 0.56, 0.62), (0, 0.02, 0.31), CABINET, bevel=0.006)]
P.append(box((1.0, 0.02, 0.21), (0, -0.25, 0.725), CABINET))
P.append(box((1.0, 0.02, 0.21), (0, 0.29, 0.725), CABINET))
for x in (-0.49, 0.49):
    P.append(box((0.02, 0.56, 0.21), (x, 0.02, 0.725), CABINET))
for x in (-0.25, 0.25):
    P.append(box((0.47, 0.02, 0.66), (x, -0.265, 0.45), CABINET, bevel=0.008))
    P.append(box((0.02, 0.025, 0.12), (x + (0.18 if x < 0 else -0.18), -0.285, 0.62), CAB_EDGE))
P.append(box((0.96, 0.02, 0.08), (0, -0.255, 0.05), CAB_EDGE))                   # цоколь
# Столешница вокруг выреза под чашу (чаша: x −0.36..0.06, y −0.2..0.16).
SX0, SX1, SY0, SY1 = -0.36, 0.06, -0.2, 0.16
TZ = 0.845
BOTTOM = 0.64                                                                      # дно чаши (глубже)
P.append(box((SX0 + 0.51, 0.62, 0.03), ((SX0 - 0.51) / 2, 0.0, TZ), WORKTOP))
P.append(box((0.51 - SX1, 0.62, 0.03), ((SX1 + 0.51) / 2, 0.0, TZ), WORKTOP))
P.append(box((SX1 - SX0, SY0 + 0.31, 0.03), ((SX0 + SX1) / 2, (SY0 - 0.31) / 2, TZ), WORKTOP))
P.append(box((SX1 - SX0, 0.31 - SY1, 0.03), ((SX0 + SX1) / 2, (SY1 + 0.31) / 2, TZ), WORKTOP))
# Чаша: дно и стенки из стали, ниже столешницы (глубина 20 см).
DEEP = TZ - BOTTOM
P.append(box((SX1 - SX0, SY1 - SY0, 0.01), ((SX0 + SX1) / 2, (SY0 + SY1) / 2, BOTTOM), STEEL))
for x in (SX0 + 0.005, SX1 - 0.005):
    P.append(box((0.01, SY1 - SY0, DEEP), (x, (SY0 + SY1) / 2, BOTTOM + DEEP / 2), STEEL))
for y in (SY0 + 0.005, SY1 - 0.005):
    P.append(box((SX1 - SX0, 0.01, DEEP), ((SX0 + SX1) / 2, y, BOTTOM + DEEP / 2), STEEL))
# Слив с сеточкой-фильтром: тёмная дыра, хромированное кольцо, решётка из прутиков.
DX, DY = (SX0 + SX1) / 2, (SY0 + SY1) / 2
P.append(cyl(0.032, 0.004, (DX, DY, BOTTOM + 0.006), BLACK, verts=20))
bpy.ops.mesh.primitive_torus_add(major_radius=0.032, minor_radius=0.004, major_segments=20,
                                 minor_segments=6, location=(DX, DY, BOTTOM + 0.009))
P.append(finish(bpy.context.object, CHROME))
for k in range(-2, 3):
    P.append(box((0.004, 0.058 - abs(k) * 0.012, 0.003), (DX + k * 0.011, DY, BOTTOM + 0.01), CHROME))
P.append(box((0.058, 0.004, 0.003), (DX, DY, BOTTOM + 0.011), CHROME))
# Смеситель: стойка сзади, «гусак» вперёд.
TX = DX
P.append(cyl(0.016, 0.2, (TX, 0.24, 0.96), CHROME, verts=12))
P.append(cyl(0.012, 0.2, (TX, 0.14, 1.06), CHROME, verts=12, rot=(math.radians(90), 0, 0)))
P.append(cyl(0.012, 0.05, (TX, 0.045, 1.04), CHROME, verts=12))
for dx in (-0.07, 0.07):
    P.append(cyl(0.01, 0.04, (TX + dx, 0.24, 0.88), CHROME, verts=8))           # ножки вентилей
body = join("KitchenSinkBody", P)


def tap(name, dx, cap):
    """Вентиль-«крестовина» с цветной меткой сверху (красная — горячая, синяя — холодная)."""
    x = TX + dx
    parts = [cyl(0.009, 0.03, (x, 0.24, 0.915), CHROME, verts=8),
             box((0.06, 0.012, 0.012), (x, 0.24, 0.93), CHROME),
             box((0.012, 0.06, 0.012), (x, 0.24, 0.93), CHROME),
             cyl(0.011, 0.008, (x, 0.24, 0.94), cap, verts=12)]
    return join(name, parts, origin=(x, 0.24, 0.9))


hot = tap("TapHot", -0.07, RED_CAP)
cold = tap("TapCold", 0.07, BLUE_CAP)
water = box((SX1 - SX0 - 0.012, SY1 - SY0 - 0.012, 0.006), (DX, DY, BOTTOM + 0.02), WATER)
water = join("SinkWater", [water], origin=(DX, DY, BOTTOM + 0.02))
export_objects("kitchen_sink", [body, hot, cold, water])

# ---------------- Навесной шкафчик ----------------
# Полый: левая дверца — часть корпуса, правая — отдельная модель kitchen_cabinet_door (петля —
# справа), открывается. В правой половине: наверху стопки-стаканчики, внизу — батон (не трогаются).
GLASS_CUP = mat("CupGlass", (0.8, 0.9, 0.93), 0.05)
BREAD = mat("Bread", (0.5, 0.24, 0.07), 0.6)                     # румяная корочка
CRUST = mat("BreadCut", (0.8, 0.55, 0.25), 0.8)                   # светлый мякиш в надрезе
INSIDE = mat("CabinetInside", (0.85, 0.8, 0.62), 0.6)
P = [box((1.0, 0.02, 0.6), (0, 0.14, 0.3), INSIDE)]                                # задняя стенка
for x in (-0.49, 0.49):
    P.append(box((0.02, 0.3, 0.6), (x, 0.0, 0.3), CABINET))                       # бока
for z in (0.01, 0.59):
    P.append(box((1.0, 0.3, 0.02), (0, 0.0, z), CABINET))                        # дно и верх
P.append(box((0.02, 0.28, 0.58), (0.0, 0.0, 0.3), CABINET))                       # перегородка
P.append(box((0.47, 0.27, 0.015), (0.245, 0.005, 0.3), INSIDE))                   # полка справа
P.append(box((0.484, 0.02, 0.56), (-0.248, -0.155, 0.3), CABINET, bevel=0.008))  # левая дверца (до середины)
P.append(box((0.02, 0.025, 0.1), (-0.07, -0.175, 0.1), CAB_EDGE))
P.append(box((1.02, 0.32, 0.02), (0, 0.0, 0.61), CAB_EDGE))                      # карниз
for k in range(4):                                                                 # стопки
    x = 0.08 + k * 0.1
    P.append(cyl(0.022, 0.07, (x, 0.0, 0.3075 + 0.035), GLASS_CUP, verts=8, r2=0.026))
# Батон как на фото владельца: гладкий, вытянутый, к концам сужается, низ плоский; надрезы —
# светлые вдавленные косые полоски по верху (раньше торчали белые «палочки»).
LX, LY, LZ = 0.245, 0.0, 0.02                                  # центр низа батона (на дне шкафчика)
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1.0, location=(LX, LY, LZ))
loaf = bpy.context.object
for v in loaf.data.vertices:
    xn = v.co.x
    taper = 1.0 - 0.18 * xn * xn                                   # концы уже середины
    v.co.x *= 0.16
    v.co.y *= 0.062 * taper
    v.co.z = (v.co.z * 0.062 * taper if v.co.z > 0 else v.co.z * 0.012) + 0.012
P.append(finish(loaf, BREAD, smooth=True))
for k in range(4):
    dx = -0.09 + k * 0.06
    xn = dx / 0.16
    top = 0.012 + 0.062 * (1.0 - 0.18 * xn * xn) * math.sqrt(max(0.0, 1.0 - xn * xn))
    cut = sphere(1.0, (LX + dx, LY, LZ + top - 0.0035), CRUST, scale=(0.032, 0.0075, 0.006), segs=12, rings=8)
    cut.rotation_euler = (0, 0, math.radians(55))
    bpy.context.view_layer.objects.active = cut
    bpy.ops.object.transform_apply(rotation=True, location=False, scale=False)
    P.append(cut)
export("kitchen_cabinet", P)
# Правая дверца: петля — правый край (x = 0.49, y = −0.155), открывается наружу.
P = [box((0.484, 0.02, 0.56), (0.248, -0.155, 0.3), CABINET, bevel=0.008),       # без щели посередине
     box((0.02, 0.025, 0.1), (0.07, -0.175, 0.1), CAB_EDGE)]
for o in P:
    o.location -= Vector((0.49, -0.155, 0.0))
    bpy.context.view_layer.update()
export("kitchen_cabinet_door", P)

# ---------------- Окно ----------------
# Рама окна под проём 1.0 × 1.1 (низ — z = 0): по контуру, стойка посередине, форточки сверху,
# подоконник в комнату. Рама — в плоскости стены (y = 0), подоконник выступает к −Y.
FRAME = mat("WindowFrame", (0.95, 0.94, 0.9), 0.5)
W, H = 1.0, 1.1
P = [box((W, 0.1, 0.06), (0, 0, 0.03), FRAME), box((W, 0.1, 0.06), (0, 0, H - 0.03), FRAME)]
for x in (-W / 2 + 0.03, 0.0, W / 2 - 0.03):
    P.append(box((0.06, 0.1, H), (x, 0, H / 2), FRAME))
P.append(box((W, 0.08, 0.05), (0, 0, H - 0.3), FRAME))                           # форточки
P.append(box((W + 0.2, 0.15, 0.04), (0, -0.095, 0.0), FRAME, bevel=0.006))       # подоконник (узкий)
export("kitchen_window", P)

# ---------------- Стол с клеёнкой ----------------
# Столешница — дерево, сверху клеёнка (только сверху), по кромке — тонкая красная полоса
# (раньше клеёнка свисала по бокам, и на торцах была «шахматная доска»).
# Цвет — как красная клетка клеёнки (196, 40, 36 в sRGB → линейный цвет Blender).
HEM = mat("OilclothHem", (0.55, 0.021, 0.017), 0.35)
P = [box((1.0, 0.7, 0.03), (0, 0, 0.735), WOOD)]
bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0, 0.7505))
top = bpy.context.object
top.scale = (1.0, 0.7, 1.0)
bpy.ops.object.transform_apply(scale=True, location=False)
for loop in top.data.uv_layers.active.data:
    loop.uv = Vector((loop.uv.x * 1.25, loop.uv.y * 0.875))                    # клетка ~8 см
P.append(finish(top, OILCLOTH))
for y in (-0.351, 0.351):
    P.append(box((1.004, 0.004, 0.012), (0, y, 0.744), HEM))
for x in (-0.501, 0.501):
    P.append(box((0.004, 0.706, 0.012), (x, 0, 0.744), HEM))
P.append(box((0.92, 0.62, 0.06), (0, 0, 0.69), WOOD))                             # царга
for x in (-0.44, 0.44):
    for y in (-0.29, 0.29):
        P.append(box((0.045, 0.045, 0.69), (x, y, 0.345), WOOD))
export("kitchen_table", P)

# ---------------- Чайник ----------------
# Эмалированный чайник как на фото владельца: широкий низ с ободком, купол, крышка с чёрной
# кнопкой, изогнутый носик-«гусак», проволочная ручка с чёрной рукояткой поверх.
CHROME_WIRE = mat("KettleWire", (0.85, 0.86, 0.88), 0.15, 0.9)


def lathe(name, profile, m, segs=32, caps=True):
    """Тело вращения вокруг Z: profile — [(радиус, высота)]; caps — закрыть низ и верх."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / segs),
                                    r * math.sin(2 * math.pi * i / segs), z)) for i in range(segs)])
    for k in range(len(rings) - 1):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    if caps:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return finish(o, m, smooth=True)


def tube(name, pts, radius, m, taper=None):
    """Изогнутая трубка по точкам (носик, проволока); taper — радиусы по точкам (доли)."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 4
    spline = curve.splines.new("NURBS")
    spline.points.add(len(pts) - 1)
    for k, (p, pt) in enumerate(zip(spline.points, pts)):
        p.co = (*pt, 1)
        p.radius = taper[k] if taper else 1.0
    spline.use_endpoint_u = True
    spline.order_u = 3
    o = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.object
    o.data.materials.clear()
    return finish(o, m, smooth=True)


P = [lathe("KettleBody", [(0.001, 0.0), (0.094, 0.0), (0.096, 0.004), (0.096, 0.042),
                          (0.092, 0.046), (0.095, 0.05), (0.097, 0.075), (0.093, 0.11),
                          (0.08, 0.14), (0.062, 0.158), (0.058, 0.162), (0.001, 0.162)], KETTLE)]
P.append(lathe("KettleLid", [(0.001, 0.158), (0.064, 0.158), (0.062, 0.166), (0.05, 0.18),
                             (0.025, 0.19), (0.001, 0.192)], KETTLE))
P.append(lathe("KettleKnob", [(0.001, 0.188), (0.012, 0.188), (0.016, 0.2), (0.019, 0.208),
                              (0.014, 0.215), (0.001, 0.216)], BLACK, segs=8))
P.append(tube("Spout", [(0, -0.085, 0.06), (0, -0.115, 0.075), (0, -0.135, 0.105),
                        (0, -0.14, 0.14), (0, -0.155, 0.165), (0, -0.175, 0.172)],
              0.02, KETTLE, taper=[1.0, 0.8, 0.6, 0.5, 0.45, 0.45]))
for y in (0.062, -0.062):                                                           # ушки ручки
    P.append(box((0.012, 0.012, 0.022), (0, y * 1.04, 0.168), KETTLE))
P.append(tube("WireA", [(0, 0.066, 0.175), (0, 0.1, 0.23), (0, 0.11, 0.28), (0, 0.1, 0.305)],
              0.0032, CHROME_WIRE))
P.append(tube("WireB", [(0, -0.066, 0.175), (0, -0.1, 0.23), (0, -0.11, 0.28), (0, -0.1, 0.305)],
              0.0032, CHROME_WIRE))
P.append(tube("Grip", [(0, 0.104, 0.302), (0, 0.04, 0.315), (0, -0.04, 0.315), (0, -0.104, 0.302)],
              0.011, BLACK))
export("kitchen_kettle", P)

# ---------------- Бутылка и гранёные стаканы ----------------
# Тёмно-зелёная бутылка (без надписей) и гранёный стакан: kitchen_tumbler — пустой,
# kitchen_tumbler_wine — с тёмно-бордовым налитым. Стекло полупрозрачное (альфа).
def clear_glass(name, color, alpha, rough=0.05):
    m = mat(name, color, rough)
    m.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = alpha
    m.blend_method = "BLEND"
    return m


# Винная бутылка: тёмно-зелёное полупрозрачное стекло, внутри — тёмно-бордовое вино до плечиков
# (видно, что полная), бордовая фольга на горлышке, кремовая этикетка с бордовой полосой.
# Этикетка заметно шире стекла (раньше почти совпадала с ним и шла полосами-«мерцанием»).
BOTTLE = clear_glass("BottleGreen", (0.05, 0.25, 0.08), 0.35, 0.06)
LABEL = mat("BottleLabel", (0.8, 0.7, 0.5), 0.8)
FOIL = mat("BottleFoil", (0.25, 0.01, 0.03), 0.3, 0.6)
TUMBLER = clear_glass("TumblerGlass", (0.85, 0.92, 0.94), 0.6)               # мутнее
WINE = mat("DarkWine", (0.2, 0.005, 0.02), 0.1)
# Бутылка собрана из трёх колец одной поверхности: стекло — этикетка — стекло. Этикетка не
# надета поверх стекла (раньше две поверхности рядом давали полосы), а заменяет кусок стенки.
P = [lathe("BottleLow", [(0.001, 0.0), (0.036, 0.0), (0.038, 0.006), (0.038, 0.075)], BOTTLE,
           segs=24, caps=False),
     lathe("BottleLabel", [(0.0383, 0.075), (0.0383, 0.145)], LABEL, segs=24, caps=False),
     lathe("BottleHigh", [(0.038, 0.145), (0.038, 0.2), (0.034, 0.225), (0.02, 0.255),
                          (0.014, 0.275), (0.014, 0.31), (0.016, 0.313), (0.016, 0.322),
                          (0.001, 0.322)], BOTTLE, segs=24, caps=False)]
P.append(lathe("Wine", [(0.001, 0.004), (0.034, 0.004), (0.035, 0.008), (0.035, 0.2),
                        (0.031, 0.222), (0.022, 0.236), (0.001, 0.236)], WINE, segs=24))
P.append(lathe("LabelBand", [(0.0386, 0.13), (0.0386, 0.14)], FOIL, segs=24, caps=False))  # полоса
P.append(cyl(0.0172, 0.055, (0, 0, 0.295), FOIL, verts=20, smooth=True))           # фольга
export("kitchen_bottle", P)


def tumbler(name, fill):
    """Гранёный стакан: 16 граней, гладкий ободок сверху, толстое дно; fill — налито (или None)."""
    parts = [lathe(name + "Body", [(0.001, 0.0), (0.029, 0.0), (0.031, 0.004), (0.031, 0.012),
                                   (0.001, 0.012)], TUMBLER, segs=16)]
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.03, radius2=0.036, depth=0.09,
                                    location=(0, 0, 0.012 + 0.045), end_fill_type="NOTHING")
    wall = bpy.context.object
    wall.data.materials.append(TUMBLER)
    mod = wall.modifiers.new("S", "SOLIDIFY")
    mod.thickness = 0.002
    bpy.ops.object.modifier_apply(modifier="S")
    parts.append(wall)                                                              # грани
    parts.append(cyl(0.0365, 0.012, (0, 0, 0.108), TUMBLER, verts=32, smooth=True))  # ободок
    if fill:
        parts.append(cyl(0.031, 0.05, (0, 0, 0.012 + 0.025), fill, verts=16, r2=0.033, smooth=True))
    export(name, parts)


tumbler("kitchen_tumbler", None)
tumbler("kitchen_tumbler_wine", WINE)

# ---------------- Мусорное ведро с педалью (для туалета) ----------------
# Эмалированное ведро цвета слоновой кости, закрытое крышкой-куполом с ободком, педаль спереди
# (−Y Blender = +Z Godot), петля крышки сзади. Начало — на полу, в центре.
BIN = mat("BinEnamel", (0.85, 0.82, 0.72), 0.3)
BIN_DARK = mat("BinDark", (0.18, 0.18, 0.2), 0.5)
P = [lathe("BinBody", [(0.0, 0.0), (0.105, 0.0), (0.112, 0.01), (0.122, 0.3), (0.0, 0.3)], BIN, segs=28)]
P.append(lathe("BinBase", [(0.0, 0.0), (0.108, 0.0), (0.108, 0.02), (0.0, 0.02)], BIN_DARK, segs=28))
P.append(lathe("BinLid", [(0.0, 0.3), (0.128, 0.3), (0.128, 0.31), (0.115, 0.325), (0.07, 0.345),
                          (0.0, 0.35)], BIN, segs=28))
P.append(lathe("BinRim", [(0.124, 0.296), (0.13, 0.296), (0.13, 0.312), (0.124, 0.312)], BIN_DARK, segs=28))
P.append(box((0.07, 0.06, 0.012), (0, -0.14, 0.03), BIN_DARK))                      # педаль
P.append(box((0.04, 0.03, 0.02), (0, -0.115, 0.03), BIN_DARK))
P.append(box((0.06, 0.02, 0.025), (0, 0.125, 0.305), BIN_DARK))                     # петля
export("trash_bin", P)

# ---------------- Мухобойка (лежит на холодильнике) ----------------
# Красная пластиковая: рукоятка с дырочкой, тонкий стержень, решётчатая лопатка. Лежит плашмя,
# начало — посередине, на нижней грани; длинная сторона — вдоль X.
SWAT = mat("SwatterRed", (0.62, 0.03, 0.02), 0.45)
P = [box((0.17, 0.028, 0.006), (0.155, 0, 0.003), SWAT, bevel=0.002)]           # рукоятка
P.append(cyl(0.0035, 0.2, (-0.03, 0, 0.003), SWAT, verts=6, rot=(0, math.radians(90), 0)))
PX = -0.19                                                                          # центр лопатки
for k in range(9):                                                                  # решётка
    P.append(box((0.004, 0.11, 0.004), (PX - 0.052 + k * 0.013, 0, 0.002), SWAT))
for k in range(9):
    P.append(box((0.11, 0.004, 0.004), (PX, -0.052 + k * 0.013, 0.002), SWAT))
for side in (-1, 1):                                                                # рамка
    P.append(box((0.118, 0.006, 0.005), (PX, side * 0.056, 0.0025), SWAT))
    P.append(box((0.006, 0.118, 0.005), (PX + side * 0.056, 0, 0.0025), SWAT))
P.append(box((0.03, 0.02, 0.005), (PX + 0.07, 0, 0.0025), SWAT))                  # «шейка»
export("kitchen_swatter", P)

# ---------------- Радиоточка ----------------
# Стоит на полочке: низ — z = 0, центр по глубине — y = 0 (провода нет).
P = [box((0.24, 0.08, 0.16), (0, 0.0, 0.08), IVORY, bevel=0.012, segs=2)]
P.append(box((0.15, 0.01, 0.1), (-0.03, -0.043, 0.08), BAKELITE))
for k in range(6):
    P.append(box((0.13, 0.012, 0.006), (-0.03, -0.046, 0.04 + k * 0.016), IVORY))
P.append(cyl(0.018, 0.02, (0.085, -0.048, 0.08), BAKELITE, verts=12, rot=(math.radians(90), 0, 0)))
for x in (-0.09, 0.09):
    P.append(box((0.03, 0.06, 0.008), (x, 0.0, -0.004), BAKELITE))                # ножки
export("kitchen_radio", P)

# ---------------- Пачка соды ----------------
# Просто: красная коробка, спереди и сзади — этикетка (assets/textures/kitchen/soda.png).
SODA_RED = mat("SodaRed", (0.75, 0.05, 0.03), 0.6)
SODA_LABEL = mat("SodaLabel", (1, 1, 1), 0.6, image="assets/textures/kitchen/soda.png")
P = [box((0.075, 0.045, 0.12), (0, 0, 0.06), SODA_RED)]
for side in (-1, 1):
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, side * 0.0228, 0.06),
                                     rotation=(math.radians(90), 0, math.radians(0 if side < 0 else 180)))
    label = bpy.context.object
    label.scale = (0.075, 0.12, 1)
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    P.append(finish(label, SODA_LABEL))
export("kitchen_soda", P)

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
layout = {"kitchen_fridge": (-1.6, 0), "kitchen_stove": (-0.95, 0), "KitchenSinkBody": (-0.1, 0),
          "kitchen_table": (1.3, -0.3), "kitchen_lamp": (1.3, -0.3)}
for o in list(bpy.context.scene.objects):
    if o.name in layout:
        o.location = (*layout[o.name], 0)  # начало моделей — на полу
    elif o.name == "kitchen_cabinet":
        o.location = (-0.1, 0.12, 1.45)
    elif o.name == "kitchen_kettle":
        o.location = (-1.07, -0.12, 0.88)
    elif o.name == "kitchen_bottle":
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
