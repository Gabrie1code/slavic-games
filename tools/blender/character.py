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


# ======================= Общие заготовки одежды =======================

def sphere_cap(r, center, m, zmin, scale=(1, 1, 1), segs=12, rings=8):
    """Верх сферы выше zmin (для шапок), снизу закрыт — без дыры."""
    o = sphere(r, center, m, scale=scale, segs=segs, rings=rings)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < zmin - 0.001], context="VERTS")
    bmesh.ops.holes_fill(bm, edges=bm.edges, sides=0)
    bm.to_mesh(o.data)
    bm.free()
    return o


def torso_r(z):
    """Радиус туловища на высоте z (туловище расширяется к плечам)."""
    return 0.23 + (min(max(z, 0.505), 1.055) - 0.505) / 0.55 * 0.04


def torso_front_y(x, z, extra=0.02, depth=0.74):
    """Где передняя поверхность одежды на туловище (для накладок вплотную)."""
    r = torso_r(z) + extra
    return depth * r * math.sqrt(max(0.0, 1 - (x / r) ** 2))


def torso_shell(m, z_bot, z_top, extra=0.02, shoulders=True, depth=0.74):
    pieces = [cyl(torso_r(z_bot) + extra, z_top - z_bot, (0, 0, (z_top + z_bot) / 2), m, verts=12,
                  r2=torso_r(z_top) + extra, scale=(1, depth, 1))]
    if shoulders:
        pieces.append(sphere(0.27 + extra, (0, 0, 1.03), m, scale=(1, depth, 0.36), segs=12, rings=5))
    return pieces


def striped_tube(x, side, r, z_bot, z_top, base, stripe, verts=16):
    """Труба (рукав/штанина) с полосами ПО ТКАНИ на внешней стороне — вровень, без накладок."""
    o = cyl(r, z_top - z_bot, (x, 0, (z_top + z_bot) / 2), base, verts=verts)
    o.data.materials.append(stripe)
    step = 2 * math.pi / verts
    if STRIPES == 3:
        offsets = (-2, 0, 2)
    elif STRIPES == 2:
        offsets = (-1, 1)
    else:
        offsets = tuple(range(-(STRIPES - 1), STRIPES, 2))
    for poly in o.data.polygons:
        if abs(poly.normal.z) > 0.5:
            continue
        c = poly.center
        ang = math.atan2(c.y, c.x - x)
        # Полосы по шву, чуть развёрнуты к лицу — так их видно спереди.
        out = 0.55 if side > 0 else math.pi - 0.55
        d = (ang - out + math.pi) % (2 * math.pi) - math.pi
        k = round(d / step)
        if abs(d - k * step) < step * 0.3 and k in offsets:
            poly.material_index = 1
    return o


def sleeve(x, m, z_bot=0.66, r=0.088):
    return [cyl(r, 1.0 - z_bot, (x, 0, (1.0 + z_bot) / 2), m, verts=10),
            sphere(r + 0.002, (x, 0, 1.0), m, segs=10, rings=5)]


def jacket(body, sleeves_fn=None):
    """Куртка: туловище + рукава. sleeves_fn(x, side) -> куски рукава."""
    objs = [part("Torso", body)]
    if sleeves_fn:
        for side, x, s in (("ArmL", -0.31, -1), ("ArmR", 0.31, 1)):
            objs.append(part(side, sleeves_fn(x, s)))
    return objs


def seat(m):
    """Посадка штанов: закрывает таз и промежность, чтобы тело не просвечивало."""
    return [cyl(0.252, 0.13, (0, 0, 0.585), m, verts=12, scale=(1, 0.76, 1)),
            sphere(0.252, (0, 0, 0.53), m, scale=(1, 0.76, 0.45), segs=12, rings=6)]


def legs(leg_fn, waist=None):
    """Штаны/обувь: leg_fn(x, side) -> куски штанины; waist — куски на туловище."""
    objs = [part("Torso", waist)] if waist else []
    for side, x, s in (("LegL", -0.13, -1), ("LegR", 0.13, 1)):
        objs.append(part(side, leg_fn(x, s)))
    return objs


def buttons(m, x, zs, y=0.215, r=0.022):
    return [cyl(r, 0.02, (x, y, z), m, verts=8, rot=(math.radians(90), 0, 0)) for z in zs]


def front_patch(m, x, z, w, h, extra=0.02, thick=0.012, rot_y=0.0):
    """Плоская накладка вплотную к груди (карман, лацкан, пятно)."""
    y = torso_front_y(x, z, extra) + thick / 2 - 0.004
    return box((w, thick, h), (x, y, z), m, rot=(0, math.radians(rot_y), 0))


def shoulder_straps(m, xs=(-0.13, 0.13), z_front=0.8, z_back=0.8, w=0.055, extra=0.02, buckle=None):
    """Лямки через плечи: спереди вниз, через верх плеча, сзади вниз."""
    pieces = []
    for x in xs:
        top = 1.1
        yf = torso_front_y(x, (top + z_front) / 2, extra) + 0.008
        pieces.append(box((w, 0.016, top - z_front), (x, yf, (top + z_front) / 2), m))
        pieces.append(box((w, 0.016, top - z_back), (x, -yf, (top + z_back) / 2), m))
        pieces.append(box((w, 2 * yf + 0.016, 0.03), (x, 0, top), m))
        if buckle:
            pieces.append(box((w + 0.015, 0.02, 0.035), (x, yf + 0.006, z_front + 0.05), buckle))
    return pieces


def segment_box(p1, p2, m, w=0.05, t=0.014):
    """Плоская лента от точки p1 до p2 (лямки, ремни)."""
    a, b = Vector(p1), Vector(p2)
    d = b - a
    o = box((w, t, d.length + 0.01), (0, 0, 0), m)
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.location = (a + b) / 2
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return o


def strap_path(points, m, w=0.05, t=0.014):
    """Лента по ломаной: соседние точки соединяются кусками."""
    return [segment_box(points[i], points[i + 1], m, w, t) for i in range(len(points) - 1)]


def chest_y(x, z, extra=0.0):
    """Передняя поверхность тела (туловище + купол плеч) на высоте z."""
    if z > 1.03:
        k = max(0.0, 1 - ((z - 1.03) / (0.36 * 0.27)) ** 2)
        rx, ry = 0.27 * math.sqrt(k) + extra, 0.2 * math.sqrt(k) + extra
    else:
        rx = torso_r(z) + extra
        ry = 0.74 * rx
    return ry * math.sqrt(max(0.0, 1 - (x / max(rx, 0.01)) ** 2))


