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


# ======================= Общие заготовки одежды =======================

def sphere_cap(r, center, m, zmin, scale=(1, 1, 1), segs=12, rings=8):
    """Верх сферы выше zmin (для шапок)."""
    o = sphere(r, center, m, scale=scale, segs=segs, rings=rings)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < zmin - 0.001], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    return o


def torso_r(z):
    """Радиус туловища на высоте z (туловище расширяется к плечам)."""
    return 0.23 + (min(max(z, 0.505), 1.055) - 0.505) / 0.55 * 0.04


def torso_shell(m, z_bot, z_top, extra=0.02, shoulders=True, depth=0.74):
    pieces = [cyl(torso_r(z_bot) + extra, z_top - z_bot, (0, 0, (z_top + z_bot) / 2), m, verts=10,
                  r2=torso_r(z_top) + extra, scale=(1, depth, 1))]
    if shoulders:
        pieces.append(sphere(0.27 + extra, (0, 0, 1.03), m, scale=(1, depth, 0.36), segs=10, rings=5))
    return pieces


def sleeve(x, m, z_bot=0.66, r=0.088):
    return [cyl(r, 1.0 - z_bot, (x, 0, (1.0 + z_bot) / 2), m, verts=8),
            sphere(r + 0.002, (x, 0, 1.0), m, segs=8, rings=5)]


def jacket(body, sleeves_fn=None):
    """Куртка: туловище + рукава. sleeves_fn(x, side) -> куски рукава."""
    objs = [part("Torso", body)]
    if sleeves_fn:
        for side, x, s in (("ArmL", -0.31, -1), ("ArmR", 0.31, 1)):
            objs.append(part(side, sleeves_fn(x, s)))
    return objs


def legs(leg_fn, waist=None):
    """Штаны/обувь: leg_fn(x, side) -> куски штанины; waist — куски на туловище."""
    objs = [part("Torso", waist)] if waist else []
    for side, x, s in (("LegL", -0.13, -1), ("LegR", 0.13, 1)):
        objs.append(part(side, leg_fn(x, s)))
    return objs


def buttons(m, x, zs, y=0.215, r=0.022):
    return [cyl(r, 0.02, (x, y, z), m, verts=8, rot=(math.radians(90), 0, 0)) for z in zs]


# ======================= Шапки =======================

def item_hat_petushok():
    """Шапка-«петушок»: вязаная, с острым гребешком сверху."""
    P = primary()
    W = mat("KnitWhite", (0.92, 0.92, 0.9), 0.95)
    pieces = [cyl(0.315, 0.1, (0, 0, 1.47), W, verts=12)]
    pieces.append(cyl(0.31, 0.3, (0, 0, 1.66), P, verts=12, r2=0.1))
    pieces.append(sphere(0.12, (0, 0, 1.83), P, scale=(0.35, 1.1, 1), segs=8, rings=5))
    return [part("Head", pieces)]


def item_hat_panama():
    W = mat("PanamaWhite", (0.9, 0.88, 0.8), 0.9)
    BAND = mat("PanamaBand", (0.3, 0.45, 0.6), 0.8)
    pieces = [cyl(0.28, 0.16, (0, 0, 1.6), W, verts=12, r2=0.25)]
    pieces.append(cyl(0.46, 0.08, (0, 0, 1.5), W, verts=14, r2=0.3))
    pieces.append(cyl(0.285, 0.04, (0, 0, 1.54), BAND, verts=12))
    return [part("Head", pieces)]


def item_hat_bandana():
    """Бандана на лицо, как у бандита."""
    P = primary()
    DOT = mat("BandanaDot", (0.95, 0.95, 0.95), 0.8)
    pieces = [cyl(0.305, 0.16, (0, 0, 1.25), P, verts=12, scale=(1, 0.97, 1))]
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.17, radius2=0.0, depth=0.02,
                                    location=(0, 0.27, 1.12), rotation=(math.radians(-90), 0, 0))
    tri = flat(bpy.context.object, P)
    tri.rotation_euler = (math.radians(90), math.radians(180), 0)
    bpy.ops.object.transform_apply(rotation=True)
    pieces.append(tri)
    for x, z in [(-0.12, 1.27), (0.1, 1.22), (0.0, 1.29), (-0.05, 1.19), (0.15, 1.28)]:
        pieces.append(sphere(0.018, (x, 0.29, z), DOT, scale=(1, 0.4, 1), segs=6, rings=4))
    return [part("Head", pieces)]


