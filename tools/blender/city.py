"""Дома и дальний горизонт вокруг дворов (сначала — «Морожка»): разные дома 70–80-х, у каждого
окна и балконы разные (случайно, но с постоянным seed — каждый раз одинаково).

  brick_khrushchevka — кирпичная хрущёвка, 5 этажей, 3 подъезда;
  panel_ninestory    — панельная девятиэтажка с голубой плиткой, будки лифтов на крыше;
  stalinka           — сталинка: высокие этажи, рустованный низ, карниз, скатная крыша;
  tower_block        — точечная башня, 14 этажей, окна на все стороны (ставится вдали);
  garage_row         — ряд гаражей с разными воротами;
  transformer_box    — кирпичная трансформаторная будка с жёлтым знаком;
  tec_chimney        — труба ТЭЦ в красно-белую полоску (горизонт);
  water_tower        — водонапорная башня (горизонт);

Окна: занавески разных цветов, тюль, фольга, газета, открытая форточка, кондиционер, цветок,
окно заклеенное крестом. Балконы: бетонный, с металлическими прутьями, самодельно застеклённый,
обшитый профлистом; на них бельё, тарелка, лыжи, велосипед, ковёр на перилах, ящики с цветами,
кот, санки.

Здания смотрят «лицом» в −Y Blender (= +Z в Godot), начало координат — на земле, по центру.
Всё собирается в один меш на дом (быстро и в Blender, и в Godot).

Запуск:
    python tools/blender/city.py assets/models/courtyard [--render превью.png]
"""
import bpy, math, sys, os, random
from mathutils import Vector, Matrix, Euler

args = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = args[0] if args else "."
RENDER = sys.argv[sys.argv.index("--render") + 1] if "--render" in sys.argv else None
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
_mats = {}
MADE = []


ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def mat(name, color, rough=0.7, metal=0.0, image=None):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if image:
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(os.path.join(ROOT, image))
        m.node_tree.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    _mats[name] = m
    return m


class Builder:
    """Копит коробки и цилиндры в один меш (по материалам)."""

    def __init__(self):
        self.verts, self.faces, self.mats, self.mat_list = [], [], [], []
        self.uvs = {}                                                   # номер грани -> UV вершин

    def _mi(self, m):
        if m not in self.mat_list:
            self.mat_list.append(m)
        return self.mat_list.index(m)

    def box(self, size, loc, m, rot=(0, 0, 0)):
        sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
        R = Euler(rot).to_matrix()
        c = Vector(loc)
        base = len(self.verts)
        for x, y, z in ((-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
                        (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)):
            self.verts.append(tuple(c + R @ Vector((x * sx, y * sy, z * sz))))
        mi = self._mi(m)
        for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            self.faces.append(tuple(base + i for i in f))
            self.mats.append(mi)

    def cyl(self, r, h, loc, m, n=10, r2=None, rot=(0, 0, 0)):
        r2 = r if r2 is None else r2
        R = Euler(rot).to_matrix()
        c = Vector(loc)
        base = len(self.verts)
        for z, rr in ((-h / 2, r), (h / 2, r2)):
            for k in range(n):
                a = k * math.tau / n
                self.verts.append(tuple(c + R @ Vector((math.cos(a) * rr, math.sin(a) * rr, z))))
        mi = self._mi(m)
        for k in range(n):
            k2 = (k + 1) % n
            self.faces.append((base + k, base + k2, base + n + k2, base + n + k))
            self.mats.append(mi)
        self.faces.append(tuple(base + k for k in reversed(range(n))))
        self.mats.append(mi)
        self.faces.append(tuple(base + n + k for k in range(n)))
        self.mats.append(mi)

    def quad(self, corners, uv_rect, m):
        """Плоский четырёхугольник с картинкой: corners — 4 точки (левый-низ, правый-низ, правый-верх,
        левый-верх), uv_rect — (u0, v0, u1, v1) участок картинки."""
        base = len(self.verts)
        self.verts += [tuple(c) for c in corners]
        u0, v0, u1, v1 = uv_rect
        self.uvs[len(self.faces)] = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
        self.faces.append((base, base + 1, base + 2, base + 3))
        self.mats.append(self._mi(m))

    def tri_uv(self, pts, uvs, m):
        """Треугольник с картинкой: pts — 3 точки, uvs — их UV."""
        base = len(self.verts)
        self.verts += [tuple(p) for p in pts]
        self.uvs[len(self.faces)] = list(uvs)
        self.faces.append((base, base + 1, base + 2))
        self.mats.append(self._mi(m))

    def poly(self, pts, faces, m):
        base = len(self.verts)
        self.verts += [tuple(p) for p in pts]
        mi = self._mi(m)
        for f in faces:
            self.faces.append(tuple(base + i for i in f))
            self.mats.append(mi)

    def build(self, name):
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.verts, [], self.faces)
        for m in self.mat_list:
            me.materials.append(m)
        for p, mi in zip(me.polygons, self.mats):
            p.material_index = mi
            p.use_smooth = False
        if self.uvs:
            uv = me.uv_layers.new(name="UVMap")
            for fi, coords in self.uvs.items():
                for k, li in enumerate(me.polygons[fi].loop_indices):
                    uv.data[li].uv = coords[k]
        me.validate()
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        return o


def export(name, b):
    o = b.build(name)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True,
                              export_format="GLB", export_draco_mesh_compression_enable=False)
    print("EXPORTED", name, len(b.faces), "faces")
    MADE.append(o)
    return o


# ---------------- Материалы ----------------
WHITE = mat("CWhite", (0.88, 0.87, 0.84))
FRAME_W = mat("CFrameWhite", (0.86, 0.85, 0.8))
FRAME_WOOD = mat("CFrameWood", (0.42, 0.27, 0.14))
GLASS = mat("CGlass", (0.16, 0.22, 0.28), 0.15)
GLASS_SKY = mat("CGlassSky", (0.4, 0.52, 0.6), 0.1)
DISH = mat("CDish", (0.82, 0.83, 0.84), 0.5, 0.2)
# Лицо тарелки: пародийный логотип «ДВУКОЛОР» (tools/textures/dish_logo.py).
DISH_FACE = mat("CDishFace", (1, 1, 1), 0.45, image="assets/textures/city/dish_logo.png")