def print_dot(center, normal_angle, r, m, depth=0.004, stretch=1.0, spin=0.0):
    """Плоское «напечатанное» пятно вплотную к ткани (горошек, камуфляж)."""
    o = cyl(r, depth, (0, 0, 0), m, verts=8, rot=(math.radians(90), 0, 0), scale=(1, 1, 1))
    o.scale = (1, 1, stretch)
    o.rotation_euler = (0, spin, normal_angle - math.pi / 2)
    o.location = center
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return o


def dots_on_tube(x, r, zs, m, per_ring=6, dot=0.022, stretch=1.0, offset=30, mats=None):
    """Горошек/пятна по трубе (штанине) — вплотную к ткани."""
    pieces = []
    for j, z in enumerate(zs):
        for k in range(per_ring):
            a = math.radians(k * 360 / per_ring + j * offset)
            center = (x + math.cos(a) * (r + 0.001), math.sin(a) * (r + 0.001), z)
            mm = mats[(j + k) % len(mats)] if mats else m
            pieces.append(print_dot(center, a, dot, mm, stretch=stretch, spin=math.radians(17 * k)))
    return pieces


def dots_on_seat(zs, m, per_ring=8, dot=0.022, stretch=1.0, mats=None):
    pieces = []
    for j, z in enumerate(zs):
        for k in range(per_ring):
            a = math.radians(k * 360 / per_ring + j * 22)
            rx, ry = 0.253, 0.253 * 0.76
            px, py = math.cos(a) * rx, math.sin(a) * ry
            normal = math.atan2(py / ry ** 2, px / rx ** 2)
            mm = mats[(j + k) % len(mats)] if mats else m
            pieces.append(print_dot((px, py, z), normal, dot, mm, stretch=stretch))
    return pieces


def rotate_pieces(pieces, angle_y, center):
    """Повернуть набор кусков вокруг оси Y относительно точки (наклон гитары и т.п.)."""
    from mathutils import Matrix
    c = Vector(center)
    m = Matrix.Translation(c) @ Matrix.Rotation(angle_y, 4, "Y") @ Matrix.Translation(-c)
    for o in pieces:
        o.matrix_world = m @ o.matrix_world
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        # apply переносит поворот в вершины, но сдвиг остаётся в location — это нормально для part()
    return pieces


# ======================= Шапки =======================

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
    pieces.append(cyl(0.345, 0.1, (0, 0.0, 1.47), FUR, verts=10))
    pieces.append(box((0.42, 0.07, 0.12), (0, 0.33, 1.56), FUR, bevel=0.03))
    for x in (-0.31, 0.31):
        pieces.append(box((0.07, 0.24, 0.26), (x, 0.0, 1.35), FUR, bevel=0.03))
    pieces.append(cyl(0.045, 0.02, (0, 0.37, 1.57), STAR, verts=5, rot=(math.radians(90), 0, 0)))
    return [part("Head", pieces)]


def item_hat_petushok():
    """Шапка-«петушок»: бордовая вязаная, с белой полосой и гребешком."""
    BORDO = mat("Bordo", (0.32, 0.02, 0.06), 0.95)
    W = mat("KnitWhite", (0.92, 0.92, 0.9), 0.95)
    pieces = [cyl(0.318, 0.1, (0, 0, 1.47), BORDO, verts=12)]
    pieces.append(cyl(0.322, 0.035, (0, 0, 1.47), W, verts=12))
    pieces.append(cyl(0.31, 0.3, (0, 0, 1.66), BORDO, verts=12, r2=0.1))
    pieces.append(sphere(0.12, (0, 0, 1.83), BORDO, scale=(0.35, 1.1, 1), segs=8, rings=5))
    return [part("Head", pieces)]


def item_hat_panama():
    W = mat("PanamaWhite", (0.9, 0.88, 0.8), 0.9)
    BAND = mat("PanamaBand", (0.3, 0.45, 0.6), 0.8)
    pieces = [cyl(0.28, 0.16, (0, 0, 1.6), W, verts=12, r2=0.25)]
    pieces.append(cyl(0.46, 0.08, (0, 0, 1.5), W, verts=14, r2=0.3))
    pieces.append(cyl(0.285, 0.04, (0, 0, 1.54), BAND, verts=12))
    return [part("Head", pieces)]


def item_hat_pilotka():
    """Пилотка: вытянутая «лодочка» со скруглёнными концами."""
    KHAKI = mat("Khaki", (0.33, 0.35, 0.18), 0.85)
    STAR = mat("Star", (0.85, 0.08, 0.05), 0.4, 0.3)
    pieces = [sphere_cap(0.3, (0, 0, 1.53), KHAKI, 1.53, scale=(0.55, 1.1, 0.5), segs=16, rings=8)]
    pieces.append(cyl(0.3, 0.07, (0, 0, 1.555), KHAKI, verts=16, scale=(0.58, 1.12, 1)))
    pieces.append(cyl(0.04, 0.02, (0, 0.33, 1.57), STAR, verts=5, rot=(math.radians(90), 0, 0)))
    return [part("Head", pieces)]


def item_hat_fedora():
    FELT = mat("Felt", (0.25, 0.2, 0.16), 0.85)
    BAND = mat("FedoraBand", (0.08, 0.07, 0.07), 0.6)
    pieces = [cyl(0.27, 0.2, (0, 0, 1.66), FELT, verts=12, r2=0.22, scale=(1, 1.1, 1))]
    pieces.append(cyl(0.44, 0.03, (0, 0, 1.56), FELT, verts=14, scale=(1, 1.1, 1)))
    pieces.append(cyl(0.272, 0.05, (0, 0, 1.59), BAND, verts=12, scale=(1, 1.1, 1)))
    pieces.append(box((0.08, 0.3, 0.04), (0, 0, 1.765), FELT))
    return [part("Head", pieces)]


def item_hat_tubeteika():
    """Тюбетейка: круглая, низкая, чёрная с белым узором."""
    BLACK = mat("TubBlack", (0.03, 0.03, 0.035), 0.7)
    WHITE = mat("TubWhite", (0.95, 0.95, 0.9), 0.6)
    pieces = [cyl(0.255, 0.1, (0, -0.02, 1.565), BLACK, verts=16, r2=0.24)]
    pieces.append(sphere_cap(0.24, (0, -0.02, 1.6), BLACK, 1.613, scale=(1, 1, 0.25), segs=16))
    pieces.append(cyl(0.258, 0.018, (0, -0.02, 1.522), WHITE, verts=16))           # кайма
    for i in range(6):                                                              # «перчики»
        a = math.radians(i * 60)
        x, y = math.cos(a) * 0.253, math.sin(a) * 0.253 - 0.02
        pieces.append(sphere(0.03, (x, y, 1.57), WHITE, scale=(0.5, 0.5, 1.2), segs=6, rings=4))
    return [part("Head", pieces)]


