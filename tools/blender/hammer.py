"""Молоток-гвоздодёр (для серванта в лобби): гладкая модель — тела вращения с большим числом
граней и сглаживанием (как у майки: плотная сетка + гладкие нормали), а не коробки.
  рукоятка — красная резина, чуть толще к низу, скруглённый торец;
  рукоять — тонкая тёмная сталь; боёк — ударная часть с круглым «пятаком» и изогнутый вниз
  раздвоенный гвоздодёр.
Точка (0,0,0) — середина рукоятки (там кулак). Ручка — вверх по +Z Blender (= +Y Godot), ударная
часть смотрит на +Y Blender (= −Z Godot), гвоздодёр — на −Y.

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


RUBBER = mat("HammerGrip", (0.78, 0.06, 0.05), 0.65)
STEEL = mat("HammerSteel", (0.2, 0.22, 0.25), 0.35, 0.35)   # не чистый металл — иначе чёрный
FACE = mat("HammerFace", (0.45, 0.47, 0.5), 0.25, 0.35)


def lathe(name, profile, m, segs=32, axis="Z", center=(0, 0, 0)):
    """Тело вращения: profile — [(радиус, координата вдоль оси)], концы закрыты."""
    bm = bmesh.new()
    rings = []
    for r, h in profile:
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
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
        poly.use_smooth = True
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
# Рукоятка: чуть пузатая книзу, скруглённый торец.
grip = [(0.0005, -0.095)]
for k in range(6):
    a = math.pi / 2 * k / 5
    grip.append((0.021 * math.sin(a) + 0.0005, -0.095 + 0.012 * (1 - math.cos(a))))
for z, r in ((-0.06, 0.0225), (-0.02, 0.022), (0.02, 0.0205), (0.055, 0.019), (0.07, 0.0175)):
    grip.append((r, z))
grip.append((0.013, 0.075))
parts.append(lathe("Grip", grip, RUBBER))
# Рукоять (сталь) и утолщение под бойком.
parts.append(lathe("Shaft", [(0.0115, 0.072), (0.011, 0.2), (0.012, 0.245), (0.017, 0.262),
                             (0.019, 0.272)], STEEL))
# Боёк: шейка с ударной частью — тело вращения вдоль +Y (к ударной части).
head = [(0.0005, -0.012), (0.017, -0.012), (0.02, -0.005), (0.02, 0.01), (0.015, 0.025),
        (0.0145, 0.04), (0.019, 0.05), (0.022, 0.058), (0.0225, 0.072), (0.0205, 0.078),
        (0.0005, 0.079)]
parts.append(lathe("Head", head, STEEL, axis="Y", center=(0, 0, 0.29)))
parts.append(lathe("Face", [(0.0005, 0.0785), (0.0185, 0.0785), (0.0175, 0.081),
                            (0.0005, 0.0815)], FACE, axis="Y", center=(0, 0, 0.29)))
# Гвоздодёр: две изогнутые вниз лапки, к концу тоньше и площе (кривая с переменным радиусом).
for side in (-1, 1):
    curve = bpy.data.curves.new("Claw", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 0.0095
    curve.bevel_resolution = 4
    spline = curve.splines.new("POLY")
    pts = []
    for k in range(11):
        t = k / 10
        y = -0.01 - 0.08 * t                                     # назад от рукояти
        z = 0.302 + 0.006 * t - 0.055 * t ** 2.2                 # и загибается вниз к концу
        pts.append((side * (0.007 + 0.0035 * t), y, z, 1.0 - 0.55 * t))
    spline.points.add(len(pts) - 1)
    for p, (x, y, z, rad) in zip(spline.points, pts):
        p.co = (x, y, z, 1)
        p.radius = rad
    o = bpy.data.objects.new("Claw", curve)
    bpy.context.scene.collection.objects.link(o)
    o.scale = (1.0, 1.0, 1.0)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.object
    o.data.materials.clear()
    o.data.materials.append(STEEL)
    for poly in o.data.polygons:
        poly.use_smooth = True
    o.select_set(False)
    parts.append(o)
# «Глаз» бойка вокруг рукояти — сглаженный брусок.
bpy.ops.mesh.primitive_cube_add(location=(0, -0.004, 0.292))
eye = bpy.context.object
eye.scale = (0.019, 0.028, 0.024)
bpy.ops.object.transform_apply(scale=True)
mod = eye.modifiers.new("S", "SUBSURF")
mod.levels = 2
bpy.ops.object.modifier_apply(modifier="S")
eye.data.materials.append(STEEL)
for poly in eye.data.polygons:
    poly.use_smooth = True
parts.append(eye)

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
    hammer.rotation_euler = (0, 0, math.radians(-25))  # чуть развернуть, чтобы было видно объём
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 48
    sc.render.resolution_x, sc.render.resolution_y = 1100, 700
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
    look = (Vector((0, 0, 0.11)) - cam.location).to_track_quat("-Z", "Z")
    cam.rotation_euler = look.to_euler()
    cam.rotation_euler.rotate_axis("Z", math.radians(130))      # рукоятка по диагонали кадра
    sc.render.filepath = RENDER
    bpy.ops.render.render(write_still=True)
