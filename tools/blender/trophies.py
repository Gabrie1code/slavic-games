"""Кубки для экрана итогов: золотой, серебряный, бронзовый (значки с прозрачным фоном).

Запуск:
    python tools/blender/trophies.py assets/ui/icons assets/models/props
    -> cup_gold.png, cup_silver.png, cup_bronze.png (значки)
       и cup_gold.glb, cup_silver.glb, cup_bronze.glb (3D — персонажи держат их на пьедестале)
"""
import bpy, math, os, sys
from mathutils import Vector

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
GLB_OUT = sys.argv[2] if len(sys.argv) > 2 else None
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.cursor.location = (0, 0, 0)


def mat(name, color, rough, metal):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def flat(o, m, smooth=False):
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = smooth
    return o


def cup(metal_color, star_color):
    METAL = mat("Metal", metal_color, 0.22, 0.85)
    WOOD = mat("Base", (0.18, 0.09, 0.04), 0.5, 0.0)
    PLATE = mat("Plate", (0.95, 0.85, 0.5), 0.3, 0.8)
    parts = []
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.09, radius2=0.2, depth=0.26, location=(0, 0, 0.62))
    parts.append(flat(bpy.context.object, METAL, True))                         # чаша
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=12, radius=0.092, location=(0, 0, 0.49))
    bowl = bpy.context.object
    bowl.scale = (1, 1, 0.6)
    parts.append(flat(bowl, METAL, True))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.2, minor_radius=0.018, major_segments=32, minor_segments=8,
                                     location=(0, 0, 0.75))
    parts.append(flat(bpy.context.object, METAL, True))                         # кант
    for s in (-1, 1):                                                           # ручки
        bpy.ops.mesh.primitive_torus_add(major_radius=0.09, minor_radius=0.018, major_segments=20, minor_segments=8,
                                         location=(s * 0.19, 0, 0.62), rotation=(math.radians(90), 0, 0))
        parts.append(flat(bpy.context.object, METAL, True))
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.025, depth=0.14, location=(0, 0, 0.38))
    parts.append(flat(bpy.context.object, METAL, True))                         # ножка
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.045, location=(0, 0, 0.33))
    parts.append(flat(bpy.context.object, METAL, True))
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.12, radius2=0.04, depth=0.05, location=(0, 0, 0.29))
    parts.append(flat(bpy.context.object, METAL, True))
    bpy.ops.mesh.primitive_cube_add(location=(0, 0, 0.17))
    base = bpy.context.object
    base.scale = (0.15, 0.15, 0.1)
    parts.append(flat(base, WOOD))                                              # подставка
    bpy.ops.mesh.primitive_cube_add(location=(0, -0.151, 0.17))
    plate = bpy.context.object
    plate.scale = (0.09, 0.005, 0.045)
    parts.append(flat(plate, PLATE))                                            # табличка
    # Звезда на чаше.
    star = bpy.data.meshes.new("Star")
    verts = [(0, 0, 0)]
    for k in range(10):
        r = 0.055 if k % 2 == 0 else 0.024
        a = math.pi / 2 + k * math.pi / 5
        verts.append((math.cos(a) * r, 0, math.sin(a) * r))
    faces = [(0, 1 + k, 1 + (k + 1) % 10) for k in range(10)]
    star.from_pydata(verts, [], faces)
    so = bpy.data.objects.new("Star", star)
    bpy.context.collection.objects.link(so)
    so.location = (0, -0.16, 0.6)
    so.rotation_euler.x = math.radians(-12)
    parts.append(flat(so, mat("Star", star_color, 0.2, 0.4)))
    return parts


scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 256
scene.view_settings.view_transform = "Standard"
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.9, 0.92, 1.0, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 1.2
for loc, energy in (((-2, -3, 3), 400), ((3, -2, 1.5), 150)):
    light = bpy.data.objects.new("L", bpy.data.lights.new("L", "AREA"))
    light.data.energy = energy
    light.data.size = 2
    light.location = loc
    light.rotation_euler = (Vector((0, 0, 0.5)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(light)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 0.98
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (0.25, -2.5, 0.7)
cam.rotation_euler = (Vector((0, 0, 0.52)) - cam.location).to_track_quat("-Z", "Y").to_euler()
CUPS = (("gold", (1.0, 0.72, 0.15), (1.0, 0.95, 0.75)), ("silver", (0.82, 0.84, 0.88), (0.35, 0.42, 0.6)),
        ("bronze", (0.75, 0.42, 0.2), (1.0, 0.9, 0.7)))
for name, color, star in CUPS:
    parts = cup(color, star)
    scene.render.filepath = os.path.join(OUT, "cup_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    if GLB_OUT:
        bpy.ops.object.select_all(action="DESELECT")
        for o in parts:
            o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(GLB_OUT, "cup_%s.glb" % name),
                                  use_selection=True, export_format="GLB")
    for o in parts:
        bpy.data.objects.remove(o)
    print("CUP", name)
print("DONE")