def item_hat_pompom():
    P = mat("KnitNavy", (0.03, 0.06, 0.2), 0.95)
    W = mat("KnitWhite", (0.92, 0.92, 0.9), 0.95)
    pieces = [sphere_cap(0.315, (0, -0.01, 1.36), P, 1.44)]
    pieces.append(cyl(0.32, 0.1, (0, -0.01, 1.47), W, verts=12))
    pieces.append(sphere(0.11, (0, -0.01, 1.71), W, segs=8, rings=6))
    return [part("Head", pieces)]


def item_hat_hardhat():
    """Каска строителя: цельная оранжевая каска с козырьком и ребром."""
    ORANGE = mat("HardHatOrange", (0.95, 0.32, 0.03), 0.35)
    BAND = mat("HardHatBand", (0.15, 0.15, 0.16), 0.7)
    pieces = [sphere_cap(0.33, (0, -0.01, 1.38), ORANGE, 1.44, scale=(1, 1.05, 1), segs=16, rings=10)]
    pieces.append(cyl(0.335, 0.06, (0, -0.01, 1.465), BAND, verts=16, scale=(1, 1.05, 1)))   # оголовье
    pieces.append(cyl(0.37, 0.025, (0, 0.0, 1.44), ORANGE, verts=16, scale=(1, 1.12, 1)))    # поля
    pieces.append(box((0.3, 0.13, 0.025), (0, 0.36, 1.44), ORANGE, bevel=0.01))              # козырёк
    pieces.append(box((0.06, 0.62, 0.05), (0, -0.01, 1.7), ORANGE, bevel=0.02))              # ребро
    return [part("Head", pieces)]


# ======================= Куртки и верх =======================

def item_abibas_jacket():
    """Олимпийка «Абибас»: воротник-стойка, молния, полосы по шву рукава, манжеты и пояс."""
    P = primary()
    W = mat("StripeWhite", (0.95, 0.95, 0.95), 0.5)
    ZIP = mat("Zipper", (0.15, 0.15, 0.16), 0.4, 0.5)
    body = torso_shell(P, 0.55, 1.06)
    body.append(cyl(0.16, 0.1, (0, 0, 1.11), P, verts=12))                          # воротник-стойка
    body.append(cyl(0.163, 0.02, (0, 0, 1.155), W, verts=12))                       # кант воротника
    body.append(cyl(torso_r(0.55) + 0.03, 0.06, (0, 0, 0.56), P, verts=12, scale=(1, 0.76, 1)))  # пояс
    body.append(front_patch(ZIP, 0, 0.82, 0.014, 0.52))
    def arm(x, s):
        return [striped_tube(x, s, 0.09, 0.7, 1.0, P, W),
                sphere(0.092, (x, 0, 1.0), P, segs=10, rings=5),
                cyl(0.096, 0.06, (x, 0, 0.68), P, verts=10)]                      # манжет
    return jacket(body, arm)


def item_jacket_alkogolichka():
    """Майка-алкоголичка: круглый вырез, глубокие проймы, лямки — часть майки."""
    WHITE = mat("Undershirt", (0.95, 0.95, 0.93), 0.9)
    TRIM = mat("UndershirtTrim", (0.82, 0.82, 0.8), 0.9)
    e = 0.014
    shell = [cyl(torso_r(0.58) + e, 0.475, (0, 0, 0.8175), WHITE, verts=48, r2=torso_r(1.055) + e,
                 scale=(1, 0.74, 1)),
             sphere(0.27 + e, (0, 0, 1.03), WHITE, scale=(1, 0.74, 0.36), segs=48, rings=14)]

    def neck_z(x):
        return 0.88 + 2.8 * x * x                                                    # U-образный вырез

    def keep(c, normal_z):
        ax = abs(c.x)
        if abs(normal_z) > 0.95 and (c.z < 0.6 or c.z > 1.1):
            return False                                                             # торцы
        if c.z > 1.035 and not (0.115 < ax < 0.2):
            return False                                                             # над плечом — только лямка
        if c.y > 0 and ax < 0.125 and c.z > neck_z(ax):
            return False                                                             # вырез спереди
        if c.y < 0 and ax < 0.12 and c.z > 0.98:
            return False                                                             # вырез сзади
        side = ax / (torso_r(min(c.z, 1.05)) + e)
        if side > 0.7 and c.z > 0.84 - (side - 0.7) * 0.25:
            return False                                                             # проймы
        return True

    for o in shell:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        vertical = [ed for ed in bm.edges if abs(ed.verts[0].co.z - ed.verts[1].co.z) > 0.05]
        if vertical:
            bmesh.ops.subdivide_edges(bm, edges=vertical, cuts=26, use_grid_fill=True)
        kill = [f for f in bm.faces if not keep(f.calc_center_median(), f.normal.z)]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bm.to_mesh(o.data)
        bm.free()
    shell.append(cyl(torso_r(0.6) + e + 0.003, 0.025, (0, 0, 0.595), TRIM, verts=32, scale=(1, 0.74, 1)))
    return jacket(shell)


def item_jacket_dutik():
    """Пуховик-«дутик»: тёмно-синий, стёганый."""
    NAVY = mat("DutikNavy", (0.05, 0.08, 0.22), 0.35)
    SEAM = mat("DutikSeam", (0.02, 0.03, 0.08), 0.6)
    body = []
    for z in (0.62, 0.76, 0.9):
        body.append(sphere(torso_r(z) + 0.075, (0, 0, z), NAVY, scale=(1, 0.8, 0.36), segs=14, rings=6))
        body.append(cyl(torso_r(z) + 0.05, 0.012, (0, 0, z + 0.068), SEAM, verts=14, scale=(1, 0.8, 1)))
    body.append(sphere(0.34, (0, 0, 1.03), NAVY, scale=(1, 0.8, 0.36), segs=14, rings=6))
    body.append(cyl(0.18, 0.14, (0, 0, 1.12), NAVY, verts=12))
    ZIP = mat("ZipSilver", (0.85, 0.85, 0.88), 0.25, 1.0)
    body.append(front_patch(SEAM, 0, 0.82, 0.05, 0.56, extra=0.085, thick=0.02))     # планка
    body.append(front_patch(ZIP, 0, 0.82, 0.018, 0.56, extra=0.085, thick=0.03))     # молния
    body.append(front_patch(ZIP, 0, 1.0, 0.03, 0.06, extra=0.11, thick=0.02))        # бегунок
    def puffy(x, s):
        pieces = [sphere(0.115, (x, 0, z), NAVY, scale=(1, 1, 0.65), segs=10, rings=5) for z in (0.94, 0.84, 0.74)]
        pieces.append(sphere(0.12, (x, 0, 1.0), NAVY, segs=10, rings=5))
        pieces.append(cyl(0.09, 0.05, (x, 0, 0.67), SEAM, verts=10))
        return pieces
    return jacket(body, puffy)


