"""Наша валюта: пачка рублей (как пачка денег, выпадающая в боевиках, но в нашем стиле) и фишки
игры на рубли (модели + картинки-значки для интерфейса).
Знак ₽ — настоящая буква из шрифта DejaVu Sans Bold (выдавлена в 3D), без наслоений.

Запуск:
    python tools/blender/currency.py assets
    -> assets/models/props/money_stack.glb, chip_10.glb, chip_50.glb, chip_100.glb, chip_500.glb
    -> assets/ui/icons/ruble.png (пачка), chip_10.png, chip_50.png, chip_100.png, chip_500.png
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


FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def ruble_sign(z, size, m, depth=0.004, rot_z=0.0, loc=(0, 0)):
    """Знак ₽ из шрифта: высота size, лежит на плоскости z (смотрит вверх)."""
    curve = bpy.data.curves.new("Rub", "FONT")
    curve.body = "\u20bd"
    curve.font = bpy.data.fonts.load(FONT, check_existing=True)
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.size = size * 1.35
    curve.extrude = depth / 2
    o = bpy.data.objects.new("Rub", curve)
    bpy.context.collection.objects.link(o)
    o.location = (loc[0], loc[1], z + depth / 2)
    o.rotation_euler.z = rot_z
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return [flat(o, m)]


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


# ---------------- Пачка денег ----------------
# Купюры светло-зелёные (как старые рубли), пачка перехвачена бумажной лентой с ₽.
BILL = mat("Bill", (0.36, 0.6, 0.32), 0.7)
BILL_EDGE = mat("BillEdge", (0.78, 0.86, 0.68), 0.8)
BILL_INK = mat("BillInk", (0.12, 0.3, 0.14), 0.6)
BAND = mat("Band", (0.96, 0.93, 0.85), 0.7)
BAND_RED = mat("BandRed", (0.75, 0.12, 0.1), 0.6)
L, W, H = 0.16, 0.075, 0.045
P = [box((L, W, H), (0, 0, H / 2), BILL_EDGE)]                       # торцы — светлые листы
P.append(box((L - 0.004, W - 0.004, H + 0.002), (0, 0, H / 2), BILL))  # бока чуть темнее
for k in range(4):                                                    # «листы» на торце
    P.append(box((L + 0.001, 0.002, 0.0015), (0, W / 2, 0.006 + k * 0.007), BILL_INK))
# Верхняя купюра чуть сдвинута — пачка не идеальная.
P.append(box((L, W, 0.003), (0.006, 0.002, H + 0.0015), BILL, rot=(0, 0, 0.05)))
P.append(box((L - 0.02, W - 0.016, 0.001), (0.006, 0.002, H + 0.0035), BILL_INK, rot=(0, 0, 0.05)))
P.append(box((L - 0.026, W - 0.022, 0.0012), (0.006, 0.002, H + 0.0038), BILL, rot=(0, 0, 0.05)))
P.append(cyl(0.017, 0.0014, (0.05, 0.004, H + 0.0042), BILL_INK, verts=16))  # медальон
# Бумажная лента посередине.
P.append(box((0.04, W + 0.004, H + 0.006), (0, 0, H / 2 + 0.001), BAND))
for x in (-0.017, 0.017):
    P.append(box((0.004, W + 0.005, H + 0.007), (x, 0, H / 2 + 0.001), BAND_RED))
P += ruble_sign(H + 0.004, 0.026, BAND_RED, depth=0.0015)
coin = join("MoneyStack", P)
export(coin, "money_stack")

# ---------------- Фишки ----------------
CHIPS = {10: (0.92, 0.92, 0.9), 50: (0.75, 0.08, 0.06), 100: (0.1, 0.25, 0.65), 500: (0.08, 0.08, 0.09)}
chips = {}
for value, color in CHIPS.items():
    base = mat("Chip%d" % value, color, 0.45)
    edge = mat("ChipEdge", (0.96, 0.94, 0.88), 0.45) if value != 10 else mat("ChipEdge10", (0.75, 0.08, 0.06), 0.45)
    sign_color = mat("ChipSign", (0.97, 0.97, 0.95), 0.4) if value != 10 else mat("ChipSign10", (0.75, 0.08, 0.06), 0.45)
    cr, ct = 0.11, 0.025
    P = [cyl(cr, ct, (0, 0, 0), base, verts=32)]
    for i in range(8):                                                                    # насечки по краю
        a = i * math.pi / 4
        P.append(box((0.04, 0.012, ct + 0.002), (math.cos(a) * (cr - 0.004), math.sin(a) * (cr - 0.004), 0),
                     edge, rot=(0, 0, a + math.pi / 2)))
    P.append(cyl(cr * 0.62, ct + 0.002, (0, 0, 0), edge, verts=32))                      # вставка
    P.append(cyl(cr * 0.55, ct + 0.004, (0, 0, 0), base, verts=32))
    P += ruble_sign(ct / 2 + 0.0025, cr * 0.75, sign_color, depth=0.003)
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
coin.rotation_euler.z = 0.5
for o in everything:
    o.hide_render = True
for o, name in [(coin, "ruble")] + [(chips[v], "chip_%d" % v) for v in CHIPS]:
    o.hide_render = False
    o.location = (0, 0, 0)
    cam.data.ortho_scale = 0.2 if o == coin else 0.26                 # пачку — крупнее
    scene.render.filepath = os.path.join(ICONS, name + ".png")
    bpy.ops.render.render(write_still=True)
    o.hide_render = True
    print("ICON", name)
print("DONE")
