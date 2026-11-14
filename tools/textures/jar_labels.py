"""Этикетки банок с заготовками (оборачиваются вокруг банки, рисунок повторён дважды — виден
с любой стороны): кремовая бумага, рамка, нарисованный овощ/ягода.
  jar_label_pickles.png — огурцы с укропом;  jar_label_jam.png — вишни.
Запуск: python3 tools/textures/jar_labels.py  →  assets/textures/apartment/
"""
import os
from PIL import Image, ImageDraw

OUT = "assets/textures/apartment/"
os.makedirs(OUT, exist_ok=True)
W, H = 1024, 256
PAPER = (238, 228, 196)


def frame(d, x0, color):
    d.rounded_rectangle((x0 + 30, 22, x0 + 482, 234), 18, outline=color, width=8)


def cucumber(d, cx, cy, ang):
    import math
    dx, dy = math.cos(ang) * 80, math.sin(ang) * 80
    d.line((cx - dx, cy - dy, cx + dx, cy + dy), fill=(50, 110, 40), width=46)
    for t in (-1, 1):
        d.ellipse((cx + t * dx - 23, cy + t * dy - 23, cx + t * dx + 23, cy + t * dy + 23), fill=(50, 110, 40))
    for k in range(-3, 4):
        px, py = cx + dx * k / 4, cy + dy * k / 4
        d.ellipse((px - 4, py - 10, px + 4, py - 2), fill=(150, 200, 110))


def pickles(d, x0):
    frame(d, x0, (60, 120, 50))
    cucumber(d, x0 + 200, 128, -0.35)
    cucumber(d, x0 + 300, 140, 0.4)
    for k in range(6):                                                 # укроп
        x = x0 + 390 + k * 9
        d.line((x0 + 410, 200, x, 70 + k * 6), fill=(80, 150, 60), width=3)


def cherry(d, cx, cy):
    d.ellipse((cx - 34, cy - 34, cx + 34, cy + 34), fill=(170, 20, 30))
    d.ellipse((cx - 18, cy - 22, cx - 6, cy - 10), fill=(235, 120, 120))


def jam(d, x0):
    frame(d, x0, (150, 25, 35))
    d.line((x0 + 210, 160, x0 + 250, 60, x0 + 300, 165), fill=(90, 60, 25), width=7)
    d.polygon([(x0 + 250, 60), (x0 + 330, 40), (x0 + 290, 85)], fill=(70, 140, 50))      # листик
    cherry(d, x0 + 205, 170)
    cherry(d, x0 + 302, 172)


for name, draw in (("pickles", pickles), ("jam", jam)):
    # Половина этикетки на банке в 1.35 раза шире картинки — рисуем половину, сжимаем по ширине
    # (иначе рисунок растягивался вширь) и ставим два раза на бумагу.
    half = Image.new("RGB", (512, H), PAPER)
    draw(ImageDraw.Draw(half), 0)
    half = half.resize((380, H), Image.LANCZOS)
    img = Image.new("RGB", (W, H), PAPER)
    for x0 in (66, 578):
        img.paste(half, (x0, 0))
    img.save(OUT + "jar_label_%s.png" % name)
    print("saved", name)