def item_hat_pilotka():
    KHAKI = mat("Khaki", (0.33, 0.35, 0.18), 0.85)
    STAR = mat("Star", (0.85, 0.08, 0.05), 0.4, 0.3)
    pieces = [box((0.3, 0.58, 0.17), (0, 0, 1.6), KHAKI, bevel=0.06)]
    pieces.append(box((0.34, 0.54, 0.06), (0, 0, 1.54), KHAKI, bevel=0.02))
    pieces.append(cyl(0.04, 0.02, (0, 0.285, 1.58), STAR, verts=5, rot=(math.radians(90), 0, 0)))
    return [part("Head", pieces)]


def item_hat_fedora():
    FELT = mat("Felt", (0.25, 0.2, 0.16), 0.85)
    BAND = mat("FedoraBand", (0.08, 0.07, 0.07), 0.6)
    pieces = [cyl(0.27, 0.2, (0, 0, 1.66), FELT, verts=12, r2=0.22, scale=(1, 1.1, 1))]
    pieces.append(cyl(0.44, 0.03, (0, 0, 1.56), FELT, verts=14, scale=(1, 1.1, 1)))
    pieces.append(cyl(0.272, 0.05, (0, 0, 1.59), BAND, verts=12, scale=(1, 1.1, 1)))
    pieces.append(box((0.08, 0.3, 0.04), (0, 0, 1.765), FELT))                       # вмятина-гребень
    return [part("Head", pieces)]


def item_hat_curlers():
    """Бигуди под платком."""
    P = primary()
    PINK = mat("CurlerPink", (0.95, 0.5, 0.65), 0.5)
    pieces = [sphere_cap(0.32, (0, -0.02, 1.36), P, 1.44, scale=(1.02, 1, 1))]
    for x in (-0.24, 0.24):                                                          # концы под подбородок
        pieces.append(box((0.05, 0.08, 0.2), (x, 0.12, 1.24), P, rot=(0, 0, 0)))
    pieces.append(sphere(0.06, (0, 0.2, 1.08), P, segs=8, rings=5))                  # узел
    for x in (-0.15, -0.05, 0.05, 0.15):
        pieces.append(cyl(0.04, 0.09, (x, 0.24, 1.47), PINK, verts=8, rot=(0, math.radians(90), 0)))
    return [part("Head", pieces)]


def item_hat_tubeteika():
    GREEN = mat("TubGreen", (0.05, 0.25, 0.15), 0.6)
    GOLD = mat("TubGold", (0.9, 0.75, 0.3), 0.4, 0.5)
    WHITE = mat("TubWhite", (0.95, 0.95, 0.9), 0.6)
    pieces = [cyl(0.27, 0.14, (0, 0, 1.55), GREEN, verts=4, rot=(0, 0, math.radians(45)))]
    for i in range(4):
        a = math.radians(45 + 90 * i)
        pieces.append(box((0.03, 0.03, 0.13), (math.cos(a) * 0.195, math.sin(a) * 0.195, 1.55), WHITE))
    pieces.append(box((0.22, 0.22, 0.02), (0, 0, 1.625), GOLD, rot=(0, 0, math.radians(45))))
    return [part("Head", pieces)]


def item_hat_pompom():
    P = primary()
    W = mat("KnitWhite", (0.92, 0.92, 0.9), 0.95)
    pieces = [sphere_cap(0.315, (0, -0.01, 1.36), P, 1.44)]
    pieces.append(cyl(0.32, 0.1, (0, -0.01, 1.47), W, verts=12))
    pieces.append(sphere(0.11, (0, -0.01, 1.71), W, segs=8, rings=6))
    return [part("Head", pieces)]


def item_hat_hardhat():
    Y = mat("HardHat", (0.95, 0.6, 0.05), 0.35)
    pieces = [sphere_cap(0.325, (0, -0.01, 1.4), Y, 1.46)]
    pieces.append(cyl(0.35, 0.025, (0, 0, 1.47), Y, verts=14, scale=(1, 1.1, 1)))
    pieces.append(box((0.3, 0.12, 0.025), (0, 0.33, 1.47), Y, bevel=0.01))
    pieces.append(box((0.05, 0.55, 0.05), (0, -0.01, 1.71), Y, bevel=0.015))
    return [part("Head", pieces)]


# ======================= Куртки и верх =======================

