"""Стилизованный low-poly советский ламповый телевизор.

Запуск (нужен модуль bpy, см. tools/blender/README.md):
    python tools/blender/soviet_tv.py assets/models/props          # только .glb
    python tools/blender/soviet_tv.py assets/models/props --render # .glb + превью-рендеры
"""
import bpy, bmesh, math, sys, os
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else "."
RENDER = "--render" in sys.argv
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def mat(name, color, rough=0.6, metal=0.0, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m

WOOD   = mat("Wood",   (0.17, 0.055, 0.018), 0.45)
WOOD_D = mat("WoodDark", (0.08, 0.03, 0.012), 0.5)
PANEL  = mat("Panel",  (0.78, 0.70, 0.55), 0.5)
SCREEN = mat("Screen", (0.10, 0.16, 0.14), 0.15, emit=(0.35, 0.6, 0.5), strength=0.6)
FRAME  = mat("Frame",  (0.06, 0.05, 0.05), 0.4)
KNOB   = mat("Knob",   (0.08, 0.07, 0.07), 0.35)
METAL  = mat("Metal",  (0.75, 0.75, 0.78), 0.3, metal=1.0)
GRILLE = mat("Grille", (0.20, 0.17, 0.13), 0.9)
FLOOR  = mat("Floor",  (0.55, 0.12, 0.10), 0.9)   # «ковровый» красный
WALL   = mat("Wall",   (0.80, 0.72, 0.55), 0.9)

def finish(obj, m, bevel=0.0, segs=1):
    obj.data.materials.append(m)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segs
        mod.limit_method = "ANGLE"
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj

def box(name, size, loc, m, bevel=0.0, segs=1):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, bevel, segs)

def cyl(name, r, depth, loc, rot, m, verts=8, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    return finish(o, m, bevel)

parts = []
# Корпус (ось Y: минус — перед)
W, D, H = 1.0, 0.75, 0.72
BASE_Z = 0.42
cz = BASE_Z + H / 2
parts.append(box("Cabinet", (W, D, H), (0, 0, cz), WOOD, bevel=0.06, segs=2))
# Передняя светлая панель
FY = -D / 2 - 0.005
parts.append(box("FrontPanel", (W - 0.08, 0.02, H - 0.08), (0, FY, cz), PANEL, bevel=0.02))
# Рамка экрана и экран (слегка выпуклый)
SX = -0.12
parts.append(box("ScreenFrame", (0.64, 0.03, 0.54), (SX, FY - 0.015, cz), FRAME, bevel=0.05, segs=3))
def rounded_rect(w, h, r, seg=3):
    pts = []
    for cx, cz, a0 in [(w/2-r, h/2-r, 0), (-w/2+r, h/2-r, 90), (-w/2+r, -h/2+r, 180), (w/2-r, -h/2+r, 270)]:
        for i in range(seg + 1):
            a = math.radians(a0 + 90 * i / seg)
            pts.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return pts
me = bpy.data.meshes.new("Screen"); bm = bmesh.new()
outer = [bm.verts.new((SX + x, FY - 0.03, cz + z)) for x, z in rounded_rect(0.54, 0.44, 0.09)]
mid   = [bm.verts.new((SX + x * 0.6, FY - 0.055, cz + z * 0.6)) for x, z in rounded_rect(0.54, 0.44, 0.09)]
top = bm.verts.new((SX, FY - 0.065, cz))
n = len(outer)
for i in range(n):
    j = (i + 1) % n
    bm.faces.new((outer[i], outer[j], mid[j], mid[i]))
    bm.faces.new((mid[i], mid[j], top))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(me); bm.free()
scr = bpy.data.objects.new("Screen", me); scene.collection.objects.link(scr)
parts.append(finish(scr, SCREEN))

# Правая панель управления: решётка динамика и ручки
PX = 0.36
for i in range(6):
    parts.append(box(f"Grille{i}", (0.16, 0.012, 0.012), (PX, FY - 0.012, cz - 0.05 - i * 0.032), GRILLE))
for i, (z, r) in enumerate([(cz + 0.2, 0.05), (cz + 0.07, 0.04)]):
    parts.append(cyl(f"Knob{i}", r, 0.05, (PX, FY - 0.035, z), (math.pi / 2, 0, 0), KNOB, verts=10, bevel=0.008))
    parts.append(box(f"KnobMark{i}", (0.008, 0.01, r * 0.8), (PX, FY - 0.062, z + r * 0.35), PANEL))
# Маленькие кнопки внизу
for i in range(3):
    parts.append(box(f"Btn{i}", (0.035, 0.02, 0.025), (PX - 0.045 + i * 0.045, FY - 0.015, BASE_Z + 0.08), METAL, bevel=0.005))

# Ножки — разведённые конусы, как у советской мебели
for sx in (-1, 1):
    for sy in (-1, 1):
        lx, ly = sx * (W / 2 - 0.12), sy * (D / 2 - 0.1)
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.022, radius2=0.04, depth=0.45,
                                        location=(lx + sx * 0.03, ly + sy * 0.02, BASE_Z - 0.20),
                                        rotation=(-sy * 0.12, sx * 0.12, 0))
        leg = bpy.context.object; leg.name = "Leg"
        parts.append(finish(leg, WOOD_D))
        bpy.context.view_layer.update()
        low = min((leg.matrix_world @ v.co for v in leg.data.vertices), key=lambda c: c.z)
        tip = cyl("LegTip", 0.024, 0.05, (0, 0, 0), leg.rotation_euler, METAL, verts=6)
        tip.location = leg.matrix_world @ Vector((0, 0, -0.225 + 0.02))
        parts.append(tip)

