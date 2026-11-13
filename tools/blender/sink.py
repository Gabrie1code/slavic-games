"""Рукомойник на ножке для туалета: чаша с настоящим углублением (вырезано булевой операцией),
металлический слив с решёткой, излив-«гусак», два крестовых вентиля (горячая — красная,
холодная — синяя) и вода в чаше — отдельными частями, чтобы в игре их двигать:
  SinkBody — чаша, ножка, излив, слив, мыло;
  TapHot / TapCold — вентили (поворачиваются вокруг вертикальной оси);
  SinkWater — вода (поднимается, когда чаша наполняется).
Задняя сторона — в y = 0 (к стене), лицом на −Y (в Godot +Z).

Запуск:
    python tools/blender/sink.py assets/models/apartment
    python tools/blender/sink.py assets/models/apartment --render   # + docs/previews/sink.png
"""
import bpy, math, os, sys
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else "."
RENDER = "--render" in sys.argv
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, rough=0.3, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


PORCELAIN = mat("Porcelain", (0.93, 0.93, 0.9), 0.2)
# Хром — не полностью металл: в игре без отражений «чистый металл» выглядит чёрным.
CHROME = mat("Chrome", (0.86, 0.87, 0.9), 0.22, 0.35)
DARK = mat("DrainDark", (0.08, 0.08, 0.08), 0.5)
RED = mat("TapRed", (0.8, 0.12, 0.1), 0.3)
BLUE = mat("TapBlue", (0.15, 0.35, 0.85), 0.3)
WATER = mat("SinkWater", (0.55, 0.75, 0.9), 0.05)
SOAP = mat("Soap", (0.9, 0.78, 0.45), 0.5)
BOWL = Vector((0, -0.21, 0))        # центр чаши
TOP = 0.88                          # верх раковины


def finish(o, m, smooth=True):
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = smooth
    return o


def cyl(r, h, loc, m, r2=None, verts=20, rot=(0, 0, 0)):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    return finish(bpy.context.object, m)