def item_jacket_kosuha():
    LEATHER = mat("Leather", (0.04, 0.04, 0.045), 0.35, 0.1)
    METAL = mat("Steel", (0.8, 0.8, 0.82), 0.25, 1.0)
    body = torso_shell(LEATHER, 0.55, 1.06)
    body.append(box((0.015, 0.02, 0.48), (0.05, 0.21, 0.8), METAL, rot=(0, math.radians(-12), 0)))  # косая молния
    for x, a in ((-0.12, 18), (0.14, -18)):                                          # лацканы
        body.append(box((0.1, 0.03, 0.2), (x, 0.205, 0.98), LEATHER, rot=(0, math.radians(a), 0)))
    body.append(box((0.54, 0.4, 0.05), (0, 0, 0.58), LEATHER))                       # пояс
    body.append(box((0.06, 0.02, 0.05), (0.12, 0.2, 0.58), METAL))                   # пряжка
    return jacket(body, lambda x, s: sleeve(x, LEATHER) + [cyl(0.091, 0.03, (x, 0, 0.68), METAL, verts=8)])


def item_jacket_alkogolichka():
    """Майка-алкоголичка."""
    WHITE = mat("Undershirt", (0.93, 0.93, 0.9), 0.9)
    body = torso_shell(WHITE, 0.6, 0.97, extra=0.012, shoulders=False)
    for x in (-0.13, 0.13):                                                          # лямки
        body.append(box((0.06, 0.2, 0.12), (x, 0, 1.02), WHITE))
    return jacket(body)


def item_jacket_dutik():
    """Пуховик-«дутик»."""
    P = primary()
    body = []
    for i, z in enumerate((0.62, 0.76, 0.9, 1.02)):
        body.append(cyl(torso_r(z) + 0.07, 0.13, (0, 0, z), P, verts=12, scale=(1, 0.78, 1)))
    body.append(sphere(0.33, (0, 0, 1.05), P, scale=(1, 0.78, 0.33), segs=12, rings=5))
    body.append(cyl(0.17, 0.14, (0, 0, 1.12), P, verts=10))                          # высокий ворот
    def puffy(x, s):
        return [cyl(0.11, 0.12, (x, 0, z), P, verts=8) for z in (0.95, 0.83, 0.71)] + \
               [sphere(0.115, (x, 0, 1.0), P, segs=8, rings=5)]
    return jacket(body, puffy)


def item_jacket_varenka():
    """Джинсовка-варёнка."""
    DENIM = mat("DenimLight", (0.42, 0.55, 0.72), 0.85)
    SPOT = mat("DenimSpot", (0.7, 0.78, 0.88), 0.9)
    BTN = mat("Copper", (0.7, 0.45, 0.2), 0.4, 0.8)
    body = torso_shell(DENIM, 0.56, 1.06)
    body.append(cyl(0.17, 0.07, (0, 0, 1.1), DENIM, verts=10))
    for x in (-0.12, 0.12):                                                          # нагрудные карманы
        body.append(box((0.11, 0.02, 0.09), (x, 0.205, 0.92), DENIM, bevel=0.01))
    for x, y, z in ((-0.17, 0.18, 0.7), (0.15, 0.19, 0.78), (-0.05, 0.21, 0.64), (0.2, 0.15, 0.95), (-0.2, 0.12, 1.0)):
        body.append(sphere(0.045, (x, y, z), SPOT, scale=(1, 0.35, 1), segs=6, rings=4))
    body += buttons(BTN, 0, (0.66, 0.78, 0.9, 1.0), y=0.215, r=0.016)
    return jacket(body, lambda x, s: sleeve(x, DENIM) + [sphere(0.04, (x + s * 0.08, 0.02, 0.82), SPOT,
                                                                    scale=(0.4, 1, 1), segs=6, rings=4)])


def item_jacket_pioneer():
    """Пионерская рубашка с красным галстуком."""
    WHITE = mat("ShirtWhite", (0.95, 0.95, 0.93), 0.8)
    RED = mat("TieRed", (0.85, 0.06, 0.04), 0.6)
    body = torso_shell(WHITE, 0.56, 1.06)
    for x, a in ((-0.08, 30), (0.08, -30)):                                          # воротник
        body.append(box((0.12, 0.02, 0.06), (x, 0.17, 1.08), WHITE, rot=(0, math.radians(a), 0)))
    body.append(sphere(0.04, (0, 0.2, 1.04), RED, segs=6, rings=4))                  # узел
    for x, a in ((-0.04, 12), (0.05, -14)):                                          # концы галстука
        body.append(box((0.05, 0.015, 0.22), (x, 0.215, 0.92), RED, rot=(0, math.radians(a), 0)))
    return jacket(body, lambda x, s: sleeve(x, WHITE, z_bot=0.8))


