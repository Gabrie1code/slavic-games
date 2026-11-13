"""Вещицы для настенных полок (гладкие, подробнее, чем первые коробочные версии).
Каждая — отдельная модель (в игре бьётся и восстанавливается); точка (0,0,0) — под вещью
посередине, «лицом» к −Y Blender (= +Z Godot — в комнату, полка разворачивает).
  shelf_matryoshka — три матрёшки (красная, зелёная, синяя): платок, лицо с глазами и румянцем,
                     фартук с цветком, золотой поясок;
  shelf_elephant   — фарфоровый слоник «гжель»: хобот вверх, уши, бивни, синяя попонка;
  shelf_jar        — стеклянная банка с разноцветными пуговицами, жестяная крышка;
  shelf_clock      — красный будильник с двумя звонками и циферблатом;
  shelf_samovar    — маленький латунный самовар с краником и заварничком сверху;
  shelf_frame      — фотография в деревянной рамке на подставке (сепия);
  shelf_vase       — ваза «гжель»: белая с синими поясками и горошинами.
Растения и книги — в tools/blender/decor.py.

Запуск:
    python tools/blender/shelf_items.py assets/models/apartment [--render превью.png]
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
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
bpy.ops.wm.read_factory_settings(use_empty=True)
_mats = {}


def mat(name, color, rough=0.5, metal=0.0, image=None, alpha=1.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    if image:
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(os.path.join(ROOT, image))
        m.node_tree.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    _mats[name] = m
    return m


def finish(o, m, smooth=True):
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = smooth
    return o


def lathe(profile, m, loc=(0, 0, 0), segs=28, smooth=True):
    """Тело вращения вокруг Z: profile — [(радиус, высота)], дно и верх закрыты."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        rings.append([bm.verts.new((loc[0] + r * math.cos(2 * math.pi * i / segs),
                                    loc[1] + r * math.sin(2 * math.pi * i / segs), loc[2] + z))
                      for i in range(segs)])
    for k in range(len(rings) - 1):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("L")
    bm.to_mesh(me)
    o = bpy.data.objects.new("L", me)
    bpy.context.scene.collection.objects.link(o)
    return finish(o, m, smooth)


def ball(r, loc, m, scale=(1, 1, 1), segs=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True, location=False)
    return finish(o, m)


def cyl(r, h, loc, m, verts=20, r2=None, rot=(0, 0, 0), smooth=True):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc,
                                        rotation=rot)
    o = bpy.context.object
    bpy.ops.object.transform_apply(rotation=True, location=False)
    return finish(o, m, smooth)


