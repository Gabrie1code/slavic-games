"""Наша валюта: монета-рубль и фишки игры на рубли (модели + картинки-значки для интерфейса).

Запуск:
    python tools/blender/currency.py assets
    -> assets/models/props/ruble_coin.glb, chip_10.glb, chip_50.glb, chip_100.glb, chip_500.glb
    -> assets/ui/icons/ruble.png, chip_10.png, chip_50.png, chip_100.png, chip_500.png
"""
import bpy, math, sys, os
from mathutils import Vector

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
MODELS = os.path.join(ROOT, "models", "props")
ICONS = os.path.join(ROOT, "ui", "icons")
os.makedirs(MODELS, exist_ok=True)
os.makedirs(ICONS, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
_mats = {}


def mat(name, color, rough=0.4, metal=0.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    _mats[name] = m
    return m


def flat(o, m):
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def cyl(r, h, loc, m, verts=24, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    return flat(bpy.context.object, m)


def box(size, loc, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    return flat(o, m)


def ruble_sign(z, size, m, depth=0.004):
    """Знак ₽ из простых форм, лежит на плоскости z (смотрит вверх)."""
    s = size
    parts = [box((0.16 * s, 0.9 * s, depth), (-0.12 * s, 0, z), m)]                   # ножка
    bpy.ops.mesh.primitive_torus_add(major_radius=0.2 * s, minor_radius=0.075 * s, major_segments=16,
                                     minor_segments=4, location=(0.02 * s, 0.22 * s, z))
    bowl = bpy.context.object
    bowl.scale.z = depth / (0.15 * s)
    bpy.ops.object.transform_apply(scale=True)
    parts.append(flat(bowl, m))
    # Перекладина чуть толще ножки: иначе совпадающие грани дают чёрную точку.
    parts.append(box((0.55 * s, 0.13 * s, depth + 0.002), (-0.02 * s, -0.12 * s, z + 0.0005), m))
    return parts


def join(name, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    return o


def export(o, name):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(MODELS, name + ".glb"), use_selection=True,
                              export_format="GLB", export_draco_mesh_compression_enable=False)
    print("EXPORTED", name)


# ---------------- Монета ----------------
BRASS = mat("Brass", (0.95, 0.7, 0.25), 0.25, 1.0)
BRASS_D = mat("BrassDark", (0.6, 0.38, 0.1), 0.35, 1.0)
R, T = 0.1, 0.02
P = [cyl(R, T, (0, 0, 0), BRASS, verts=32)]
bpy.ops.mesh.primitive_torus_add(major_radius=R * 0.86, minor_radius=0.006, major_segments=32, minor_segments=4,
                                 location=(0, 0, T / 2))
P.append(flat(bpy.context.object, BRASS_D))                                              # ободок
for i in range(12):                                                                       # лучи-звезда
    a = i * math.pi / 6
    P.append(box((0.012, 0.03, 0.003), (math.cos(a) * R * 0.66, math.sin(a) * R * 0.66, T / 2 + 0.001),
                 BRASS_D, rot=(0, 0, a + math.pi / 2)))
P += ruble_sign(T / 2 + 0.002, R * 0.95, BRASS_D)
coin = join("RubleCoin", P)
export(coin, "ruble_coin")

# ---------------- Фишки ----------------
CHIPS = {10: (0.92, 0.92, 0.9), 50: (0.75, 0.08, 0.06), 100: (0.1, 0.25, 0.65), 500: (0.08, 0.08, 0.09)}
chips = {}
for value, color in CHIPS.items():
    base = mat("Chip%d" % value, color, 0.45)
    edge = mat("ChipEdge", (0.96, 0.94, 0.88), 0.45) if value != 10 else mat("ChipEdge10", (0.75, 0.08, 0.06), 0.45)
    gold = mat("ChipGold", (0.95, 0.75, 0.3), 0.3, 1.0)
    cr, ct = 0.11, 0.025
    P = [cyl(cr, ct, (0, 0, 0), base, verts=32)]
    for i in range(8):                                                                    # насечки по краю
        a = i * math.pi / 4
        P.append(box((0.04, 0.012, ct + 0.002), (math.cos(a) * (cr - 0.004), math.sin(a) * (cr - 0.004), 0),
                     edge, rot=(0, 0, a + math.pi / 2)))
    P.append(cyl(cr * 0.62, ct + 0.002, (0, 0, 0), edge, verts=32))                      # вставка
    P.append(cyl(cr * 0.55, ct + 0.004, (0, 0, 0), base, verts=32))
    P += ruble_sign(ct / 2 + 0.004, cr * 0.7, gold)
    chips[value] = join("Chip%d" % value, P)
    export(chips[value], "chip_%d" % value)

# ---------------- Значки (прозрачный фон) ----------------
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 256
scene.view_settings.view_transform = "Standard"
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
sun = bpy.data.lights.new("Sun", "SUN")
sun.energy = 3.5
so = bpy.data.objects.new("Sun", sun)
so.rotation_euler = (0.5, 0.2, 0.6)
scene.collection.objects.link(so)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 0.26
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (0, -0.25, 0.42)
cam.rotation_euler = (Vector((0, 0, 0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
everything = [coin] + list(chips.values())
for o in everything:
    o.hide_render = True
for o, name in [(coin, "ruble")] + [(chips[v], "chip_%d" % v) for v in CHIPS]:
    o.hide_render = False
    o.location = (0, 0, 0)
    scene.render.filepath = os.path.join(ICONS, name + ".png")
    bpy.ops.render.render(write_still=True)
    o.hide_render = True
    print("ICON", name)
print("DONE")