def item_jacket_seller_robe():
    """Халат продавщицы."""
    WHITE = mat("RobeWhite", (0.96, 0.96, 0.94), 0.85)
    BLUE = mat("RobeTrim", (0.3, 0.55, 0.8), 0.7)
    body = torso_shell(WHITE, 0.55, 1.06)
    body.append(cyl(0.29, 0.25, (0, 0, 0.48), WHITE, verts=10, r2=torso_r(0.55) + 0.02, scale=(1, 0.76, 1)))
    body.append(box((0.02, 0.02, 0.6), (0.0, 0.215, 0.7), BLUE))
    for x in (-0.13, 0.13):
        body.append(box((0.12, 0.02, 0.1), (x, 0.215, 0.62), WHITE, bevel=0.01))
    body += buttons(BLUE, 0.04, (0.6, 0.75, 0.9), y=0.22, r=0.018)
    return jacket(body, lambda x, s: sleeve(x, WHITE, z_bot=0.72) + [cyl(0.091, 0.03, (x, 0, 0.73), BLUE, verts=8)])


def item_jacket_blazer():
    """Пиджак с огромными подплечниками."""
    P = primary()
    SHIRT = mat("ShirtWhite", (0.95, 0.95, 0.93), 0.8)
    BTN = mat("BtnBlack", (0.05, 0.05, 0.05), 0.4)
    body = torso_shell(P, 0.55, 1.06)
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.09, radius2=0, depth=0.02, location=(0, 0.21, 0.98),
                                    rotation=(math.radians(90), 0, math.radians(180)))
    body.append(flat(bpy.context.object, SHIRT))                                      # вырез с рубашкой
    for x, a in ((-0.1, 22), (0.1, -22)):
        body.append(box((0.08, 0.025, 0.25), (x, 0.205, 0.94), P, rot=(0, math.radians(a), 0)))
    body += buttons(BTN, 0, (0.68, 0.78), y=0.22, r=0.018)
    def padded(x, s):
        return sleeve(x, P) + [box((0.22, 0.24, 0.07), (x - s * 0.03, 0, 1.08), P, bevel=0.03)]
    return jacket(body, padded)


def item_jacket_granny():
    """Кофта «как у бабушки» на пуговицах."""
    KNIT = mat("GrannyKnit", (0.55, 0.42, 0.32), 0.95)
    BTN = mat("BtnWood", (0.3, 0.18, 0.1), 0.6)
    body = torso_shell(KNIT, 0.5, 1.06, extra=0.03)
    body.append(box((0.02, 0.02, 0.55), (0.0, 0.225, 0.78), mat("GrannyEdge", (0.45, 0.33, 0.24), 0.95)))
    for x in (-0.14, 0.14):
        body.append(box((0.12, 0.02, 0.11), (x, 0.22, 0.64), KNIT, bevel=0.015))
    body += buttons(BTN, 0.035, (0.62, 0.74, 0.86, 0.98), y=0.23, r=0.025)
    return jacket(body, lambda x, s: sleeve(x, KNIT, r=0.095) + [cyl(0.098, 0.05, (x, 0, 0.66), KNIT, verts=8)])


# ======================= Штаны =======================

def waist(m, z=0.56, h=0.12):
    return [cyl(0.245, h, (0, 0, z), m, verts=10, scale=(1, 0.74, 1))]


def item_pants_klesh():
    DENIM = mat("DenimDark", (0.12, 0.2, 0.42), 0.85)
    return legs(lambda x, s: [cyl(0.17, 0.44, (x, 0, 0.34), DENIM, verts=10, r2=0.1)], waist(DENIM))


def item_pants_sharovary():
    P = mat("Sharovary", (0.45, 0.06, 0.35), 0.7)
    return legs(lambda x, s: [sphere(0.15, (x, 0, 0.36), P, scale=(1, 1, 1.45), segs=10, rings=6),
                              cyl(0.1, 0.05, (x, 0, 0.14), P, verts=8)], waist(P))


