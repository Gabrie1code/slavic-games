"""BaseCharacter (после basechar_eyes.py) → модель игры assets/models/character/character_rigged.glb:
глаза вплавлены в сетку на кость Head, руки опущены (новая исходная поза), масштаб 0.52 (рост ~1.6 м),
лицом в +Y Blender (в Godot — в −Z), материал тела «Primary» (цвет игрока), анимации убраны
(анимация — кодом, через CharacterRig). Печатает замеры для подгонки одежды.
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
# --- 2. Руки вниз: поза → сетка (модификатор), затем кости в новое положение.
# Сначала снять анимацию и позу: в файле стоит кадр анимации, а не исходная Т-поза.
if rig.animation_data:
    rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()
R = {}
for side, s in (("R", -1), ("L", 1)):
    pb = rig.pose.bones["UpperArm." + side]
    d = (pb.tail - pb.head).normalized()
    target = Vector((s * math.sin(math.radians(9)), 0.0, -math.cos(math.radians(9))))
    q = d.rotation_difference(target)
    p = pb.head.copy()
    print('ROT', side, tuple(d), tuple(target), q)
    R[side] = Matrix.Translation(p) @ q.to_matrix().to_4x4() @ Matrix.Translation(-p)
    pb.matrix = R[side] @ pb.matrix
    bpy.context.view_layer.update()
with bpy.context.temp_override(object=body, active_object=body, selected_objects=[body]):
    bpy.ops.object.modifier_apply(modifier="Armature")
for o in bpy.context.view_layer.objects:
    o.select_set(False)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
print("ACTIVE", bpy.context.view_layer.objects.active.name, rig.data.name, rig.data.library)
if True:
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.ops.object.mode_set(mode="EDIT")
    print("MODE", rig.mode, len(rig.data.edit_bones))
    eb = rig.data.edit_bones
    # Соединённые кости тянут друг друга — поэтому новые положения считаем по исходным и ставим разом.
    G = Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Scale(SCALE, 4)
    plan = {}
    for b in eb:
        m = G
        for side in ("R", "L"):
            if b.name in ("UpperArm." + side, "LowerArm." + side, "Fist." + side):
                m = G @ R[side]
        z = (m.to_3x3() @ b.z_axis).normalized()
        plan[b.name] = (m @ b.head, m @ b.tail, z)
        if b.name.startswith('UpperArm'): print('PLAN', b.name, tuple(b.head), tuple(b.tail), tuple(plan[b.name][1]), m is G)
    for b in eb:
        b.use_connect = False
    for b in eb:
        h, t, z = plan[b.name]
        b.head, b.tail = h, t
        b.align_roll(z)
    # Кости стоп были «ручками» IK от корня — делаем их дочерними голеням: ступни (ниже) висят
    # на них и двигаются с ногой; размер стопы можно менять отдельно.
    for side in ("R", "L"):
        eb["Foot." + side].parent = eb["LowerLeg." + side]
    bpy.ops.object.mode_set(mode="OBJECT")
me.transform(G)
# --- 4. Ступни: у модели ноги сужались в точку — добавляем скруглённые ступни носком вперёд (+Y),
# на кость голени (двигаются вместе с ней), цвет тела.
FOOT = (0.07, 0.12, 0.045)            # полуразмеры: ширина, длина, высота
bm = bmesh.new()
bm.from_mesh(me)
dl = bm.verts.layers.deform.verify()
prim_i = [i for i, m in enumerate(me.materials) if m and m.name == "Skin"][0]
for side, sx in (("R", 1), ("L", -1)):
    vg = body.vertex_groups["Foot." + side].index
    tail = rig.data.bones["LowerLeg." + side].tail_local
    res = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0)
    for v in res["verts"]:
        c = v.co
        v.co = Vector((tail.x + sx * 0.004 + c.x * FOOT[0], tail.y + 0.035 + c.y * FOOT[1],
                       FOOT[2] + max(c.z, -0.75) * FOOT[2]))     # подошва плоская, на земле
        for k in list(v[dl].keys()):
            del v[dl][k]
        v[dl][vg] = 1.0
    for f in {f for v in res["verts"] for f in v.link_faces}:
        f.material_index = prim_i
        f.smooth = True
bm.to_mesh(me); bm.free(); me.update()
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = rig
for m in me.materials:
    if m and m.name == "Skin":
        m.name = "Primary"
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
if rig.animation_data:
    rig.animation_data.action = None
bpy.context.view_layer.update()
# --- Замеры для подгонки одежды.
def head_of(n): return tuple(round(v, 4) for v in rig.data.bones[n].head_local)
def tail_of(n): return tuple(round(v, 4) for v in rig.data.bones[n].tail_local)
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
zs = [v.co.z for v in me.vertices]
print("HEIGHT", round(min(zs), 4), round(max(zs), 4))
for o in bpy.data.objects:
    o.select_set(o in (rig, body))
with bpy.context.temp_override(selected_objects=[rig, body], active_object=rig):
    bpy.ops.export_scene.gltf(filepath=out_glb, use_selection=True, export_format="GLB",
                              export_animations=False, export_skins=True,
                              export_draco_mesh_compression_enable=False)
print("EXPORTED", out_glb, len(me.polygons), "faces")
# Готовая модель (глаза, ступни, руки вниз, наш масштаб) — рядом с исходником, чтобы открыть в Blender.
final_blend = os.path.join(os.path.dirname(os.path.abspath(__file__)), "source", "character_final.blend")
bpy.ops.wm.save_as_mainfile(filepath=final_blend, copy=True, compress=True)
print("SAVED", final_blend)
