"""Кот Баггет, новая версия — в стиле обновлённого персонажа: крупная голова, наши глаза
(белые с чёрным зрачком), гранёные скруглённые формы, рыжий с тёмными полосками, кремовые лапки,
морда и кончик хвоста. Пока прототип для правок владельца — в игру не подключён.

Части те же, что у прежнего кота (apartment_extras.py), с теми же суставами, чтобы потом заменить
модель без переделки LobbyCat: CatBody, CatHead, CatTail, LegFL, LegFR, LegBL, LegBR.
Кот смотрит в +Y Blender (= вперёд, −Z в Godot), стоит на z = 0.

Запуск:
    python tools/blender/cat_v2.py <папка вывода> [--render превью]
"""
import bpy, math, sys, os
from mathutils import Vector

args = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = args[0] if args else "."
RENDER = sys.argv[sys.argv.index("--render") + 1] if "--render" in sys.argv else None
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
_mats = {}


def mat(name, color, rough=0.75):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    _mats[name] = m
    return m


FUR = mat("CatFur", (0.86, 0.42, 0.12))
FUR_D = mat("CatFurDark", (0.62, 0.24, 0.05))
CREAM = mat("CatCream", (0.97, 0.84, 0.66))
PINK = mat("CatPink", (0.96, 0.55, 0.6), 0.5)
EYE_W = mat("EyeWhite", (0.95, 0.95, 0.95), 0.35)
EYE_B = mat("EyeBlack", (0.03, 0.03, 0.03), 0.3)
WHISKER = mat("Whisker", (0.95, 0.93, 0.9), 0.5)


def _finish(o, m, smooth=False):
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = smooth
    return o


def _apply_mods(o):
    with bpy.context.temp_override(object=o, active_object=o, selected_objects=[o]):
        for md in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=md.name)


def rbox(size, loc, m, round_=0.35, segs=2, rot=(0, 0, 0)):
    """Скруглённый «гранёный» брусок: size — полные размеры, round_ — доля скругления."""
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    bv = o.modifiers.new("b", "BEVEL")
    bv.width = min(size) * round_ * 0.5
    bv.segments = segs
    bv.limit_method = "NONE"
    _apply_mods(o)
    return _finish(o, m)


def sphere(r, loc, m, scale=(1, 1, 1), segs=16, rings=10, smooth=True):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return _finish(o, m, smooth)


def pyramid(base, h, loc, m, tilt=(0, 0, 0)):
    """Ухо: четырёхгранная пирамидка."""
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=base, radius2=0.0, depth=h, location=loc,
                                    rotation=tilt)
    o = bpy.context.object
    bpy.ops.object.transform_apply(rotation=True)
    return _finish(o, m)


def rod(a, b, r, m, verts=6):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(rotation=True)
    return _finish(o, m)


def join(name, parts, pivot):
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    bpy.context.scene.cursor.location = pivot
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.context.scene.cursor.location = (0, 0, 0)
    return o


cat = []
# ---------------- Тело: брусок, полоски поверху и по бокам, кремовая грудка ----------------
BODY_Z = 0.2
P = [rbox((0.19, 0.34, 0.17), (0, 0, BODY_Z), FUR, 0.45)]
for y in (-0.11, -0.035, 0.04):
    P.append(rbox((0.193, 0.03, 0.115), (0, y, BODY_Z + 0.027), FUR_D, 0.45))
P.append(rbox((0.13, 0.06, 0.12), (0, 0.145, BODY_Z - 0.02), CREAM, 0.5))      # грудка
cat.append(join("CatBody", P, (0, 0, BODY_Z)))

# ---------------- Голова: крупная, наши глаза, кремовая мордочка, розовый нос ----------------
HEAD = Vector((0, 0.2, 0.39))
P = [rbox((0.25, 0.2, 0.21), HEAD, FUR, 0.5)]
for x in (-0.045, 0.045):                                                     # полоски на лбу
    P.append(rbox((0.02, 0.09, 0.02), HEAD + Vector((x, -0.01, 0.0965)), FUR_D, 0.5))