def item_pants_family():
    """Семейные трусы в горошек."""
    P = primary()
    BASE = mat("ShortsLight", (0.85, 0.9, 0.95), 0.9)
    def leg(x, s):
        pieces = [cyl(0.125, 0.18, (x, 0, 0.45), BASE, verts=10)]
        for a in (0, 120, 240):
            r = math.radians(a + (40 if s > 0 else 0))
            pieces.append(sphere(0.022, (x + math.cos(r) * 0.126, math.sin(r) * 0.126, 0.43), P, segs=6, rings=4))
        return pieces
    w = waist(BASE, 0.56, 0.12)
    for x, y in ((-0.12, 0.18), (0.1, 0.19), (0.0, -0.18)):
        w.append(sphere(0.022, (x, y, 0.55), P, segs=6, rings=4))
    return legs(leg, w)


def item_pants_overalls():
    DENIM = mat("DenimOveralls", (0.18, 0.3, 0.55), 0.85)
    BTN = mat("Copper", (0.7, 0.45, 0.2), 0.4, 0.8)
    w = waist(DENIM, 0.6, 0.2)
    w.append(box((0.3, 0.04, 0.3), (0, 0.18, 0.8), DENIM))                           # нагрудник
    w.append(box((0.12, 0.02, 0.08), (0, 0.205, 0.82), DENIM, bevel=0.01))
    for x in (-0.12, 0.12):                                                          # лямки
        w.append(box((0.05, 0.42, 0.04), (x, 0.0, 1.03), DENIM))
        w.append(cyl(0.02, 0.02, (x, 0.21, 0.94), BTN, verts=8, rot=(math.radians(90), 0, 0)))
    return legs(lambda x, s: [cyl(0.108, 0.42, (x, 0, 0.36), DENIM, verts=8)], w)


def item_pants_school():
    GREY = mat("SchoolGrey", (0.18, 0.19, 0.24), 0.8)
    CREASE = mat("Crease", (0.32, 0.33, 0.38), 0.8)
    return legs(lambda x, s: [cyl(0.105, 0.43, (x, 0, 0.355), GREY, verts=8),
                              box((0.01, 0.02, 0.4), (x, 0.104, 0.36), CREASE)], waist(GREY))


def item_pants_camo():
    GREEN = mat("CamoGreen", (0.25, 0.32, 0.16), 0.9)
    DARK = mat("CamoDark", (0.12, 0.15, 0.08), 0.9)
    BROWN = mat("CamoBrown", (0.35, 0.26, 0.15), 0.9)
    def leg(x, s):
        pieces = [cyl(0.108, 0.43, (x, 0, 0.355), GREEN, verts=8)]
        for i, (a, z) in enumerate(((20, 0.48), (150, 0.4), (260, 0.3), (80, 0.22), (200, 0.17))):
            r = math.radians(a)
            pieces.append(sphere(0.05, (x + math.cos(r) * 0.105, math.sin(r) * 0.105, z), DARK if i % 2 else BROWN,
                                 scale=(0.6, 0.6, 1.2), segs=6, rings=4))
        pieces.append(box((0.04, 0.09, 0.08), (x + s * 0.11, 0, 0.36), GREEN))       # боковой карман
        return pieces
    return legs(leg, waist(GREEN))


def item_pants_pe_shorts():
    BLUE = mat("PEBlue", (0.08, 0.2, 0.6), 0.7)
    W = mat("StripeWhite", (0.95, 0.95, 0.95), 0.5)
    return legs(lambda x, s: [cyl(0.12, 0.14, (x, 0, 0.47), BLUE, verts=10),
                              box((0.015, 0.02, 0.14), (x + s * 0.12, 0, 0.47), W)], waist(BLUE))


# ======================= Обувь =======================

def item_shoes_valenki():
    FELT = mat("FeltGrey", (0.4, 0.38, 0.36), 1.0)
    return legs(lambda x, s: [cyl(0.115, 0.36, (x, 0, 0.23), FELT, verts=10),
                              box((0.19, 0.3, 0.12), (x, 0.045, 0.06), FELT, bevel=0.05)])


def item_shoes_galoshi():
    BLACK = mat("Rubber", (0.03, 0.03, 0.035), 0.15, 0.1)
    RED = mat("GaloshRed", (0.8, 0.08, 0.06), 0.6)
    return legs(lambda x, s: [box((0.2, 0.31, 0.1), (x, 0.045, 0.05), BLACK, bevel=0.045),
                              box((0.16, 0.24, 0.02), (x, 0.04, 0.1), RED, bevel=0.01)])