def box(size, loc, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    return finish(o, m, smooth=False)


def ring(r, thick, loc, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=thick, major_segments=28,
                                     minor_segments=8, location=loc, rotation=rot)
    return finish(bpy.context.object, m)


def tube(pts, radius, m, taper=None):
    curve = bpy.data.curves.new("T", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
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
    return finish(o, m)


def export(name, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True,
                              export_format="GLB")
    print("EXPORTED", name)
    return obj


SKIN = mat("MatrFace", (0.95, 0.82, 0.68), 0.5)
GOLD = mat("MatrGold", (0.9, 0.68, 0.15), 0.3, 0.6)
YELLOW = mat("MatrApron", (0.98, 0.85, 0.3), 0.45)
DARK = mat("MatrEyes", (0.08, 0.06, 0.05), 0.4)
PINK = mat("MatrCheek", (0.95, 0.45, 0.45), 0.5)
FLOWER = mat("MatrFlower", (0.85, 0.08, 0.1), 0.4)
LEAFG = mat("MatrLeaf", (0.15, 0.5, 0.15), 0.5)
PORCELAIN = mat("Porcelain", (0.94, 0.94, 0.92), 0.2)
COBALT = mat("Cobalt", (0.06, 0.18, 0.6), 0.25)
BRASS = mat("Brass", (0.78, 0.55, 0.22), 0.25, 0.85)
TIN = mat("Tin", (0.7, 0.7, 0.72), 0.3, 0.8)
GLASS = mat("JarGlass", (0.8, 0.9, 0.88), 0.05, alpha=0.35)
WOOD = mat("FrameWood", (0.36, 0.18, 0.07), 0.45)
CLOCK_RED = mat("ClockRed", (0.75, 0.06, 0.05), 0.25)
DIAL = mat("ClockDial", (0.97, 0.95, 0.88), 0.4)


# ---------------- Матрёшки ----------------
def matryoshka(x, s, body, scarf):
    """Матрёшка высотой 0.14·s: гладкий силуэт, платок другого цвета, лицо, фартук с цветком."""
    prof = [(0.0, 0.0), (0.036, 0.0), (0.043, 0.012), (0.045, 0.035), (0.041, 0.06), (0.032, 0.08),
            (0.03, 0.088), (0.033, 0.1), (0.033, 0.115), (0.026, 0.13), (0.014, 0.139), (0.0, 0.141)]
    P = [lathe([(r * s, z * s) for r, z in prof[:7]] + [(0.0, 0.088 * s)], body, (x, 0, 0))]
    P.append(lathe([(0.0, 0.08 * s)] + [(r * s, z * s) for r, z in prof[5:]], scarf, (x, 0, 0)))
    P.append(ring(0.0315 * s, 0.003 * s, (x, 0, 0.083 * s), GOLD))               # поясок
    face_z = 0.107 * s
    P.append(ball(0.021 * s, (x, -0.022 * s, face_z), SKIN, scale=(1, 0.55, 1.05)))
    for side in (-1, 1):
        P.append(ball(0.0028 * s, (x + side * 0.0075 * s, -0.034 * s, face_z + 0.004 * s), DARK))
        P.append(ball(0.0042 * s, (x + side * 0.012 * s, -0.031 * s, face_z - 0.006 * s), PINK,
                      scale=(1, 0.5, 1)))
    P.append(ball(0.0035 * s, (x, -0.034 * s, face_z - 0.011 * s), FLOWER, scale=(1.3, 0.5, 0.7)))  # губы
    # Фартук (жёлтый овал спереди) и цветок на нём.
    P.append(ball(0.027 * s, (x, -0.034 * s, 0.035 * s), YELLOW, scale=(0.9, 0.35, 1.2)))
    for k in range(5):
        a = 2 * math.pi * k / 5
        P.append(ball(0.0055 * s, (x + math.cos(a) * 0.008 * s, -0.044 * s,
                                    0.04 * s + math.sin(a) * 0.008 * s), FLOWER, scale=(1, 0.5, 1)))
    P.append(ball(0.004 * s, (x, -0.046 * s, 0.04 * s), YELLOW, scale=(1, 0.5, 1)))
    for side in (-1, 1):
        P.append(ball(0.005 * s, (x + side * 0.012 * s, -0.042 * s, 0.022 * s), LEAFG,
                      scale=(1.3, 0.45, 0.7)))
    return P


P = (matryoshka(-0.08, 1.0, mat("MatrRed", (0.8, 0.08, 0.06), 0.3), mat("MatrScarf1", (0.95, 0.75, 0.15), 0.4))
     + matryoshka(0.03, 0.78, mat("MatrGreen", (0.1, 0.5, 0.2), 0.3), mat("MatrScarf2", (0.85, 0.1, 0.1), 0.4))
     + matryoshka(0.115, 0.58, mat("MatrBlue", (0.1, 0.25, 0.7), 0.3), mat("MatrScarf3", (0.95, 0.75, 0.15), 0.4)))
export("shelf_matryoshka", P)

# ---------------- Фарфоровый слоник ----------------
P = [ball(1.0, (0, 0, 0.068), PORCELAIN, scale=(0.06, 0.036, 0.04))]                  # туловище
P.append(ball(0.03, (-0.058, -0.004, 0.09), PORCELAIN, scale=(1, 0.95, 1)))          # голова
for side in (-1, 1):
    P.append(ball(1.0, (-0.05, side * 0.03, 0.093), PORCELAIN, scale=(0.006, 0.024, 0.026)))  # уши
    P.append(ball(1.0, (-0.046, side * 0.032, 0.093), COBALT, scale=(0.003, 0.016, 0.017)))
    P.append(ball(0.0035, (-0.081, side * 0.015, 0.1), DARK))                              # глаза
    P.append(cyl(0.004, 0.022, (-0.083, side * 0.012, 0.074), PORCELAIN, verts=8, r2=0.0015,
                 rot=(0, math.radians(-60), 0)))                                        # бивни
for lx in (-0.035, 0.035):
    for ly in (-0.018, 0.018):
        P.append(cyl(0.012, 0.04, (lx, ly, 0.02), PORCELAIN, verts=14))               # ноги
        P.append(cyl(0.0125, 0.006, (lx, ly, 0.003), COBALT, verts=14))
P.append(tube([(-0.08, 0, 0.085), (-0.098, 0, 0.065), (-0.105, 0, 0.09), (-0.11, 0, 0.12),
               (-0.1, 0, 0.135)], 0.009, PORCELAIN, taper=[1.0, 0.8, 0.6, 0.5, 0.45]))  # хобот вверх
P.append(ball(1.0, (0.0, 0, 0.1), COBALT, scale=(0.032, 0.038, 0.012)))                # попонка
P.append(ring(0.026, 0.0025, (0.0, 0, 0.104), GOLD, rot=(0, 0, 0)))
P.append(tube([(0.058, 0, 0.075), (0.068, 0, 0.06), (0.07, 0, 0.045)], 0.003, PORCELAIN))  # хвост
export("shelf_elephant", P)

# ---------------- Банка с пуговицами ----------------
P = [lathe([(0.0, 0.0), (0.034, 0.0), (0.037, 0.008), (0.037, 0.075), (0.031, 0.088),
            (0.029, 0.095), (0.0, 0.095)], GLASS)]
BUTTONS = [mat("Btn%d" % i, c, 0.35) for i, c in enumerate(
    [(0.85, 0.1, 0.1), (0.1, 0.35, 0.8), (0.95, 0.8, 0.15), (0.1, 0.55, 0.2), (0.95, 0.95, 0.9),
     (0.45, 0.2, 0.08)])]
k = 0
for layer in range(4):
    for i in range(6):
        a = 2 * math.pi * i / 6 + layer * 0.5
        r = 0.018 if i % 2 else 0.008
        P.append(cyl(0.008, 0.003, (math.cos(a) * r, math.sin(a) * r, 0.008 + layer * 0.012),
                     BUTTONS[k % 6], verts=10, rot=(0.4 * (i % 3 - 1), 0.3 * (layer % 2), 0)))
        k += 1
P.append(cyl(0.032, 0.014, (0, 0, 0.101), TIN, verts=24))                               # крышка
P.append(ring(0.032, 0.0025, (0, 0, 0.096), TIN))
export("shelf_jar", P)

# ---------------- Будильник ----------------
P = [cyl(0.042, 0.032, (0, 0, 0.058), CLOCK_RED, verts=28, rot=(math.radians(90), 0, 0))]
P.append(cyl(0.036, 0.004, (0, -0.017, 0.058), DIAL, verts=28, rot=(math.radians(90), 0, 0)))
P.append(ring(0.038, 0.003, (0, -0.017, 0.058), TIN, rot=(math.radians(90), 0, 0)))
for k in range(12):
    a = 2 * math.pi * k / 12
    ln = 0.007 if k % 3 == 0 else 0.004
    P.append(box((0.0018, 0.002, ln), (math.sin(a) * 0.029, -0.0195, 0.058 + math.cos(a) * 0.029), DARK,
                 rot=(0, -a, 0)))
P.append(box((0.0025, 0.002, 0.018), (-0.006, -0.0205, 0.064), DARK, rot=(0, math.radians(40), 0)))
P.append(box((0.0018, 0.002, 0.026), (0.008, -0.0205, 0.066), DARK, rot=(0, math.radians(-30), 0)))
for side in (-1, 1):
    P.append(ball(0.016, (side * 0.026, 0, 0.1), TIN, scale=(1, 1, 0.7)))              # звонки
    P.append(cyl(0.004, 0.03, (side * 0.025, 0.006, 0.012), TIN, verts=8,
                 rot=(0, math.radians(side * 25), 0)))                                 # ножки
P.append(cyl(0.003, 0.03, (0, 0, 0.105), TIN, verts=8))
P.append(ball(0.006, (0, 0, 0.12), TIN))
export("shelf_clock", P)

# ---------------- Самовар ----------------
P = [lathe([(0.0, 0.0), (0.028, 0.0), (0.022, 0.012), (0.03, 0.022), (0.046, 0.05),
            (0.05, 0.08), (0.044, 0.105), (0.03, 0.115), (0.02, 0.12), (0.0, 0.12)], BRASS)]
P.append(lathe([(0.0, 0.12), (0.016, 0.12), (0.022, 0.128), (0.0, 0.132)], BRASS))
for side in (-1, 1):                                                                   # ручки
    P.append(tube([(side * 0.046, 0, 0.1), (side * 0.064, 0, 0.098), (side * 0.064, 0, 0.082),
                   (side * 0.048, 0, 0.078)], 0.003, DARK))
P.append(tube([(0, -0.045, 0.045), (0, -0.065, 0.044), (0, -0.07, 0.032)], 0.004, BRASS))  # краник
P.append(box((0.012, 0.004, 0.006), (0, -0.07, 0.03), DARK))
# Заварничек сверху: белый с синим.
P.append(lathe([(0.0, 0.132), (0.016, 0.132), (0.024, 0.145), (0.022, 0.16), (0.012, 0.166),
                (0.0, 0.167)], PORCELAIN))
P.append(ball(0.005, (0, 0, 0.17), COBALT))
P.append(tube([(0, -0.02, 0.146), (0, -0.034, 0.152), (0, -0.038, 0.162)], 0.0035, PORCELAIN))
export("shelf_samovar", P)

# ---------------- Фото в рамке ----------------
PHOTO = mat("OldPhoto", (1, 1, 1), 0.7, image="assets/textures/posters/shelf_photo.png")
TILT = math.radians(12)
frame = [box((0.11, 0.012, 0.14), (0, 0, 0.0), WOOD), ]
bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, -0.0065, 0), rotation=(math.radians(90), 0, 0))
pic = bpy.context.object
pic.scale = (0.086, 0.116, 1)
bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
frame.append(finish(pic, PHOTO, smooth=False))
for o in frame:                                                                        # наклон назад
    o.rotation_euler = (TILT, 0, 0)
    o.location += Vector((0, 0.008, 0.07))
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.object.transform_apply(rotation=True, location=True)
P = frame + [box((0.008, 0.06, 0.004), (0, 0.035, 0.002), WOOD)]                        # подставка
export("shelf_frame", P)