def dish(B, center, out, ax=0.34, az=0.38, depth=0.07, tilt=0.25):
    """Спутниковая тарелка как настоящая офсетная: овальная вогнутая чаша (лицо с картинкой,
    изнанка серая, ободок), снизу изогнутая штанга с конвертером в фокусе, сзади кронштейн.
    center — центр чаши, out — ±1: куда смотрит (по Y), tilt — наклон вверх (рад)."""
    c = Vector(center)
    n, rings = 20, 4
    ct, st = math.cos(tilt), math.sin(tilt)

    def pt(u, v, back=False):
        x, z = u * ax, v * az
        y = -out * depth * (1 - (u * u + v * v)) - (out * 0.012 if back else 0.0)
        # Наклон вверх: поворот вокруг X (лицо смотрит наружу и чуть вверх).
        yy = y * ct - z * st * out
        zz = z * ct + y * st * out
        return c + Vector((x, yy, zz))

    grid = [[(0.0, 0.0)] * (n) for _ in range(rings + 1)]
    for r in range(rings + 1):
        rad = r / rings
        for k in range(n):
            a = k * math.tau / n
            grid[r][k] = (math.cos(a) * rad, math.sin(a) * rad)
    for r in range(rings):
        for k in range(n):
            k2 = (k + 1) % n
            quad = [grid[r][k], grid[r][k2], grid[r + 1][k2], grid[r + 1][k]]
            tris = [(quad[0], quad[1], quad[2]), (quad[0], quad[2], quad[3])]
            for t in tris:
                if out > 0:
                    t = (t[0], t[2], t[1])
                uvs = [(0.5 + u * 0.5, 0.5 + v * 0.5) for u, v in t]
                B.tri_uv([pt(u, v) for u, v in t], uvs, DISH_FACE)                 # лицо
                B.tri_uv([pt(u, v, True) for u, v in reversed(t)], [(0, 0)] * 3, DISH)  # изнанка
    for k in range(n):                                                             # ободок
        a0, a1 = k * math.tau / n, (k + 1) * math.tau / n
        p0, p1 = pt(math.cos(a0), math.sin(a0)), pt(math.cos(a1), math.sin(a1))
        q0, q1 = pt(math.cos(a0), math.sin(a0), True), pt(math.cos(a1), math.sin(a1), True)
        B.poly([p0, p1, q1, q0], [(0, 1, 2, 3) if out < 0 else (3, 2, 1, 0)], DISH)
    # Штанга: от низа чаши вперёд-вверх к фокусу, на конце — конвертер.
    bottom = pt(0.0, -0.95)
    focus = c + Vector((0.12, out * 0.42, -0.02))
    knee = c + Vector((0.08, out * 0.3, -az * 0.9))
    for a, b in ((bottom, knee), (knee, focus)):
        d = b - a
        B.box((0.025, 0.025, d.length), tuple((a + b) / 2), DISH, rot=tuple(d.to_track_quat("Z", "Y").to_euler()))
    B.box((0.06, 0.08, 0.06), tuple(focus + Vector((0, -out * 0.02, 0))), WHITE)
    B.box((0.05, 0.05, 0.04), tuple(focus + Vector((0, out * 0.03, 0))), DARK)
    return pt(0.0, 0.0, True)                                                      # центр изнанки


# Стекло застеклённых балконов: картинка «что за стеклом» (tools/textures/balcony_glass.py, 8 вариантов).
BALCONY_GLASS = mat("CBalconyGlass", (1, 1, 1), 0.15, image="assets/textures/city/balcony_glass.png")


# Стекло обычных окон: комната за стеклом (tools/textures/window_glass.py, 8 вариантов).
WINDOW_GLASS = mat("CWindowGlass", (1, 1, 1), 0.15, image="assets/textures/city/window_glass.png")