def item_shoes_slippers():
    """Шлёпанцы с носками."""
    P = primary()
    SOCK = mat("Sock", (0.95, 0.95, 0.92), 0.95)
    SOLE = mat("Sole", (0.15, 0.15, 0.16), 0.9)
    return legs(lambda x, s: [cyl(0.097, 0.2, (x, 0, 0.2), SOCK, verts=8),
                              box((0.18, 0.28, 0.09), (x, 0.04, 0.06), SOCK, bevel=0.035),
                              box((0.2, 0.32, 0.03), (x, 0.045, 0.015), SOLE, bevel=0.01),
                              box((0.2, 0.09, 0.04), (x, 0.08, 0.1), P, bevel=0.015)])


def item_shoes_rubber_boots():
    Y = mat("BootYellow", (0.95, 0.75, 0.05), 0.25)
    SOLE = mat("Sole", (0.15, 0.15, 0.16), 0.9)
    return legs(lambda x, s: [cyl(0.115, 0.4, (x, 0, 0.25), Y, verts=10),
                              cyl(0.122, 0.04, (x, 0, 0.43), Y, verts=10),
                              box((0.2, 0.31, 0.11), (x, 0.045, 0.055), Y, bevel=0.04),
                              box((0.21, 0.32, 0.03), (x, 0.045, 0.012), SOLE)])


def item_shoes_pumba():
    """Кроссовки «Пумба» (пародия)."""
    P = primary()
    W = mat("CanvasWhite", (0.92, 0.92, 0.9), 0.8)
    GUM = mat("Gum", (0.6, 0.42, 0.22), 0.8)
    return legs(lambda x, s: [box((0.19, 0.3, 0.1), (x, 0.045, 0.075), W, bevel=0.035),
                              box((0.2, 0.31, 0.035), (x, 0.045, 0.017), GUM, bevel=0.01),
                              box((0.012, 0.2, 0.04), (x + s * 0.097, 0.04, 0.08), P,
                                  rot=(math.radians(-20), 0, 0)),
                              cyl(0.1, 0.06, (x, 0, 0.14), W, verts=8)])


def item_shoes_platform():
    P = mat("PlatformRed", (0.75, 0.05, 0.12), 0.25)
    SOLE = mat("PlatformSole", (0.95, 0.9, 0.8), 0.6)
    return legs(lambda x, s: [box((0.2, 0.31, 0.11), (x, 0.045, 0.055), SOLE, bevel=0.02),
                              box((0.18, 0.27, 0.08), (x, 0.04, 0.14), P, bevel=0.03)])


# ======================= Аксессуары: лицо =======================

def item_face_mustache():
    HAIR = mat("Hair", (0.1, 0.07, 0.05), 0.8)
    pieces = []
    for s in (-1, 1):
        pieces.append(sphere(0.07, (s * 0.06, 0.28, 1.265), HAIR, scale=(1.1, 0.4, 0.45), segs=8, rings=5))
        pieces.append(sphere(0.03, (s * 0.13, 0.26, 1.28), HAIR, scale=(1, 0.5, 0.7), segs=6, rings=4))
    return [part("Head", pieces)]


def item_face_unibrow():
    HAIR = mat("Hair", (0.1, 0.07, 0.05), 0.8)
    pieces = [box((0.3, 0.03, 0.04), (0, 0.272, 1.465), HAIR, bevel=0.012)]
    for s in (-1, 1):
        pieces.append(box((0.08, 0.03, 0.04), (s * 0.17, 0.255, 1.45), HAIR, bevel=0.012, rot=(0, math.radians(-s * 20), 0)))
    return [part("Head", pieces)]


def item_face_terminator():
    """Очки «как у Терминатора» (пародийные)."""
    BLACK = mat("Lens", (0.04, 0.05, 0.06), 0.1, 0.6)
    pieces = [box((0.44, 0.03, 0.09), (0, 0.3, 1.37), BLACK, bevel=0.012)]
    for s in (-1, 1):
        pieces.append(box((0.03, 0.26, 0.03), (s * 0.29, 0.16, 1.39), BLACK))
    return [part("Head", pieces)]


# ======================= Аксессуары: шея и спина =======================

def item_neck_gold_chain():
    """Золотая цепь «с палец»: дуга звеньев по груди."""
    GOLD = mat("Gold", (0.85, 0.65, 0.2), 0.3, 1.0)
    pieces = []
    n = 13
    for i in range(n):
        t = i / (n - 1) * 2 - 1                                                       # -1..1
        x, z = 0.17 * t, 0.86 + 0.2 * t * t
        y = 0.205 + 0.03 * (1 - abs(t))
        bpy.ops.mesh.primitive_torus_add(major_radius=0.026, minor_radius=0.011, major_segments=8,
                                         minor_segments=4, location=(x, y, z),
                                         rotation=(0, math.radians(90) if i % 2 else 0, math.atan2(0.4 * t, 1)))
        pieces.append(flat(bpy.context.object, GOLD))
    return [part("Torso", pieces)]


