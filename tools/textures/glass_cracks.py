"""Трещины разбитого стекла (для экрана игрового автомата после удара молотком): белые
ломаные лучи от точки удара и кольца-«паутинка», прозрачный фон.

Запуск (Python с Pillow):
    python3 tools/textures/glass_cracks.py assets/textures/fx
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
random.seed(4)
S = 512
img = Image.new("RGBA", (S, S), (255, 255, 255, 0))
d = ImageDraw.Draw(img)
cx, cy = S * 0.46, S * 0.42
rays = []
for i in range(14):
    a = i / 14 * math.tau + random.uniform(-0.15, 0.15)
    pts = [(cx, cy)]
    r = 0
    while r < S:
        r += random.uniform(25, 60)
        a += random.uniform(-0.25, 0.25)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    rays.append(pts)
    d.line(pts, fill=(235, 245, 255, 230), width=3)
for ring_r in (45, 95, 160):                           # «паутинка» между лучами
    for k in range(len(rays)):
        p1 = min(rays[k], key=lambda p: abs(math.dist(p, (cx, cy)) - ring_r))
        p2 = min(rays[(k + 1) % len(rays)], key=lambda p: abs(math.dist(p, (cx, cy)) - ring_r))
        if random.random() < 0.8:
            d.line([p1, p2], fill=(235, 245, 255, 190), width=2)
d.ellipse((cx - 14, cy - 14, cx + 14, cy + 14), fill=(255, 255, 255, 200))   # место удара
glow = img.filter(ImageFilter.GaussianBlur(2))
img = Image.alpha_composite(glow, img)
img.save(os.path.join(OUT, "glass_cracks.png"))
print("DONE")
