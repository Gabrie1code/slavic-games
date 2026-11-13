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
BREAD = mat("Bread", (0.6, 0.33, 0.12), 0.7)                     # румяная корочка
CRUST = mat("BreadCut", (0.93, 0.8, 0.55), 0.8)
INSIDE = mat("CabinetInside", (0.85, 0.8, 0.62), 0.6)
P = [box((1.0, 0.02, 0.6), (0, 0.14, 0.3), INSIDE)]                                # задняя стенка
for x in (-0.49, 0.49):
    P.append(box((0.02, 0.3, 0.6), (x, 0.0, 0.3), CABINET))                       # бока
for z in (0.01, 0.59):
    P.append(box((1.0, 0.3, 0.02), (0, 0.0, z), CABINET))                        # дно и верх
P.append(box((0.02, 0.28, 0.58), (0.0, 0.0, 0.3), CABINET))                       # перегородка
P.append(box((0.47, 0.27, 0.015), (0.245, 0.005, 0.3), INSIDE))                   # полка справа
P.append(box((0.47, 0.02, 0.56), (-0.25, -0.155, 0.3), CABINET, bevel=0.008))    # левая дверца
P.append(box((0.02, 0.025, 0.1), (-0.07, -0.175, 0.1), CAB_EDGE))
P.append(box((1.02, 0.32, 0.02), (0, 0.0, 0.61), CAB_EDGE))                      # карниз
for k in range(4):                                                                 # стопки
    x = 0.08 + k * 0.1
    P.append(cyl(0.022, 0.07, (x, 0.0, 0.3075 + 0.035), GLASS_CUP, verts=8, r2=0.026))
# Батон: вытянутый, скруглённый, с косыми надрезами.
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=1.0, location=(0.245, 0.0, 0.065))
loaf = bpy.context.object
loaf.scale = (0.17, 0.06, 0.045)
bpy.ops.object.transform_apply(scale=True, location=False)
P.append(finish(loaf, BREAD, smooth=True))
for k in range(4):
    P.append(box((0.012, 0.09, 0.006), (0.15 + k * 0.065, 0.0, 0.106), CRUST, rot=(0, 0, math.radians(35))))
export("kitchen_cabinet", P)
# Правая дверца: петля — правый край (x = 0.49, y = −0.155), открывается наружу.
P = [box((0.47, 0.02, 0.56), (0.25, -0.155, 0.3), CABINET, bevel=0.008),
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
P.append(box((W + 0.2, 0.3, 0.04), (0, -0.17, -0.02), FRAME, bevel=0.006))       # подоконник
export("kitchen_window", P)

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
layout = {"kitchen_fridge": (-1.6, 0), "kitchen_stove": (-0.95, 0), "KitchenSinkBody": (-0.1, 0),
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