def item_neck_whistle():
    METAL = mat("Steel", (0.8, 0.8, 0.82), 0.25, 1.0)
    CORD = mat("Cord", (0.85, 0.15, 0.1), 0.8)
    pieces = []
    for s in (-1, 1):
        pieces.append(box((0.015, 0.015, 0.22), (s * 0.06, 0.2, 0.98), CORD, rot=(0, math.radians(s * 22), 0)))
    pieces.append(cyl(0.035, 0.08, (0, 0.235, 0.87), METAL, verts=8, rot=(0, math.radians(90), 0)))
    pieces.append(box((0.05, 0.04, 0.03), (0.06, 0.235, 0.885), METAL))
    return [part("Torso", pieces)]


def item_back_bag():
    """Челночная сумка в клетку за спиной."""
    RED = mat("BagRed", (0.75, 0.12, 0.1), 0.8)
    BLUE = mat("BagBlue", (0.12, 0.2, 0.6), 0.8)
    WHITE = mat("BagWhite", (0.9, 0.9, 0.88), 0.8)
    W, D, H, Y, Z = 0.5, 0.26, 0.46, -0.33, 0.8
    pieces = [box((W, D, H), (0, Y, Z), WHITE)]
    for face_y in (Y - D / 2, Y + D / 2):                                             # задняя и передняя грани
        for i, x in enumerate((-0.18, -0.06, 0.06, 0.18)):
            pieces.append(box((0.05, 0.008, H), (x, face_y, Z), RED if i % 2 else BLUE))
        for i, z in enumerate((-0.15, -0.05, 0.05, 0.15)):
            pieces.append(box((W, 0.012, 0.04), (0, face_y, Z + z), BLUE if i % 2 else RED))
    for face_x in (-W / 2, W / 2):                                                   # боковые грани
        for i, z in enumerate((-0.15, -0.05, 0.05, 0.15)):
            pieces.append(box((0.012, D, 0.04), (face_x, Y, Z + z), BLUE if i % 2 else RED))
    pieces.append(box((0.12, 0.05, 0.03), (0, Y, Z + H / 2 + 0.015), BLUE))           # ручка
    for s_ in (-1, 1):
        pieces.append(box((0.04, 0.2, 0.04), (s_ * 0.15, -0.12, 1.02), BLUE))
    return [part("Torso", pieces)]


def item_back_ranets():
    """Школьный ранец."""
    BROWN = mat("RanetsBrown", (0.35, 0.18, 0.08), 0.6)
    REFLECT = mat("Reflector", (0.95, 0.75, 0.1), 0.3)
    STRAP = mat("Strap", (0.15, 0.1, 0.06), 0.7)
    pieces = [box((0.36, 0.16, 0.38), (0, -0.28, 0.82), BROWN, bevel=0.04)]
    pieces.append(box((0.32, 0.03, 0.18), (0, -0.37, 0.86), BROWN, bevel=0.02))
    pieces.append(box((0.1, 0.02, 0.06), (0, -0.39, 0.8), REFLECT))
    for s in (-1, 1):
        pieces.append(box((0.04, 0.42, 0.04), (s * 0.13, -0.03, 1.03), STRAP))
    return [part("Torso", pieces)]


