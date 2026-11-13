"""Молоток-гвоздодёр (для серванта в лобби) по референсу владельца: низкополигональный,
с плоскими гранями.
  рукоятка — чёрная резина, восьмигранная, к низу чуть толще, внизу — расширенный торец;
  шейка — жёлтая (стеклопластик), восьмигранная;
  боёк — стальной блок с фасками; с одной стороны расширяющийся восьмигранный ударник,
  с другой — загнутый вниз гвоздодёр из двух лапок с прорезью.
Точка (0,0,0) — середина рукоятки (там кулак). Ручка — вверх по +Z Blender (= +Y Godot), ударная
часть смотрит на +Y Blender (= −Z Godot), гвоздодёр — на −Y. Размеры — как у прежнего молотка
(низ −0.095, верх бойка 0.31), чтобы хват и форма столкновений не поменялись.

Запуск:
    python tools/blender/hammer.py assets/models/apartment [--render превью.png]
"""
import math
import os
import sys

import bpy  # noqa: I001 — bpy первым: модуль bmesh появляется только после него
import bmesh
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else "."
RENDER = sys.argv[sys.argv.index("--render") + 1] if "--render" in sys.argv else None
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, rough, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


RUBBER = mat("HammerGrip", (0.035, 0.035, 0.04), 0.8)
NECK = mat("HammerNeck", (0.72, 0.6, 0.2), 0.5)
STEEL = mat("HammerSteel", (0.42, 0.44, 0.47), 0.35, 0.3)   # не чистый металл — иначе чёрный


def lathe(name, profile, m, segs=8, axis="Z", center=(0, 0, 0), turn=math.pi / 8):
    """Тело вращения: profile — [(радиус, координата вдоль оси)], концы закрыты."""
    bm = bmesh.new()
    rings = []
    for r, h in profile:
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs + turn                # грань, а не ребро, — сверху
            x, y = r * math.cos(a), r * math.sin(a)
            p = {"Z": (x, y, h), "Y": (x, h, y), "X": (h, x, y)}[axis]
            ring.append(bm.verts.new(Vector(p) + Vector(center)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(m)
    for poly in me.polygons:
        poly.use_smooth = False                                    # плоские грани, как в референсе
    return o


def rounded(r0, z0, z1, r1=None, cap=0.006, steps=4):
    """Профиль цилиндра со скруглёнными краями (r0 внизу → r1 вверху)."""
    r1 = r0 if r1 is None else r1
    prof = []
    for k in range(steps + 1):                                       # нижнее скругление
        a = math.pi / 2 * k / steps
        prof.append((r0 - cap + cap * math.sin(a), z0 + cap - cap * math.cos(a)))
    for k in range(steps + 1):                                       # верхнее скругление
        a = math.pi / 2 * k / steps
        prof.append((r1 - cap + cap * math.cos(a), z1 - cap + cap * math.sin(a)))
    return [(max(r, 0.0005), z) for r, z in prof]


parts = []
# Торец рукоятки: расширенный восьмигранник с фасками.
parts.append(lathe("Cap", [(0.0005, -0.095), (0.026, -0.095), (0.031, -0.089), (0.031, -0.073),
                           (0.027, -0.066), (0.0005, -0.066)], RUBBER))
# Рукоятка: чёрная резина, чуть пузатая внизу.
parts.append(lathe("Grip", [(0.0005, -0.067), (0.027, -0.067), (0.029, -0.03), (0.0285, 0.03),
                            (0.0265, 0.09), (0.025, 0.128), (0.0005, 0.128)], RUBBER))
# Шейка: жёлтая, восьмигранная, до бойка.
parts.append(lathe("Neck", [(0.0005, 0.127), (0.0235, 0.127), (0.023, 0.236),
                            (0.0005, 0.236)], NECK))

# Блок бойка с фасками.
bpy.ops.mesh.primitive_cube_add(location=(0, 0, 0.271))
block = bpy.context.object
block.scale = (0.019, 0.032, 0.039)
bpy.ops.object.transform_apply(scale=True)
mod = block.modifiers.new("B", "BEVEL")
mod.width = 0.005
mod.segments = 1
bpy.ops.object.modifier_apply(modifier="B")
block.data.materials.append(STEEL)
parts.append(block)
# Ворот под блоком (шире шейки, как в референсе).
parts.append(lathe("Collar", [(0.0005, 0.229), (0.027, 0.229), (0.031, 0.234),
                              (0.0005, 0.234)], STEEL))

# Ударник: шейка → расширение к круглому (восьмигранному) пятаку.
FACE_Z = 0.285
parts.append(lathe("Striker", [(0.0005, 0.03), (0.014, 0.03), (0.013, 0.04), (0.015, 0.05),
                               (0.024, 0.09), (0.0255, 0.093), (0.0255, 0.097),
                               (0.0005, 0.098)], STEEL, axis="Y", center=(0, 0, FACE_Z)))


def prong(side):
    """Лапка гвоздодёра: брусок, сужающийся и загибающийся вниз к концу (по сечениям)."""
    bm = bmesh.new()
    secs = []
    steps = 10
    for k in range(steps + 1):
        t = k / steps
        y = -0.028 - 0.08 * t                                     # назад от блока
        top = 0.31 - 0.05 * t ** 1.8                              # верх дугой загибается вниз
        bot = 0.27 - 0.026 * t ** 1.6 if t > 0 else 0.25          # у корня — внутри блока
        bot = min(bot, top - 0.013)
        w = 0.0175 - 0.006 * t
        x0, x1 = 0.0016, w                                        # прорезь между лапками
        if side < 0:
            x0, x1 = -x1, -x0
        secs.append([bm.verts.new((x, y, z)) for x, z in ((x0, bot), (x1, bot), (x1, top), (x0, top))])
    for k in range(steps):
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((secs[k][i], secs[k][j], secs[k + 1][j], secs[k + 1][i]))
    bm.faces.new(secs[0])
    bm.faces.new(list(reversed(secs[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("Claw")
    bm.to_mesh(me)
    o = bpy.data.objects.new("Claw", me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(STEEL)
    for poly in me.polygons:
        poly.use_smooth = False
    return o


parts += [prong(1), prong(-1)]

bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
hammer = bpy.context.object
hammer.name = "Hammer"
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "hammer.glb"), use_selection=True,
                          export_format="GLB")
print("EXPORTED hammer", len(hammer.data.polygons), "faces")

if RENDER:
    hammer.rotation_euler = (0, 0, math.radians(-15))  # чуть развернуть, чтобы было видно объём
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 48
    sc.render.resolution_x, sc.render.resolution_y = 700, 900
    sc.view_settings.view_transform = "Standard"
    sc.world = bpy.data.worlds.new("W")
    sc.world.color = (0.3, 0.3, 0.32)
    sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(40), math.radians(10), math.radians(30))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 0.56
    cam.location = (1.0, 0.0, 0.11)
    cam.rotation_euler = (math.radians(90), 0, math.radians(90))  # сбоку, ручка вертикально
    sc.render.filepath = RENDER
    bpy.ops.render.render(write_still=True)