def item_jacket_varenka():
    """Джинсовка-варёнка: синяя, с потёртостями, кокеткой, карманами и медными пуговицами."""
    DENIM = mat("Denim", (0.16, 0.27, 0.5), 0.85)
    WASH = mat("DenimWash", (0.28, 0.42, 0.66), 0.9)
    SEAM = mat("DenimSeam", (0.8, 0.6, 0.25), 0.7)
    BTN = mat("Copper", (0.7, 0.45, 0.2), 0.4, 0.8)
    body = torso_shell(DENIM, 0.56, 1.06)
    for x, z, w, h in ((-0.12, 0.72, 0.13, 0.1), (0.13, 0.66, 0.1, 0.12), (0.02, 0.6, 0.16, 0.06)):
        body.append(front_patch(WASH, x, z, w, h, thick=0.008))                     # потёртости
    body.append(front_patch(SEAM, 0, 0.97, 0.42, 0.012, thick=0.008))               # кокетка
    for x in (-0.12, 0.12):                                                          # карманы с клапаном
        body.append(front_patch(DENIM, x, 0.9, 0.11, 0.09, thick=0.016))
        body.append(front_patch(SEAM, x, 0.94, 0.12, 0.012, thick=0.02))
        body.append(front_patch(BTN, x, 0.925, 0.02, 0.02, thick=0.024))
    body += [front_patch(BTN, 0.0, z, 0.024, 0.024, thick=0.02) for z in (0.62, 0.72, 0.82)]
    for x, a in ((-0.09, 35), (0.09, -35)):                                          # отложной воротник
        body.append(box((0.14, 0.03, 0.08), (x, 0.15, 1.1), DENIM, rot=(math.radians(-30), math.radians(a), 0)))
    def arm(x, s):
        return sleeve(x, DENIM, r=0.09) + [cyl(0.094, 0.05, (x, 0, 0.68), DENIM, verts=10),
                                           sphere(0.045, (x + s * 0.085, 0.02, 0.84), WASH, scale=(0.3, 1, 1.4),
                                                  segs=6, rings=4)]
    return jacket(body, arm)


def item_jacket_pioneer():
    """Пионерская рубашка с красным галстуком."""
    WHITE = mat("ShirtWhite", (0.95, 0.95, 0.93), 0.8)
    RED = mat("TieRed", (0.85, 0.06, 0.04), 0.6)
    body = torso_shell(WHITE, 0.56, 1.06)
    for x, a in ((-0.08, 30), (0.08, -30)):
        body.append(box((0.12, 0.02, 0.06), (x, 0.17, 1.08), WHITE, rot=(0, math.radians(a), 0)))
    body.append(sphere(0.04, (0, 0.2, 1.04), RED, segs=6, rings=4))
    for x, a in ((-0.04, 12), (0.05, -14)):
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


def item_jacket_kosuha():
    """Кожанка-косуха: косая молния, большие лацканы с кнопками, погоны, пояс с пряжкой."""
    LEATHER = mat("Leather", (0.05, 0.05, 0.055), 0.28, 0.15)
    METAL = mat("Steel", (0.8, 0.8, 0.82), 0.25, 1.0)
    body = torso_shell(LEATHER, 0.55, 1.06)
    # Косая молния от левого бедра к правому плечу.
    for i in range(7):
        t = i / 6
        x, z = -0.1 + 0.2 * t, 0.62 + 0.4 * t
        body.append(front_patch(METAL, x, z, 0.016, 0.075, thick=0.016, rot_y=-27))
    # Лацканы: большие треугольники, отогнутые на грудь.
    for s in (-1, 1):
        bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.12, radius2=0, depth=0.02,
                                        location=(s * 0.11, torso_front_y(s * 0.11, 0.97) + 0.012, 0.97),
                                        rotation=(math.radians(90), 0, math.radians(180 if s > 0 else 0)))
        body.append(flat(bpy.context.object, LEATHER))
        body.append(front_patch(METAL, s * 0.17, 0.93, 0.022, 0.022, thick=0.03))   # кнопка лацкана
    body.append(front_patch(METAL, 0.12, 0.76, 0.1, 0.012, thick=0.02))              # карман на молнии
    body.append(cyl(torso_r(0.6) + 0.035, 0.06, (0, 0, 0.6), LEATHER, verts=12, scale=(1, 0.77, 1)))  # пояс
    body.append(front_patch(METAL, -0.08, 0.6, 0.06, 0.05, extra=0.035, thick=0.02))               # пряжка
    for s in (-1, 1):                                                                # погоны
        body.append(box((0.12, 0.06, 0.02), (s * 0.22, 0, 1.12), LEATHER, rot=(0, math.radians(-s * 18), 0)))
        body.append(cyl(0.012, 0.02, (s * 0.27, 0.0, 1.11), METAL, verts=6))
    def arm(x, s):
        return sleeve(x, LEATHER, r=0.092) + [cyl(0.095, 0.03, (x, 0, 0.7), METAL, verts=10),
                                             box((0.012, 0.03, 0.1), (x + s * 0.09, 0, 0.74), METAL)]
    return jacket(body, arm)


