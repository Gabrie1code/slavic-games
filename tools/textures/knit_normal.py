"""Карта нормалей «вязка» (как у вязаной игрушки): ряды петель-«ёлочек» V. Без цвета — только
рельеф: в игре свет ложится по петлям. Петли вписаны в картинку целиком, она повторяется по кругу
(для UV шаров: u — вокруг, v — сверху вниз).

Запуск (Python 3 + numpy + Pillow):
    python3 tools/textures/knit_normal.py assets/textures/knit_normal.png
"""
import sys

import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "knit_normal.png"
W, H = 1024, 512
COLS, ROWS = 56, 28                       # петель по кругу и сверху вниз
y, x = np.mgrid[0:H, 0:W].astype(np.float32)
cw, ch = W / COLS, H / ROWS
u = (x % cw) / cw - 0.5                   # −0.5..0.5 внутри петли
v = (y % ch) / ch
# Петля — две наклонные «капли» (левая и правая половинки V).
height = np.zeros((H, W), np.float32)
for side in (-1, 1):
    cx = side * 0.22
    du = (u - cx) - side * 0.18 * (v - 0.5)          # наклон половинки
    dv = v - 0.5
    height += np.exp(-((du / 0.2) ** 2 + (dv / 0.42) ** 2))
height = height / height.max()
gy, gx = np.gradient(height)
strength = 6.0
n = np.dstack((-gx * strength, -gy * strength, np.ones_like(height)))
n /= np.linalg.norm(n, axis=2, keepdims=True)
img = ((n * 0.5 + 0.5) * 255).astype(np.uint8)
Image.fromarray(img, "RGB").save(OUT)
print("DONE")
