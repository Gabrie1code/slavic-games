"""Этикетки банок с заготовками — спереди банки, одна крупная понятная картинка в рамке:
  jar_label_pickles.png — один огурец;  jar_label_jam.png — одна вишня (ягода с хвостиком
  и листиком). Пропорция картинки 9 : 4 — как у этикетки на банке (дуга 150°, высота 12 см).
Запуск: python3 tools/textures/jar_labels.py  →  assets/textures/apartment/
"""
import math
import os
from PIL import Image, ImageDraw

OUT = "assets/textures/apartment/"
os.makedirs(OUT, exist_ok=True)
W, H = 576, 256
PAPER = (240, 230, 198)


def base(color):
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((16, 16, W - 16, H - 16), 22, outline=color, width=9)
    return img, d


img, d = base((60, 120, 50))                                          # огурец
cx, cy, half, r = W / 2, H / 2, 150, 46
ang = -0.18
dx, dy = math.cos(ang) * half, math.sin(ang) * half
d.line((cx - dx, cy - dy, cx + dx, cy + dy), fill=(55, 120, 45), width=r * 2)
for t in (-1, 1):
    d.ellipse((cx + t * dx - r, cy + t * dy - r, cx + t * dx + r, cy + t * dy + r), fill=(55, 120, 45))
d.line((cx - dx * 0.9, cy - dy * 0.9 - 18, cx + dx * 0.9, cy + dy * 0.9 - 18), fill=(110, 170, 80), width=10)
for k in range(-4, 5):                                                # пупырышки
    px, py = cx + dx * k / 5, cy + dy * k / 5
    d.ellipse((px - 6, py + 8, px + 6, py + 20), fill=(30, 85, 30))
d.rectangle((cx + dx + r - 6, cy + dy - 8, cx + dx + r + 14, cy + dy + 8), fill=(120, 150, 60))  # хвостик
img.save(OUT + "jar_label_pickles.png")

img, d = base((150, 25, 35))                                          # вишня
d.line((W / 2, 150, W / 2 + 40, 50), fill=(90, 60, 25), width=9)
d.polygon([(W / 2 + 40, 50), (W / 2 + 130, 34), (W / 2 + 85, 80)], fill=(70, 140, 50))
d.ellipse((W / 2 - 62, 112, W / 2 + 62, 236 - 8), fill=(175, 20, 32))
d.ellipse((W / 2 - 35, 132, W / 2 - 8, 160), fill=(240, 130, 130))
img.save(OUT + "jar_label_jam.png")
print("saved labels")
