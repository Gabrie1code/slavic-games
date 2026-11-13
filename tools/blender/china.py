"""Фарфоровый сервиз для серванта и вещи на шкаф (низкополигонально):
  china_cup.glb     — чашка на блюдце (белый фарфор, кобальтовая «сетка» и золотой ободок);
  china_teapot.glb  — заварочный чайник;
  china_plate.glb   — тарелка на подставке (стоит на ребре);
  china_sugar.glb   — сахарница с крышкой;
  mantel_clock.glb  — настольные часы: корпус и циферблат (стрелки — в игре, по настоящему времени).
У всех точка (0,0,0) — на дне, лицом вещь смотрит на −Y (в Godot на +Z).

Запуск:
    python tools/blender/china.py assets/models/apartment
    python tools/blender/china.py assets/models/apartment --render   # + docs/previews/china.png
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


WHITE = mat("Porcelain", (0.95, 0.95, 0.93), 0.15)
COBALT = mat("Cobalt", (0.08, 0.18, 0.6), 0.2)
GOLD = mat("Gold", (0.95, 0.75, 0.3), 0.25, 0.9)
FUR = mat("Fur", (0.55, 0.35, 0.18), 0.9)
FUR_L = mat("FurLight", (0.8, 0.65, 0.45), 0.9)
EYE = mat("Eye", (0.03, 0.03, 0.03), 0.2)
RIBBON = mat("Ribbon", (0.8, 0.1, 0.12), 0.5)
WOOD = mat("ClockWood", (0.35, 0.16, 0.06), 0.4)
FACE = mat("ClockFace", (0.95, 0.92, 0.82), 0.5)
DARK = mat("ClockMarks", (0.1, 0.08, 0.06), 0.5)


def smooth(o, m):
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def cyl(r, h, z, m, r2=None, verts=16, loc=(0, 0), rot=(0, 0, 0)):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=(*loc, z), rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=(*loc, z),
                                        rotation=rot)
    return smooth(bpy.context.object, m)


def ball(r, loc, m, scale=(1, 1, 1), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    o.rotation_euler = rot
    return smooth(o, m)


def ring(major, minor, z, m, loc=(0, 0), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=20,
                                     minor_segments=6, location=(*loc, z), rotation=rot)
    return smooth(bpy.context.object, m)


def box(size, loc, m):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(m)
    return o


def export(name, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.context.scene.cursor.location = (0, 0, 0)                     # точка — на дне вещи
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True,
                              export_format="GLB")
    print("EXPORTED", name)
    return obj


made = []
# Чашка на блюдце.
P = [cyl(0.075, 0.012, 0.006, WHITE, r2=0.06), ring(0.068, 0.004, 0.012, GOLD),
     cyl(0.035, 0.07, 0.047, WHITE, r2=0.048), cyl(0.0485, 0.012, 0.072, COBALT, r2=0.049),
     ring(0.048, 0.003, 0.082, GOLD), ring(0.022, 0.006, 0.05, WHITE, loc=(0.055, 0), rot=(math.pi / 2, 0, 0))]
made.append(export("china_cup", P))
# Чайник.
P = [cyl(0.06, 0.02, 0.01, WHITE), ball(0.085, (0, 0, 0.085), WHITE, scale=(1, 1, 0.85)),
     ring(0.083, 0.005, 0.085, COBALT),
     cyl(0.04, 0.02, 0.155, WHITE, r2=0.045), ball(0.016, (0, 0, 0.175), GOLD),
     cyl(0.014, 0.1, 0.11, WHITE, r2=0.008, loc=(-0.11, 0), rot=(0, math.radians(-50), 0)),
     ring(0.035, 0.008, 0.095, WHITE, loc=(0.09, 0), rot=(math.pi / 2, 0, 0))]
made.append(export("china_teapot", P))
# Тарелка на подставке: стоит на ребре лицом вперёд (−Y), сзади ножка-упор.
P = [cyl(0.1, 0.012, 0.11, WHITE, verts=24, rot=(math.pi / 2, 0, 0)),
     ring(0.085, 0.007, 0.11, COBALT, rot=(math.pi / 2, 0, 0)), ring(0.1, 0.004, 0.11, GOLD, rot=(math.pi / 2, 0, 0)),
     ball(0.03, (0, -0.008, 0.11), COBALT, scale=(1, 0.2, 1)),
     box((0.12, 0.08, 0.008), (0, 0.01, 0.004), WOOD), box((0.01, 0.01, 0.1), (0, 0.04, 0.05), WOOD)]
made.append(export("china_plate", P))
# Сахарница.
P = [cyl(0.04, 0.015, 0.0075, WHITE), cyl(0.055, 0.08, 0.055, WHITE, r2=0.045),
     ring(0.052, 0.005, 0.06, COBALT), cyl(0.05, 0.015, 0.1, WHITE, r2=0.03), ball(0.012, (0, 0, 0.115), GOLD)]
for s in (-1, 1):
    P.append(ring(0.02, 0.005, 0.07, WHITE, loc=(s * 0.055, 0), rot=(math.pi / 2, 0, 0)))
made.append(export("china_sugar", P))

# Плюшевый мишка — отдельно: tools/blender/teddy.py (гладкий, «вязаный»).

# Настольные часы: корпус «домиком», круглый циферблат с метками (стрелки — в игре).
P = [box((0.32, 0.12, 0.2), (0, 0, 0.1), WOOD), cyl(0.12, 0.12, 0.2, WOOD, verts=24, rot=(math.pi / 2, 0, 0)),
     box((0.36, 0.14, 0.02), (0, 0, 0.01), WOOD),
     cyl(0.095, 0.01, 0.17, FACE, verts=24, loc=(0, -0.062), rot=(math.pi / 2, 0, 0)),
     ring(0.1, 0.008, 0.17, GOLD, loc=(0, -0.066), rot=(math.pi / 2, 0, 0))]
for k in range(12):                                                         # метки часов — точки
    a = k / 12 * math.tau
    r = 0.078
    P.append(ball(0.008 if k % 3 == 0 else 0.005, (math.sin(a) * r, -0.068, 0.17 + math.cos(a) * r), DARK,
                  scale=(1, 0.4, 1)))
for x in (-0.13, 0.13):
    P.append(ball(0.02, (x, 0, 0.0), GOLD))
made.append(export("mantel_clock", P))

if not RENDER:
    sys.exit(0)
scene = bpy.context.scene
for i, o in enumerate(made):
    o.location = (i * 0.3 - 0.75, 0, 0)
bpy.ops.mesh.primitive_plane_add(size=4)
bpy.context.object.data.materials.append(mat("Shelf", (0.28, 0.12, 0.04), 0.4))
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1400, 500
scene.view_settings.view_transform = "Standard"
scene.world = bpy.data.worlds.new("W")
scene.world.color = (0.45, 0.45, 0.47)
sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN"))
sun.data.energy = 2.5
sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (0.0, -2.3, 0.8)
cam.rotation_euler = (Vector((0.0, 0, 0.12)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.filepath = os.path.abspath("docs/previews/china.png")
bpy.ops.render.render(write_still=True)
