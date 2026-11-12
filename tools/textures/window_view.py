"""Вид из окна квартиры: небо с облаками, хрущёвки напротив, верхушки тополей.
Картинка вставляется в окно гостиной (вместо пересвеченного «неба»).

Запуск (Python с Pillow):
    python3 tools/textures/window_view.py assets/textures/window_view.png
"""
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "window_view.png"
W, H = 1400, 1500
random.seed(5)
img = Image.new("RGB", (W, H))
d = ImageDraw.Draw(img)
# Небо: сверху насыщенно-голубое, к горизонту светлее.
for y in range(H):
    t = y / H
    c = (int(110 + 90 * t), int(160 + 70 * t), int(215 + 25 * t))
    d.line((0, y, W, y), fill=c)
# Облака.
clouds = Image.new("RGBA", (W, H), (0, 0, 0, 0))
cd = ImageDraw.Draw(clouds)
for cx, cy, s in [(250, 180, 1.0), (900, 120, 1.3), (1200, 330, 0.8), (520, 380, 0.7)]:
    for k in range(7):
        r = int(random.randint(50, 90) * s)
        x = cx + int((k - 3) * 55 * s)
        y = cy + random.randint(-20, 20)
        cd.ellipse((x - r, y - r * 0.7, x + r, y + r * 0.7), fill=(255, 255, 255, 230))
img.paste(clouds.filter(ImageFilter.GaussianBlur(3)), (0, 0), clouds.filter(ImageFilter.GaussianBlur(3)))
d = ImageDraw.Draw(img)


def building(x0, y0, w, h, base, floors, cols, lit=0.15):
    d.rectangle((x0, y0, x0 + w, H), fill=base)
    shade = tuple(int(c * 0.82) for c in base)
    d.rectangle((x0 + w - 12, y0, x0 + w, H), fill=shade)                       # боковая тень
    d.rectangle((x0 - 6, y0 - 10, x0 + w + 6, y0), fill=tuple(int(c * 0.7) for c in base))
    fh = h / floors
    for f in range(floors):
        for c in range(cols):
            wx = x0 + 14 + c * (w - 28) / cols
            wy = y0 + 14 + f * fh
            ww, wh = (w - 28) / cols - 14, fh * 0.55
            glass = (255, 225, 140) if random.random() < lit else (70, 95, 120)
            d.rectangle((wx, wy, wx + ww, wy + wh), fill=(235, 232, 225))
            d.rectangle((wx + 3, wy + 3, wx + ww - 3, wy + wh - 3), fill=glass)
            if random.random() < 0.25:                                           # балкон с бельём
                d.rectangle((wx - 4, wy + wh, wx + ww + 4, wy + wh + 14), fill=shade)
                for k in range(3):
                    lx = wx + 6 + k * ww / 3
                    d.rectangle((lx, wy + wh - 18, lx + ww / 5, wy + wh),
                                fill=random.choice([(220, 60, 60), (240, 240, 235), (70, 110, 200)]))
    # Антенны на крыше.
    for ax in range(int(x0 + 30), int(x0 + w - 20), 90):
        d.line((ax, y0 - 10, ax, y0 - 70), fill=(80, 80, 85), width=4)
        d.line((ax - 22, y0 - 55, ax + 22, y0 - 55), fill=(80, 80, 85), width=3)
        d.line((ax - 15, y0 - 42, ax + 15, y0 - 42), fill=(80, 80, 85), width=3)


building(-40, 600, 620, 900, (205, 196, 175), 6, 5)
building(640, 520, 820, 980, (190, 185, 172), 7, 6, lit=0.2)
building(560, 760, 200, 740, (215, 205, 185), 4, 2)
# Тополя на переднем плане (верхушки).
for x in range(-40, W + 80, 150):
    h = random.randint(260, 420)
    color = random.choice([(70, 125, 55), (85, 140, 60), (60, 110, 50)])
    for k in range(5):
        r = random.randint(80, 120)
        cx = x + random.randint(-40, 40)
        cy = H - h + k * 70
        d.ellipse((cx - r, cy - r * 1.2, cx + r, cy + r * 1.2), fill=color)
        d.ellipse((cx - r * 0.6, cy - r * 1.0, cx + r * 0.2, cy - r * 0.2),
                  fill=tuple(min(255, c + 25) for c in color))
img = img.filter(ImageFilter.SMOOTH)
img.save(OUT)
print("DONE")
