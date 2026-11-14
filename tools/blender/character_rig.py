"""Прототип нового персонажа (как на референсе владельца): ОДНА цельная гладкая сетка тела со
скелетом внутри (кости: таз, спина, грудь, шея, голова, плечи, локти, кисти, бёдра, колени, стопы),
поэтому руки, локти, колени и корпус гнутся без стыков. Голова — «кубик» со скруглёнными углами,
кисти — варежки с большим пальцем, ноги — с ботинками.

Тело собирается из простых форм, сливается в одну сетку (voxel remesh), сглаживается и
привязывается к скелету автоматическими весами. Глаза — на кости головы.

Запуск:
    python tools/blender/character_rig.py <папка> [--render <префикс>]
Пишет <папка>/character_rig.glb; с --render — превью-кадры и позы.
"""
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else "."
RENDER = sys.argv[sys.argv.index("--render") + 1] if "--render" in sys.argv else None
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
SCN = bpy.context.scene

# ---- Размеры (м). Оси: X — вправо (правая рука персонажа), +Y — лицо, Z — вверх. ----
HIP_Z, CHEST_Z, NECK_Z, HEAD_Z = 0.6, 0.95, 1.08, 1.13
SHOULDER = Vector((0.205, 0.0, 1.0))
ELBOW = Vector((0.26, -0.01, 0.8))
WRIST = Vector((0.29, 0.0, 0.6))
HIP = Vector((0.092, 0.0, 0.6))
KNEE = Vector((0.094, 0.005, 0.34))
ANKLE = Vector((0.094, 0.0, 0.11))
HEAD_SIZE = Vector((0.43, 0.39, 0.42))


def mat(name, color, rough=0.55):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    return m


PRIMARY = mat("Primary", (0.75, 0.12, 0.08))
WHITE = mat("EyeWhite", (0.95, 0.95, 0.95), 0.4)
BLACK = mat("EyeBlack", (0.03, 0.03, 0.03), 0.3)


def link(me, name):
    o = bpy.data.objects.new(name, me)
    SCN.collection.objects.link(o)
    return o


def lathe(rings, segs=32, name="L"):
    """Тело вращения: rings — [(rx, ry, z)] снизу вверх, концы с rx = 0 закрыты."""
    verts, faces, idx = [], [], []
    for rx, ry, z in rings:
        if rx <= 1e-4:
            idx.append([len(verts)])
            verts.append((0, 0, z))
            continue
        ring = []
        for k in range(segs):
            a = k * math.tau / segs
            ring.append(len(verts))
            verts.append((math.cos(a) * rx, math.sin(a) * ry, z))
        idx.append(ring)
    for a, b in zip(idx, idx[1:]):
        if len(a) == 1:
            faces += [(a[0], b[(k + 1) % segs], b[k]) for k in range(segs)]
        elif len(b) == 1:
            faces += [(a[k], a[(k + 1) % segs], b[0]) for k in range(segs)]
        else:
            faces += [(a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]) for k in range(segs)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    return link(me, name)


def tube(p0, p1, r0, r1, segs=24, name="T"):
    """Трубка от p0 (радиус r0) до p1 (r1) со сферическими концами."""
    d = p1 - p0
    length = d.length
    rings = []
    for k in range(7):                                      # нижний купол
        a = -math.pi / 2 + k * math.pi / 12
        rings.append((r0 * math.cos(a), r0 * math.cos(a), r0 * math.sin(a)))
    for k in range(1, 6):
        t = k / 6
        r = r0 + (r1 - r0) * t
        rings.append((r, r, length * t))
    for k in range(7):                                      # верхний купол
        a = k * math.pi / 12
        rings.append((r1 * math.cos(a), r1 * math.cos(a), length + r1 * math.sin(a)))
    rings[0] = (0, 0, -r0)
    rings[-1] = (0, 0, length + r1)
    o = lathe(rings, segs, name)
    o.matrix_world = Matrix.Translation(p0) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
    return o


def ellipsoid(c, r, segs=24, rings=14, name="E", rot=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=1.0, location=c)
    o = bpy.context.object
    o.name = name
    o.scale = r
    if rot:
        o.rotation_euler = rot
    return o


