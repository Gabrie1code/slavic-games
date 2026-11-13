"""Варианты рта (улыбки) для персонажа — превью на выбор (10 голов в сетке, под каждой номер).
Голова как в character.py (сфера r=0.3 в (0, 0, 1.33), лицо смотрит в +Y), рот — на поверхности.

Запуск:
    python tools/blender/mouths.py docs/previews/mouths.png
"""
import math
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[1] if len(sys.argv) > 1 else "mouths.png"
bpy.ops.wm.read_factory_settings(use_empty=True)

HEAD_C = Vector((0, 0, 1.33))
HEAD_R = 0.3
HEAD_SY = 0.95
MOUTH_Z = 1.22


def mat(name, color, rough=0.6, metal=0.0, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


SKIN = mat("Primary", (0.75, 0.12, 0.08), 0.55)
WHITE = mat("EyeWhite", (0.95, 0.95, 0.95), 0.4)
BLACK = mat("EyeBlack", (0.03, 0.03, 0.03), 0.3)
MOUTH = mat("Mouth", (0.25, 0.05, 0.05), 0.6)
DARK = mat("MouthInside", (0.12, 0.02, 0.03), 0.7)
TOOTH = mat("Tooth", (0.97, 0.95, 0.88), 0.35)
TONGUE = mat("Tongue", (0.95, 0.4, 0.45), 0.5)
GOLD = mat("Gold", (1.0, 0.75, 0.2), 0.25, 0.6)
STRAW = mat("Straw", (0.85, 0.75, 0.35), 0.8)
STRAW_TIP = mat("StrawTip", (0.55, 0.65, 0.25), 0.8)


def surface_y(x, z):
    """Где поверхность головы (по Y) в точке (x, z) лица."""
    k = 1 - (x / HEAD_R) ** 2 - ((z - HEAD_C.z) / (HEAD_R * HEAD_SY)) ** 2
    return HEAD_R * HEAD_SY * math.sqrt(max(k, 0.0))


def box(size, x, z, m, rot_y=0.0, out=0.0, dy=0.0):
    y = surface_y(x, z) + out
    bpy.ops.mesh.primitive_cube_add(location=(x, y + dy, z))
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    # Наклон по дуге (вокруг оси Y, в плоскости лица) и разворот по изгибу головы (вокруг Z).
    o.rotation_euler = (0, rot_y, -math.atan2(x, HEAD_R) * 0.9)
    o.data.materials.append(m)
    return o


def blob(r, x, z, m, scale=(1, 0.5, 1), out=0.0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=7, radius=r,
                                         location=(x, surface_y(x, z) + out, z))
    o = bpy.context.object
    o.scale = scale
    o.data.materials.append(m)
    return o


def arc(width, depth, m, thick=0.022, n=7, z0=MOUTH_Z, tilt=0.0):
    """Дуга из кусочков: depth > 0 — улыбка (края выше середины), < 0 — грусть; tilt — ухмылка."""
    pieces = []
    for i in range(n):
        t = i / (n - 1) * 2 - 1                       # −1..1
        x = t * width / 2
        z = z0 + depth * t * t + tilt * t
        slope = 2 * depth * t / (width / 2) + tilt / (width / 2)
        pieces.append(box((width / (n - 1) * 1.35, 0.025, thick), x, z, m, rot_y=-math.atan(slope)))
    return pieces


def mouth(kind):
    if kind == "line":                                # 1. как сейчас — чёрточка
        return [box((0.1, 0.03, 0.025), 0, MOUTH_Z, MOUTH)]
    if kind == "smile":                               # 2. улыбка
        return arc(0.13, 0.025, MOUTH)
    if kind == "grin":                                # 3. широкая улыбка с зубами
        p = [blob(0.075, 0, MOUTH_Z - 0.005, DARK, scale=(1, 0.35, 0.55), out=-0.012)]
        p.append(box((0.12, 0.02, 0.025), 0, MOUTH_Z + 0.012, TOOTH, out=0.004))
        return p
    if kind == "o":                                   # 4. удивление «О»
        p = [blob(0.04, 0, MOUTH_Z - 0.01, MOUTH, scale=(0.85, 0.45, 1.1))]
        p.append(blob(0.028, 0, MOUTH_Z - 0.01, DARK, scale=(0.85, 0.45, 1.1), out=0.006))
        return p
    if kind == "smirk":                               # 5. ухмылка (один уголок вверх)
        return arc(0.12, 0.012, MOUTH, tilt=0.018)
    if kind == "tongue":                              # 6. язык
        p = arc(0.12, 0.02, MOUTH)
        p.append(blob(0.032, 0.015, MOUTH_Z - 0.03, TONGUE, scale=(1, 0.55, 1.15), out=0.006))
        return p
    if kind == "buck":                                # 7. заячьи зубы
        p = arc(0.11, 0.012, MOUTH)
        for x in (-0.012, 0.012):
            p.append(box((0.021, 0.018, 0.032), x, MOUTH_Z - 0.018, TOOTH, out=0.006))
        return p
    if kind == "sad":                                 # 8. грустный
        return arc(0.12, -0.022, MOUTH, z0=MOUTH_Z - 0.01)
    if kind == "gold":                                # 9. улыбка с золотым зубом
        p = [blob(0.07, 0, MOUTH_Z - 0.004, DARK, scale=(1, 0.35, 0.5), out=-0.012)]
        for i in range(5):
            x = -0.044 + i * 0.022
            p.append(box((0.019, 0.02, 0.024), x, MOUTH_Z + 0.01, GOLD if i == 3 else TOOTH,
                         out=0.004))
        return p
    if kind == "straw":                               # 10. травинка в зубах
        p = [box((0.09, 0.03, 0.022), 0, MOUTH_Z, MOUTH)]
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.006, depth=0.2,
                                            location=(0.09, surface_y(0.04, MOUTH_Z) + 0.04,
                                                      MOUTH_Z + 0.02),
                                            rotation=(0, math.radians(75), math.radians(-30)))
        stem = bpy.context.object
        stem.data.materials.append(STRAW)
        p.append(stem)
        tip = blob(0.014, 0.0, MOUTH_Z, STRAW_TIP, scale=(1, 1, 2.2), out=0.0)
        tip.location = (0.175, surface_y(0.04, MOUTH_Z) + 0.09, MOUTH_Z + 0.05)
        p.append(tip)
        return p
    raise ValueError(kind)


