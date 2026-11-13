"""Каталог одежды одной картинкой (для дизайнера: собирать красивые «наборы»).
Каждая строка — категория (шапки, лицо, верх, штаны, обувь, шея/спина), в углу — персонаж без одежды.
Подписи — русские названия из scripts/core/cosmetics.gd.

Запуск (из корня проекта):
    python tools/blender/catalog.py docs/previews/catalog.png
"""
import bpy, math, os, re, sys
from mathutils import Vector

OUT = sys.argv[-1] if sys.argv[-1].endswith(".png") else "docs/previews/catalog.png"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODELS = os.path.join(ROOT, "assets", "models", "character")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
BODY_COLOR = (0.25, 0.5, 0.9)          # «цвет игрока» на каталоге
CELL_X, CELL_Y = 1.35, 2.75

# Категории и вещи — из cosmetics.gd (порядок как в игре).
src = open(os.path.join(ROOT, "scripts", "core", "cosmetics.gd"), encoding="utf-8").read()
items = re.findall(r'"(\w+)": \{\s*"slot": Slot\.(\w+), "name": "([^"]+)", "price": (\d+)', src)
SLOTS = [("HAT", "Шапки"), ("FACE", "Лицо"), ("MOUTH", "Рот"), ("JACKET", "Верх"),
         ("PANTS", "Штаны"), ("SHOES", "Обувь"), ("NECK", "Шея и спина")]

bpy.ops.wm.read_factory_settings(use_empty=True)
font = bpy.data.fonts.load(FONT)


def place(paths, x, y, yaw=-0.45):
    """Импортировать модели в ячейку (x — колонка слева направо, y — строка сверху вниз)."""
    holder = bpy.data.objects.new("Cell", None)
    bpy.context.collection.objects.link(holder)
    for path in paths:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        for o in set(bpy.data.objects) - before:
            if o.parent is None:
                o.parent = holder
    # Камера смотрит с +Y на −Y: «вправо» на картинке — это −X.
    holder.location = (-x * CELL_X, 0, -y * CELL_Y)
    holder.rotation_euler.z = yaw


def text(body, x, y, size=0.16, color=(0.1, 0.1, 0.12), align="CENTER", dz=-0.32):
    curve = bpy.data.curves.new("T", "FONT")
    curve.body = body
    curve.font = font
    curve.size = size
    curve.align_x = align
    o = bpy.data.objects.new("T", curve)
    bpy.context.collection.objects.link(o)
    o.location = (-x * CELL_X, 0.6, -y * CELL_Y + dz)
    o.rotation_euler = (math.radians(90), 0, math.radians(180))   # лицом к камере (+Y)
    m = bpy.data.materials.new("Txt")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1)
    curve.materials.append(m)


base = os.path.join(MODELS, "character_base.glb")
place([base], 0, 0)
text("Без одежды", 0, 0)
text("SLAVIC GAMES — гардероб", 1.0, 0, size=0.42, align="LEFT", dz=1.0)
text("цвет тела = цвет игрока (здесь синий)", 1.0, 0, size=0.2, align="LEFT", dz=0.55,
     color=(0.35, 0.35, 0.4))
cols = 0
for row, (slot, title) in enumerate(SLOTS, start=1):
    text(title, -0.35, row, size=0.3, dz=1.95, color=(0.55, 0.12, 0.08), align="LEFT")
    col = 0
    for item_id, item_slot, name, price in items:
        if item_slot != slot:
            continue
        place([base, os.path.join(MODELS, "cosmetics", item_id + ".glb")], col, row)
        label = name if int(price) == 0 else "%s · %s ₽" % (name, price)
        text(label, col, row, size=0.14 if len(label) < 20 else 0.115)
        col += 1
    cols = max(cols, col)

# Цвет игрока на всех материалах «Primary».
for m in bpy.data.materials:
    if m.name.startswith("Primary") and m.use_nodes:
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*BODY_COLOR, 1)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 16
scene.cycles.use_denoising = True
rows = len(SLOTS) + 1
width, height = cols * CELL_X + 0.4, rows * CELL_Y + 0.6
scene.render.resolution_x = 2400
scene.render.resolution_y = int(2400 * height / width)
scene.view_settings.view_transform = "Standard"
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.95, 0.93, 0.88, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 2.5
sun.rotation_euler = (math.radians(-50), math.radians(20), math.radians(160))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = max(width, height)
scene.collection.objects.link(cam)
scene.camera = cam
center = Vector((-(cols - 1) * CELL_X / 2, 0, -(rows - 1) * CELL_Y / 2 + 0.9))
cam.location = center + Vector((0, 30, 0))
cam.rotation_euler = (math.radians(90), 0, math.radians(180))
scene.render.filepath = os.path.abspath(OUT)
bpy.ops.render.render(write_still=True)
print("DONE", len(items), "items")