def box(size, loc, m, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        mod = o.modifiers.new("B", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier="B")
    return finish(o, m, smooth=False)


def join(name, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    return o


# Чаша: строим сеткой (bmesh) — верхняя плита с овальным отверстием, воронка вниз и дно,
# бока и низ. Вершины по кругу сопоставлены по углу, плита — «мост» прямоугольник→овал.
import bmesh
N = 40
HW, HD = 0.26, 0.21                 # половины ширины и глубины чаши
RX, RY = 0.2, 0.156                 # овал отверстия
BX, BY = 0.07, 0.055                # дно воронки
DEPTH = 0.12
bm = bmesh.new()
rect_top, rect_low, rim, bottom = [], [], [], []
for k in range(N):
    a = k / N * math.tau
    c, sn = math.cos(a), math.sin(a)
    t = min(HW / abs(c) if abs(c) > 1e-6 else 9, HD / abs(sn) if abs(sn) > 1e-6 else 9)
    rect_top.append(bm.verts.new((c * t, BOWL.y + sn * t, TOP)))
    rect_low.append(bm.verts.new((c * t, BOWL.y + sn * t, TOP - 0.16)))
    rim.append(bm.verts.new((RX * c, BOWL.y + RY * sn, TOP)))
    bottom.append(bm.verts.new((BX * c, BOWL.y + BY * sn, TOP - DEPTH)))
for k in range(N):
    j = (k + 1) % N
    bm.faces.new((rect_top[k], rect_top[j], rim[j], rim[k]))          # плита
    bm.faces.new((rim[k], rim[j], bottom[j], bottom[k]))              # воронка
    bm.faces.new((rect_low[k], rect_low[j], rect_top[j], rect_top[k]))  # бока
bm.faces.new(bottom)                                                  # дно воронки
bm.faces.new(list(reversed(rect_low)))                                # низ
# Порядок вершин задан так, что все грани смотрят наружу/вверх (recalc тут переворачивал плиту).
me = bpy.data.meshes.new("Basin")
bm.to_mesh(me)
bm.free()
basin = bpy.data.objects.new("Basin", me)
bpy.context.collection.objects.link(basin)
finish(basin, PORCELAIN, smooth=False)
parts = [basin]
parts.append(cyl(0.07, 0.72, (0, -0.17, 0.36), PORCELAIN, r2=0.09))          # ножка
# Слив: металлическое кольцо с решёткой на дне углубления.
drain_z = TOP - DEPTH + 0.003
parts.append(cyl(0.032, 0.006, (BOWL.x, BOWL.y, drain_z), CHROME, verts=20))
parts.append(cyl(0.024, 0.007, (BOWL.x, BOWL.y, drain_z), DARK, verts=20))
for k in range(-2, 3):
    parts.append(box((0.04, 0.004, 0.008), (BOWL.x, BOWL.y + k * 0.009, drain_z), CHROME))
# Излив «гусак»: стойка сзади, дуга, носик вниз над центром чаши.
parts.append(cyl(0.022, 0.02, (0, -0.035, TOP + 0.01), CHROME, verts=16))
parts.append(cyl(0.012, 0.12, (0, -0.035, TOP + 0.08), CHROME, verts=12))
parts.append(cyl(0.012, 0.14, (0, -0.105, TOP + 0.14), CHROME, verts=12, rot=(math.pi / 2, 0, 0)))
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.013, location=(0, -0.035, TOP + 0.14))
parts.append(finish(bpy.context.object, CHROME))
parts.append(cyl(0.012, 0.03, (0, -0.175, TOP + 0.125), CHROME, verts=12))     # носик
parts.append(box((0.06, 0.09, 0.025), (0.17, -0.33, TOP + 0.012), SOAP, bevel=0.008))  # мыло
body = join("SinkBody", parts)


def tap(name, x, color):
    """Крестовый вентиль: ножка, крестовина, цветной колпачок. Точка поворота — на оси ножки."""
    p = [cyl(0.012, 0.04, (x, -0.06, TOP + 0.02), CHROME, verts=12)]
    for rz in (0, math.pi / 2):
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.008, depth=0.08,
                                            location=(x, -0.06, TOP + 0.045), rotation=(math.pi / 2, 0, rz))
        p.append(finish(bpy.context.object, CHROME))
        for s in (-1, 1):
            off = Vector((0, s * 0.04, 0)) if rz == 0 else Vector((s * 0.04, 0, 0))
            bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=0.011,
                                                 location=Vector((x, -0.06, TOP + 0.045)) + off)
            p.append(finish(bpy.context.object, CHROME))
    p.append(cyl(0.016, 0.012, (x, -0.06, TOP + 0.056), color, verts=14))
    o = join(name, p)
    bpy.context.scene.cursor.location = (x, -0.06, TOP)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return o


hot = tap("TapHot", -0.11, RED)
cold = tap("TapCold", 0.11, BLUE)
# Вода — плоский овал на дне чаши; в игре поднимается и расширяется вместе с воронкой.
bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.07, depth=0.004, location=(BOWL.x, BOWL.y, drain_z + 0.006))
water = finish(bpy.context.object, WATER)
water.scale = (1.0, 0.78, 1.0)
bpy.ops.object.transform_apply(scale=True)
water.name = "SinkWater"
# Точка воды — в её центре (в игре её поднимают и расширяют вокруг этой точки).
bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")

bpy.ops.object.select_all(action="DESELECT")
for o in (body, hot, cold, water):
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "sink.glb"), use_selection=True, export_format="GLB")
print("EXPORTED sink")

if not RENDER:
    sys.exit(0)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 900, 700
scene.view_settings.view_transform = "Standard"
scene.world = bpy.data.worlds.new("W")
scene.world.color = (0.62, 0.66, 0.68)
sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN"))
sun.data.energy = 2.5
sun.rotation_euler = (math.radians(40), 0, math.radians(-30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (0.6, -1.2, 1.2)
cam.rotation_euler = (Vector((0, -0.2, 0.8)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.filepath = os.path.abspath("docs/previews/sink.png")
bpy.ops.render.render(write_still=True)