ITEMS = {
    # Шапки (в т.ч. бандана на лицо)
    "hat_kepka": item_kepka,
    "hat_ushanka": item_ushanka,
    "hat_petushok": item_hat_petushok,
    "hat_panama": item_hat_panama,
    "hat_bandana": item_hat_bandana,
    "hat_pilotka": item_hat_pilotka,
    "hat_fedora": item_hat_fedora,
    "hat_curlers": item_hat_curlers,
    "hat_tubeteika": item_hat_tubeteika,
    "hat_pompom": item_hat_pompom,
    "hat_hardhat": item_hat_hardhat,
    # Куртки и верх
    "jacket_abibas": item_abibas_jacket,
    "jacket_kosuha": item_jacket_kosuha,
    "jacket_alkogolichka": item_jacket_alkogolichka,
    "jacket_dutik": item_jacket_dutik,
    "jacket_varenka": item_jacket_varenka,
    "jacket_pioneer": item_jacket_pioneer,
    "jacket_seller_robe": item_jacket_seller_robe,
    "jacket_blazer": item_jacket_blazer,
    "jacket_granny": item_jacket_granny,
    # Штаны
    "pants_abibas": item_abibas_pants,
    "pants_klesh": item_pants_klesh,
    "pants_sharovary": item_pants_sharovary,
    "pants_family": item_pants_family,
    "pants_overalls": item_pants_overalls,
    "pants_school": item_pants_school,
    "pants_camo": item_pants_camo,
    "pants_pe_shorts": item_pants_pe_shorts,
    # Обувь
    "shoes_kedy": item_kedy,
    "shoes_valenki": item_shoes_valenki,
    "shoes_galoshi": item_shoes_galoshi,
    "shoes_slippers": item_shoes_slippers,
    "shoes_rubber_boots": item_shoes_rubber_boots,
    "shoes_pumba": item_shoes_pumba,
    "shoes_platform": item_shoes_platform,
    # Лицо
    "face_glasses_drops": item_glasses_drops,
    "face_terminator": item_face_terminator,
    "face_mustache": item_face_mustache,
    "face_unibrow": item_face_unibrow,
    # Шея и спина
    "neck_gold_chain": item_neck_gold_chain,
    "neck_whistle": item_neck_whistle,
    "back_bag": item_back_bag,
    "back_ranets": item_back_ranets,
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
scene = bpy.context.scene
COLORS = [(0.75, 0.12, 0.08), (0.08, 0.22, 0.7), (0.85, 0.6, 0.05), (0.12, 0.5, 0.15)]


def light(loc, energy, color, size, target):
    d = bpy.data.lights.new("L", "AREA")
    d.energy, d.color, d.size = energy, color, size
    o = bpy.data.objects.new("L", d)
    o.location = loc
    scene.collection.objects.link(o)
    o.rotation_euler = (Vector(target) - o.location).to_track_quat("-Z", "Y").to_euler()


def render_lineup(filename, looks, back_view=False):
    """Ряд персонажей: looks — списки вещей. back_view — смотреть со спины."""
    for o in list(bpy.data.objects):
        if o.name != "Cam":
            bpy.data.objects.remove(o, do_unlink=True)
    n = len(looks)
    step = 0.95
    for i, items in enumerate(looks):
        offset = Vector(((i - (n - 1) / 2) * step, 0, 0))
        m = mat(f"Player{i % 4}", COLORS[i % 4], 0.55)
        objs = build_base()
        for item_id in items:
            objs += ITEMS[item_id]()
        for o in objs:
            o.location += offset
            for slot in o.material_slots:
                if slot.material and slot.material.name.startswith("Primary"):
                    slot.link = "OBJECT"
                    slot.material = m
    scene.cursor.location = (0, 0, 0)
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    bpy.context.object.data.materials.append(mat("Ground", (0.45, 0.42, 0.38), 0.9))
    side = -1 if back_view else 1
    light((-3, 5 * side, 5), 1200, (1, 0.93, 0.82), 5, (0, 0, 0.8))
    light((4, 3 * side, 2), 300, (0.75, 0.82, 1), 4, (0, 0, 0.8))
    width = n * step
    dist = max(4.0, width * 1.65)
    cam.location = (0, dist * side, 1.5)
    cam.rotation_euler = (Vector((0, 0, 0.85)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, filename)
    bpy.ops.render.render(write_still=True)
    print("RENDERED", filename)


scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.7, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.5
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 50
scene.render.engine = "CYCLES"
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1800, 700
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"


def with_cam(fn):
    def run(*a, **k):
        if cam.name not in scene.collection.objects:
            scene.collection.objects.link(cam)
        scene.camera = cam
        return fn(*a, **k)
    return run


render_lineup = with_cam(render_lineup)
by_prefix = lambda p: [[k] for k in ITEMS if k.startswith(p)]
render_lineup("_preview_hats.png", by_prefix("hat_"))
render_lineup("_preview_jackets.png", by_prefix("jacket_"))
render_lineup("_preview_pants.png", by_prefix("pants_"))
render_lineup("_preview_shoes.png", by_prefix("shoes_"))
render_lineup("_preview_face_neck.png", by_prefix("face_") + by_prefix("neck_"))
render_lineup("_preview_back.png", by_prefix("back_"), back_view=True)
print("DONE")
