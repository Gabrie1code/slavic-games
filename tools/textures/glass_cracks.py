"""Трещины разбитого стекла (экран игрового автомата после удара молотком): тонкие приглушённые
лучи от точки удара и кольца-«паутинка», прозрачный фон. Три разных варианта — в игре случайный.
Все три — в одном стиле (понравился первый): лучи от точки удара и паутинка колец вокруг.
  glass_cracks_1.png — удар чуть левее центра, 14 лучей, три кольца паутинки;
  glass_cracks_2.png — удар правее и выше центра, 12 лучей, кольца пошире;
  glass_cracks_3.png — удар ниже и левее центра, 16 лучей, паутинка погуще у центра.

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
S = 512
LINE = (200, 215, 225)          # приглушённый серо-голубой (было почти белое и яркое)


def cracks(name, seed, center, rays_n, rings, alpha, extra):
    random.seed(seed)
    img = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    cx, cy = center[0] * S, center[1] * S
    rays = []
    for i in range(rays_n):
        a = i / rays_n * math.tau + random.uniform(-0.2, 0.2)
        pts = [(cx, cy)]
        r = 0
        while r < S * 1.3:
            r += random.uniform(25, 65)
            a += random.uniform(-0.25, 0.25)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        rays.append(pts)
        d.line(pts, fill=LINE + (alpha,), width=2)
    for ring_r in rings:
        for k in range(len(rays)):
            p1 = min(rays[k], key=lambda p: abs(math.dist(p, (cx, cy)) - ring_r))
            p2 = min(rays[(k + 1) % len(rays)], key=lambda p: abs(math.dist(p, (cx, cy)) - ring_r))
            if random.random() < 0.75:
                d.line([p1, p2], fill=LINE + (int(alpha * 0.75),), width=1)
    for _ in range(extra):                                # отдельные трещины в стороне
        x, y = random.uniform(0, S), random.uniform(0, S)
        a = random.uniform(0, math.tau)
        pts = [(x, y)]
        for _ in range(5):
            a += random.uniform(-0.4, 0.4)
            x += math.cos(a) * 40
            y += math.sin(a) * 40
            pts.append((x, y))
        d.line(pts, fill=LINE + (int(alpha * 0.8),), width=1)
    d.ellipse((cx - 9, cy - 9, cx + 9, cy + 9), fill=LINE + (alpha,))  # место удара
    glow = img.filter(ImageFilter.GaussianBlur(1.5))
    img = Image.alpha_composite(glow, img)
    img.save(os.path.join(OUT, name + ".png"))


cracks("glass_cracks_1", 4, (0.46, 0.42), 14, (45, 95, 160), 150, 0)
cracks("glass_cracks_2", 23, (0.6, 0.36), 12, (55, 115, 190), 150, 0)
cracks("glass_cracks_3", 31, (0.38, 0.56), 16, (35, 75, 130), 150, 0)
print("DONE")