def item_jacket_blazer():
    """Малиновый пиджак с подплечниками: лацканы, белая рубашка, золотые пуговицы."""
    RASP = mat("Raspberry", (0.5, 0.02, 0.16), 0.5)
    SHIRT = mat("ShirtWhite", (0.95, 0.95, 0.93), 0.8)
    GOLD = mat("Gold", (0.85, 0.65, 0.2), 0.3, 1.0)
    body = torso_shell(RASP, 0.52, 1.06)
    body.append(sphere(0.31, (0, 0, 1.03), RASP, scale=(1.08, 0.76, 0.36), segs=12, rings=5))   # широкие плечи
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.12, radius2=0, depth=0.02,
                                    location=(0, torso_front_y(0, 0.97) + 0.008, 0.97),
                                    rotation=(math.radians(90), 0, math.radians(180)))
    body.append(flat(bpy.context.object, SHIRT))                                     # вырез с рубашкой
    for s in (-1, 1):                                                                # лацканы
        body.append(front_patch(RASP, s * 0.085, 0.93, 0.07, 0.26, thick=0.02, rot_y=-s * 20))
    body += [front_patch(GOLD, 0.0, z, 0.026, 0.026, thick=0.024) for z in (0.66, 0.76)]
    body.append(front_patch(SHIRT, 0.15, 0.92, 0.06, 0.03, thick=0.02))             # платочек
    body.append(front_patch(RASP, -0.14, 0.66, 0.12, 0.012, thick=0.02))            # клапаны карманов
    body.append(front_patch(RASP, 0.14, 0.66, 0.12, 0.012, thick=0.02))
    def padded(x, s):
        return sleeve(x, RASP, r=0.095) + [sphere(0.13, (x - s * 0.02, 0, 1.04), RASP, scale=(1.1, 1, 0.55),
                                                  segs=10, rings=5),
                                           cyl(0.075, 0.03, (x, 0, 0.66), SHIRT, verts=10)]
    return jacket(body, padded)


def item_jacket_granny():
    """Бабушкина кофта: вязаная, горчичная, V-вырез, большие пуговицы, карманы."""
    KNIT = mat("GrannyKnit", (0.55, 0.38, 0.08), 0.95)
    RIB = mat("GrannyRib", (0.42, 0.28, 0.05), 0.95)
    BTN = mat("BtnWood", (0.28, 0.14, 0.06), 0.6)
    body = torso_shell(KNIT, 0.5, 1.06, extra=0.03)
    for z in (0.6, 0.7, 0.8, 0.9):                                                   # вязаные «рубчики»
        body.append(cyl(torso_r(z) + 0.034, 0.012, (0, 0, z), RIB, verts=12, scale=(1, 0.75, 1)))
    body.append(cyl(torso_r(0.5) + 0.036, 0.06, (0, 0, 0.52), RIB, verts=12, scale=(1, 0.75, 1)))
    for s in (-1, 1):                                                                # кант V-выреза
        body.append(front_patch(RIB, s * 0.05, 0.97, 0.035, 0.2, extra=0.03, thick=0.02, rot_y=-s * 22))
    body += [front_patch(BTN, 0.0, z, 0.034, 0.034, extra=0.03, thick=0.026) for z in (0.6, 0.7, 0.8)]
    for x in (-0.15, 0.15):
        body.append(front_patch(RIB, x, 0.63, 0.12, 0.11, extra=0.03, thick=0.02))
    return jacket(body, lambda x, s: sleeve(x, KNIT, r=0.096) + [cyl(0.1, 0.06, (x, 0, 0.67), RIB, verts=10)])


# ======================= Штаны =======================

def item_abibas_pants():
    P = primary()
    W = mat("StripeWhite", (0.95, 0.95, 0.95), 0.5)
    w = seat(P) + [cyl(0.257, 0.05, (0, 0, 0.625), P, verts=12, scale=(1, 0.76, 1))]
    return legs(lambda x, s: [striped_tube(x, s, 0.105, 0.17, 0.56, P, W),
                              cyl(0.108, 0.05, (x, 0, 0.16), P, verts=12)], w)


def item_pants_klesh():
    DENIM = mat("DenimNight", (0.04, 0.06, 0.16), 0.85)
    SEAM = mat("DenimSeam", (0.8, 0.6, 0.25), 0.7)
    return legs(lambda x, s: [cyl(0.17, 0.44, (x, 0, 0.34), DENIM, verts=12, r2=0.1),
                              cyl(0.172, 0.02, (x, 0, 0.13), SEAM, verts=12)], seat(DENIM))


def item_pants_sharovary():
    P = mat("Sharovary", (0.45, 0.06, 0.35), 0.7)
    GOLD = mat("TubGold", (0.9, 0.75, 0.3), 0.4, 0.5)
    w = seat(P)
    return legs(lambda x, s: [sphere(0.15, (x, 0, 0.38), P, scale=(1, 1, 1.4), segs=12, rings=6),
                              cyl(0.1, 0.05, (x, 0, 0.17), GOLD, verts=10)], w)


def item_pants_family():
    """Семейные трусы: белые в тёмно-синий горошек (горошек — рисунок на ткани)."""
    BASE = mat("ShortsWhite", (0.93, 0.93, 0.92), 0.9)
    DOT = mat("NavyDot", (0.03, 0.06, 0.28), 0.7)
    w = seat(BASE) + dots_on_seat((0.5, 0.57), DOT, per_ring=10)
    return legs(lambda x, s: [cyl(0.125, 0.18, (x, 0, 0.46), BASE, verts=12)] +
                dots_on_tube(x, 0.125, (0.41, 0.48), DOT, per_ring=7), w)


def item_pants_overalls():
    """Рабочий комбинезон: нагрудник, лямки через плечи с пряжками."""
    DENIM = mat("DenimOveralls", (0.18, 0.3, 0.55), 0.85)
    BTN = mat("Copper", (0.7, 0.45, 0.2), 0.4, 0.8)
    w = seat(DENIM)
    w.append(cyl(0.26, 0.12, (0, 0, 0.63), DENIM, verts=12, scale=(1, 0.77, 1)))
    w.append(front_patch(DENIM, 0, 0.8, 0.3, 0.26, extra=0.03, thick=0.03))         # нагрудник
    w.append(front_patch(DENIM, 0, 0.82, 0.12, 0.08, extra=0.05, thick=0.015))      # карман
    w += shoulder_straps(DENIM, xs=(-0.12, 0.12), z_front=0.88, z_back=0.7, w=0.055, extra=0.03, buckle=BTN)
    return legs(lambda x, s: [cyl(0.108, 0.42, (x, 0, 0.36), DENIM, verts=10)], w)


def item_pants_school():
    GREY = mat("SchoolGrey", (0.18, 0.19, 0.24), 0.8)
    CREASE = mat("Crease", (0.32, 0.33, 0.38), 0.8)
    return legs(lambda x, s: [cyl(0.105, 0.43, (x, 0, 0.355), GREY, verts=10),
                              box((0.01, 0.02, 0.4), (x, 0.104, 0.36), CREASE)], seat(GREY))


