"""Базовый персонаж из частей + первая одежда.

Персонаж собран из отдельных частей с точкой поворота в суставе:
    Head (шея), Torso (таз), ArmL / ArmR (плечо), LegL / LegR (бедро).
Анимация делается в Godot кодом — поворотом этих частей.

Одежда: в каждом .glb лежат куски с теми же именами частей и той же точкой поворота.
В Godot кусок просто кладётся внутрь нужной части тела.
Материал "Primary" перекрашивается в цвет игрока (тело и «фирменные» цвета одежды).

Оси Blender: X — вправо (правая рука персонажа), +Y — лицо, Z — вверх.

Запуск:
    python tools/blender/character.py assets/models/character           # .glb
    python tools/blender/character.py assets/models/character --render  # + превью
"""
import bpy, bmesh, math, sys, os
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else "."
RENDER = "--render" in sys.argv
os.makedirs(os.path.join(OUT, "cosmetics"), exist_ok=True)

## Число полос на костюме «Абибас» (перед релизом можно сменить на 2).
STRIPES = 3

# Точки поворота частей тела.
PIVOTS = {
    "Torso": (0, 0, 0.55),
    "Head": (0, 0, 1.05),
    "ArmL": (-0.31, 0, 1.0),
    "ArmR": (0.31, 0, 1.0),
    "LegL": (-0.13, 0, 0.55),
    "LegR": (0.13, 0, 0.55),
}

_mats = {}


def mat(name, color, rough=0.6, metal=0.0):
    if name in _mats and _mats[name].name in bpy.data.materials:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    _mats[name] = m
    return m


def primary():
    # Цвет по умолчанию; в игре заменяется цветом игрока.
    return mat("Primary", (0.75, 0.12, 0.08), 0.55)


