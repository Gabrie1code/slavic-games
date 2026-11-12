"""Модели для доски: игральный кубик и бутылочка для развилок.

Кубик: грани в осях Godot — 1: +Z (к камере при нулевом повороте), 6: −Z,
2: +X, 5: −X, 3: +Y (верх), 4: −Y (низ). Противоположные грани дают в сумме 7.
Бутылочка лежит вдоль оси Z, горлышко смотрит в −Z Godot (вперёд).

Запуск:
    python tools/blender/board_props.py assets/models/props           # .glb
    python tools/blender/board_props.py assets/models/props --render  # + превью
"""
import bpy, math, sys, os
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else "."
RENDER = "--render" in sys.argv
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, rough=0.5, metal=0.0, alpha=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    return m


def finish(o, m, bevel=0.0, segs=2):
    o.data.materials.append(m)
    if bevel:
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segs
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def join(name, parts):
    for o in parts:
        for mod in list(o.modifiers):
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    return obj


def export(obj, name):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True,
                              export_format="GLB", export_draco_mesh_compression_enable=False)
    print("EXPORTED", name)


# ---------------- Кубик ----------------
S = 0.5                       # ребро
H = S / 2
WHITE = mat("DiceWhite", (0.95, 0.93, 0.86), 0.4)
PIP = mat("DicePip", (0.05, 0.05, 0.06), 0.5)
PIP_RED = mat("DicePipRed", (0.8, 0.05, 0.04), 0.5)

bpy.ops.mesh.primitive_cube_add(size=S)
parts = [finish(bpy.context.object, WHITE, bevel=0.07, segs=3)]

# Грани в координатах Blender (Godot +Z = Blender −Y, Godot +Y = Blender +Z).
FACES = {
    1: (Vector((0, -1, 0)), Vector((1, 0, 0)), Vector((0, 0, 1))),
    6: (Vector((0, 1, 0)), Vector((-1, 0, 0)), Vector((0, 0, 1))),
    2: (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))),
    5: (Vector((-1, 0, 0)), Vector((0, -1, 0)), Vector((0, 0, 1))),
    3: (Vector((0, 0, 1)), Vector((1, 0, 0)), Vector((0, 1, 0))),
    4: (Vector((0, 0, -1)), Vector((1, 0, 0)), Vector((0, -1, 0))),
}
LAYOUT = {
    1: [(0, 0)],
    2: [(-1, -1), (1, 1)],
    3: [(-1, -1), (0, 0), (1, 1)],
    4: [(-1, -1), (-1, 1), (1, -1), (1, 1)],
    5: [(-1, -1), (-1, 1), (0, 0), (1, -1), (1, 1)],
    6: [(-1, -1), (-1, 0), (-1, 1), (1, -1), (1, 0), (1, 1)],
}
for value, (n, u, v) in FACES.items():
    for a, b in LAYOUT[value]:
        pos = n * (H - 0.006) + u * a * 0.13 + v * b * 0.13
        r = 0.065 if value == 1 else 0.045
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=r, location=pos)
        pip = bpy.context.object
        # Сплющить точку вдоль нормали грани.
        pip.scale = Vector((1, 1, 1)) - Vector((abs(n.x), abs(n.y), abs(n.z))) * 0.7
        bpy.ops.object.transform_apply(scale=True)
        parts.append(finish(pip, PIP_RED if value == 1 else PIP))
dice = join("Dice", parts)
export(dice, "dice")

# ---------------- Бутылочка ----------------
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()
GLASS = mat("BottleGlass", (0.1, 0.45, 0.2), 0.1, 0.0)
LABEL = mat("BottleLabel", (0.92, 0.85, 0.6), 0.6)
CAP = mat("BottleCap", (0.85, 0.75, 0.35), 0.3, 0.8)
parts = []
# Корпус вдоль оси Y Blender: горлышко в +Y Blender = −Z Godot.
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.11, depth=0.42, location=(0, -0.08, 0),
                                    rotation=(math.radians(90), 0, 0))
parts.append(finish(bpy.context.object, GLASS))
bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.11, radius2=0.045, depth=0.12, location=(0, 0.19, 0),
                                rotation=(math.radians(-90), 0, 0))
parts.append(finish(bpy.context.object, GLASS))
bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.045, depth=0.16, location=(0, 0.32, 0),
                                    rotation=(math.radians(90), 0, 0))
parts.append(finish(bpy.context.object, GLASS))
bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.05, depth=0.03, location=(0, 0.41, 0),
                                    rotation=(math.radians(90), 0, 0))
parts.append(finish(bpy.context.object, CAP))
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.113, depth=0.18, location=(0, -0.08, 0),
                                    rotation=(math.radians(90), 0, 0))
parts.append(finish(bpy.context.object, LABEL))
bottle = join("Bottle", parts)
export(bottle, "bottle")

if not RENDER:
    print("DONE")
    sys.exit(0)

scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, "dice.glb"))
d = bpy.context.selected_objects[0]
d.location = (-0.5, 0, 0.4)
d.rotation_euler = (math.radians(25), 0, math.radians(35))
bottle.location = (0.5, 0, 0.12)
bottle.rotation_euler.z = math.radians(-30)
bpy.ops.mesh.primitive_plane_add(size=10, location=(0, 0, 0))
bpy.context.object.data.materials.append(mat("Ground", (0.4, 0.4, 0.4), 0.9))
ld = bpy.data.lights.new("L", "AREA")
ld.energy, ld.size = 300, 3
lo = bpy.data.objects.new("L", ld)
lo.location = (-1.5, -2.5, 3)
scene.collection.objects.link(lo)
lo.rotation_euler = (Vector((0, 0, 0.3)) - lo.location).to_track_quat("-Z", "Y").to_euler()
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.5
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (0, -2.6, 1.4)
cam.rotation_euler = (Vector((0, 0, 0.25)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.engine = "CYCLES"
scene.cycles.samples = 64
scene.render.resolution_x, scene.render.resolution_y = 1000, 600
scene.view_settings.view_transform = "AgX"
scene.render.filepath = os.path.join(OUT, "_preview_board_props.png")
bpy.ops.render.render(write_still=True)
print("DONE")
