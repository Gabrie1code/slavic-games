"""BaseCharacter (после basechar_eyes.py) → модель игры assets/models/character/character_rigged.glb:
глаза вплавлены в сетку на кость Head, добавлены ступни, масштаб 0.52 (рост ~1.6 м) и разворот лицом
в +Y Blender (в Godot — в −Z) — трансформом объекта, материал тела «Primary» (цвет игрока).
Все 16 анимаций файла (Idle, Walk, Run, Jump, Punch, Victory, Death…) экспортируются: в игре их
проигрывает CharacterRig, а позы от кода (предмет в руке, сидя, присед) накладываются поверх.
Запуск: python -I tools/blender/basechar_convert.py tools/blender/source/character_eyes.blend \
    assets/models/character/character_rigged.glb
Исходник с нашими глазами — tools/blender/source/character_eyes.blend (из BaseCharacter.blend через
basechar_eyes.py); готовая модель сохраняется в tools/blender/source/character_final.blend.
"""
import bpy, bmesh, sys, math, os
from mathutils import Vector, Matrix, Quaternion
bpy.context.preferences.filepaths.use_scripts_auto_execute = False
src, out_glb = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=src, load_ui=False, use_scripts=False)
SCALE = 0.52
rig = bpy.data.objects["CharacterArmature"]
body = bpy.data.objects["Body"]
me = body.data
# --- 1. Глаза — в сетку тела, на кость Head (вес 1).
mats = [m.name for m in me.materials]
for name in ("EyeWhite", "EyeBlack"):
    if name not in mats:
        me.materials.append(bpy.data.materials[name])
mats = [m.name for m in me.materials]
head_vg = body.vertex_groups["Head"].index
bm = bmesh.new()
bm.from_mesh(me)
dl = bm.verts.layers.deform.verify()
for eye in [o for o in bpy.data.objects if o.name.startswith("Eye")]:
    em = eye.data.copy()
    em.transform(eye.matrix_world)
    before_v, before_f = len(bm.verts), len(bm.faces)
    bm.from_mesh(em)
    bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
    mi = mats.index(eye.data.materials[0].name)
    for v in bm.verts[before_v:]:
        for k in list(v[dl].keys()):
            del v[dl][k]
        v[dl][head_vg] = 1.0
    for f in bm.faces[before_f:]:
        f.material_index = mi
        f.smooth = True
    bpy.data.objects.remove(eye)
bm.to_mesh(me); bm.free(); me.update()
# --- 2. Исходная поза — Т-поза файла (анимации записаны относительно неё, поэтому кости не трогаем).
if rig.animation_data:
    rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()
# --- 3. Ступни: у модели ноги сужались в точку — добавляем скруглённые ступни носком вперёд
# (модель смотрит в −Y), на кости Foot (это «ручки» IK ног — в анимациях они ставят стопу), цвет тела.
# Размеры заданы в метрах игры, в файле единицы крупнее в 1/SCALE раз.
FOOT = (0.07, 0.12, 0.045)            # полуразмеры: ширина, длина, высота
k = 1.0 / SCALE
bm = bmesh.new()
bm.from_mesh(me)
dl = bm.verts.layers.deform.verify()
prim_i = [i for i, m in enumerate(me.materials) if m and m.name == "Skin"][0]
for side in ("R", "L"):
    vg = body.vertex_groups["Foot." + side].index
    tail = rig.data.bones["LowerLeg." + side].tail_local
    sx = 1.0 if tail.x > 0 else -1.0
    res = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0)
    for v in res["verts"]:
        c = v.co
        v.co = Vector((tail.x + (sx * 0.004 + c.x * FOOT[0]) * k, tail.y + (-0.035 + c.y * FOOT[1]) * k,
                       (FOOT[2] + max(c.z, -0.75) * FOOT[2]) * k))     # подошва плоская, на земле
        for kk in list(v[dl].keys()):
            del v[dl][kk]
        v[dl][vg] = 1.0
    for f in {f for v in res["verts"] for f in v.link_faces}:
        f.material_index = prim_i
        f.smooth = True
bm.to_mesh(me); bm.free(); me.update()
for m in me.materials:
    if m and m.name == "Skin":
        m.name = "Primary"
# --- 4. Масштаб и разворот — трансформом объекта (не «применять»: иначе съедут сдвиги в анимациях).
rig.scale = (SCALE, SCALE, SCALE)
rig.rotation_euler = (0.0, 0.0, math.pi)
# --- 5. Свои анимации: присед на корточки (Crouch) и ходьба присев (CrouchWalk).
# Берём Idle / Walk и опускаем корень тела: ступни — цели IK, они остаются на земле, и колени сами
# сгибаются вперёд (к полюсам IK). Таз наклоняем вперёд (корпус чуть к коленям), голову — обратно,
# чтобы смотрел вперёд. У ходьбы шаг короче: присевший не дотянется ногой так далеко.
# Оси костей: у Body/Hips/Head локальная Y — вверх, Z — вперёд; у ступней Y — вперёд, Z — вверх.
CROUCH_DROP = 0.2 / SCALE    # насколько опускается таз (0.2 м в игре)
CROUCH_LEAN = 0.38           # наклон корпуса вперёд, рад
HEAD_BACK = 0.3              # голова поднимается обратно, рад
ELBOW_BEND = 0.55            # локти сильнее согнуты (иначе кажется, что руки прямые), рад