P.append(rbox((0.024, 0.1, 0.02), HEAD + Vector((0, 0.0, 0.0975)), FUR_D, 0.5))
for s in (-1, 1):
    ear = HEAD + Vector((s * 0.075, -0.02, 0.135))
    P.append(pyramid(0.06, 0.1, ear, FUR, tilt=(0.0, s * -0.25, math.pi / 4)))
    P.append(pyramid(0.035, 0.07, ear + Vector((0, 0.022, -0.008)), PINK, tilt=(0.0, s * -0.25, math.pi / 4)))
    # Глаза как у персонажа: белый «диск» и чёрный зрачок, крупные.
    eye = HEAD + Vector((s * 0.058, 0.098, 0.018))
    P.append(sphere(0.038, eye, EYE_W, scale=(1.0, 0.45, 1.1)))
    P.append(sphere(0.022, eye + Vector((s * -0.004, 0.015, -0.004)), EYE_B, scale=(1.0, 0.45, 1.15)))
    for k in (-1, 1):                                                         # усы
        P.append(rod(HEAD + Vector((s * 0.06, 0.105, -0.05 + k * 0.006)),
                     HEAD + Vector((s * 0.17, 0.09, -0.04 + k * 0.03)), 0.0025, WHISKER, verts=4))
P.append(rbox((0.11, 0.05, 0.07), HEAD + Vector((0, 0.1, -0.05)), CREAM, 0.6))  # мордочка
P.append(rbox((0.03, 0.02, 0.02), HEAD + Vector((0, 0.128, -0.025)), PINK, 0.6))  # нос
# Шея: короткая, от груди к голове (крутится вместе с головой).
P.append(rbox((0.1, 0.1, 0.12), (0, 0.13, 0.29), FUR, 0.5, rot=(-0.5, 0, 0)))
cat.append(join("CatHead", P, (0, 0.13, 0.27)))

# ---------------- Хвост: звенья вверх-назад, тёмные кольца, кремовый кончик ----------------
pts = [Vector((0, -0.16, 0.25)), Vector((0, -0.23, 0.31)), Vector((0, -0.27, 0.4)),
       Vector((0, -0.28, 0.49)), Vector((0, -0.26, 0.56))]
P = []
for i, (a, b) in enumerate(zip(pts, pts[1:])):
    d = b - a
    m = (a + b) / 2
    P.append(rbox((0.055, 0.055, d.length + 0.03), m, FUR_D if i % 2 else FUR, 0.5,
                  rot=tuple(d.to_track_quat("Z", "Y").to_euler())))
P.append(rbox((0.06, 0.06, 0.06), pts[-1] + Vector((0, 0.005, 0.01)), CREAM, 0.6))
cat.append(join("CatTail", P, tuple(pts[0])))

# ---------------- Лапы: бруски с тёмной полоской и кремовой «тапочкой» ----------------
for name, x, y in (("LegFL", -0.06, 0.11), ("LegFR", 0.06, 0.11), ("LegBL", -0.062, -0.12),
                   ("LegBR", 0.062, -0.12)):
    top = 0.2
    P = [rbox((0.062, 0.066, 0.17), (x, y, 0.105), FUR, 0.45)]
    P.append(rbox((0.066, 0.07, 0.025), (x, y, 0.1), FUR_D, 0.4))
    P.append(rbox((0.07, 0.085, 0.04), (x, y + 0.01, 0.02), CREAM, 0.55))
    cat.append(join(name, P, (x, y, top)))

bpy.ops.object.select_all(action="DESELECT")
for o in cat:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "cat_v2.glb"), use_selection=True,
                          export_format="GLB", export_draco_mesh_compression_enable=False)
print("EXPORTED cat_v2")

if RENDER:
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 48
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x = 700
    sc.render.resolution_y = 700
    wd = bpy.data.worlds.new("w")
    sc.world = wd
    wd.use_nodes = True
    wd.node_tree.nodes["Background"].inputs[0].default_value = (0.78, 0.8, 0.86, 1)
    wd.node_tree.nodes["Background"].inputs[1].default_value = 0.45
    bpy.ops.mesh.primitive_plane_add(size=10)
    g = bpy.context.object
    g.data.materials.append(mat("Ground", (0.45, 0.47, 0.52)))
    sun = bpy.data.objects.new("s", bpy.data.lights.new("s", "SUN"))
    sun.data.energy = 2.6
    sun.rotation_euler = (math.radians(40), 0, math.radians(200))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 70
    target = Vector((0, 0.02, 0.27))
    for name, ang, h in (("q34", 55, 0.35), ("front", 90, 0.2), ("side", 0, 0.15), ("back", 230, 0.4)):
        a = math.radians(ang)
        cam.location = target + Vector((math.cos(a) * 1.9, math.sin(a) * 1.9, h + 0.25))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = RENDER + "_" + name + ".png"
        bpy.ops.render.render(write_still=True)
print("DONE")
