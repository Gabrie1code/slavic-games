"""Советский унитаз-компакт для туалета в квартире-лобби.

Отдельные объекты (Godot находит их по именам):
  ToiletBody  — чаша, ободок, сиденье, бачок, ножка (одним куском);
  Lid         — крышка, точка поворота на петле (открывается поворотом вокруг X);
  Water       — вода в чаше (цвет меняется в игре: голубая → жёлтая → после смыва голубая);
  FlushButton — кнопка смыва на крышке бачка.
Задняя стенка бачка — в начале координат (ставится вплотную к стене), смотрит на −Y (в Godot +Z).

Запуск:
    python tools/blender/toilet.py assets/models/apartment            # .glb
    python tools/blender/toilet.py assets/models/apartment --render   # + превью docs/previews/toilet.png
"""
import bpy, math, os, sys
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else "."
RENDER = "--render" in sys.argv
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, rough=0.4, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


PORCELAIN = mat("Porcelain", (0.93, 0.93, 0.9), 0.25)
SEAT = mat("Seat", (0.95, 0.94, 0.9), 0.4)
CHROME = mat("Chrome", (0.86, 0.87, 0.9), 0.22, 0.35) # не чистый металл — иначе в игре чёрный
WATER = mat("Water", (0.45, 0.75, 0.95), 0.05)
SHADOW = mat("BowlInside", (0.82, 0.83, 0.82), 0.3)

BOWL_Y = -0.40          # центр чаши
STRETCH = 1.25          # чаша вытянута вперёд (овал)
HINGE = Vector((0, -0.235, 0.445))


def finish(o, m, name=None, smooth=True):
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = smooth
    if name:
        o.name = name
    return o


def cone(r1, r2, z0, z1, m, y=BOWL_Y, caps="NOTHING", verts=24, stretch=STRETCH):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=z1 - z0,
                                    location=(0, y, (z0 + z1) / 2), end_fill_type=caps)
    o = bpy.context.object
    o.scale = (1, stretch, 1)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m)


def torus(major, minor, z, m, flat=1.0):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=28,
                                     minor_segments=8, location=(0, BOWL_Y, z))
    o = bpy.context.object
    o.scale = (1, STRETCH, flat)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m)


def box(size, loc, m, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        mod = o.modifiers.new("B", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier="B")
    return finish(o, m, smooth=False)


body = [
    cone(0.12, 0.10, 0.0, 0.16, PORCELAIN, caps="NGON", stretch=1.15),     # ножка
    cone(0.12, 0.2, 0.12, 0.4, PORCELAIN),                                  # чаша снаружи
    cone(0.05, 0.15, 0.2, 0.4, SHADOW),                                     # чаша внутри
    torus(0.175, 0.026, 0.4, PORCELAIN),                                    # ободок
    torus(0.17, 0.034, 0.428, SEAT, flat=0.45),                             # сиденье
    box((0.44, 0.18, 0.36), (0, -0.09, 0.6), PORCELAIN, bevel=0.03),         # бачок
    box((0.47, 0.2, 0.03), (0, -0.09, 0.795), PORCELAIN, bevel=0.01),        # крышка бачка
    box((0.12, 0.08, 0.12), (0, -0.2, 0.36), PORCELAIN),                     # горловина к чаше
]
for i, s in enumerate((-1, 1)):                                              # петли крышки
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.016, depth=0.05,
                                        location=(s * 0.09, HINGE.y, HINGE.z),
                                        rotation=(0, math.radians(90), 0))
    body.append(finish(bpy.context.object, CHROME))
bpy.ops.object.select_all(action="DESELECT")
for o in body:
    o.select_set(True)
bpy.context.view_layer.objects.active = body[0]
bpy.ops.object.join()
toilet = bpy.context.object
toilet.name = "ToiletBody"

# Крышка: овал над сиденьем, точка поворота — на петле.
bpy.ops.mesh.primitive_cylinder_add(vertices=28, radius=0.19, depth=0.022, location=(0, BOWL_Y, 0.452))
lid = bpy.context.object
lid.scale = (1, 1.2, 1)
bpy.ops.object.transform_apply(scale=True)
finish(lid, SEAT, "Lid")
bpy.context.scene.cursor.location = HINGE
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

# Вода — плоский овал внутри чаши.
bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.105, depth=0.004, location=(0, BOWL_Y + 0.01, 0.3))
water = bpy.context.object
water.scale = (1, STRETCH, 1)
bpy.ops.object.transform_apply(scale=True)
finish(water, WATER, "Water")

bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.032, depth=0.02, location=(0, -0.09, 0.82))
finish(bpy.context.object, CHROME, "FlushButton")

parts = [toilet, lid, water, bpy.data.objects["FlushButton"]]
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "toilet.glb"), use_selection=True,
                          export_format="GLB")
print("EXPORTED toilet", sum(len(p.data.polygons) for p in parts), "faces")

if not RENDER:
    sys.exit(0)

# ---------- Превью: крышка закрыта и открыта, вода голубая и жёлтая ----------
scene = bpy.context.scene
copies = []
for o in parts:
    c = o.copy()
    c.data = o.data.copy()
    scene.collection.objects.link(c)
    c.location.x += 1.0
    copies.append(c)
copies[1].rotation_euler.x = math.radians(-92)       # открытая крышка (опирается на бачок)
yellow = WATER.copy()
yellow.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.95, 0.8, 0.2, 1)
copies[2].data.materials[0] = yellow
bpy.ops.mesh.primitive_plane_add(size=6, location=(0.5, -1, 0))
finish(bpy.context.object, mat("Floor", (0.75, 0.8, 0.85), 0.6), smooth=False)
bpy.ops.mesh.primitive_plane_add(size=6, location=(0.5, 0.01, 1.5), rotation=(math.pi / 2, 0, 0))
finish(bpy.context.object, mat("Wall", (0.55, 0.72, 0.75), 0.8), smooth=False)
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1100, 700
scene.view_settings.view_transform = "Standard"
scene.world = bpy.data.worlds.new("W")
scene.world.color = (0.35, 0.35, 0.37)
sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN"))
sun.data.energy = 1.6
sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (1.6, -2.2, 1.4)
cam.rotation_euler = (Vector((0.5, -0.3, 0.45)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.filepath = os.path.abspath("docs/previews/toilet.png")
bpy.ops.render.render(write_still=True)
