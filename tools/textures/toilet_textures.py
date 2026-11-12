"""Плитка для туалета: мелкая советская «шахматка» (белая и голубая) на пол.

Запуск (Python с Pillow):
    python3 tools/textures/toilet_textures.py assets/textures/toilet
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/textures/toilet"
os.makedirs(OUT, exist_ok=True)
random.seed(3)
S, N = 512, 8                      # 8×8 плиток на текстуру (в игре — 1 м, плитка 12.5 см)
cell = S // N
img = Image.new("RGB", (S, S), (120, 128, 130))
d = ImageDraw.Draw(img)
for i in range(N):
    for j in range(N):
        tone = random.randint(-8, 6)
        base = (226, 228, 222) if (i + j) % 2 == 0 else (130, 175, 196)
        color = tuple(max(0, min(255, c + tone)) for c in base)
        d.rectangle((i * cell + 2, j * cell + 2, (i + 1) * cell - 3, (j + 1) * cell - 3), fill=color)
        # Блик в углу плитки — эмаль.
        d.line((i * cell + 6, j * cell + 6, i * cell + 22, j * cell + 6), fill=(245, 248, 248), width=2)
d.rectangle((3 * cell + 2, 5 * cell + 2, 4 * cell - 3, 6 * cell - 3), fill=(200, 196, 180))  # одна старая
for _ in range(3):
    x, y = random.randrange(S), random.randrange(S)
    d.line((x, y, x + random.randint(-20, 20), y + random.randint(10, 30)), fill=(95, 100, 102), width=1)
img = img.filter(ImageFilter.GaussianBlur(0.4))
img.save(os.path.join(OUT, "floor_tiles.png"))
print("DONE")