# ---------------- Ваза «гжель» ----------------
P = [lathe([(0.0, 0.0), (0.026, 0.0), (0.03, 0.01), (0.044, 0.05), (0.046, 0.075), (0.036, 0.105),
            (0.02, 0.13), (0.018, 0.15), (0.024, 0.165), (0.0, 0.165)], PORCELAIN)]
for z, r in ((0.012, 0.031), (0.105, 0.0365), (0.16, 0.0225)):
    P.append(ring(r, 0.0028, (0, 0, z), COBALT))
for k in range(10):                                                                    # горошины
    a = 2 * math.pi * k / 10
    for z, r in ((0.045, 0.043), (0.075, 0.046)):
        aa = a + (0.31 if z > 0.06 else 0.0)
        P.append(ball(0.0042, (math.cos(aa) * r, math.sin(aa) * r, z), COBALT,
                      scale=(1, 1, 1)))
export("shelf_vase", P)
print("DONE")

if RENDER:
    names = ["shelf_matryoshka", "shelf_elephant", "shelf_jar", "shelf_clock", "shelf_samovar",
             "shelf_frame", "shelf_vase"]
    for i, n in enumerate(names):
        bpy.data.objects[n].location = (-0.66 + i * 0.22, 0, 0)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 32
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x, sc.render.resolution_y = 1400, 420
    w = bpy.data.worlds.new("W")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.7, 0.5, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(55), 0, math.radians(-25))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = (0.0, -1.9, 0.3)
    cam.rotation_euler = (Vector((0.0, 0, 0.07)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 45
    sc.render.filepath = RENDER
    bpy.ops.render.render(write_still=True)
