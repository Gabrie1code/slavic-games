"""Тумбочка с выдвижным ящиком и баллончик с краской (для спальни лобби).

  nightstand_body.glb   — корпус с пустой нишей под ящик (размеры как у старой nightstand.glb);
  nightstand_drawer.glb — ящик: лицевая панель с ручкой + лоток (выдвигается вперёд, по −Y);
  spray_can.glb         — баллончик: корпус, белая полоса, колпачок, распылитель;
  drawer_joke.glb       — шутка на 10%: тёмно-розовый «предмет» и наручники (лежат в ящике).

Запуск:
    python tools/blender/nightstand.py assets/models/apartment
    python tools/blender/nightstand.py assets/models/apartment --render   # + docs/previews/nightstand.png
"""
import bpy, math, os, sys
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else "."
RENDER = "--render" in sys.argv
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, rough=0.5, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


WOOD = mat("WoodPolish", (0.28, 0.12, 0.04), 0.35)
WOOD_L = mat("WoodLight", (0.55, 0.33, 0.14), 0.5)
INSIDE = mat("WoodInside", (0.4, 0.24, 0.1), 0.7)
METAL = mat("Metal", (0.75, 0.75, 0.78), 0.3, 1.0)
RED = mat("CanRed", (0.75, 0.08, 0.06), 0.35, 0.3)
WHITE = mat("CanWhite", (0.92, 0.92, 0.9), 0.4)
BLACK = mat("CanBlack", (0.05, 0.05, 0.05), 0.5)


def box(size, loc, m, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        mod = o.modifiers.new("B", "BEVEL")
        mod.width = bevel
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier="B")
    o.data.materials.append(m)
    return o


def cyl(r, h, loc, m, verts=16, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    o = bpy.context.object
    o.data.materials.append(m)
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
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True,
                              export_format="GLB")
    print("EXPORTED", name)
    return obj


# Корпус 0.45 × 0.4 × 0.55 (низ на 0.025), ниша под ящик спереди: z 0.33..0.51.
body = export("nightstand_body", [
    box((0.45, 0.4, 0.31), (0, 0, 0.025 + 0.155), WOOD, bevel=0.01),       # низ
    box((0.45, 0.4, 0.06), (0, 0, 0.545), WOOD, bevel=0.01),               # крышка
    box((0.03, 0.4, 0.2), (-0.21, 0, 0.42), WOOD),                         # боковины ниши
    box((0.03, 0.4, 0.2), (0.21, 0, 0.42), WOOD),
    box((0.39, 0.02, 0.2), (0, 0.19, 0.42), INSIDE),                       # задняя стенка ниши
    box((0.4, 0.02, 0.16), (0, -0.205, 0.17), WOOD_L),                     # нижняя филёнка
])

# Ящик: лицевая панель (как была на тумбочке) + лоток внутри корпуса.
drawer = export("nightstand_drawer", [
    box((0.4, 0.02, 0.18), (0, -0.205, 0.42), WOOD_L),
    cyl(0.015, 0.02, (0, -0.22, 0.42), METAL, verts=8, rot=(math.radians(90), 0, 0)),
    box((0.36, 0.36, 0.01), (0, -0.02, 0.34), INSIDE),                     # дно
    box((0.01, 0.36, 0.12), (-0.175, -0.02, 0.4), INSIDE),                 # бортики
    box((0.01, 0.36, 0.12), (0.175, -0.02, 0.4), INSIDE),
    box((0.36, 0.01, 0.12), (0, 0.155, 0.4), INSIDE),
])

# Баллончик стоит на донышке (z = 0), высота ~0.2.
can = export("spray_can", [
    cyl(0.033, 0.15, (0, 0, 0.075), RED, verts=16),
    cyl(0.0335, 0.04, (0, 0, 0.09), WHITE, verts=16),
    cyl(0.026, 0.03, (0, 0, 0.165), METAL, verts=12),
    cyl(0.01, 0.015, (0, 0, 0.187), BLACK, verts=8),
    cyl(0.003, 0.012, (0, -0.012, 0.19), BLACK, verts=6, rot=(math.radians(90), 0, 0)),
])

# Шутка: продолговатый тёмно-розовый предмет (скруглённый, на «подставке») и наручники.
PINK = mat("JokePink", (0.55, 0.08, 0.28), 0.35)
STEEL = mat("Steel", (0.7, 0.7, 0.72), 0.25, 1.0)
bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.022, depth=0.13, location=(0, 0, 0.022),
                                    rotation=(0, math.radians(90), 0))
joke = [bpy.context.object]
joke[0].data.materials.append(PINK)
bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=8, radius=0.023, location=(0.065, 0, 0.022))
joke.append(bpy.context.object)
joke[-1].data.materials.append(PINK)
joke.append(cyl(0.032, 0.016, (-0.07, 0, 0.022), PINK, verts=14, rot=(0, math.radians(90), 0)))
for o in joke:
    for p in o.data.polygons:
        p.use_smooth = True
for x in (-0.03, 0.05):                                                     # наручники
    bpy.ops.mesh.primitive_torus_add(major_radius=0.03, minor_radius=0.005, major_segments=16,
                                     minor_segments=6, location=(x, 0.07, 0.005))
    bpy.context.object.data.materials.append(STEEL)
    joke.append(bpy.context.object)
for k in range(3):
    bpy.ops.mesh.primitive_torus_add(major_radius=0.007, minor_radius=0.002, major_segments=8,
                                     minor_segments=4, location=(0.0 + k * 0.01, 0.07, 0.006),
                                     rotation=(math.radians(90 * (k % 2)), 0, 0))
    bpy.context.object.data.materials.append(STEEL)
    joke.append(bpy.context.object)
joke_obj = export("drawer_joke", joke)

if not RENDER:
    sys.exit(0)
scene = bpy.context.scene
drawer.location.y = -0.25                     # выдвинутый ящик
can.location = (0.0, -0.27, 0.36)
joke_obj.location = (0.9, -0.6, 0.0)
can.rotation_euler = (0, math.radians(90), 0.3)
bpy.ops.mesh.primitive_plane_add(size=4)
bpy.context.object.data.materials.append(mat("Floor", (0.4, 0.28, 0.17), 0.8))
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 900, 700
scene.view_settings.view_transform = "Standard"
scene.world = bpy.data.worlds.new("W")
scene.world.color = (0.35, 0.35, 0.37)
sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN"))
sun.data.energy = 2.5
sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (0.9, -1.3, 1.1)
cam.rotation_euler = (Vector((0, -0.1, 0.35)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.filepath = os.path.abspath("docs/previews/nightstand.png")
bpy.ops.render.render(write_still=True)
