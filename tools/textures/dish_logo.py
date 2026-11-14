"""Лицо спутниковой тарелки (пародия, без настоящей марки): светло-серая чаша с лёгким
затенением к краю, синяя и красная волны и надпись «ДВУКОЛОР».
Запуск: python3 tools/textures/dish_logo.py  →  assets/textures/city/dish_logo.png
"""
import math
from PIL import Image, ImageDraw, ImageFont

S = 512
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
img = Image.new("RGB", (S, S), (236, 237, 238))
d = ImageDraw.Draw(img)
for r in range(S // 2, 0, -2):                                         # чаша светлее к центру
    k = r / (S / 2)
    c = int(242 - 30 * k * k)
    d.ellipse((S / 2 - r, S / 2 - r, S / 2 + r, S / 2 + r), fill=(c, c, c + 2))
BLUE, RED = (30, 70, 165), (215, 35, 35)


def wave(y0, amp, color, thick):
    pts = [(x, y0 + amp * math.sin((x - 90) / 330 * math.pi)) for x in range(90, 425, 6)]
    upper = pts
    lower = [(x, y + thick * (0.4 + 0.6 * math.sin((x - 90) / 335 * math.pi))) for x, y in reversed(pts)]
    d.polygon(upper + lower, fill=color)


wave(170, -55, BLUE, 52)
wave(250, -45, RED, 40)
font = ImageFont.truetype(BOLD, 62)
d.text((S / 2, 362), "ДВУКОЛОР", font=font, fill=BLUE, anchor="mm")
img.save("assets/textures/city/dish_logo.png")
print("saved dish_logo.png")
