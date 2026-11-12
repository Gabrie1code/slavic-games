"""Ковёр-гобелен «Олени у озера» на стену в спальне (классика советских квартир):
лес, горы, озеро, олень с оленихой; по краю — орнаментальная кайма; ткань — мелкая «вязка».

Запуск (Python с Pillow):
    python3 tools/textures/carpet_deer.py assets/textures/carpet_deer.png
"""
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "carpet_deer.png"
W, H = 1300, 850
random.seed(9)
img = Image.new("RGB", (W, H), (120, 40, 30))
d = ImageDraw.Draw(img)

# Кайма: тёмно-красная с золотыми ромбами и бежевой полосой.
d.rectangle((0, 0, W, H), fill=(110, 28, 24))
for x in range(20, W, 46):
    for y in (22, H - 22):
        d.polygon([(x, y - 12), (x + 12, y), (x, y + 12), (x - 12, y)], fill=(205, 160, 70))
for y in range(64, H - 50, 46):
    for x in (22, W - 22):
        d.polygon([(x, y - 12), (x + 12, y), (x, y + 12), (x - 12, y)], fill=(205, 160, 70))
d.rectangle((44, 44, W - 44, H - 44), fill=(220, 200, 150))
IN = (56, 56, W - 56, H - 56)

# Картина: небо на закате, горы, лес, озеро.
x0, y0, x1, y1 = IN
for y in range(y0, y1):
    t = (y - y0) / (y1 - y0)
    if t < 0.45:
        c = (int(230 - 60 * t), int(170 - 40 * t), int(110 + 60 * t))
    else:
        c = (60, 90, 70)
    d.line((x0, y, x1, y), fill=c)
d.ellipse((820, 140, 940, 260), fill=(250, 220, 150))                        # солнце
for k, (base, color) in enumerate([(430, (110, 100, 130)), (470, (80, 90, 110))]):
    pts = [(x0, base)]
    for x in range(x0, x1 + 60, 120):
        pts.append((min(x, x1), base - random.randint(60, 180) + k * 40))
    pts += [(x1, base), (x1, y1), (x0, y1)]
    d.polygon(pts, fill=color)
d.rectangle((x0, 520, x1, 650), fill=(80, 120, 150))                           # озеро
for k in range(12):
    y = 535 + k * 10
    d.line((x0 + random.randint(0, 300), y, x0 + random.randint(600, 1100), y), fill=(120, 160, 185), width=2)
d.rectangle((x0, 650, x1, y1), fill=(70, 100, 50))                             # берег
for x in list(range(x0 + 34, 330, 38)) + list(range(1000, x1 - 34, 38)):        # ели по краям
    h = random.randint(200, 330)
    d.polygon([(x, 660 - h), (x - 32, 660), (x + 32, 660)], fill=(35, 70, 45))
    d.rectangle((x - 4, 660, x + 4, 680), fill=(70, 50, 30))
for x in (360, 960):                                                            # берёзы
    d.rectangle((x - 7, 330, x + 7, 680), fill=(235, 230, 215))
    for y in range(340, 680, 28):
        d.line((x - 7, y, x + 2, y), fill=(40, 40, 40), width=3)
    d.ellipse((x - 70, 260, x + 70, 420), fill=(90, 140, 60))


def deer(cx, base, s, stag):
    """Олень (смотрит влево): тело, короткая крепкая шея, голова с мордой и ушами, ноги, хвостик;
    у самца — ветвистые рога."""
    body = (95, 60, 35)
    light = (200, 170, 130)
    d.ellipse((cx - 70 * s, base - 125 * s, cx + 65 * s, base - 65 * s), fill=body)    # тело
    d.ellipse((cx + 50 * s, base - 120 * s, cx + 75 * s, base - 100 * s), fill=light)  # хвостик
    d.polygon([(cx - 55 * s, base - 110 * s), (cx - 75 * s, base - 165 * s),
               (cx - 45 * s, base - 170 * s), (cx - 20 * s, base - 115 * s)], fill=body)  # шея
    d.ellipse((cx - 95 * s, base - 185 * s, cx - 50 * s, base - 155 * s), fill=body)     # голова
    d.ellipse((cx - 115 * s, base - 175 * s, cx - 80 * s, base - 158 * s), fill=body)    # морда
    d.ellipse((cx - 118 * s, base - 172 * s, cx - 110 * s, base - 165 * s), fill=(30, 20, 15))
    for ex in (-62, -52):                                                                 # уши
        d.polygon([(cx + ex * s, base - 180 * s), (cx + (ex + 14) * s, base - 200 * s),
                   (cx + (ex + 10) * s, base - 178 * s)], fill=body)
    for lx in (-50, -32, 30, 48):                                                         # ноги
        d.line((cx + lx * s, base - 80 * s, cx + (lx + 3) * s, base - 35 * s), fill=body, width=int(10 * s))
        d.line((cx + (lx + 3) * s, base - 35 * s, cx + lx * s, base), fill=body, width=int(7 * s))
    if stag:
        antler = (150, 120, 80)
        for side in (-1, 1):
            ax, ay = cx - 72 * s, base - 185 * s
            tip = (ax + side * 30 * s, ay - 70 * s)
            d.line((ax, ay, *tip), fill=antler, width=int(6 * s))
            for k in range(3):
                t = 0.35 + k * 0.25
                bx, by = ax + (tip[0] - ax) * t, ay + (tip[1] - ay) * t
                d.line((bx, by, bx + side * 22 * s, by - 6 * s), fill=antler, width=int(4 * s))


deer(620, 700, 1.25, True)
deer(800, 705, 1.0, False)
d.ellipse((560, 700, 880, 730), fill=(55, 85, 40))                             # тень на траве

# «Вязка»: мелкий шум и лёгкие вертикальные нити.
noise = Image.effect_noise((W, H), 18).convert("RGB")
img = Image.blend(img, noise, 0.06)
weave = Image.new("RGB", (W, H), (0, 0, 0))
wd = ImageDraw.Draw(weave)
for x in range(0, W, 6):
    wd.line((x, 0, x, H), fill=(255, 255, 255), width=1)
img = Image.blend(img, Image.composite(img.point(lambda v: int(v * 0.88)), img, weave.convert("L")), 1.0)
img = img.filter(ImageFilter.SMOOTH)
img.save(OUT)
print("DONE")