def glass_tile(rng):
    """Случайный вариант из атласа 4 × 2: (u0, v0, u1, v1)."""
    k = rng.randrange(8)
    u, v = (k % 4) * 0.25, (k // 4) * 0.5
    return (u, v, u + 0.25, v + 0.5)
DARK = mat("CDark", (0.05, 0.05, 0.06), 0.6)
METAL = mat("CMetal", (0.5, 0.52, 0.54), 0.45, 0.6)
RAIL = mat("CRail", (0.18, 0.2, 0.2), 0.6, 0.3)
CONCRETE = mat("CConcrete", (0.62, 0.61, 0.57), 0.9)
SEAM = mat("CSeam", (0.42, 0.41, 0.38), 0.9)
ROOF = mat("CRoofTar", (0.12, 0.12, 0.13), 0.95)
DOOR = mat("CDoorBrown", (0.33, 0.19, 0.09), 0.7)
GREEN = mat("CPlant", (0.2, 0.48, 0.18), 0.8)
CURTAINS = [mat("CCurt%d" % i, c) for i, c in enumerate([
    (0.85, 0.42, 0.12), (0.92, 0.78, 0.25), (0.75, 0.15, 0.12), (0.25, 0.42, 0.7),
    (0.35, 0.55, 0.3), (0.55, 0.3, 0.5), (0.9, 0.9, 0.85), (0.45, 0.3, 0.2)])]
TULLE = mat("CTulle", (0.82, 0.83, 0.8), 0.9)
FOIL = mat("CFoil", (0.78, 0.78, 0.8), 0.25, 0.8)
PAPER = mat("CNewspaper", (0.72, 0.7, 0.62), 0.9)
CLAD = [mat("CClad%d" % i, c, 0.6, 0.2) for i, c in enumerate([
    (0.2, 0.42, 0.28), (0.25, 0.38, 0.6), (0.5, 0.25, 0.12), (0.72, 0.68, 0.55), (0.55, 0.12, 0.1)])]
LAUNDRY = [mat("CL%d" % i, c, 0.9) for i, c in enumerate(
    [tuple((v / 255) ** 2.2 for v in c) for c in (                         # пастельные цвета 80–90-х (sRGB)
        (226, 132, 128), (240, 170, 160), (232, 196, 120), (150, 196, 150), (120, 176, 196),
        (160, 150, 210), (214, 150, 196), (120, 160, 220), (238, 168, 104), (176, 214, 120),
        (110, 190, 176), (200, 120, 150))])]

# Семейства похожих оттенков (индексы в LAUNDRY): на одной верёвке вещи из РАЗНЫХ семейств,
# чтобы не висели подряд два бирюзовых или три голубых.
LAUNDRY_FAMILIES = [(0, 11), (1, 6), (2, 8), (3, 9), (4, 7, 10), (5,)]


def laundry_set(n, rnd):
    """n разных по цвету вещей для одной верёвки (n <= 6)."""
    return [LAUNDRY[rnd.choice(fam)] for fam in rnd.sample(LAUNDRY_FAMILIES, n)]
CARPETS = [mat("CCarpet%d" % i, c, 0.95) for i, c in enumerate(
    [(0.55, 0.08, 0.1), (0.2, 0.15, 0.4), (0.6, 0.35, 0.1)])]
CAT = mat("CCat", (0.85, 0.48, 0.15), 0.8)
SKI = mat("CSki", (0.75, 0.15, 0.1), 0.5)


# ---------------- Окна и балконы ----------------
def window(B, rng, x, y, z, w, h, frame=FRAME_W, dress=True, out=-1, reveal=0.0):
    """Окно в глубине проёма: y — плоскость стекла (out = −1: лицо в −Y), reveal — глубина
    проёма (насколько стена впереди). Рама, стекло, переплёт и «жизнь» (картинка за стеклом)."""
    f = out
    B.box((w + 0.16, 0.08, h + 0.16), (x, y + f * 0.02, z), frame)
    B.box((w, 0.1, h), (x, y + f * 0.03, z), GLASS)
    gy = y + f * 0.081                                                            # картинка на стекле
    pts = [(x - w / 2, gy, z - h / 2), (x + w / 2, gy, z - h / 2), (x + w / 2, gy, z + h / 2),
           (x - w / 2, gy, z + h / 2)]
    if f > 0:                                                                     # окно смотрит в +Y
        pts = [pts[1], pts[0], pts[3], pts[2]]
    B.quad(pts, glass_tile(rng), WINDOW_GLASS)
    B.box((0.06, 0.12, h), (x - w * 0.15, y + f * 0.03, z), frame)              # переплёт
    B.box((w * 0.35, 0.12, 0.05), (x - w * 0.32, y + f * 0.03, z + h * 0.2), frame)  # форточка
    B.box((w + 0.3, 0.2, 0.05), (x, y + f * 0.1, z - h / 2 - 0.08), WHITE)          # отлив
    if not dress:
        return
    yy = y + f * 0.085
    r = rng.random()
    if r < 0.32:                                                                  # занавески
        c = rng.choice(CURTAINS)
        for s in (-1, 1):
            B.box((w * 0.26, 0.01, h * 0.92), (x + s * (w / 2 - w * 0.13), yy, z), c)
        if rng.random() < 0.4:
            B.box((w * 0.46, 0.008, h * 0.9), (x, yy + f * 0.002, z), TULLE)
    elif r < 0.44:
        B.box((w * 0.94, 0.01, h * 0.94), (x, yy, z), TULLE)                       # тюль
    elif r < 0.48:
        B.box((w * 0.94, 0.01, h * 0.94), (x, yy, z), FOIL)                        # фольга
    elif r < 0.52:
        B.box((w * 0.45, 0.01, h * 0.6), (x + w * 0.2, yy, z - h * 0.1), PAPER)    # газета
    elif r < 0.535:                                                               # заклеено крестом (редко)
        for a in (0.9, -0.9):
            B.box((math.hypot(w, h) * 0.9, 0.01, 0.05), (x, yy, z), WHITE, rot=(0, a, 0))
    if rng.random() < 0.12:                                                        # открытая форточка
        B.box((w * 0.33, 0.012, h * 0.36), (x - w * 0.32, yy + f * 0.01, z + h * 0.2), DARK)
    if rng.random() < 0.08:                                                        # кондиционер
        B.box((0.7, 0.32, 0.45), (x + w * 0.4, y + f * (0.2 + reveal), z - h / 2 - 0.4), mat("CAC", (0.85, 0.85, 0.82)))
        B.box((0.55, 0.02, 0.25), (x + w * 0.4, y + f * (0.365 + reveal), z - h / 2 - 0.4), SEAM)
    if rng.random() < 0.1:                                                         # цветок на окне
        B.box((0.16, 0.12, 0.12), (x + w * 0.25, y + f * 0.12, z - h / 2 + 0.03), mat("CPot", (0.6, 0.3, 0.15)))
        B.cyl(0.11, 0.18, (x + w * 0.25, y + f * 0.12, z - h / 2 + 0.17), GREEN, n=6, r2=0.04)


def balcony(B, rng, x, y, z_floor, w=2.4, depth=1.1, style=None, out=-1):
    """Балкон на стене y: плита на уровне пола этажа z_floor, ограждение и вещи."""
    f = out
    yc = y + f * depth / 2
    yf = y + f * depth                                                              # передний край
    B.box((w, depth, 0.14), (x, yc, z_floor), CONCRETE)
    style = style or rng.choice(["concrete", "rails", "rails", "glazed", "glazed", "clad"])
    H = 1.0
    if style == "concrete":
        B.box((w, 0.08, H), (x, yf, z_floor + H / 2), CONCRETE)
        for s in (-1, 1):
            B.box((0.08, depth, H), (x + s * w / 2, yc, z_floor + H / 2), CONCRETE)
    elif style == "rails":
        B.box((w, 0.06, 0.05), (x, yf, z_floor + H), RAIL)
        n = int(w / 0.14)
        for k in range(n + 1):
            B.box((0.025, 0.025, H), (x - w / 2 + k * w / n, yf, z_floor + H / 2), RAIL)
        for s in (-1, 1):
            B.box((0.04, depth, 0.05), (x + s * w / 2, yc, z_floor + H), RAIL)
            for k in range(1, 6):
                B.box((0.025, 0.025, H), (x + s * w / 2, y + f * depth * k / 6, z_floor + H / 2), RAIL)
    elif style == "glazed":                                                          # самодельное остекление
        low = rng.choice(CLAD + [CONCRETE])
        B.box((w, 0.06, H), (x, yf, z_floor + H / 2), low)
        for s in (-1, 1):
            B.box((0.06, depth, H), (x + s * w / 2, yc, z_floor + H / 2), low)
        top = 2.55
        frame = rng.choice([FRAME_WOOD, FRAME_W, FRAME_WOOD])
        z0, z1 = z_floor + H, z_floor + top
        gy = yf + f * 0.005                                                         # перед: картинка
        B.quad([(x - w / 2, gy, z0), (x + w / 2, gy, z0), (x + w / 2, gy, z1), (x - w / 2, gy, z1)],
               glass_tile(rng), BALCONY_GLASS)                                      # лицом в −Y
        panes = rng.randint(3, 5)
        for k in range(panes + 1):
            B.box((0.05, 0.08, top - H), (x - w / 2 + k * w / panes, yf, z_floor + (H + top) / 2), frame)
        for zz in (H, top):
            B.box((w + 0.06, 0.09, 0.06), (x, yf, z_floor + zz), frame)
        for s in (-1, 1):
            sx = x + s * (w / 2 + 0.035)                                             # бока: тоже картинка
            near, far = (y, yf) if s < 0 else (yf, y)                               # лицом наружу (±X)
            B.quad([(sx, near, z0), (sx, far, z0), (sx, far, z1), (sx, near, z1)], glass_tile(rng),
                   BALCONY_GLASS)
        B.box((w + 0.2, depth + 0.15, 0.06), (x, yc, z_floor + top + 0.03), rng.choice(CLAD))  # козырёк
        if rng.random() < 0.4:                                                       # шторка внутри
            B.box((w * 0.3, 0.01, top - H - 0.1), (x - w * 0.3, yf - f * 0.05, z_floor + (H + top) / 2),
                  rng.choice(CURTAINS))
        return                                                                      # внутри вещей не видно
    else:                                                                           # профлист
        c = rng.choice(CLAD)
        B.box((w, 0.05, H), (x, yf, z_floor + H / 2), c)
        n = int(w / 0.12)
        for k in range(n + 1):
            B.box((0.03, 0.04, H), (x - w / 2 + k * w / n, yf + f * 0.03, z_floor + H / 2), c)
        for s in (-1, 1):
            B.box((0.05, depth, H), (x + s * w / 2, yc, z_floor + H / 2), c)
    # Вещи на открытом балконе. Тарелка — редко (у каждого ~10-го), и тогда на перилах ничего не
    # висит (ковёр, ящики с цветами закрыли бы её или вошли в неё).
    has_dish = rng.random() < 0.09
    r = rng.random()
    if has_dish and 0.3 <= r < 0.55:
        r = 0.9                                                                     # без ковра и ящиков
    if r < 0.3:                                                                     # бельё
        B.box((w - 0.2, 0.015, 0.015), (x, yc, z_floor + 1.85), WHITE)
        for k, cloth in enumerate(laundry_set(rng.randint(2, 4), rng)):
            B.box((0.32, 0.02, rng.uniform(0.3, 0.6)), (x - w / 2 + 0.4 + k * 0.5, yc, z_floor + 1.6),
                  cloth)
    elif r < 0.42:                                                                  # ковёр на перилах
        B.box((min(1.6, w - 0.3), 0.03, 1.1), (x, yf + f * 0.04, z_floor + H - 0.45), rng.choice(CARPETS))
    elif r < 0.55:                                                                  # ящики с цветами
        B.box((w - 0.3, 0.2, 0.18), (x, yf + f * 0.12, z_floor + H - 0.05), mat("CBoxWood", (0.45, 0.3, 0.16)))
        for k in range(6):
            B.cyl(0.08, 0.14, (x - w / 2 + 0.3 + k * (w - 0.6) / 5, yf + f * 0.12, z_floor + H + 0.1),
                  rng.choice([GREEN, CURTAINS[2], CURTAINS[1], CURTAINS[6]]), n=6, r2=0.03)
    elif r < 0.63:                                                                  # лыжи
        for k in range(2):
            B.box((0.08, 0.02, 1.8), (x + w / 2 - 0.25 - k * 0.12, yc, z_floor + 0.95), SKI, rot=(0, 0.12, 0))
    elif r < 0.7:                                                                   # велосипед
        for dx in (-0.45, 0.45):
            B.cyl(0.33, 0.04, (x + dx, yc, z_floor + 0.4), DARK, n=12, rot=(math.pi / 2, 0, 0))
        B.box((0.9, 0.04, 0.04), (x, yc, z_floor + 0.62), CURTAINS[3])
    elif r < 0.76:                                                                  # кот на перилах
        cx = x + rng.uniform(-0.6, 0.6)
        B.box((0.35, 0.16, 0.18), (cx, yf, z_floor + H + 0.13), CAT)
        B.box((0.14, 0.14, 0.14), (cx + 0.2, yf, z_floor + H + 0.27), CAT)              # голова
    elif r < 0.82:                                                                  # санки
        B.box((0.9, 0.35, 0.05), (x, yc, z_floor + 0.75), mat("CSled", (0.55, 0.35, 0.18)), rot=(0, 1.3, 0))
    if has_dish:                                                                    # спутниковая тарелка
        # Висит снаружи перил (ни во что не входит): чаша смотрит наружу и чуть вверх,
        # от изнанки к перилам — кронштейн.
        dx = x + w / 2 - 0.5
        center = (dx, yf + f * 0.42, z_floor + H + 0.42)
        back = dish(B, center, f)
        rail = Vector((dx, yf + f * 0.04, z_floor + H - 0.1))
        d = rail - back
        B.box((0.04, 0.04, d.length), tuple((back + rail) / 2), METAL, rot=tuple(d.to_track_quat("Z", "Y").to_euler()))


def entrance(B, x, y, ground=0.0, w=1.4, canopy=CONCRETE, door=DOOR, out=-1):
    f = out
    B.box((w, 0.1, 2.2), (x, y + f * 0.03, ground + 1.1), door)
    B.box((w + 0.9, 1.4, 0.15), (x, y + f * 0.7, ground + 2.6), canopy)
    B.box((w + 1.1, 1.5, 0.3), (x, y + f * 0.75, ground + 0.15), CONCRETE)
    B.box((0.3, 0.05, 0.2), (x + w / 2 + 0.3, y + f * 0.03, ground + 2.0), mat("CSignBlue", (0.15, 0.3, 0.6)))


def antennas(B, xs, y, top):
    for x in xs:
        B.box((0.06, 0.06, 2.4), (x, y, top + 1.2), METAL)
        for k in range(3):
            B.box((1.2 - k * 0.25, 0.03, 0.03), (x, y, top + 1.6 + k * 0.3), METAL)


REVEAL = 0.22                                                                     # глубина оконных проёмов


def facade(B, W, H, y_face, out, openings, mat_at, depth=REVEAL):
    """Стена-фасад с настоящими проёмами: полосы стены толщиной depth (от y_face внутрь) между
    окнами. openings — (x, z, w, h) проёмов (с рамой). mat_at(z) — материал стены на высоте z."""
    rows = {}
    for x, z, w, h in openings:
        rows.setdefault((round(z - h / 2, 3), round(z + h / 2, 3)), []).append((x - w / 2, x + w / 2))
    yc = y_face - out * depth / 2

    def band(z0, z1):
        if z1 - z0 > 0.001:
            B.box((W, depth, z1 - z0), (0, yc, (z0 + z1) / 2), mat_at((z0 + z1) / 2))

    z = 0.0
    for (zb, zt) in sorted(rows):
        band(z, zb)
        x = -W / 2
        for x0, x1 in sorted(rows[(zb, zt)]) + [(W / 2, W / 2)]:
            if x0 - x > 0.001:
                B.box((x0 - x, depth, zt - zb), ((x + x0) / 2, yc, (zb + zt) / 2), mat_at((zb + zt) / 2))
            x = x1
        z = zt
    band(z, H)


def slab_building(name, W, D, floors, fh, wall, cols, entrances, balcony_cols, rng, base=0.6,
                  band=None, band_every=1, roof_edge=SEAM, back=True):
    """Типовая коробка: стены, швы/пояски, окна на лицевой (и тыльной) стороне, балконы, подъезды."""
    B = Builder()
    H = base + floors * fh
    B.box((W, D - 2 * REVEAL, H), (0, 0, H / 2), wall)                              # «тело» за проёмами
    B.box((W + 0.3, D + 0.3, 0.35), (0, 0, H + 0.17), roof_edge)
    for fl in range(1, floors + 1):
        B.box((W + 0.04, D + 0.04, 0.06), (0, 0, base + fl * fh), SEAM)
    xs = [-W / 2 + 1.3 + c * (W - 2.6) / (cols - 1) for c in range(cols)]
    front, rear = [], []
    for fl in range(floors):
        z = base + fl * fh + 1.45
        if band and fl % band_every == 0:
            B.box((W + 0.02, D + 0.02, 0.44), (0, 0, base + fl * fh + 0.42), band)
        for c, x in enumerate(xs):
            if fl == 0 and c in entrances:
                continue
            window(B, rng, x, -D / 2 + REVEAL, z, 1.2, 1.4, reveal=REVEAL)
            front.append((x, z, 1.36, 1.56))
            if back:
                window(B, rng, x, D / 2 - REVEAL, z, 1.2, 1.4, dress=rng.random() < 0.3, out=1,
                       reveal=REVEAL)
                rear.append((x, z, 1.36, 1.56))
            if fl >= 1 and c in balcony_cols:
                balcony(B, rng, x + 0.3, -D / 2, base + fl * fh)
    facade(B, W, H, -D / 2, -1, front, lambda z: wall)
    facade(B, W, H, D / 2, 1, rear, lambda z: wall)
    for c in entrances:
        entrance(B, xs[c], -D / 2)
    return B, H, xs


# ---------------- 1. Кирпичная хрущёвка ----------------
rng = random.Random(101)
BRICK = mat("CBrick", (0.5, 0.24, 0.16), 0.9)
BRICK_SEAM = mat("CBrickSeam", (0.7, 0.62, 0.55), 0.9)
B, H, xs = slab_building("brick_khrushchevka", 26.0, 10.0, 5, 2.7, BRICK, 11, (2, 5, 8),
                         {1, 3, 4, 6, 7, 9}, rng, roof_edge=BRICK_SEAM)
for fl in range(5):                                                                 # светлые перемычки
    for x in xs:
        B.box((1.6, 0.06, 0.12), (x, -5.02, 0.6 + fl * 2.7 + 2.25), BRICK_SEAM)
antennas(B, (-8, -1, 6, 10), 0, H)
export("brick_khrushchevka", B)

# ---------------- 2. Панельная девятиэтажка ----------------
rng = random.Random(202)
PANEL9 = mat("CPanel9", (0.86, 0.85, 0.8), 0.85)
TILE_BLUE = mat("CTileBlue", (0.32, 0.52, 0.72), 0.5)
B, H, xs = slab_building("panel_ninestory", 30.0, 12.0, 9, 2.8, PANEL9, 13, (3, 9),
                         {1, 2, 5, 6, 7, 10, 11}, rng, band=TILE_BLUE, band_every=1)
for x in (xs[3], xs[9]):                                                           # будки лифтов
    B.box((3.2, 3.0, 2.6), (x, 0.5, H + 1.3), PANEL9)
    B.box((3.4, 3.2, 0.2), (x, 0.5, H + 2.7), SEAM)
    B.box((0.9, 0.08, 1.9), (x, -1.02, H + 0.95), DARK)
for x in xs[::3]:                                                                  # вертикальные швы
    B.box((0.08, 12.04, H), (x + 1.1, 0, H / 2), SEAM)
antennas(B, (-12, -4, 4, 12), 2, H)
export("panel_ninestory", B)

# ---------------- 3. Сталинка ----------------
rng = random.Random(303)
OCHRE = mat("COchre", (0.83, 0.68, 0.45), 0.85)
RUST_BASE = mat("CRustica", (0.55, 0.45, 0.36), 0.9)
STUCCO = mat("CStucco", (0.92, 0.88, 0.8), 0.8)
ROOF_GREEN = mat("CRoofGreen", (0.2, 0.3, 0.26), 0.6, 0.3)
W, D, FL, FH = 28.0, 13.0, 5, 3.3
B = Builder()
H = FL * FH + 0.5
B.box((W, D - REVEAL, H), (0, REVEAL / 2, H / 2), OCHRE)                          # «тело» за фасадом
B.box((W + 0.1, D - REVEAL, FH + 0.5), (0, REVEAL / 2, (FH + 0.5) / 2), RUST_BASE)  # рустованный низ
B.box((W + 0.9, D + 0.9, 0.5), (0, 0, H + 0.1), STUCCO)                             # карниз
B.box((W + 0.5, D + 0.5, 0.25), (0, 0, H - 0.3), STUCCO)
# Скатная крыша (вальмовая): низ — контур карниза, верх — конёк.
rw, rd, rh = W / 2 + 0.45, D / 2 + 0.45, 3.2
B.poly([(-rw, -rd, H + 0.35), (rw, -rd, H + 0.35), (rw, rd, H + 0.35), (-rw, rd, H + 0.35),
        (-rw + rd, 0, H + 0.35 + rh), (rw - rd, 0, H + 0.35 + rh)],
       [(0, 1, 5, 4), (1, 2, 5), (2, 3, 4, 5), (3, 0, 4), (3, 2, 1, 0)], ROOF_GREEN)
for x in (-9, 0, 9):                                                               # трубы на крыше
    B.box((0.7, 0.7, 2.0), (x, 1.5, H + 2.2), mat("CChimneyBrick", (0.5, 0.26, 0.18), 0.9))
cols = 11
xs = [-W / 2 + 1.5 + c * (W - 3.0) / (cols - 1) for c in range(cols)]
front = []
for fl in range(FL):
    z = 0.5 + fl * FH + 1.7
    for c, x in enumerate(xs):
        if fl == 0 and c in (2, 8):
            continue
        window(B, rng, x, -D / 2 + REVEAL, z, 1.2, 1.8, frame=FRAME_WOOD, reveal=REVEAL)
        front.append((x, z, 1.36, 1.96))
        B.box((1.6, 0.12, 0.25), (x, -D / 2 - 0.06, z + 1.12), STUCCO)              # сандрик над окном
        if fl in (2, 3) and c in (4, 6):                                           # балкончики с балясинами
            yb = -D / 2 - 0.5
            B.box((1.8, 1.0, 0.18), (x, yb, 0.5 + fl * FH), STUCCO)
            for k in range(9):
                B.cyl(0.05, 0.75, (x - 0.8 + k * 0.2, yb - 0.4, 0.5 + fl * FH + 0.45), STUCCO, n=6)
            B.box((1.9, 0.12, 0.1), (x, yb - 0.4, 0.5 + fl * FH + 0.85), STUCCO)
facade(B, W, H, -D / 2, -1, front, lambda z: RUST_BASE if z < FH + 0.5 else OCHRE)
for c in (2, 8):
    entrance(B, xs[c], -D / 2, door=FRAME_WOOD, canopy=STUCCO)
export("stalinka", B)

# ---------------- 4. Точечная башня (14 этажей, окна на все стороны) ----------------
rng = random.Random(404)
TOWER = mat("CTower", (0.82, 0.84, 0.86), 0.85)
STRIPE = mat("CTowerStripe", (0.85, 0.45, 0.18), 0.6)
S, FL, FH = 16.0, 14, 2.8
B = Builder()
H = 0.6 + FL * FH
B.box((S - 2 * REVEAL, S - 2 * REVEAL, H), (0, 0, H / 2), TOWER)                   # «тело» за проёмами
B.box((S + 0.3, S + 0.3, 0.35), (0, 0, H + 0.17), SEAM)
for s in (-1, 1):                                                                   # оранжевые полосы по углам
    for t in (-1, 1):
        B.box((0.9, 0.9, H - 1.0), (s * (S / 2 - 0.35), t * (S / 2 - 0.35), H / 2 + 0.5), STRIPE)
B.box((5, 5, 3.0), (0, 0, H + 1.5), TOWER)
for side in range(4):
    # Сторона side: строим как лицевую (в −Y), потом поворачиваем. Передняя и задняя — во всю
    # ширину, боковые — между ними (без наложения на углах).
    Bs = Builder()
    width = S if side % 2 == 0 else S - 2 * REVEAL
    opens = []
    for fl in range(FL):
        z = 0.6 + fl * FH + 1.45
        for c in range(5):
            u = -S / 2 + 2.0 + c * (S - 4.0) / 4
            if side == 0 and fl == 0 and c == 2:
                continue                                                           # подъезд
            window(Bs, rng, u, -S / 2 + REVEAL, z, 1.2, 1.4, dress=rng.random() < 0.5, reveal=REVEAL)
            opens.append((u, z, 1.36, 1.56))
            if fl >= 1 and c in (1, 3) and side == 0:
                balcony(Bs, rng, u, -S / 2, 0.6 + fl * FH, w=2.0, depth=1.0)
    facade(Bs, width, H, -S / 2, -1, opens, lambda z: TOWER)
    R = Matrix.Rotation(side * math.pi / 2, 3, "Z")
    base = len(B.verts)
    B.verts += [tuple(R @ Vector(v)) for v in Bs.verts]
    for face, mi in zip(Bs.faces, Bs.mats):
        B.faces.append(tuple(base + i for i in face))
        B.mats.append(B._mi(Bs.mat_list[mi]))
entrance(B, 0, -S / 2)
antennas(B, (-4, 4), 4, H)
export("tower_block", B)

# ---------------- 5. Ряд гаражей ----------------
rng = random.Random(505)
GARAGE_WALL = mat("CGarageWall", (0.6, 0.58, 0.54), 0.9)
GATES = [mat("CGate%d" % i, c, 0.6, 0.3) for i, c in enumerate(
    [(0.2, 0.4, 0.25), (0.22, 0.32, 0.55), (0.45, 0.22, 0.12), (0.55, 0.5, 0.42), (0.6, 0.15, 0.1)])]
B = Builder()
n, gw, gd, gh = 6, 3.4, 6.0, 2.6
L = n * gw
OPEN = 3                                                                        # приоткрытый гараж
ox = -L / 2 + gw / 2 + OPEN * gw
# Корпус — без бокса открытого гаража: он полый (пол, стены, потолок, вещи внутри).
B.box((ox - gw / 2 + L / 2, gd, gh), ((-L / 2 + ox - gw / 2) / 2, gd / 2, gh / 2), GARAGE_WALL)
B.box((L / 2 - ox - gw / 2, gd, gh), ((ox + gw / 2 + L / 2) / 2, gd / 2, gh / 2), GARAGE_WALL)
B.box((L + 0.4, gd + 0.4, 0.15), (0, gd / 2, gh + 0.07), ROOF)
WARM = mat("CGarageInside", (0.62, 0.48, 0.3), 0.9)
GARAGE_NUM = mat("CGarageNum", (1, 1, 1), 0.5, image="assets/textures/city/garage_numbers.png")
WARM_D = mat("CGarageInsideDark", (0.4, 0.3, 0.2), 0.9)
B.box((gw - 0.1, 0.1, gh), (ox, gd - 0.05, gh / 2), WARM)                      # задняя стена
B.box((gw - 0.1, gd, 0.08), (ox, gd / 2, gh - 0.04), WARM_D)                   # потолок
B.box((gw - 0.1, gd, 0.02), (ox, gd / 2, 0.01), mat("CGarageFloor", (0.35, 0.34, 0.32), 0.9))
for sx in (-1, 1):
    B.box((0.06, gd, gh), (ox + sx * (gw / 2 - 0.08), gd / 2, gh / 2), WARM)     # боковые стены
# Внутри: стеллаж с банками и коробками, стопка покрышек, верстак, лампочка, канистра.
for z in (0.6, 1.2, 1.8):
    B.box((0.5, 1.6, 0.04), (ox + 1.3, 2.4, z), WARM_D)
    for k in range(4):
        B.box((0.16, 0.16, 0.2), (ox + 1.3, 1.8 + k * 0.38, z + 0.12),
              rng.choice([mat("CJarG", (0.5, 0.6, 0.35), 0.4), mat("CBoxC", (0.65, 0.5, 0.3), 0.9),
                          mat("CCanR", (0.6, 0.15, 0.12), 0.5)]))
for k in range(3):
    B.cyl(0.33, 0.2, (ox - 1.0, 1.2, 0.1 + k * 0.2), DARK, n=14)
B.box((1.4, 0.6, 0.08), (ox - 0.4, gd - 0.45, 0.9), WARM_D)                     # верстак
for sx in (-1, 1):
    B.box((0.06, 0.06, 0.88), (ox - 0.4 + sx * 0.6, gd - 0.45, 0.44), WARM_D)
B.box((0.03, 0.03, 0.4), (ox, 3.0, gh - 0.28), DARK)                           # лампочка
B.cyl(0.07, 0.12, (ox, 3.0, gh - 0.52), mat("CBulbWarm", (1.0, 0.85, 0.5), 0.3), n=10)
# Канистра: корпус с выпуклым «крестом» на боках, три ручки сверху, горловина с крышкой наискосок.
CAN = mat("CCanister", (0.55, 0.12, 0.1), 0.5)
cx_, cy_ = ox + 0.9, 0.7
B.box((0.16, 0.34, 0.44), (cx_, cy_, 0.22), CAN)
for side in (-1, 1):
    for a in (0.9, -0.9):
        B.box((0.012, 0.36, 0.03), (cx_ + side * 0.085, cy_, 0.22), CAN, rot=(a, 0, 0))
for dy in (-0.1, 0.0, 0.1):
    B.box((0.03, 0.03, 0.08), (cx_, cy_ + dy, 0.46), CAN)
B.box((0.03, 0.24, 0.025), (cx_, cy_, 0.5), CAN)
B.cyl(0.03, 0.06, (cx_, cy_ - 0.15, 0.47), CAN, n=10, rot=(-0.6, 0, 0))
B.cyl(0.033, 0.02, (cx_, cy_ - 0.17, 0.5), DARK, n=10, rot=(-0.6, 0, 0))
B.box((2.6, 1.8, 0.012), (ox + 0.2, -0.9, 0.006), mat("CLightSpill", (0.5, 0.44, 0.34), 0.9))  # свет на асфальте
for k in range(n):
    x = -L / 2 + gw / 2 + k * gw
    B.box((0.15, 0.1, gh), (x - gw / 2, -0.04, gh / 2), SEAM)
    g = rng.choice(GATES)
    rng.random()                                                                # (порядок случайностей прежний)
    if k == OPEN:                                                               # приоткрытые ворота
        B.box((1.28, 0.08, 2.1), (x - 0.66, -0.04, 1.05), g)                    # левая створка закрыта
        B.box((gw, 0.1, gh - 2.1), (x, -0.04, (gh + 2.1) / 2), GARAGE_WALL)     # над воротами
        a = math.radians(-55)                                                   # правая — на петле наружу
        hinge = Vector((x + 1.3, -0.04, 0))
        mid = hinge + Vector((-math.cos(a) * 0.64, math.sin(a) * 0.64, 1.05))
        B.box((1.28, 0.08, 2.1), tuple(mid), g, rot=(0, 0, -a))
    else:
        for s in (-1, 1):
            B.box((1.28, 0.08, 2.1), (x + s * 0.66, -0.04, 1.05), g)
        B.box((0.08, 0.1, 0.25), (x + 0.1, -0.1, 1.0), METAL)                     # замок
    B.box((0.5, 0.05, 0.3), (x + 1.1, -0.115, 2.3), WHITE)                        # табличка (перед стеной)
    u0 = k / n                                                                  # номер (у 4-го — 57)
    B.quad([(x + 0.85, -0.142, 2.15), (x + 1.35, -0.142, 2.15), (x + 1.35, -0.142, 2.45),
            (x + 0.85, -0.142, 2.45)], (u0, 0.0, u0 + 1.0 / n, 1.0), GARAGE_NUM)
export("garage_row", B)

# ---------------- 6. Трансформаторная будка ----------------
B = Builder()
B.box((3.2, 2.6, 3.0), (0, 0, 1.5), BRICK)
B.box((3.5, 2.9, 0.15), (0, 0, 3.07), ROOF)
B.box((1.4, 0.08, 2.1), (-0.5, -1.32, 1.05), mat("CTrDoor", (0.35, 0.36, 0.33), 0.6, 0.3))
B.poly([(0.6, -1.36, 1.9), (1.2, -1.36, 1.9), (0.9, -1.36, 2.45)], [(0, 1, 2)],
       mat("CWarnYellow", (0.95, 0.78, 0.1), 0.5))
B.box((0.06, 0.02, 0.3), (0.9, -1.37, 2.1), DARK, rot=(0, 0.4, 0))                 # молния
export("transformer_box", B)

# ---------------- 7. Горизонт: труба ТЭЦ, водонапорная башня ----------------
RED = mat("CChimneyRed", (0.7, 0.12, 0.1), 0.8)
B = Builder()
for k in range(10):                                                                 # полосы
    B.cyl(3.0 - k * 0.15, 6.0, (0, 0, 3 + k * 6), RED if k % 2 == 0 else WHITE, n=16, r2=2.85 - k * 0.15)
B.cyl(1.8, 1.0, (0, 0, 60.5), DARK, n=16)
B.box((14, 10, 12), (14, 0, 6), CONCRETE)                                          # корпус ТЭЦ
B.box((14.4, 10.4, 0.4), (14, 0, 12.2), SEAM)
export("tec_chimney", B)

B = Builder()
B.cyl(2.2, 22, (0, 0, 11), BRICK, n=12, r2=1.8)
B.cyl(5.0, 5.5, (0, 0, 25), mat("CTankGreen", (0.3, 0.42, 0.35), 0.7, 0.3), n=16)
B.cyl(5.4, 1.2, (0, 0, 28.3), ROOF, n=16, r2=0.5)
export("water_tower", B)


# ---------------- 8. Башенный кран, как на стройках 80–90-х (горизонт) ----------------
# Решётчатая мачта и стрела выцветшей жёлто-оранжевой краской, красно-белые полосы на оголовке и
# конце стрелы, бетонные плиты-противовесы, кабина крановщика, тележка с крюком, тяги к стреле.
CRANE = mat("CCraneSoviet", (0.88, 0.6, 0.14), 0.7, 0.15)
CRANE_RED = mat("CCraneRed", (0.72, 0.12, 0.08), 0.6)
CAB = mat("CCraneCab", (0.82, 0.84, 0.86), 0.6)


def beam(B, a, b, r, m):
    """Балка (квадратного сечения 2r) от точки a до точки b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    B.box((r * 2, r * 2, d.length), tuple((a + b) / 2), m, rot=tuple(d.to_track_quat("Z", "Y").to_euler()))


B = Builder()
MH, M = 46.0, 1.0                                                         # высота мачты, полуширина
B.box((7, 7, 1.4), (0, 0, 0.7), CONCRETE)                                  # балластная база
for x in (-3.0, 3.0):
    B.box((0.3, 9, 0.25), (x, 0, 0.12), RAIL)                              # рельсы
corners = [(-M, -M), (M, -M), (M, M), (-M, M)]
for cx, cy in corners:
    beam(B, (cx, cy, 1.4), (cx, cy, MH), 0.09, CRANE)
z = 1.4
step = 2.6
while z + step <= MH:                                                     # раскосы зигзагом по граням
    for k in range(4):
        (x0, y0), (x1, y1) = corners[k], corners[(k + 1) % 4]
        beam(B, (x0, y0, z), (x1, y1, z + step), 0.05, CRANE)
        beam(B, (x0, y0, z), (x1, y1, z), 0.04, CRANE)
    z += step
B.box((3.2, 3.2, 0.6), (0, 0, MH + 0.3), CRANE)                          # поворотная платформа
B.box((2.2, 2.0, 2.2), (2.2, -1.6, MH - 0.6), CAB)                         # кабина
B.box((2.0, 0.05, 1.0), (2.2, -2.62, MH - 0.3), DARK)
HEAD = MH + 8.0                                                           # оголовок (А-рама)
for cy in (-0.8, 0.8):
    beam(B, (-0.8, cy, MH + 0.6), (0, 0, HEAD), 0.08, CRANE)
    beam(B, (0.8, cy, MH + 0.6), (0, 0, HEAD), 0.08, CRANE)
for k in range(4):                                                        # полосы на оголовке
    B.box((0.5, 0.5, 0.6), (0, 0, HEAD - 0.3 - k * 0.6), CRANE_RED if k % 2 == 0 else WHITE)
JL, JZ = 38.0, MH + 0.9                                                   # стрела
x = 1.6
while x < JL:
    nx = min(JL, x + 2.4)
    for cy in (-0.7, 0.7):
        beam(B, (x, cy, JZ), (nx, cy, JZ), 0.07, CRANE)
        beam(B, (x, cy, JZ), ((x + nx) / 2, 0, JZ + 1.4), 0.04, CRANE)
        beam(B, ((x + nx) / 2, 0, JZ + 1.4), (nx, cy, JZ), 0.04, CRANE)
    beam(B, ((x + nx) / 2, 0, JZ + 1.4), (min(JL, nx + 1.2), 0, JZ + 1.4), 0.06, CRANE)
    x = nx
for k in range(3):                                                        # красно-белый конец стрелы
    B.box((0.8, 1.6, 0.3), (JL - 0.4 - k * 0.8, 0, JZ), CRANE_RED if k % 2 == 0 else WHITE)
for cy in (-0.7, 0.7):                                                    # противовесная консоль
    beam(B, (-1.6, cy, JZ), (-13, cy, JZ), 0.08, CRANE)
for k in range(4):
    B.box((1.0, 2.2, 2.0), (-10.5 - k * 0.8, 0, JZ - 1.0), CONCRETE)       # плиты-противовесы
for end in ((JL * 0.7, 0, JZ + 1.4), (-12.5, 0, JZ)):                     # тяги от оголовка
    beam(B, (0, 0, HEAD), end, 0.035, DARK)
TX = 22.0                                                                 # тележка и крюк
B.box((1.6, 1.6, 0.5), (TX, 0, JZ - 0.3), DARK)
beam(B, (TX, 0, JZ - 0.5), (TX, 0, JZ - 14), 0.03, DARK)
B.box((0.8, 0.5, 1.0), (TX, 0, JZ - 14.5), CRANE_RED)
export("tower_crane", B)

if not RENDER:
    sys.exit(0)

# ---------------- Превью ----------------
spots = {"brick_khrushchevka": (-30, 0), "panel_ninestory": (0, 4), "stalinka": (31, 0),
         "tower_block": (-48, 22), "garage_row": (-22, -18), "transformer_box": (-8, -16),
         "tec_chimney": (55, 60), "water_tower": (20, 40), "tower_crane": (-10, 50)}
for o in MADE:
    o.location = (*spots[o.name], 0)
bpy.ops.mesh.primitive_plane_add(size=400)
bpy.context.object.data.materials.append(mat("CGround", (0.35, 0.42, 0.25)))
scene = bpy.context.scene
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (0, -62, 14)
cam.rotation_euler = (Vector((0, 10, 12)) - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 22
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
scene.collection.objects.link(sun)
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.75, 0.9, 1)
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.view_settings.view_transform = "Standard"
scene.render.resolution_x, scene.render.resolution_y = 1400, 700
scene.render.filepath = RENDER
bpy.ops.render.render(write_still=True)
