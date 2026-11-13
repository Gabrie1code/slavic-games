"""Облака для неба за окном (прозрачный фон, повторяется по горизонтали без шва).
Вверху картинки облака крупнее, к горизонту (низ) — мельче и плоше, как в перспективе.
Цвет облаков меняется в игре по времени суток (window_sky.gdshader), здесь они белые.

Запуск (Python с Pillow):
    python3 tools/textures/window_clouds.py assets/textures/window
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
random.seed(11)
W, H = 2048, 512
img = Image.new("RGBA", (W, H), (255, 255, 255, 0))
d = ImageDraw.Draw(img)


def puff(cx, cy, s, flat):
    for k in range(random.randint(5, 9)):
        r = random.uniform(30, 60) * s
        x = cx + (k - 4) * 34 * s + random.uniform(-10, 10) * s
        y = cy + random.uniform(-14, 6) * s
        for dx in (-W, 0, W):  # рисуем и за краями — картинка без шва
            d.ellipse((x + dx - r, y - r * flat, x + dx + r, y + r * flat), fill=(255, 255, 255, 230))


for _ in range(26):
    cy = random.uniform(40, H - 40)
    depth = cy / H                       # 0 — высоко, 1 — у горизонта
    s = 1.3 - depth * 0.85
    puff(random.uniform(0, W), cy, s, 0.75 - depth * 0.35)
img = img.filter(ImageFilter.GaussianBlur(5))
img.save(os.path.join(OUT, "window_clouds.png"))
print("DONE")