def camo_paint(o, mats, scale=9.0, cuts=10):
    """Раскрасить грани в камуфляж: мелкая сетка граней + цвет по шуму. Узор — часть ткани."""
    from mathutils import noise
    for m in mats[1:]:
        o.data.materials.append(m)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    vertical = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 0.03]
    if vertical:
        bmesh.ops.subdivide_edges(bm, edges=vertical, cuts=cuts, use_grid_fill=True)
    for f in bm.faces:
        c = f.calc_center_median()
        n = noise.noise(Vector((c.x * scale, c.y * scale, c.z * scale * 1.4)))
        n2 = noise.noise(Vector((c.x * scale * 2 + 5, c.y * scale * 2, c.z * scale * 2)))
        if n > 0.25:
            f.material_index = 1
        elif n < -0.25:
            f.material_index = 2
        elif n2 > 0.35:
            f.material_index = 3
    bm.to_mesh(o.data)
    bm.free()
    return o


def item_pants_camo():
    """Камуфляж: пятна — раскраска самой ткани, плоские карманы-«карго»."""
    GREEN = mat("CamoGreen", (0.25, 0.32, 0.16), 0.9)
    DARK = mat("CamoDark", (0.08, 0.1, 0.05), 0.9)
    BROWN = mat("CamoBrown", (0.3, 0.21, 0.11), 0.9)
    SAND = mat("CamoSand", (0.45, 0.42, 0.27), 0.9)
    mats = [GREEN, DARK, BROWN, SAND]
    def leg(x, s):
        tube = camo_paint(cyl(0.108, 0.43, (x, 0, 0.355), GREEN, verts=16), mats)
        side = 0.0 if s > 0 else math.pi
        pocket = print_dot((x + s * 0.111, 0, 0.35), side, 0.055, BROWN, depth=0.01, stretch=1.2)
        flap = box((0.016, 0.115, 0.03), (x + s * 0.113, 0, 0.42), DARK)
        return [tube, pocket, flap]
    waist = [camo_paint(o, mats, cuts=6) for o in seat(GREEN)]
    return legs(leg, waist)


def item_pants_pe_shorts():
    """Синие шорты физрука."""
    BLUE = mat("PEBlue", (0.08, 0.2, 0.6), 0.7)
    return legs(lambda x, s: [cyl(0.122, 0.18, (x, 0, 0.47), BLUE, verts=12)], seat(BLUE))


def shoe_body(x, upper, sole, w=0.205, d=0.315, h=0.13, sole_h=0.03, y=0.04, bevel=0.04):
    """Цельный ботинок: подошва и верх одного размера — без «платформы»."""
    return [box((w, d, h - sole_h), (x, y, sole_h + (h - sole_h) / 2), upper, bevel=bevel),
            box((w, d, sole_h), (x, y, sole_h / 2), sole, bevel=0.012)]


def item_kedy():
    """Кеды: тёмно-синий верх, белая резиновая подошва и носок, шнурки."""
    CANVAS = mat("KedyNavy", (0.06, 0.09, 0.22), 0.85)
    RUBBER = mat("KedyRubber", (0.93, 0.92, 0.88), 0.7)
    LACE = mat("Lace", (0.95, 0.95, 0.95), 0.8)
    def shoe(x, s):
        pieces = shoe_body(x, CANVAS, RUBBER, h=0.14, sole_h=0.035)
        pieces.append(box((0.206, 0.09, 0.07), (x, 0.16, 0.06), RUBBER, bevel=0.03))       # резиновый носок
        pieces.append(cyl(0.108, 0.1, (x, -0.01, 0.17), CANVAS, verts=10))                 # высокий верх
        pieces.append(cyl(0.112, 0.02, (x, -0.01, 0.12), RUBBER, verts=10))
        for z in (0.1, 0.13, 0.16):
            pieces.append(box((0.08, 0.012, 0.01), (x, 0.09 - (z - 0.1) * 0.6, z), LACE))
        return pieces
    return legs(shoe)


def item_shoes_galoshi():
    """Галоши: блестящие чёрные, с красной подкладкой."""
    BLACK = mat("Rubber", (0.02, 0.02, 0.025), 0.12, 0.1)
    RED = mat("GaloshRed", (0.75, 0.05, 0.05), 0.7)
    return legs(lambda x, s: [box((0.21, 0.32, 0.12), (x, 0.045, 0.06), BLACK, bevel=0.05),
                              box((0.15, 0.22, 0.012), (x, 0.03, 0.121), RED, bevel=0.005),
                              cyl(0.098, 0.03, (x, -0.02, 0.135), BLACK, verts=10)])


def item_shoes_slippers():
    """Шлёпанцы с носками: белые носки до середины голени, синие шлёпанцы."""
    SOCK = mat("Sock", (0.95, 0.95, 0.92), 0.95)
    STRIPE = mat("SockStripe", (0.75, 0.08, 0.06), 0.9)
    SLIP = mat("SlipperBlue", (0.08, 0.3, 0.7), 0.5)
    def shoe(x, s):
        pieces = [box((0.19, 0.3, 0.11), (x, 0.04, 0.075), SOCK, bevel=0.045),
                  cyl(0.098, 0.22, (x, 0, 0.22), SOCK, verts=10),
                  cyl(0.1, 0.025, (x, 0, 0.3), STRIPE, verts=10)]
        pieces.append(box((0.215, 0.33, 0.03), (x, 0.045, 0.015), SLIP, bevel=0.012))     # подошва шлёпанца
        pieces.append(box((0.215, 0.12, 0.05), (x, 0.085, 0.07), SLIP, bevel=0.02))       # перемычка
        return pieces
    return legs(shoe)


def item_shoes_rubber_boots():
    """Жёлтые резиновые сапоги — цельные, до колена."""
    Y = mat("BootYellow", (0.95, 0.72, 0.03), 0.22)
    SOLE = mat("BootSole", (0.3, 0.22, 0.08), 0.8)
    def boot(x, s):
        pieces = shoe_body(x, Y, SOLE, w=0.215, d=0.32, h=0.14, sole_h=0.035, bevel=0.05)
        pieces.append(cyl(0.12, 0.34, (x, -0.01, 0.29), Y, verts=12))
        pieces.append(cyl(0.128, 0.04, (x, -0.01, 0.45), Y, verts=12))                  # отворот
        return pieces
    return legs(boot)


def item_shoes_valenki():
    """Валенки: серые, цельные, с округлым носом."""
    FELT = mat("FeltGrey", (0.36, 0.35, 0.34), 1.0)
    def boot(x, s):
        return [box((0.215, 0.32, 0.15), (x, 0.045, 0.075), FELT, bevel=0.065),
                cyl(0.12, 0.34, (x, -0.01, 0.29), FELT, verts=12),
                cyl(0.128, 0.05, (x, -0.01, 0.44), FELT, verts=12)]
    return legs(boot)


