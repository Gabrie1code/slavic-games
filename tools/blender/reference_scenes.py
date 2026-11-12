"""Рендеры-референсы для карточек мини-игр (их прикладывают к промптам для генерации картинок).

Собирает сцены из готовых моделей игры: персонажи с одеждой и позами, предметы мини-игр.

Запуск:
    python tools/blender/reference_scenes.py docs/references
"""
import bpy, math, sys, os
from mathutils import Matrix, Vector

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models")
CHAR = os.path.join(ROOT, "character")
PROPS = os.path.join(ROOT, "props")

C = Matrix.Rotation(math.radians(90), 4, "X")   # координаты Godot -> Blender
Ci = C.inverted()
PIVOTS_G = {"ArmL": Vector((-0.31, 1.0, 0)), "ArmR": Vector((0.31, 1.0, 0)),
            "LegL": Vector((-0.13, 0.55, 0)), "LegR": Vector((0.13, 0.55, 0)),
            "Head": Vector((0, 1.05, 0))}
COLORS = {"red": (0.75, 0.1, 0.06), "blue": (0.06, 0.2, 0.7), "yellow": (0.85, 0.6, 0.04),
          "green": (0.1, 0.5, 0.14), "white": (0.9, 0.9, 0.88)}
_mats = {}


def mat(name, color, rough=0.55, metal=0.0, transmission=0.0, alpha=1.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if transmission:
        b.inputs["Transmission Weight"].default_value = transmission
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
    _mats[name] = m
    return m


def rot_g(x=0.0, y=0.0, z=0.0):
    """Поворот как у Node3D в Godot (порядок YXZ)."""
    return Matrix.Rotation(y, 4, "Y") @ Matrix.Rotation(x, 4, "X") @ Matrix.Rotation(z, 4, "Z")


def import_glb(path):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.context.selected_objects if o.type == "MESH"]


def base_name(o):
    return o.name.split(".")[0]


