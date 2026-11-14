"""Стекло окон старой хрущёвки (атлас 4 × 2 = 8 вариантов, 256 × 256) — днём, свет выключен.
Другие картинки, чем у новых домов (window_glass.py): тюль с кружевом и герань, тяжёлые шторы
наполовину, кухня с «кафешторами» и банками на подоконнике, оранжевый абажур, кот на
подоконнике, окно, заклеенное фольгой от солнца, кактусы и алоэ, сервант с хрусталём.
Переплёт рисует модель (посередине), здесь только то, что за стеклом, и отражение неба.
Запуск: python3 tools/textures/khrush_glass.py  →  assets/textures/city/khrush_glass.png
"""
import random
from PIL import Image, ImageDraw, ImageFilter

T = 256
img = Image.new("RGB", (T * 4, T * 2))
random.seed(91)


def dim(c, k=0.55):
    return tuple(int(v * k + 22) for v in c)


def tulle(d, top=0, bottom=T, lace=True):
    """Белый тюль: вертикальные складки и кружевной край снизу."""
    for x in range(0, T, 6):
        shade = 200 + (x // 6 % 3) * 14
        d.line((x, top, x, bottom), fill=dim((shade, shade, shade - 6), 0.7), width=4)
    if lace:
        for x in range(0, T, 22):
            d.ellipse((x - 4, bottom - 26, x + 18, bottom - 4), outline=dim((240, 240, 235), 0.75), width=3)


def sill(d, color=(225, 222, 210)):
    d.rectangle((0, 226, T, 240), fill=dim(color))


def pot(d, x, leaf, flower=None):
    d.polygon([(x - 18, 200), (x + 18, 200), (x + 13, 226), (x - 13, 226)], fill=dim((175, 90, 50)))
    d.ellipse((x - 30, 150, x + 30, 205), fill=dim(leaf))
    if flower:
        for dx, dy in ((-12, 160), (8, 152), (16, 172), (-4, 176)):
            d.ellipse((x + dx - 7, dy - 7, x + dx + 7, dy + 7), fill=dim(flower, 0.8))


def tile(k):
    wall = random.choice([(170, 150, 120), (140, 150, 130), (160, 140, 150), (130, 140, 160)])
    t = Image.new("RGB", (T, T), tuple(int(c * 0.5) for c in wall))
    d = ImageDraw.Draw(t)
    if k == 0:                                                          # тюль и герань
        tulle(d)
        sill(d)
        pot(d, 70, (70, 130, 60), (220, 60, 70))
        pot(d, 180, (70, 130, 60), (230, 110, 150))
    elif k == 1:                                                        # тяжёлые шторы наполовину
        d.rectangle((0, 0, T, T), fill=(40, 36, 34))
        for x0, x1 in ((0, 110), (150, 256)):
            for x in range(x0, x1, 10):
                d.line((x, 0, x, T), fill=dim((120, 70, 45) if x // 10 % 2 else (100, 58, 38)), width=10)
        d.rectangle((0, 0, T, 14), fill=dim((90, 60, 40)))
    elif k == 2:                                                        # кухня: кафешторы и банки
        d.rectangle((0, 0, T, 120), fill=dim((215, 210, 190)))
        for x in range(0, T, 40):
            d.rectangle((x, 130, x + 20, 222), fill=dim((200, 70, 60)))
            d.rectangle((x + 20, 130, x + 40, 222), fill=dim((235, 230, 220)))
        for y in range(130, 222, 20):
            d.line((0, y, T, y), fill=dim((235, 230, 220)), width=6)
        d.line((0, 128, T, 128), fill=dim((150, 150, 150)), width=4)  # струна
        sill(d)
        for x, c in ((40, (90, 140, 70)), (110, (190, 50, 60)), (185, (220, 140, 50))):
            d.rectangle((x - 22, 168, x + 22, 226), fill=dim(c, 0.7), outline=dim((220, 225, 230)), width=3)
            d.rectangle((x - 18, 158, x + 18, 170), fill=dim((200, 200, 205)))
    elif k == 3:                                                        # оранжевый абажур, обои в полоску
        for x in range(0, T, 28):
            d.rectangle((x, 0, x + 14, T), fill=dim((190, 170, 120), 0.5))
        d.line((128, 0, 128, 60), fill=dim((60, 60, 60)), width=3)
        d.polygon([(70, 120), (186, 120), (160, 60), (96, 60)], fill=dim((235, 130, 50), 0.75))
        for x in range(74, 184, 8):
            d.line((x, 120, x, 134), fill=dim((235, 160, 80), 0.75), width=3)  # бахрома
        d.rectangle((40, 190, 216, 256), fill=dim((120, 80, 50)))      # стол
    elif k == 4:                                                        # кот на подоконнике
        tulle(d, lace=False)
        sill(d)
        cat = (120, 115, 110)
        d.ellipse((60, 170, 170, 230), fill=dim(cat))                   # туловище
        d.ellipse((140, 140, 196, 192), fill=dim(cat))                  # голова
        d.polygon([(146, 152), (152, 126), (166, 146)], fill=dim(cat))  # уши
        d.polygon([(172, 146), (186, 126), (192, 154)], fill=dim(cat))
        d.ellipse((152, 160, 160, 168), fill=(200, 190, 60))
        d.ellipse((174, 160, 182, 168), fill=(200, 190, 60))
        d.line((70, 215, 30, 190, 24, 160), fill=dim(cat), width=12)   # хвост
    elif k == 5:                                                        # фольга от солнца
        t = Image.new("RGB", (T, T), (150, 155, 160))
        d = ImageDraw.Draw(t)
        for _ in range(60):                                             # мятые блики
            x, y = random.randint(0, T), random.randint(0, T)
            s = random.randint(10, 40)
            c = random.randint(120, 230)
            d.polygon([(x, y), (x + s, y + random.randint(-12, 12)), (x + random.randint(-12, 12), y + s)],
                      fill=(c, c + 3, c + 8))
        d.line((0, 128, T, 132), fill=(200, 200, 190), width=6)         # скотч
    elif k == 6:                                                        # кактусы и алоэ, простой тюль
        tulle(d, 0, 140, lace=True)
        sill(d)
        for x in (50, 128, 205):
            d.polygon([(x - 16, 200), (x + 16, 200), (x + 12, 226), (x - 12, 226)], fill=dim((190, 100, 60)))
        d.rounded_rectangle((38, 130, 62, 200), 12, fill=dim((70, 130, 70)))
        d.rounded_rectangle((60, 150, 76, 180), 8, fill=dim((70, 130, 70)))
        for a in (-40, -20, 0, 20, 40):                                 # алоэ
            d.line((128, 200, 128 + a, 140 + abs(a)), fill=dim((90, 150, 90)), width=9)
        d.ellipse((188, 160, 222, 200), fill=dim((80, 140, 80)))
        d.ellipse((198, 150, 210, 162), fill=dim((230, 90, 140), 0.8))   # цветок кактуса
    else:                                                               # сервант с хрусталём
        d.rectangle((20, 40, 236, 256), fill=dim((95, 60, 35)))
        d.rectangle((34, 54, 222, 170), fill=dim((70, 75, 80)))
        for sy in (110, 168):
            d.line((34, sy, 222, sy), fill=dim((200, 200, 200)), width=3)
            for x in range(44, 216, 26):
                d.polygon([(x, sy), (x + 16, sy), (x + 12, sy - 30), (x + 4, sy - 30)],
                          fill=dim((200, 215, 230), 0.8))
        d.line((128, 54, 128, 170), fill=dim((60, 40, 25)), width=4)
    t = t.filter(ImageFilter.GaussianBlur(1.6))
    sky = Image.new("RGB", (T, T))                                      # отражение неба
    sd = ImageDraw.Draw(sky)
    for y in range(T):
        f = y / T
        sd.line((0, y, T, y), fill=(int(175 - 70 * f), int(198 - 70 * f), int(218 - 60 * f)))
    t = Image.blend(t, sky, 0.3)
    gl = Image.new("RGBA", (T, T), (0, 0, 0, 0))                        # косые блики
    g = ImageDraw.Draw(gl)
    for _ in range(random.randint(1, 2)):
        x = random.randint(-40, 220)
        w = random.randint(12, 30)
        g.polygon([(x, 0), (x + w, 0), (x + w - 80, T), (x - 80, T)], fill=(255, 255, 255, 50))
    t.paste(gl, (0, 0), gl)
    return t


for k in range(8):
    img.paste(tile(k), ((k % 4) * T, (k // 4) * T))
img.save("assets/textures/city/khrush_glass.png")
print("saved khrush_glass.png")
