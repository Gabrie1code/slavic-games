"""Облака для неба вокруг дворов (прозрачный фон, мягкие края, низ чуть серее — как тень):
  cloud_cumulus_a.png — большое кучевое «барашком»;
  cloud_cumulus_b.png — кучевое пониже и пошире, из нескольких шапок;
  cloud_cirrus.png    — перистые полосы-«хвосты» (высоко);
  cloud_stratus.png   — длинное слоистое облако-пелена;
  cloud_tower.png     — высокое грозовое облако-«башня» с плоской вершиной;
  smoke_puff.png      — клуб дыма из трубы ТЭЦ (серо-белый, мягкий; в игре растёт и тает).
Запуск (Python с Pillow):
    python3 tools/textures/sky_clouds.py assets/textures/sky
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)


def blobs(w, h, items, blur, shade=True):
    """items: (cx, cy, rx, ry). Белые эллипсы, снизу — серая тень, края размыты."""
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    for cx, cy, rx, ry in items:
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(255, 255, 255, 235))
    if shade:                                                         # серый низ
        px = img.load()
        top = min(cy - ry for cx, cy, rx, ry in items)
        bottom = max(cy + ry for cx, cy, rx, ry in items)
        for y in range(h):
            k = max(0.0, (y - top) / max(1.0, bottom - top) - 0.45) / 0.55
            g = int(255 - 60 * k)
            for x in range(w):
                r_, g_, b_, a = px[x, y]
                if a:
                    px[x, y] = (g, g, min(255, g + 12), a)
    return img.filter(ImageFilter.GaussianBlur(blur))


def save(img, name):
    img.save(os.path.join(OUT, name + ".png"))
    print("SAVED", name)


random.seed(5)
# Кучевое «барашком»: купол из крупных шапок и плоское дно.
items = []
for k in range(9):
    a = math.pi * (k + 0.5) / 9
    items.append((256 + math.cos(a) * 150, 170 - math.sin(a) * 70, random.uniform(55, 80), random.uniform(50, 70)))
items += [(256, 120, 110, 80), (200, 175, 120, 40), (320, 178, 120, 38)]
save(blobs(512, 256, items, 6), "cloud_cumulus_a")

random.seed(6)
items = [(110 + k * 75 + random.uniform(-15, 15), 150 + random.uniform(-25, 10), random.uniform(45, 70),
          random.uniform(35, 55)) for k in range(5)]
items += [(256, 175, 220, 32)]
save(blobs(512, 256, items, 6), "cloud_cumulus_b")

random.seed(7)
img = Image.new("RGBA", (512, 256), (255, 255, 255, 0))
d = ImageDraw.Draw(img)
for k in range(7):                                                    # перистые «хвосты»
    y0 = random.uniform(40, 210)
    x0 = random.uniform(20, 160)
    length = random.uniform(220, 330)
    for i in range(40):
        t = i / 39
        x = x0 + length * t
        y = y0 - 30 * t * t + math.sin(t * 6 + k) * 4
        r = 10 * (1 - t) + 2
        d.ellipse((x - r * 2.5, y - r, x + r * 2.5, y + r), fill=(255, 255, 255, int(150 * (1 - t * 0.7))))
save(img.filter(ImageFilter.GaussianBlur(4)), "cloud_cirrus")

random.seed(8)
items = [(40 + k * 48, 130 + random.uniform(-10, 10), random.uniform(50, 70), random.uniform(22, 32))
         for k in range(10)]
save(blobs(512, 256, items, 9), "cloud_stratus")

random.seed(9)
items = [(256 + random.uniform(-30, 30), 360 - k * 48, 120 - k * 8, 62) for k in range(6)]  # столб
items += [(256 + k * 60 - 150, 85 + random.uniform(-8, 8), 70, 30) for k in range(6)]      # наковальня
for k in range(5):                                                                      # шапки у основания
    items.append((256 + (k - 2) * 55, 385 + random.uniform(-10, 5), 60, 40))
save(blobs(512, 448, items, 7), "cloud_tower")

random.seed(10)
items = [(128 + random.uniform(-45, 45), 128 + random.uniform(-40, 40), random.uniform(38, 60),
          random.uniform(34, 52)) for _ in range(9)]
img = blobs(256, 256, items, 10)
px = img.load()
for y in range(256):                                                  # дым серее облаков
    for x in range(256):
        r, g, b, a = px[x, y]
        px[x, y] = (int(r * 0.88), int(g * 0.88), int(b * 0.9), int(a * 0.9))
save(img, "smoke_puff")