# Антенна «рога»
TOP = BASE_Z + H
parts.append(cyl("AntBase", 0.08, 0.05, (0.15, 0.05, TOP + 0.02), (0, 0, 0), FRAME, verts=10, bevel=0.01))
for s in (-1, 1):
    ang = s * 0.55
    L = 0.6
    parts.append(cyl("AntRod", 0.008, L, (0.15 + math.sin(ang) * L / 2, 0.05, TOP + 0.04 + math.cos(ang) * L / 2),
                     (0, ang, 0), METAL, verts=6))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=4, radius=0.018,
                                         location=(0.15 + math.sin(ang) * L, 0.05, TOP + 0.04 + math.cos(ang) * L))
    parts.append(finish(bpy.context.object, METAL))

# Салфетка на крышке — обязательный элемент
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.2, depth=0.006, location=(-0.2, -0.05, TOP + 0.003))
parts.append(finish(bpy.context.object, mat("Doily", (0.95, 0.93, 0.88), 0.9)))

# Объединяем в один объект для экспорта
for o in parts:
    for mod in o.modifiers:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
tv = bpy.context.object
tv.name = "SovietTV"
tris = sum(len(p.vertices) - 2 for p in tv.data.polygons)
print("TRIANGLES:", tris)

bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "soviet_tv.glb"), use_selection=True, export_format="GLB")

# ---------- Сцена для рендера ----------
if not RENDER:
    print("DONE")
    sys.exit(0)
bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, 0))
finish(bpy.context.object, FLOOR)
bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 1.2, 4), rotation=(math.pi / 2, 0, 0))
finish(bpy.context.object, WALL)

def light(kind, loc, energy, color=(1, 1, 1), size=1.0, rot=(0, 0, 0)):
    d = bpy.data.lights.new(kind, kind)
    d.energy = energy; d.color = color
    if kind == "AREA": d.size = size
    o = bpy.data.objects.new(kind, d); o.location = loc; o.rotation_euler = rot
    scene.collection.objects.link(o)
    return o

def aim(o, target):
    o.rotation_euler = (Vector(target) - o.location).to_track_quat("-Z", "Y").to_euler()

k = light("AREA", (-2.2, -2.5, 3.0), 500, (1.0, 0.9, 0.75), size=2.5); aim(k, (0, 0, 0.6))
f = light("AREA", (2.5, -1.5, 1.5), 120, (0.7, 0.8, 1.0), size=2); aim(f, (0, 0, 0.6))
r = light("AREA", (1.5, 2.5, 2.5), 200, (1.0, 0.85, 0.7), size=1.5); aim(r, (0, 0, 0.8))

scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.25, 0.22, 0.2, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.4

cam_d = bpy.data.cameras.new("Cam"); cam_d.lens = 45
cam = bpy.data.objects.new("Cam", cam_d); scene.collection.objects.link(cam); scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 1000
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"

for name, pos in [("front", (-1.7, -3.0, 1.45)), ("side", (2.6, -2.2, 1.9))]:
    cam.location = pos
    aim(cam, (0, 0, 0.72))
    scene.render.filepath = os.path.join(OUT, f"tv_{name}.png")
    bpy.ops.render.render(write_still=True)
print("DONE")
