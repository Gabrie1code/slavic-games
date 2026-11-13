"""Плюшевый мишка для шкафа в серванте — гладкий и «вязаный» (по примеру владельца):
все части — шары с большим числом граней и сглаживанием (как майка и молоток), сверху рельеф
вязки — карта нормалей assets/textures/knit_normal.png (tools/textures/knit_normal.py).
Большая круглая голова, выпуклая мордочка, треугольный нос и шов-ротик, блестящие глазки,
круглые ушки, руки вдоль тела, толстые ноги вперёд. Точка (0,0,0) — на дне, лицом на −Y.

Запуск:
    python tools/blender/teddy.py assets/models/apartment [--render превью.png]
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else "."
RENDER = sys.argv[sys.argv.index("--render") + 1] if "--render" in sys.argv else None
KNIT = os.path.abspath("assets/textures/knit_normal.png")
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, rough, knit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes = m.node_tree.nodes
    b = nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    if knit:                                                # рельеф вязки
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(KNIT)
        tex.image.colorspace_settings.name = "Non-Color"
        nmap = nodes.new("ShaderNodeNormalMap")
        nmap.inputs["Strength"].default_value = knit
        m.node_tree.links.new(tex.outputs["Color"], nmap.inputs["Color"])
        m.node_tree.links.new(nmap.outputs["Normal"], b.inputs["Normal"])
    return m


FUR = mat("TeddyFur", (0.3, 0.17, 0.08), 0.95, knit=0.8)
FUR_L = mat("TeddyMuzzle", (0.38, 0.23, 0.11), 0.95, knit=0.8)
FUR_D = mat("TeddyEarInside", (0.22, 0.12, 0.06), 0.95, knit=0.6)
NOSE = mat("TeddyNose", (0.08, 0.05, 0.04), 0.35)
EYE = mat("TeddyEye", (0.01, 0.01, 0.01), 0.08)


def ball(r, loc, m, scale=(1, 1, 1), rot=(0, 0, 0), segs=32, rings=16):
    """Гладкий шар/эллипсоид: много граней, сглаживание, поворот и масштаб — в вершины."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r, location=loc,
                                         rotation=rot)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def limb(a, b, r, m, flat=1.0):
    """Гладкая «колбаска» от точки a до точки b (рука от плеча до лапы): эллипсоид вдоль отрезка."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=r, location=(a + b) / 2)
    o = bpy.context.object
    o.scale = (flat, 1.0, (d.length / 2 + r * 0.6) / r)
    # location=False: иначе Blender переносит точку в центр мира, и поворот уводит руку под пол.
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def rod(a, b, r, m):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=r, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(rotation=True)
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


# Пропорции сверены с исходником владельца (bears.fbx — только как образец, в игру не идёт):
# голова крупнее тела, мордочка — овальная «площадка» вперёд, ушки-«чашечки», руки толще и
# длиннее (до бёдер), ноги разведены в стороны носками наружу.
P = [ball(0.076, (0, 0, 0.098), FUR, scale=(1, 0.88, 1.1)),               # тело-«груша»
     ball(0.083, (0, 0.006, 0.066), FUR, scale=(1, 0.9, 0.8)),              # низ тела шире
     ball(0.083, (0, -0.012, 0.235), FUR, scale=(1.06, 0.95, 0.96)),        # голова (крупная)
     ball(0.036, (0, -0.074, 0.208), FUR_L, scale=(1.2, 0.72, 0.8)),        # мордочка-овал
     ball(0.013, (0, -0.1, 0.217), NOSE, scale=(1.45, 0.7, 0.85), segs=20, rings=10),
     rod((0, -0.1, 0.21), (0, -0.098, 0.192), 0.0018, NOSE)]                # шов-ротик
for s in (-1, 1):
    P += [ball(0.0085, (s * 0.032, -0.08, 0.25), EYE, segs=16, rings=8),     # блестящий глаз
          ball(0.03, (s * 0.066, 0.004, 0.298), FUR, scale=(1, 0.5, 1)),     # ухо
          ball(0.02, (s * 0.066, -0.009, 0.296), FUR_D, scale=(1, 0.3, 1), segs=20, rings=10),
          # Рука растёт из плеча (круглое плечо вливается в тело) и идёт вниз-вперёд к бедру.
          ball(0.02, (s * 0.066, -0.01, 0.162), FUR),                           # плечо (небольшое)
          limb((s * 0.076, -0.012, 0.163), (s * 0.1, -0.048, 0.072), 0.031, FUR, flat=0.95),
          ball(0.047, (s * 0.052, -0.054, 0.044), FUR, scale=(0.95, 1.42, 0.88),  # бедро
               rot=(0, 0, math.radians(s * -14))),
          ball(0.042, (s * 0.068, -0.11, 0.046), FUR, scale=(0.92, 0.72, 1.05))]  # ступня
bpy.ops.object.select_all(action="DESELECT")
for o in P:
    o.select_set(True)
bpy.context.view_layer.objects.active = P[0]
bpy.ops.object.join()
bear = bpy.context.object
bear.name = "TeddyBear"
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "teddy_bear.glb"), use_selection=True,
                          export_format="GLB")
print("EXPORTED teddy_bear", len(bear.data.polygons), "faces")

if RENDER:
    sc = bpy.context.scene
    copies = []
    for i, yaw in enumerate((0, 40, 100)):
        c = bear.copy()
        sc.collection.objects.link(c)
        c.location.x = i * 0.32
        c.rotation_euler.z = math.radians(yaw)
        copies.append(c)
    bear.hide_render = True
    bpy.ops.mesh.primitive_plane_add(size=6, location=(0.32, 0, 0))
    bpy.context.object.data.materials.append(mat("Floor", (0.45, 0.45, 0.47), 0.8))
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 48
    sc.render.resolution_x, sc.render.resolution_y = 1200, 520
    sc.view_settings.view_transform = "Standard"
    sc.world = bpy.data.worlds.new("W")
    sc.world.color = (0.55, 0.55, 0.57)
    sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.0
    cam.location = (0.32, -2.5, 0.55)
    cam.rotation_euler = (Vector((0.32, 0, 0.14)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.abspath(RENDER)
    bpy.ops.render.render(write_still=True)