KINDS = ["line", "smile", "grin", "o", "smirk", "tongue", "buck", "sad", "gold", "straw"]
for i, kind in enumerate(KINDS):
    before = set(bpy.data.objects)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=HEAD_R, location=HEAD_C)
    head = bpy.context.object
    head.scale = (1, HEAD_SY, HEAD_SY)
    head.data.materials.append(SKIN)
    for x in (-0.11, 0.11):
        e = blob(0.075, x, 1.37, WHITE, scale=(1, 0.5, 1.15), out=-0.03)
        e.location.y = 0.255
        pupil = blob(0.042, x, 1.36, BLACK, scale=(1, 0.5, 1.2))
        pupil.location.y = 0.29
    mouth(kind)
    new = [o for o in bpy.data.objects if o not in before]
    root = bpy.data.objects.new("H%d" % i, None)
    bpy.context.scene.collection.objects.link(root)
    for o in new:
        o.parent = root
    root.location = (1.7 - (i % 5) * 0.85, 0, -(i // 5) * 0.95)  # камера смотрит с +Y: слева направо
    bpy.ops.object.text_add(location=(root.location.x - 0.06, 0.3, root.location.z + 0.86))
    t = bpy.context.object
    t.data.body = str(i + 1)
    t.data.size = 0.16
    t.rotation_euler = (math.pi / 2, 0, math.pi)
    t.data.materials.append(BLACK)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1500, 700
scene.view_settings.view_transform = "Standard"
scene.world = bpy.data.worlds.new("W")
scene.world.color = (0.85, 0.83, 0.78)
sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN"))
sun.data.energy = 2.5
sun.rotation_euler = (math.radians(-60), 0, math.radians(200))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = 4.4
cam.location = (0, 6, 0.9)
cam.rotation_euler = (Vector((0, 0, 0.88)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