def flat(o, m, bevel=0.0, segs=1):
    o.data.materials.append(m)
    if bevel:
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segs
        mod.limit_method = "ANGLE"
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def box(size, loc, m, bevel=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    return flat(o, m, bevel)


def cyl(r, depth, loc, m, verts=10, r2=None, rot=(0, 0, 0), scale=(1, 1, 1)):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    return flat(o, m)


def sphere(r, loc, m, scale=(1, 1, 1), segs=12, rings=8, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    return flat(o, m)


def part(name, pieces):
    """Склеить куски в одну часть тела и поставить точку поворота в сустав."""
    for o in pieces:
        for mod in list(o.modifiers):
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action="DESELECT")
    for o in pieces:
        o.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    if len(pieces) > 1:
        bpy.ops.object.join()
    obj = bpy.context.object
    bpy.context.scene.cursor.location = PIVOTS[name]
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    obj.name = name
    obj.data.name = name
    bpy.context.scene.cursor.location = (0, 0, 0)
    return obj


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in list(bpy.data.meshes):
        if block.users == 0:
            bpy.data.meshes.remove(block)


def export(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    tris = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB",
                              export_draco_mesh_compression_enable=False)
    print(f"EXPORTED {os.path.basename(path)}: {tris} tris")


# ======================= Базовое тело =======================

def build_base():
    P = primary()
    WHITE = mat("EyeWhite", (0.95, 0.95, 0.95), 0.4)
    BLACK = mat("EyeBlack", (0.03, 0.03, 0.03), 0.3)
    MOUTH = mat("Mouth", (0.25, 0.05, 0.05), 0.6)
    parts = []
    # Туловище: чуть шире к плечам.
    torso = [cyl(0.23, 0.55, (0, 0, 0.78), P, verts=10, r2=0.27, scale=(1, 0.72, 1))]
    torso.append(sphere(0.27, (0, 0, 1.03), P, scale=(1, 0.72, 0.35), segs=10, rings=5))
    torso.append(sphere(0.23, (0, 0, 0.53), P, scale=(1, 0.72, 0.4), segs=10, rings=5))
    parts.append(part("Torso", torso))
    # Голова: большая, как у фишки. Глаза и рот смотрят в +Y.
    head = [sphere(0.3, (0, 0, 1.33), P, scale=(1, 0.95, 0.95))]
    for x in (-0.11, 0.11):
        head.append(sphere(0.075, (x, 0.255, 1.37), WHITE, scale=(1, 0.5, 1.15), segs=10, rings=6))
        head.append(sphere(0.042, (x, 0.29, 1.36), BLACK, scale=(1, 0.5, 1.2), segs=8, rings=5))
    head.append(box((0.1, 0.03, 0.025), (0, 0.28, 1.22), MOUTH))
    parts.append(part("Head", head))
    # Руки: плечо → кисть вниз по -Z.
    for side, x in (("ArmL", -0.31), ("ArmR", 0.31)):
        arm = [cyl(0.075, 0.38, (x, 0, 0.81), P, verts=8)]
        arm.append(sphere(0.075, (x, 0, 1.0), P, segs=8, rings=5))
        arm.append(sphere(0.088, (x, 0, 0.6), P, segs=8, rings=5))
        parts.append(part(side, arm))
    # Ноги со ступнями.
    for side, x in (("LegL", -0.13), ("LegR", 0.13)):
        leg = [cyl(0.09, 0.43, (x, 0, 0.335), P, verts=8)]
        leg.append(box((0.17, 0.27, 0.1), (x, 0.04, 0.06), P, bevel=0.03))
        parts.append(part(side, leg))
    return parts


# ======================= Одежда =======================

def stripes_on_arm(x, side, color_mat, z_top=0.98, z_bot=0.66, r=0.09):
    """Полосы по внешней стороне рукава/штанины."""
    pieces = []
    length = z_top - z_bot
    for i in range(STRIPES):
        off = (i - (STRIPES - 1) / 2) * 0.03
        pieces.append(box((0.014, 0.018, length), (x + side * r, off, (z_top + z_bot) / 2), color_mat))
    return pieces


def item_abibas_jacket():
    P = primary()
    W = mat("StripeWhite", (0.95, 0.95, 0.95), 0.5)
    torso = [cyl(0.245, 0.48, (0, 0, 0.8), P, verts=10, r2=0.285, scale=(1, 0.74, 1))]
    torso.append(sphere(0.285, (0, 0, 1.03), P, scale=(1, 0.74, 0.36), segs=10, rings=5))
    torso.append(cyl(0.15, 0.08, (0, 0, 1.1), W, verts=10))                              # воротник
    torso.append(box((0.02, 0.02, 0.5), (0, 0.205, 0.82), W))                            # молния
    for x in (-0.25, 0.25):                                                               # полосы на плечах
        torso.append(box((0.03, 0.15, 0.03), (x, 0, 1.06), W))
    objs = [part("Torso", torso)]
    for side, x, s in (("ArmL", -0.31, -1), ("ArmR", 0.31, 1)):
        sleeve = [cyl(0.088, 0.36, (x, 0, 0.82), P, verts=8)]
        sleeve.append(sphere(0.09, (x, 0, 1.0), P, segs=8, rings=5))
        sleeve.append(cyl(0.092, 0.05, (x, 0, 0.66), W, verts=8))                       # манжет
        sleeve += stripes_on_arm(x, s, W, 0.98, 0.7, 0.088)
        objs.append(part(side, sleeve))
    return objs


def item_abibas_pants():
    P = primary()
    W = mat("StripeWhite", (0.95, 0.95, 0.95), 0.5)
    objs = [part("Torso", [cyl(0.245, 0.12, (0, 0, 0.56), P, verts=10, scale=(1, 0.74, 1))])]
    for side, x, s in (("LegL", -0.13, -1), ("LegR", 0.13, 1)):
        leg = [cyl(0.105, 0.42, (x, 0, 0.36), P, verts=8)]
        leg.append(cyl(0.108, 0.04, (x, 0, 0.16), W, verts=8))                          # резинка
        leg += stripes_on_arm(x, s, W, 0.55, 0.19, 0.105)
        objs.append(part(side, leg))
    return objs


def item_kepka():
    """Кепарик-восьмиклинка."""
    TWEED = mat("Tweed", (0.2, 0.19, 0.18), 0.9)
    BUTTON = mat("CapButton", (0.12, 0.11, 0.1), 0.8)
    pieces = [sphere(0.32, (0, -0.01, 1.5), TWEED, scale=(1, 1.05, 0.42), segs=8, rings=6)]
    pieces.append(box((0.42, 0.2, 0.04), (0, 0.27, 1.49), TWEED, bevel=0.015, rot=(math.radians(-12), 0, 0)))
    pieces.append(sphere(0.035, (0, 0, 1.63), BUTTON, segs=6, rings=4))
    return [part("Head", pieces)]


def item_ushanka():
    FUR = mat("Fur", (0.28, 0.18, 0.11), 1.0)
    CLOTH = mat("UshankaTop", (0.18, 0.15, 0.13), 0.8)
    STAR = mat("Star", (0.85, 0.08, 0.05), 0.4, 0.3)
    pieces = [cyl(0.33, 0.22, (0, 0, 1.55), CLOTH, verts=10, r2=0.3)]
    pieces.append(cyl(0.345, 0.1, (0, 0.0, 1.47), FUR, verts=10))                      # меховой обод
    pieces.append(box((0.42, 0.07, 0.12), (0, 0.33, 1.56), FUR, bevel=0.03))          # козырёк
    for x in (-0.31, 0.31):                                                            # уши
        pieces.append(box((0.07, 0.24, 0.26), (x, 0.0, 1.35), FUR, bevel=0.03))
    pieces.append(cyl(0.045, 0.02, (0, 0.37, 1.57), STAR, verts=5, rot=(math.radians(90), 0, 0)))
    return [part("Head", pieces)]


def item_glasses_drops():
    """Очки-капельки (авиаторы)."""
    LENS = mat("Lens", (0.04, 0.05, 0.06), 0.1, 0.6)
    GOLD = mat("Gold", (0.85, 0.65, 0.2), 0.3, 1.0)
    pieces = []
    for x in (-0.11, 0.11):
        pieces.append(sphere(0.085, (x, 0.3, 1.36), LENS, scale=(1, 0.3, 0.9), segs=10, rings=6))
    pieces.append(box((0.08, 0.015, 0.015), (0, 0.32, 1.4), GOLD))
    for x in (-0.2, 0.2):
        pieces.append(box((0.015, 0.25, 0.015), (x * 1.3, 0.17, 1.39), GOLD))
    return [part("Head", pieces)]


def item_kedy():
    WHITE = mat("CanvasWhite", (0.92, 0.92, 0.9), 0.8)
    SOLE = mat("Sole", (0.15, 0.15, 0.16), 0.9)
    TOE = mat("Toe", (0.85, 0.85, 0.82), 0.7)
    objs = []
    for side, x in (("LegL", -0.13), ("LegR", 0.13)):
        shoe = [box((0.19, 0.3, 0.1), (x, 0.045, 0.075), WHITE, bevel=0.03)]
        shoe.append(box((0.2, 0.31, 0.035), (x, 0.045, 0.0175), SOLE, bevel=0.01))
        shoe.append(box((0.17, 0.08, 0.06), (x, 0.17, 0.06), TOE, bevel=0.02))
        shoe.append(cyl(0.1, 0.07, (x, 0, 0.14), WHITE, verts=8))                       # верх кеда
        objs.append(part(side, shoe))
    return objs


ITEMS = {
    "jacket_abibas": item_abibas_jacket,
    "pants_abibas": item_abibas_pants,
    "hat_kepka": item_kepka,
    "hat_ushanka": item_ushanka,
    "acc_glasses_drops": item_glasses_drops,
    "shoes_kedy": item_kedy,
}

# ======================= Экспорт =======================

bpy.ops.wm.read_factory_settings(use_empty=True)
export(os.path.join(OUT, "character_base.glb"), build_base())
for item_id, builder in ITEMS.items():
    clear()
    export(os.path.join(OUT, "cosmetics", item_id + ".glb"), builder())

if not RENDER:
    print("DONE")
    sys.exit(0)

# ======================= Превью =======================
clear()
scene = bpy.context.scene
LOOKS = [
    ((0.75, 0.12, 0.08), []),
    ((0.08, 0.22, 0.7), ["jacket_abibas", "pants_abibas", "hat_kepka", "shoes_kedy"]),
    ((0.85, 0.6, 0.05), ["hat_ushanka", "acc_glasses_drops", "jacket_abibas"]),
    ((0.12, 0.5, 0.15), ["pants_abibas", "shoes_kedy", "acc_glasses_drops", "hat_kepka"]),
]
for i, (color, items) in enumerate(LOOKS):
    offset = Vector(((i - 1.5) * 1.1, 0, 0))
    m = mat(f"Player{i}", color, 0.55)
    objs = build_base()
    for item_id in items:
        objs += ITEMS[item_id]()
    for o in objs:
        o.location += offset
        o.name = f"{o.name}_{i}"
        for slot in o.material_slots:
            if slot.material and slot.material.name.startswith("Primary"):
                slot.link = "OBJECT"
                slot.material = m
    # Чуть «оживим» позу: руки в стороны.
    for o in objs:
        if o.name.startswith("ArmR"):
            o.rotation_euler.y = math.radians(-10)
        if o.name.startswith("ArmL"):
            o.rotation_euler.y = math.radians(10)

scene.cursor.location = (0, 0, 0)
bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
bpy.context.object.data.materials.append(mat("Ground", (0.45, 0.42, 0.38), 0.9))


def light(loc, energy, color, size):
    d = bpy.data.lights.new("L", "AREA")
    d.energy, d.color, d.size = energy, color, size
    o = bpy.data.objects.new("L", d)
    o.location = loc
    scene.collection.objects.link(o)
    o.rotation_euler = (Vector((0, 0, 0.8)) - o.location).to_track_quat("-Z", "Y").to_euler()


light((-3, 5, 5), 900, (1, 0.93, 0.82), 4)
light((4, 3, 2), 250, (0.75, 0.82, 1), 3)
light((0, -4, 3), 200, (1, 0.9, 0.8), 3)
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.7, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.5
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 50
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (0.9, 5.6, 1.7)
cam.rotation_euler = (Vector((0, 0, 0.82)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.engine = "CYCLES"
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1500, 900
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.render.filepath = os.path.join(OUT, "_preview_characters.png")
bpy.ops.render.render(write_still=True)
print("DONE")
