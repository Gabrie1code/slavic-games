"""Экран телевизора в лобби: фон кинескопа (свечение, полосы развёртки, виньетка) и кнопка
«▶ ИГРАТЬ». В игре кнопка слегка «дышит» и подрагивает, по экрану бежит светлая полоса.

Запуск (Python с Pillow):
    python3 tools/textures/tv_screen.py assets/textures/tv
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 70)

# Фон: тёмно-бирюзовое свечение к центру, полосы развёртки, тёмные края.
W, H = 540, 440
bg = Image.new("RGB", (W, H), (8, 20, 22))
glow = Image.new("L", (W, H), 0)
ImageDraw.Draw(glow).ellipse((-60, -60, W + 60, H + 60), fill=255)
glow = glow.filter(ImageFilter.GaussianBlur(90))
bg = Image.composite(Image.new("RGB", (W, H), (30, 85, 80)), bg, glow)
d = ImageDraw.Draw(bg)
for y in range(0, H, 4):
    d.line((0, y, W, y), fill=(0, 0, 0), width=1)
bg = bg.filter(ImageFilter.GaussianBlur(0.6))
bg.save(os.path.join(OUT, "tv_screen_bg.png"))

# Кнопка: зелёная плашка с обводкой, треугольник и надпись, мягкое свечение вокруг.
BW, BH = 520, 200
btn = Image.new("RGBA", (BW, BH), (0, 0, 0, 0))
halo = Image.new("RGBA", (BW, BH), (0, 0, 0, 0))
ImageDraw.Draw(halo).rounded_rectangle((20, 20, BW - 20, BH - 20), radius=60, fill=(120, 255, 170, 160))
btn.alpha_composite(halo.filter(ImageFilter.GaussianBlur(14)))
d = ImageDraw.Draw(btn)
d.rounded_rectangle((34, 34, BW - 34, BH - 34), radius=48, fill=(40, 150, 75, 255), outline=(220, 255, 225, 255),
                    width=7)
d.polygon([(78, 75), (78, 125), (120, 100)], fill=(240, 255, 240, 255))
d.text((BW / 2 + 30, BH / 2 + 2), "ИГРАТЬ", font=FONT, fill=(240, 255, 240, 255), anchor="mm")
btn.save(os.path.join(OUT, "tv_play_button.png"))
print("DONE")
