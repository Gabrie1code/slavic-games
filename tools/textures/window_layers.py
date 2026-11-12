"""Вид из окна гостиной слоями (для «объёмного» вида: слои стоят на разной глубине за окном,
и при движении ближние сдвигаются сильнее дальних — параллакс):
  window_sky.png    — небо с облаками (непрозрачное);
  window_houses.png — хрущёвки напротив, низ — земля двора (прозрачный фон);
  window_trees.png  — тополя и кусты у дома (прозрачный фон).

Запуск (Python с Pillow):
    python3 tools/textures/window_layers.py assets/textures/window
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
random.seed(5)

# ---------- Небо ----------
W, H = 2048, 1024
sky = Image.new("RGB", (W, H))
d = ImageDraw.Draw(sky)
for y in range(H):
    t = y / H
    d.line((0, y, W, y), fill=(int(95 + 110 * t), int(150 + 85 * t), int(210 + 35 * t)))
clouds = Image.new("RGBA", (W, H), (0, 0, 0, 0))
cd = ImageDraw.Draw(clouds)
for _ in range(9):
    cx, cy, s = random.randint(0, W), random.randint(120, 620), random.uniform(0.6, 1.4)
    for k in range(7):
        r = int(random.randint(50, 90) * s)
        x = cx + int((k - 3) * 55 * s)
        y = cy + random.randint(-20, 20)
        cd.ellipse((x - r, y - r * 0.7, x + r, y + r * 0.7), fill=(255, 255, 255, 235))
clouds = clouds.filter(ImageFilter.GaussianBlur(4))
sky.paste(clouds, (0, 0), clouds)
sky.save(os.path.join(OUT, "window_sky.png"))

# ---------- Дома напротив ----------
W, H = 2048, 1024
houses = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(houses)
GROUND = int(H * 0.86)


def building(x0, y0, w, base, floors, cols, lit=0.15):
    d.rectangle((x0, y0, x0 + w, GROUND), fill=base)
    shade = tuple(int(c * 0.82) for c in base) + (255,)
    d.rectangle((x0 + w - 14, y0, x0 + w, GROUND), fill=shade)
    d.rectangle((x0 - 6, y0 - 10, x0 + w + 6, y0), fill=tuple(int(c * 0.7) for c in base) + (255,))
    fh = (GROUND - y0 - 30) / floors
    for f in range(floors):
        for c in range(cols):
            wx = x0 + 14 + c * (w - 28) / cols
            wy = y0 + 14 + f * fh
            ww, wh = (w - 28) / cols - 14, fh * 0.55
            glass = (255, 225, 140) if random.random() < lit else (70, 95, 120)
            d.rectangle((wx, wy, wx + ww, wy + wh), fill=(235, 232, 225))
            d.rectangle((wx + 3, wy + 3, wx + ww - 3, wy + wh - 3), fill=glass)
            if random.random() < 0.2:
                d.rectangle((wx - 4, wy + wh, wx + ww + 4, wy + wh + 12), fill=shade)
    for ax in range(int(x0 + 30), int(x0 + w - 20), 90):
        d.line((ax, y0 - 10, ax, y0 - 60), fill=(80, 80, 85), width=4)
        d.line((ax - 20, y0 - 48, ax + 20, y0 - 48), fill=(80, 80, 85), width=3)


building(20, 330, 700, (205, 196, 175), 6, 6)
building(760, 250, 820, (190, 185, 172), 7, 7, lit=0.2)
building(1620, 380, 420, (215, 205, 185), 5, 3)
d.rectangle((0, GROUND, W, H), fill=(110, 112, 108, 255))                 # асфальт двора
for x in range(0, W, 160):                                               # бордюр и газон
    d.rectangle((x, GROUND + 18, x + 150, GROUND + 26), fill=(190, 188, 180, 255))
d.rectangle((0, GROUND + 26, W, H), fill=(95, 135, 70, 255))
houses.save(os.path.join(OUT, "window_houses.png"))

# ---------- Деревья у дома ----------
W, H = 2048, 1024
trees = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(trees)
for x in range(60, W, 260):
    trunk_h = random.randint(260, 380)
    d.rectangle((x - 14, H - trunk_h, x + 14, H), fill=(95, 75, 55, 255))
    color = random.choice([(70, 125, 55), (85, 140, 60), (60, 110, 50)])
    top = H - trunk_h - random.randint(250, 420)
    for k in range(6):
        r = random.randint(80, 125)
        cx = x + random.randint(-50, 50)
        cy = top + k * 75
        d.ellipse((cx - r, cy - r * 1.25, cx + r, cy + r * 1.25), fill=color + (255,))
        d.ellipse((cx - r * 0.6, cy - r * 1.05, cx + r * 0.2, cy - r * 0.25),
                  fill=tuple(min(255, c + 25) for c in color) + (255,))
for x in range(0, W, 120):                                               # кусты внизу
    r = random.randint(60, 90)
    d.ellipse((x - r, H - r * 1.1, x + r, H + r * 0.6), fill=(60, 105, 45, 255))
trees.save(os.path.join(OUT, "window_trees.png"))
print("DONE")