def item_shoes_pumba():
    """Кроссовки «Пумба» (пародия): белые, полоса цвета игрока вровень, гуммированная подошва."""
    P = primary()
    W = mat("CanvasWhite", (0.95, 0.95, 0.93), 0.75)
    GUM = mat("Gum", (0.55, 0.38, 0.18), 0.8)
    def shoe(x, s):
        pieces = shoe_body(x, W, GUM, h=0.14, sole_h=0.04)
        pieces.append(box((0.006, 0.2, 0.045), (x + s * 0.104, 0.03, 0.085), P, rot=(math.radians(-18), 0, 0)))
        pieces.append(cyl(0.108, 0.06, (x, -0.02, 0.155), W, verts=10))                  # мягкий задник
        pieces.append(box((0.07, 0.1, 0.03), (x, 0.08, 0.145), W, bevel=0.01))          # язычок
        return pieces
    return legs(shoe)


def item_shoes_platform():
    """Туфли на платформе: высокая кремовая подошва и красный лакированный верх."""
    RED = mat("PlatformRed", (0.7, 0.03, 0.08), 0.2)
    SOLE = mat("PlatformSole", (0.95, 0.9, 0.8), 0.6)
    def shoe(x, s):
        return [box((0.205, 0.315, 0.09), (x, 0.04, 0.045), SOLE, bevel=0.015),
                box((0.205, 0.315, 0.08), (x, 0.04, 0.125), RED, bevel=0.035),
                cyl(0.1, 0.04, (x, -0.02, 0.17), RED, verts=10)]
    return legs(shoe)


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
        pieces.append(box((0.08, 0.03, 0.04), (s * 0.17, 0.255, 1.45), HAIR, bevel=0.012,
                          rot=(0, math.radians(-s * 20), 0)))
    return [part("Head", pieces)]


def item_face_plaster():
    """Пластырь крест-накрест посреди лица."""
    BEIGE = mat("Plaster", (0.85, 0.66, 0.48), 0.7)
    PAD = mat("PlasterPad", (0.95, 0.9, 0.85), 0.7)
    pieces = []
    for a in (35, -35):
        pieces.append(box((0.14, 0.012, 0.035), (0, 0.29, 1.29), BEIGE, rot=(0, math.radians(a), 0)))
    pieces.append(box((0.035, 0.016, 0.035), (0, 0.292, 1.29), PAD))
    return [part("Head", pieces)]


def item_face_bruise():
    """Фингал под левым глазом."""
    BRUISE = mat("Bruise", (0.3, 0.12, 0.4), 0.8)
    BRUISE2 = mat("Bruise2", (0.2, 0.25, 0.5), 0.8)
    return [part("Head", [sphere(0.11, (-0.11, 0.245, 1.355), BRUISE, scale=(1.05, 0.3, 0.95), segs=10, rings=6),
                          sphere(0.06, (-0.15, 0.255, 1.29), BRUISE2, scale=(1, 0.3, 0.7), segs=8, rings=5)])]


def item_face_beard():
    """Борода-лопата."""
    HAIR = mat("BeardBrown", (0.18, 0.1, 0.05), 0.9)
    pieces = [box((0.36, 0.14, 0.3), (0, 0.2, 1.08), HAIR, bevel=0.06)]
    pieces.append(sphere(0.2, (0, 0.17, 1.2), HAIR, scale=(1.35, 0.6, 0.45), segs=10, rings=5))
    for s in (-1, 1):                                                                # бакенбарды
        pieces.append(box((0.06, 0.12, 0.2), (s * 0.27, 0.08, 1.27), HAIR, bevel=0.025))
    return [part("Head", pieces)]


def item_face_welder_mask():
    """Маска сварщика с тёмным стеклом."""
    SHELL = mat("WelderShell", (0.16, 0.2, 0.15), 0.6)
    GLASS = mat("WelderGlass", (0.02, 0.15, 0.05), 0.05, 0.3)
    BAND = mat("WelderBand", (0.1, 0.1, 0.1), 0.7)
    pieces = [box((0.48, 0.07, 0.46), (0, 0.33, 1.32), SHELL, bevel=0.05)]
    pieces.append(box((0.28, 0.02, 0.09), (0, 0.37, 1.38), GLASS, bevel=0.008))
    pieces.append(box((0.3, 0.025, 0.11), (0, 0.365, 1.38), BAND, bevel=0.008))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.305, minor_radius=0.018, major_segments=16, minor_segments=4,
                                     location=(0, 0, 1.45))
    pieces.append(flat(bpy.context.object, BAND))                                    # оголовье
    for s in (-1, 1):
        pieces.append(cyl(0.035, 0.03, (s * 0.31, 0.04, 1.4), BAND, verts=8, rot=(0, math.radians(90), 0)))
    return [part("Head", pieces)]


# ======================= Аксессуары: шея и спина =======================

def item_neck_gold_chain():
    """Толстая золотая цепь: петля вокруг шеи с провисом на грудь и медальоном."""
    GOLD = mat("GoldBright", (1.0, 0.82, 0.38), 0.2, 1.0)
    pts = []
    n = 15
    for i in range(n):                                                               # провис спереди
        t = i / (n - 1) * 2 - 1
        x, z = 0.16 * t, 1.1 - 0.15 * (1 - t * t)
        pts.append((x, chest_y(x, z) + 0.016, z))
    for i in range(1, 8):                                                            # сзади вокруг шеи
        b = math.radians(180 + i * 180 / 8)
        pts.append((-0.165 * math.cos(b), 0.13 * math.sin(b), 1.11))
    pieces = []
    for i, p in enumerate(pts):
        nxt = pts[(i + 1) % len(pts)]
        d = Vector(nxt) - Vector(p)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.026, minor_radius=0.011, major_segments=8,
                                         minor_segments=5, location=p)
        o = bpy.context.object
        # Звено вдоль цепи; соседние звенья повёрнуты на 90° друг к другу.
        o.rotation_euler = d.to_track_quat("X", "Z").to_euler()
        o.rotation_euler.rotate_axis("X", math.radians(90 if i % 2 else 0))
        pieces.append(flat(o, GOLD))
    pieces.append(cyl(0.045, 0.015, (0, chest_y(0, 0.92) + 0.03, 0.9), GOLD, verts=12,
                      rot=(math.radians(90), 0, 0)))
    return [part("Torso", pieces)]