def mirror_x(v):
    return Vector((-v.x, v.y, v.z))


# ======================= Тело (одна сетка) =======================

def build_body():
    pieces = []
    # Корпус: от паха до шеи, плечи покатые, спина чуть выпуклая.
    pieces.append(lathe([(0.0, 0.0, 0.53), (0.1, 0.08, 0.545), (0.155, 0.11, 0.585),
                         (0.168, 0.12, 0.65), (0.165, 0.118, 0.74), (0.172, 0.122, 0.83),
                         (0.185, 0.128, 0.91), (0.2, 0.13, 0.96), (0.205, 0.125, 0.995),
                         (0.185, 0.11, 1.03), (0.13, 0.09, 1.06), (0.075, 0.068, 1.08),
                         (0.062, 0.06, 1.1), (0.06, 0.058, 1.16), (0.0, 0.0, 1.17)], 40, "Torso"))
    for sx in (1, -1):
        sh, el, wr = [Vector((sx * v.x, v.y, v.z)) for v in (SHOULDER, ELBOW, WRIST)]
        pieces.append(tube(sh, el, 0.066, 0.058, name="Upper"))
        pieces.append(tube(el, wr, 0.058, 0.05, name="Fore"))
        # Варежка: ладонь + большой палец (смотрит вперёд-внутрь).
        palm = wr + Vector((sx * 0.006, 0.0, -0.07))
        pieces.append(ellipsoid(palm, (0.052, 0.064, 0.075), name="Palm"))
        pieces.append(tube(wr + Vector((-sx * 0.02, 0.035, -0.035)), wr + Vector((-sx * 0.03, 0.06, -0.085)),
                           0.022, 0.019, segs=16, name="Thumb"))
        hp, kn, an = [Vector((sx * v.x, v.y, v.z)) for v in (HIP, KNEE, ANKLE)]
        pieces.append(tube(hp + Vector((0, 0, 0.03)), kn, 0.088, 0.072, name="Thigh"))
        pieces.append(tube(kn, an, 0.072, 0.062, name="Shin"))
        # Ботинок: скруглённый, носок вперёд.
        pieces.append(ellipsoid(Vector((sx * 0.094, 0.05, 0.06)), (0.08, 0.135, 0.065), name="Boot"))
    # Слить всё в одну сетку и сгладить.
    bpy.ops.object.select_all(action="DESELECT")
    for o in pieces:
        o.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    body = bpy.context.object
    body.name = "Body"
    rm = body.modifiers.new("Remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = 0.009
    bpy.ops.object.modifier_apply(modifier="Remesh")
    sm = body.modifiers.new("Smooth", "CORRECTIVE_SMOOTH")
    sm.iterations = 6
    sm.smooth_type = "LENGTH_WEIGHTED"
    sm.use_only_smooth = True
    bpy.ops.object.modifier_apply(modifier="Smooth")
    dec = body.modifiers.new("Dec", "DECIMATE")
    dec.ratio = 0.12
    bpy.ops.object.modifier_apply(modifier="Dec")
    for p in body.data.polygons:
        p.use_smooth = True
    body.data.materials.append(PRIMARY)
    return body


# ======================= Голова =======================

def build_head():
    """Голова — «кубик» со скруглёнными углами, к подбородку чуть уже; глаза на лице."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=24, radius=1.0)
    head = bpy.context.object
    head.name = "Head"
    for v in head.data.vertices:
        x, y, z = v.co
        f = lambda c: math.copysign(abs(c) ** 0.6, c)           # шар → скруглённый куб
        nx, ny, nz = f(x), f(y), f(z)
        t = (nz + 1) / 2                                          # 0 — низ, 1 — верх
        taper = 0.86 + 0.14 * min(1.0, t * 1.6)
        v.co = (nx * HEAD_SIZE.x / 2 * taper, ny * HEAD_SIZE.y / 2 * taper,
                HEAD_Z + HEAD_SIZE.z / 2 + nz * HEAD_SIZE.z / 2)
    for p in head.data.polygons:
        p.use_smooth = True
    head.data.materials.append(PRIMARY)
    parts = [head]
    face_y = HEAD_SIZE.y / 2
    for sx in (1, -1):
        white = ellipsoid(Vector((sx * 0.085, face_y - 0.016, HEAD_Z + 0.25)), (0.058, 0.026, 0.07), name="EyeW")
        white.data.materials.append(WHITE)
        pupil = ellipsoid(Vector((sx * 0.082, face_y + 0.006, HEAD_Z + 0.245)), (0.032, 0.013, 0.04),
                          name="EyeB")
        pupil.data.materials.append(BLACK)
        parts += [white, pupil]
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
        for p in o.data.polygons:
            p.use_smooth = True
    bpy.context.view_layer.objects.active = head
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    return bpy.context.object


# ======================= Скелет =======================

BONES = [  # имя, начало, конец, родитель
    ("Hips", Vector((0, 0, HIP_Z - 0.02)), Vector((0, 0, 0.75)), None),
    ("Spine", Vector((0, 0, 0.75)), Vector((0, 0, CHEST_Z)), "Hips"),
    ("Chest", Vector((0, 0, CHEST_Z)), Vector((0, 0, NECK_Z)), "Spine"),
    ("Neck", Vector((0, 0, NECK_Z)), Vector((0, 0, HEAD_Z)), "Chest"),
    ("Head", Vector((0, 0, HEAD_Z)), Vector((0, 0, HEAD_Z + 0.4)), "Neck"),
]
for side, sx in (("R", 1), ("L", -1)):
    m = lambda v: Vector((sx * v.x, v.y, v.z))
    BONES += [
        ("Shoulder" + side, Vector((sx * 0.05, 0, 1.02)), m(SHOULDER), "Chest"),
        ("UpperArm" + side, m(SHOULDER), m(ELBOW), "Shoulder" + side),
        ("Forearm" + side, m(ELBOW), m(WRIST), "UpperArm" + side),
        ("Hand" + side, m(WRIST), m(WRIST) + Vector((0, 0, -0.14)), "Forearm" + side),
        ("Thigh" + side, m(HIP), m(KNEE), "Hips"),
        ("Shin" + side, m(KNEE), m(ANKLE), "Thigh" + side),
        ("Foot" + side, m(ANKLE), Vector((sx * 0.092, 0.16, 0.04)), "Shin" + side),
    ]


def build_rig():
    arm_data = bpy.data.armatures.new("Rig")
    rig = link(arm_data, "Rig")
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, tail, parent in BONES:
        b = arm_data.edit_bones.new(name)
        b.head, b.tail = head, tail
        b.roll = 0.0
        if parent:
            b.parent = arm_data.edit_bones[parent]
            b.use_connect = (b.head - arm_data.edit_bones[parent].tail).length < 1e-4
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def bind(body, head, rig):
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    # Голова — целиком на кости Head (не гнётся, только поворачивается).
    bpy.ops.object.select_all(action="DESELECT")
    head.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    rig.data.bones.active = rig.data.bones["Head"]
    bpy.ops.object.parent_set(type="BONE", keep_transform=True)


body = build_body()
head = build_head()
rig = build_rig()
bind(body, head, rig)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "character_rig.glb"), use_selection=True,
                          export_format="GLB", export_draco_mesh_compression_enable=False)
print("EXPORTED character_rig.glb", len(body.data.polygons), "faces")


# ======================= Превью =======================

# Знаки (проверено): у костей рук и ног, смотрящих вниз, +X — вперёд; колено гнётся минусом;
# спина/голова: −X — наклон вперёд; правая рука: −Z — в сторону-вверх (левая — +Z).
POSES = {
    "idle": {"UpperArmR": (0, 0, -0.05), "UpperArmL": (0, 0, 0.05), "ForearmR": (0.25, 0, 0),
             "ForearmL": (0.25, 0, 0)},
    "walk": {"UpperArmR": (0.5, 0, 0), "ForearmR": (0.7, 0, 0), "UpperArmL": (-0.45, 0, 0),
             "ForearmL": (0.2, 0, 0), "ThighR": (-0.4, 0, 0), "ShinR": (-0.5, 0, 0),
             "ThighL": (0.45, 0, 0), "ShinL": (-0.1, 0, 0), "Spine": (-0.05, 0, 0)},
    "run": {"UpperArmR": (-0.8, 0, 0), "ForearmR": (1.3, 0, 0), "UpperArmL": (0.9, 0, 0),
            "ForearmL": (1.3, 0, 0), "ThighR": (0.95, 0, 0), "ShinR": (-1.2, 0, 0),
            "ThighL": (-0.55, 0, 0), "ShinL": (-1.0, 0, 0), "Spine": (-0.18, 0, 0), "Head": (0.1, 0, 0)},
    "jump": {"UpperArmR": (0.2, 0, -2.5), "ForearmR": (0.4, 0, 0), "UpperArmL": (0.2, 0, 1.0),
             "ForearmL": (1.0, 0, 0), "ThighR": (1.0, 0, -0.18), "ShinR": (-1.5, 0, 0),
             "ThighL": (-0.2, 0, 0.15), "ShinL": (-1.1, 0, 0), "Head": (0.15, 0, 0)},
    "crouch": {"Spine": (-0.35, 0, 0), "Chest": (-0.1, 0, 0),
               "UpperArmR": (0.6, 0, -0.25), "ForearmR": (0.9, 0, 0), "UpperArmL": (0.6, 0, 0.25),
               "ForearmL": (0.9, 0, 0), "ThighR": (1.15, 0, -0.08), "ShinR": (-1.7, 0, 0),
               "ThighL": (1.15, 0, 0.08), "ShinL": (-1.7, 0, 0), "Head": (0.3, 0, 0)},
    "think": {"UpperArmR": (0.55, 0, 0.5), "ForearmR": (2.1, 0, 0), "HandR": (0.3, 0, 0), "UpperArmL": (0.15, 0, 0.15),
              "ForearmL": (0.7, 0, 0), "ThighL": (0.0, 0, 0.12), "Head": (-0.12, 0.2, 0)},
}


def set_pose(name):
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    for bone, rot in POSES.get(name, {}).items():
        rig.pose.bones[bone].rotation_euler = rot
    if name == "crouch":
        rig.pose.bones["Hips"].location = (0, -0.2, 0.05)
    if name == "jump":
        rig.pose.bones["Hips"].location = (0, 0.15, 0)
    bpy.context.view_layer.update()


if RENDER:
    PRIMARY.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (0.75, 0.08, 0.04, 1)
    bpy.ops.mesh.primitive_plane_add(size=30)
    ground = bpy.context.object
    gm = mat("Ground", (0.5, 0.52, 0.56), 0.9)
    ground.data.materials.append(gm)
    sun = link(bpy.data.lights.new("Sun", "SUN"), "Sun")
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(45), 0, math.radians(150))
    cam = link(bpy.data.cameras.new("Cam"), "Cam")
    SCN.camera = cam
    SCN.render.engine = "CYCLES"
    SCN.cycles.samples = 48
    SCN.world = bpy.data.worlds.new("W")
    SCN.world.use_nodes = True
    bg = SCN.world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.75, 0.78, 0.86, 1)
    bg.inputs[1].default_value = 0.8
    SCN.view_settings.view_transform = "Standard"
    SCN.render.resolution_x, SCN.render.resolution_y = 600, 800
    target = Vector((0, 0, 0.8))
    shots = [("front", 90, "idle"), ("q34", 50, "idle"), ("side", 0, "idle"), ("back", -90, "idle"),
             ("walk", 60, "walk"), ("run", 30, "run"), ("jump", 70, "jump"), ("crouch", 60, "crouch"),
             ("think", 75, "think")]
    for tag, ang, pose in shots:
        set_pose(pose)
        a = math.radians(ang)
        cam.data.lens = 55
        cam.location = target + Vector((math.cos(a) * 4.2, math.sin(a) * 4.2, 0.8))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        SCN.render.filepath = RENDER + "_" + tag + ".png"
        bpy.ops.render.render(write_still=True)
    print("RENDERED")