def character(color, items=(), pos=(0, 0, 0), yaw=0.0, arm_r=None, arm_l_x=0.0, legs=(0.0, 0.0),
              held=None, held_rot_x=0.0, held_scale=1.0, tilt=0.0):
    """Персонаж: цвет, одежда, поза. arm_r=(z, x) — поза правой руки как в игре."""
    body = {base_name(o): o for o in import_glb(os.path.join(CHAR, "character_base.glb"))}
    for item in items:
        for piece in import_glb(os.path.join(CHAR, "cosmetics", item + ".glb")):
            part = body[base_name(piece)]
            piece.parent = part
            piece.matrix_parent_inverse = part.matrix_world.inverted()
    paint = mat("Paint_" + color, COLORS[color])
    for o in list(body.values()) + [c for o in body.values() for c in o.children]:
        for slot in o.material_slots:
            if slot.material and slot.material.name.startswith("Primary"):
                slot.link = "OBJECT"
                slot.material = paint

    def pose(name, m_g):
        p = PIVOTS_G[name]
        body[name].matrix_world = C @ Matrix.Translation(p) @ m_g @ Matrix.Translation(-p) @ Ci @ body[name].matrix_world

    arm_r = arm_r or (0.12, 0.0)
    pose("ArmR", rot_g(x=arm_r[1], z=arm_r[0]))
    pose("ArmL", rot_g(x=arm_l_x, z=-0.12))
    pose("LegL", rot_g(x=legs[0]))
    pose("LegR", rot_g(x=legs[1]))
    objs = list(body.values())
    if held:
        thing = import_glb(held)[0]
        arm_g = Matrix.Translation(PIVOTS_G["ArmR"]) @ rot_g(x=arm_r[1], z=arm_r[0])
        thing.matrix_world = C @ arm_g @ Matrix.Translation((0, -0.42, 0)) @ rot_g(x=held_rot_x) \
            @ Matrix.Scale(held_scale, 4) @ Ci
        objs.append(thing)
    root = bpy.data.objects.new("Root", None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs:
        o.parent = root
        o.matrix_parent_inverse = root.matrix_world.inverted()
    root.rotation_euler = (tilt, 0, yaw)
    root.location = pos
    return root


def box(size, loc, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    o.data.materials.append(m)
    return o


def cyl(r, h, loc, m, verts=16, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc)
    o = bpy.context.object
    o.data.materials.append(m)
    return o


def prop(name, loc, rot=(0, 0, 0), scale=1.0):
    objs = import_glb(os.path.join(PROPS, name + ".glb"))
    for o in objs:
        o.location = loc
        o.rotation_euler = rot
        o.scale = (scale, scale, scale)
    return objs


def render(filename, cam_pos, cam_target, sun_rot=(0.75, 0.15, 0.6), sky=(0.55, 0.68, 0.82)):
    scene = bpy.context.scene
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.2
    sun.angle = 0.2
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = sun_rot
    scene.collection.objects.link(so)
    scene.world = bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (*sky, 1)
    bg.inputs[1].default_value = 0.9
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 40
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = cam_pos
    cam.rotation_euler = (Vector(cam_target) - Vector(cam_pos)).to_track_quat("-Z", "Y").to_euler()
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 900, 1200
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.filepath = os.path.join(OUT, filename)
    bpy.ops.render.render(write_still=True)
    print("RENDERED", filename)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


ARM_UP, ARM_SIDE = 2.75, 1.45
BAT_REST = dict(arm_r=(0.42, 0.9), held_rot_x=2.76)

# ---------------- 1. Очередь за колбасой ----------------
reset()
box((30, 30, 0.2), (0, 0, -0.1), mat("Asphalt", (0.36, 0.36, 0.35), 0.95))
prop("kiosk", (0, 2.6, 0))
seller = character("white", ["jacket_seller_robe"], pos=(0, 2.75, 0), yaw=math.pi,
                   arm_r=(ARM_UP, 0.0), held=os.path.join(PROPS, "sausage.glb"), held_scale=1.4)
cyl(0.3, 0.26, (0, 2.75, 1.66), mat("CapWhite", (0.97, 0.97, 0.97)), r2=0.27)
character("red", ["hat_kepka", "jacket_abibas", "pants_abibas", "shoes_kedy"], pos=(-1.6, 0.3, 0),
          arm_r=(ARM_UP, 0.0))
character("blue", ["hat_ushanka", "jacket_dutik", "pants_school", "shoes_valenki"], pos=(-0.5, 0.35, 0))
character("yellow", ["hat_panama", "jacket_granny", "pants_klesh", "shoes_galoshi", "back_bag"],
          pos=(0.6, 0.3, 0), arm_r=(1.2, 0.3))
character("green", ["hat_pompom", "jacket_varenka", "pants_camo", "shoes_rubber_boots", "face_mustache"],
          pos=(1.7, 0.35, 0))
render("sausage_queue_ref.png", (3.6, -4.6, 2.4), (0, 1.4, 1.1))

# ---------------- 2. Битва на битах ----------------
reset()
box((60, 60, 0.2), (0, 0, -3.5), mat("Grass", (0.33, 0.5, 0.22), 0.95))
box((11, 7, 0.4), (0, 0, -0.2), mat("Roof", (0.2, 0.2, 0.22), 0.9))
for i, x in enumerate((-4.125, -1.375, 1.375, 4.125)):
    box((2.75, 7, 3), (x, 0, -1.9), mat("Garage" + str(i % 2), (0.6, 0.58, 0.52) if i % 2 else (0.52, 0.48, 0.43), 0.9))
    box((2.2, 0.08, 2.2), (x, -3.52, -2.3), mat("Door" + str(i % 2), (0.2, 0.42, 0.28) if i % 2 else (0.5, 0.23, 0.12), 0.7))
bpy.ops.mesh.primitive_torus_add(major_radius=0.45, minor_radius=0.17, location=(2.6, 1.6, 0.17))
bpy.context.object.data.materials.append(mat("Tire", (0.05, 0.05, 0.06), 0.8))
prop("energy_can", (-2.2, -1.4, 0), scale=3.5)
character("red", ["face_bruise", "jacket_alkogolichka", "pants_abibas", "shoes_slippers"], pos=(-0.6, 0, 0),
          yaw=0.6, arm_r=(ARM_SIDE, 0.0), held=os.path.join(PROPS, "bat.glb"))
character("blue", ["hat_hardhat", "jacket_kosuha", "pants_camo", "shoes_kedy"], pos=(1.4, -0.6, 0),
          yaw=-0.7, held=os.path.join(PROPS, "bat_super.glb"), **BAT_REST)
character("yellow", ["hat_kepka", "jacket_abibas", "pants_abibas", "shoes_pumba"], pos=(0.5, 1.2, 1.1),
          yaw=2.2, tilt=0.9, arm_l_x=-1.2, legs=(0.8, -0.5), held=os.path.join(PROPS, "bat.glb"),
          arm_r=(2.2, 0.0))
character("green", ["hat_pilotka", "jacket_dutik", "pants_overalls", "shoes_rubber_boots", "neck_gold_chain"],
          pos=(-2.4, 0.9, 0), yaw=-0.5, held=os.path.join(PROPS, "bat.glb"), **BAT_REST)
render("bat_battle_ref.png", (3.2, -6.6, 4.6), (0, 0.2, 0.7))

# ---------------- 3. Морожка ----------------
reset()
box((60, 60, 0.2), (0, 0, -0.1), mat("Grass", (0.33, 0.5, 0.22), 0.95))
box((3, 3, 0.4), (-3.2, 3.0, 0.2), mat("Sandbox", (0.7, 0.18, 0.12), 0.7))
box((2.7, 2.7, 0.05), (-3.2, 3.0, 0.42), mat("Sand", (0.86, 0.76, 0.5), 1.0))
cyl(3.0, 0.02, (0.6, 0.6, 0.02), mat("Zone", (1.0, 0.25, 0.15), 0.9, alpha=0.35))
character("blue", ["hat_petushok", "jacket_pioneer", "pants_pe_shorts", "shoes_kedy"], pos=(0.6, 0.6, 0),
          yaw=0.4, arm_r=(0.6, 1.4), arm_l_x=1.2, legs=(0.5, -0.4))
cyl(0.68, 2.05, (0.6, 0.6, 1.0), mat("Ice", (0.65, 0.88, 1.0), 0.05, transmission=0.85), verts=6, r2=0.62)
chaser = character("red", ["jacket_abibas", "pants_abibas", "shoes_kedy"], pos=(-1.6, -0.8, 0), yaw=-0.9,
                   arm_r=(0.3, 1.3), arm_l_x=1.3, legs=(0.7, -0.6))
cyl(0.36, 0.5, (-1.6, -0.8, 1.82), mat("HatRed", (0.85, 0.2, 0.15)), verts=8, r2=0.0)
character("green", ["hat_panama", "jacket_alkogolichka", "pants_family", "shoes_slippers"], pos=(2.4, -1.2, 0),
          yaw=-2.4, arm_r=(0.2, -0.8), arm_l_x=0.8, legs=(-0.7, 0.6))
character("yellow", ["hat_pompom", "jacket_varenka", "pants_klesh", "shoes_galoshi"], pos=(1.6, 1.8, 0),
          yaw=2.6, arm_r=(0.8, 1.2))
render("freeze_tag_ref.png", (4.2, -6.0, 3.6), (0.3, 0.3, 0.8))
print("DONE")