def item_back_bag():
    """Челночная сумка в клетку за спиной, лямка наискосок через грудь до сумки."""
    RED = mat("BagRed", (0.75, 0.12, 0.1), 0.8)
    BLUE = mat("BagBlue", (0.12, 0.2, 0.6), 0.8)
    WHITE = mat("BagWhite", (0.9, 0.9, 0.88), 0.8)
    W, D, H, Y, Z = 0.5, 0.26, 0.46, -0.33, 0.8
    pieces = [box((W, D, H), (0, Y, Z), WHITE)]
    for face_y in (Y - D / 2, Y + D / 2):
        for i, x in enumerate((-0.18, -0.06, 0.06, 0.18)):
            pieces.append(box((0.05, 0.008, H), (x, face_y, Z), RED if i % 2 else BLUE))
        for i, z in enumerate((-0.15, -0.05, 0.05, 0.15)):
            pieces.append(box((W, 0.012, 0.04), (0, face_y, Z + z), BLUE if i % 2 else RED))
    for face_x in (-W / 2, W / 2):
        for i, z in enumerate((-0.15, -0.05, 0.05, 0.15)):
            pieces.append(box((0.012, D, 0.04), (face_x, Y, Z + z), BLUE if i % 2 else RED))
    # Лямка: верх сумки → через правое плечо → наискосок по груди → под левой рукой → низ сумки.
    path = [(0.15, Y + D / 2, Z + H / 2), (0.16, 0.0, 1.13)]
    for i in range(7):
        t = i / 6
        x, z = 0.16 - 0.38 * t, 1.08 - 0.46 * t
        path.append((x, chest_y(x, z, 0.02) + 0.01, z))
    path += [(-0.27, 0.0, 0.6), (-0.2, Y + D / 2, Z - H / 2 + 0.03)]
    pieces += strap_path(path, BLUE, w=0.06)
    return [part("Torso", pieces)]


def item_back_ranets():
    """Школьный ранец: лямки через плечи, по груди и под руками к низу ранца."""
    BROWN = mat("RanetsBrown", (0.35, 0.18, 0.08), 0.6)
    REFLECT = mat("Reflector", (0.95, 0.75, 0.1), 0.3)
    STRAP = mat("Strap", (0.15, 0.1, 0.06), 0.7)
    pieces = [box((0.36, 0.16, 0.38), (0, -0.28, 0.82), BROWN, bevel=0.04)]
    pieces.append(box((0.32, 0.03, 0.18), (0, -0.37, 0.86), BROWN, bevel=0.02))
    pieces.append(box((0.1, 0.02, 0.06), (0, -0.39, 0.8), REFLECT))
    for s in (-1, 1):
        x = s * 0.13
        path = [(x, -0.2, 1.0), (x, 0.0, 1.13)]
        for z in (1.06, 0.95, 0.84, 0.74):
            path.append((x, chest_y(x, z, 0.02) + 0.01, z))
        path += [(s * 0.27, 0.0, 0.68), (s * 0.15, -0.2, 0.66)]
        pieces += strap_path(path, STRAP, w=0.05)
    return [part("Torso", pieces)]


def item_back_guitar():
    """Гитара за спиной, ремень наискосок через грудь."""
    WOOD = mat("GuitarWood", (0.6, 0.3, 0.08), 0.4)
    DARK = mat("GuitarDark", (0.12, 0.07, 0.04), 0.5)
    HOLE = mat("GuitarHole", (0.02, 0.02, 0.02), 0.8)
    STRAP = mat("GuitarStrap", (0.55, 0.08, 0.08), 0.7)
    Y = -0.3
    g = [sphere(0.2, (0, Y, 0.62), WOOD, scale=(1, 0.32, 1), segs=14, rings=7),
         sphere(0.155, (0, Y, 0.88), WOOD, scale=(1, 0.32, 1), segs=14, rings=7),
         cyl(0.055, 0.01, (0, Y - 0.066, 0.76), HOLE, verts=12, rot=(math.radians(90), 0, 0)),
         box((0.07, 0.04, 0.48), (0, Y, 1.24), DARK),
         box((0.1, 0.05, 0.14), (0, Y, 1.53), DARK, bevel=0.015)]
    g = rotate_pieces(g, math.radians(-28), (0, Y, 0.85))
    # Ремень: гриф за левым плечом → наискосок по груди → под правой рукой → к корпусу.
    path = [(-0.16, -0.25, 1.08), (-0.16, 0.0, 1.13)]
    for i in range(7):
        t = i / 6
        x, z = -0.16 + 0.38 * t, 1.08 - 0.46 * t
        path.append((x, chest_y(x, z, 0.02) + 0.01, z))
    path += [(0.27, 0.0, 0.6), (0.18, Y + 0.02, 0.6)]
    g += strap_path(path, STRAP, w=0.05)
    return [part("Torso", g)]


ITEMS = {
    # Шапки
    "hat_kepka": item_kepka,
    "hat_ushanka": item_ushanka,
    "hat_petushok": item_hat_petushok,
    "hat_panama": item_hat_panama,
    "hat_pilotka": item_hat_pilotka,
    "hat_fedora": item_hat_fedora,
    "hat_tubeteika": item_hat_tubeteika,
    "hat_pompom": item_hat_pompom,
    "hat_hardhat": item_hat_hardhat,
    # Верх
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
    "face_mustache": item_face_mustache,
    "face_unibrow": item_face_unibrow,
    "face_plaster": item_face_plaster,
    "face_bruise": item_face_bruise,
    "face_beard": item_face_beard,
    "face_welder_mask": item_face_welder_mask,
    # Шея и спина
    "neck_gold_chain": item_neck_gold_chain,
    "back_bag": item_back_bag,
    "back_ranets": item_back_ranets,
    "back_guitar": item_back_guitar,
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
    dist = max(3.6, width * 1.4)
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
ONLY = [a.split("=", 1)[1] for a in sys.argv if a.startswith("--only=")]
if ONLY:
    scene.render.resolution_x, scene.render.resolution_y = 1200, 900
    render_lineup("_preview_only.png", [[k] for k in ONLY[0].split(",")])
    render_lineup("_preview_only_back.png", [[k] for k in ONLY[0].split(",")], back_view=True)
    print("DONE")
    sys.exit(0)
by_prefix = lambda p: [[k] for k in ITEMS if k.startswith(p)]
render_lineup("_preview_hats.png", by_prefix("hat_"))
render_lineup("_preview_jackets.png", by_prefix("jacket_"))
render_lineup("_preview_pants.png", by_prefix("pants_"))
render_lineup("_preview_shoes.png", by_prefix("shoes_"))
render_lineup("_preview_face.png", by_prefix("face_"))
render_lineup("_preview_neck_back_front.png", by_prefix("neck_") + by_prefix("back_"))
render_lineup("_preview_back.png", by_prefix("back_"), back_view=True)
print("DONE")
