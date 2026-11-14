"""Этикетки банок с заготовками — спереди банки, одна крупная понятная картинка в рамке:
  jar_label_pickles.png — один огурец;  jar_label_jam.png — две вишни на веточке с листиком. Пропорция картинки 9 : 4 — как у этикетки на банке (дуга 150°, высота 12 см).
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

img, d = base((150, 25, 35))                                          # две вишни на веточке
cx = W / 2
top = (cx + 6, 52)                                                    # где сходятся хвостики
d.line((cx - 52, 136, top[0], top[1]), fill=(90, 60, 25), width=8)
d.line((cx + 58, 140, top[0], top[1]), fill=(90, 60, 25), width=8)
d.polygon([(top[0], top[1]), (top[0] + 70, top[1] - 14), (top[0] + 92, top[1] + 4),
           (top[0] + 46, top[1] + 26)], fill=(70, 140, 50))           # листик целиком внутри рамки
d.line((top[0] + 4, top[1] + 4, top[0] + 80, top[1] - 4), fill=(45, 105, 35), width=3)
for bx, by in ((cx - 52, 168), (cx + 58, 172)):
    d.ellipse((bx - 38, by - 38, bx + 38, by + 38), fill=(175, 20, 32))
    d.ellipse((bx - 22, by - 26, bx - 5, by - 9), fill=(240, 130, 130))
img.save(OUT + "jar_label_jam.png")
print("saved labels")