def _curves(act, bone, prop):
    path = 'pose.bones["%s"].%s' % (bone, prop)
    fcs = sorted([fc for fc in act.fcurves if fc.data_path == path], key=lambda f: f.array_index)
    return fcs


def offset_loc(act, bone, idx, d, scale=1.0):
    for fc in _curves(act, bone, "location"):
        if fc.array_index == idx:
            for kp in fc.keyframe_points:
                for pt in (kp.co, kp.handle_left, kp.handle_right):
                    pt[1] = pt[1] * scale + d


def turn(act, bone, angle, axis=(1.0, 0.0, 0.0)):
    fcs = _curves(act, bone, "rotation_quaternion")
    if len(fcs) != 4:
        fcs = [act.fcurves.new('pose.bones["%s"].rotation_quaternion' % bone, index=i, action_group=bone)
               for i in range(4)]
        for i, fc in enumerate(fcs):
            fc.keyframe_points.insert(act.frame_range[0], 1.0 if i == 0 else 0.0)
    frames = sorted({round(kp.co[0], 3) for fc in fcs for kp in fc.keyframe_points})
    vals = [[fc.evaluate(f) for fc in fcs] for f in frames]
    add = Quaternion(axis, angle)
    for fc in fcs:
        fc.keyframe_points.clear()
    for f, v in zip(frames, vals):
        q = add @ Quaternion(v)
        for i, fc in enumerate(fcs):
            fc.keyframe_points.insert(f, q[i], options={"FAST"})


# Ходьба: таз чуть выше и почти не «проседает» на шаге (иначе встаёт на колени).
for src, name, drop, bob, stride in (("Idle", "Crouch", CROUCH_DROP, 1.0, 1.0),
                                     ("Walk", "CrouchWalk", CROUCH_DROP * 0.7, 0.3, 0.6)):
    act = bpy.data.actions[src].copy()
    act.name = name
    offset_loc(act, "Body", 1, -drop, bob)
    turn(act, "Hips", CROUCH_LEAN)
    turn(act, "Head", -HEAD_BACK)
    # Локоть: ось сгиба — локальная Z кости предплечья (у правой руки «+» — вперёд, у левой «−»).
    turn(act, "LowerArm.R", ELBOW_BEND, (0.0, 0.0, 1.0))
    turn(act, "LowerArm.L", -ELBOW_BEND, (0.0, 0.0, 1.0))
    for side in ("L", "R"):
        offset_loc(act, "Foot." + side, 1, 0.0, stride)
        # Полюса коленей — вперёд и ниже, чтобы колени шли вперёд, а не вбок.
        offset_loc(act, "PoleTarget." + side, 1, -CROUCH_DROP)

# Все анимации — в NLA-дорожки, чтобы экспорт взял каждую отдельной анимацией.
rig.animation_data_create()
for a in bpy.data.actions:
    a.use_fake_user = True
    tr = rig.animation_data.nla_tracks.new()
    tr.name = a.name
    tr.strips.new(a.name, int(a.frame_range[0]), a)
    tr.mute = True
rig.animation_data.action = None
bpy.context.view_layer.update()
# --- Замеры для подгонки одежды.
def head_of(n): return tuple(round(v * SCALE, 4) for v in rig.data.bones[n].head_local)
def tail_of(n): return tuple(round(v * SCALE, 4) for v in rig.data.bones[n].tail_local)
for n in ("Hips", "Abdomen", "Torso", "Neck", "Head", "UpperArm.R", "LowerArm.R", "Fist.R", "UpperLeg.R", "LowerLeg.R"):
    print("BONE", n, head_of(n), tail_of(n))
def vgroup_bbox(names, wmin=0.5):
    idx = [body.vertex_groups[n].index for n in names]
    pts = [v.co for v in me.vertices if any(g.group in idx and g.weight > wmin for g in v.groups)]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return tuple(round(v, 4) for v in mn), tuple(round(v, 4) for v in mx)
for label, names in (("HEAD", ["Head"]), ("TORSO", ["Torso", "Abdomen", "Hips"]), ("ARM_R", ["UpperArm.R", "LowerArm.R"]),
                     ("FIST_R", ["Fist.R"]), ("LEG_R", ["UpperLeg.R", "LowerLeg.R"])):
    print("BBOX", label, *vgroup_bbox(names))
zs = [v.co.z * SCALE for v in me.vertices]
print("HEIGHT", round(min(zs), 4), round(max(zs), 4))
for o in bpy.data.objects:
    o.select_set(o in (rig, body))
with bpy.context.temp_override(selected_objects=[rig, body], active_object=rig):
    bpy.ops.export_scene.gltf(filepath=out_glb, use_selection=True, export_format="GLB",
                              export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_force_sampling=True, export_skins=True,
                              export_draco_mesh_compression_enable=False)
print("EXPORTED", out_glb, len(me.polygons), "faces")
# Готовая модель (глаза, ступни, руки вниз, наш масштаб) — рядом с исходником, чтобы открыть в Blender.
final_blend = os.path.join(os.path.dirname(os.path.abspath(__file__)), "source", "character_final.blend")
bpy.ops.wm.save_as_mainfile(filepath=final_blend, copy=True, compress=True)
print("SAVED", final_blend)
