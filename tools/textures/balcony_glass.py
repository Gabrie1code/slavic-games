"""Стекло застеклённых балконов (атлас 4 × 2 = 8 вариантов, 256 × 256 каждый): отражение неба
(светлее вверху), косые блики и сквозь стекло — силуэты вещей на балконе: полки с банками,
коробки, велосипед, бельё на верёвке, цветы, занавеска, лыжи, шкафчик. Однотонного голубого нет.
Запуск: python3 tools/textures/balcony_glass.py  →  assets/textures/city/balcony_glass.png
"""
import random
from PIL import Image, ImageDraw, ImageFilter

T = 256
img = Image.new("RGB", (T * 4, T * 2))
random.seed(42)


def tile(k):
    t = Image.new("RGB", (T, T))
    d = ImageDraw.Draw(t)
    top = (150 + random.randint(-15, 15), 180 + random.randint(-10, 10), 205)
    bottom = (70, 85, 100)
    for y in range(T):                                                  # отражение неба
        f = y / T
        d.line((0, y, T, y), fill=tuple(int(top[i] * (1 - f) + bottom[i] * f) for i in range(3)))
    dim = lambda c: tuple(int(v * 0.55 + 40) for v in c)               # вещи за стеклом приглушены
    kind = k
    if kind == 0:                                                       # полки с банками
        for sy in (110, 170, 230):
            d.rectangle((10, sy, 246, sy + 6), fill=dim((120, 90, 60)))
            for x in range(18, 240, 26):
                h = random.randint(28, 44)
                d.rounded_rectangle((x, sy - h, x + 20, sy), 4, fill=dim(random.choice(
                    [(190, 60, 50), (120, 150, 70), (200, 170, 90), (170, 120, 60)])))
    elif kind == 1:                                                     # коробки
        for _ in range(6):
            x, y = random.randint(5, 180), random.randint(110, 200)
            d.rectangle((x, y, x + random.randint(40, 70), 256), fill=dim((160, 125, 80)), outline=dim((110, 85, 50)))
    elif kind == 2:                                                     # велосипед
        for cx in (70, 180):
            d.ellipse((cx - 45, 160, cx + 45, 250), outline=dim((40, 40, 45)), width=6)
        d.line((70, 205, 125, 150, 180, 205), fill=dim((60, 90, 150)), width=7)
        d.line((125, 150, 110, 120), fill=dim((60, 90, 150)), width=6)
    elif kind == 3:                                                     # бельё на верёвке
        d.line((0, 40, 256, 48), fill=dim((220, 220, 220)), width=2)
        for x in range(10, 240, 48):
            d.rectangle((x, 44, x + 38, 44 + random.randint(50, 100)), fill=dim(random.choice(
                [(230, 230, 225), (200, 60, 60), (70, 110, 200), (230, 200, 70)])))
    elif kind == 4:                                                     # цветы на подоконнике
        d.rectangle((0, 200, 256, 256), fill=dim((140, 110, 80)))
        for x in range(20, 250, 45):
            d.rectangle((x, 175, x + 26, 205), fill=dim((170, 80, 40)))
            d.ellipse((x - 14, 120, x + 40, 182), fill=dim((60, 130, 60)))
    elif kind == 5:                                                     # занавеска
        c = random.choice([(220, 140, 60), (230, 210, 120), (170, 90, 150)])
        for x in range(0, 140, 14):
            d.rectangle((x, 0, x + 10, 256), fill=dim(c))
    elif kind == 6:                                                     # лыжи и шкафчик
        d.rectangle((120, 70, 240, 256), fill=dim((150, 120, 85)), outline=dim((90, 70, 50)), width=4)
        for x in (40, 62):
            d.rectangle((x, 20, x + 12, 256), fill=dim((190, 50, 40)))
    else:                                                               # почти пусто: стул и таз
        d.rectangle((40, 160, 110, 175), fill=dim((150, 110, 70)))
        d.line((45, 175, 45, 250), fill=dim((100, 70, 40)), width=6)
        d.line((105, 175, 105, 250), fill=dim((100, 70, 40)), width=6)
        d.ellipse((150, 210, 240, 250), fill=dim((90, 140, 190)))
    t = t.filter(ImageFilter.GaussianBlur(1.6))
    gl = Image.new("RGBA", (T, T), (0, 0, 0, 0))                        # косые блики
    g = ImageDraw.Draw(gl)
    for _ in range(2):
        x = random.randint(-60, 200)
        w = random.randint(14, 40)
        g.polygon([(x, 0), (x + w, 0), (x + w - 90, T), (x - 90, T)], fill=(255, 255, 255, 60))
    t.paste(gl, (0, 0), gl)
    return t


for k in range(8):
    img.paste(tile(k), ((k % 4) * T, (k // 4) * T))
img.save("assets/textures/city/balcony_glass.png")
print("saved balcony_glass.png")
