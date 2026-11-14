"""Заменить глаза-чёрточки у BaseCharacter.blend на наши глаза (белок + зрачок, пропорции как в
character.py), глаза — на кости Head (двигаются во всех анимациях). Сам .blend в проект не добавлен
(ждём подтверждения источника и лицензии).
Запуск: python -I tools/blender/basechar_eyes.py <вход.blend> <выход.blend>
"""
import bpy, bmesh, sys, math
from mathutils import Vector
bpy.context.preferences.filepaths.use_scripts_auto_execute = False
src, dst = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=src, load_ui=False, use_scripts=False)
rig = bpy.data.objects["CharacterArmature"]
body = bpy.data.objects["Body"]
me = body.data
# 1) Чёрточки-глаза (материал Face) — в цвет тела.
skin_i = [i for i, m in enumerate(me.materials) if m and m.name == "Skin"][0]
face_i = [i for i, m in enumerate(me.materials) if m and m.name == "Face"][0]
# Чёрточки — выпуклые кусочки сетки: удаляем их грани и вершины, которые есть только у них,
# а образовавшиеся дырки закрываем плоскими гранями (лицо становится гладким).
bm = bmesh.new()
bm.from_mesh(me)
face_faces = [f for f in bm.faces if f.material_index == face_i]
only = [v for v in bm.verts if v.link_faces and all(f.material_index == face_i for f in v.link_faces)]
print("FACE_POLYS", len(face_faces), "ONLY_VERTS", len(only))
bmesh.ops.delete(bm, geom=only, context="VERTS")
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index == face_i], context="FACES_ONLY")
boundary = [e for e in bm.edges if e.is_boundary]
res = bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
for f in res["faces"]:
    f.material_index = skin_i
bmesh.ops.triangulate(bm, faces=res["faces"])
print("FILLED", len(res["faces"]))
bm.to_mesh(me)
bm.free()
me.update()
# 2) Голова: вершины с весом кости Head > 0.5.
hg = body.vertex_groups["Head"].index
pts = [body.matrix_world @ v.co for v in me.vertices if any(g.group == hg and g.weight > 0.5 for g in v.groups)]
mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
c = (mn + mx) / 2
R = (mx.x - mn.x) / 2                       # «радиус» головы по ширине
print("HEAD", tuple(round(v, 3) for v in mn), tuple(round(v, 3) for v in mx), "R", round(R, 3))
# Наши глаза (character.py): голова r 0.3; белок r 0.075 (1, 0.5, 1.15), зрачок r 0.042 (1, 0.5, 1.2);
# x ±0.11, белок на 0.04 выше центра головы, зрачок чуть ниже белка и впереди.
k = R / 0.3
deps = bpy.context.evaluated_depsgraph_get()
WHITE = bpy.data.materials.new("EyeWhite"); WHITE.diffuse_color = (0.95, 0.95, 0.95, 1)
BLACK = bpy.data.materials.new("EyeBlack"); BLACK.diffuse_color = (0.03, 0.03, 0.03, 1)
eyes = []
for s in (-1, 1):
    x, z = c.x + s * 0.11 * k, c.z + 0.04 * k
    # Где поверхность лица: луч спереди (модель смотрит в −Y) к центру головы.
    hit, loc, nrm, idx, obj, mtx = bpy.context.scene.ray_cast(deps, Vector((x, mn.y - 1.0, z)), Vector((0, 1, 0)))
    fy = loc.y if hit else mn.y
    for name, r, sc, dy, dz, mat in (("EyeWhite", 0.075, (1, 0.5, 1.15), 0.255 - 0.29, 0.0, WHITE),
                                      ("EyePupil", 0.042, (1, 0.5, 1.2), 0.0, -0.01, BLACK)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=14, radius=r * k,
                                             location=(x, fy + 0.012 * k + dy * k * -1 * 0 + (0.0 if name == "EyeWhite" else -0.035 * k), z + dz * k))
        o = bpy.context.object
        o.name = name + ("R" if s < 0 else "L")
        o.scale = sc
        bpy.ops.object.transform_apply(scale=True)
        o.data.materials.append(mat)
        for p in o.data.polygons:
            p.use_smooth = True
        eyes.append(o)
# 3) Прикрепить глаза к кости головы (двигаются в анимациях).
bpy.context.view_layer.update()
for o in eyes:
    mw = o.matrix_world.copy()
    o.parent = rig
    o.parent_type = "BONE"
    o.parent_bone = "Head"
    bpy.context.view_layer.update()
    o.matrix_world = mw
bpy.ops.wm.save_as_mainfile(filepath=dst)
print("SAVED")
