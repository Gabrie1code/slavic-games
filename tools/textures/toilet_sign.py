"""Табличка над дверью туалета: синяя жестяная пластинка, белая рамка со срезанными углами,
белые человечки (женщина и мужчина) через черту и надпись «ТУАЛЕТ», лёгкие потёртости.

Запуск (Python с Pillow):
    python3 tools/textures/toilet_sign.py assets/textures/toilet/sign.png
"""
import random
import sys

from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "sign.png"
W, H = 300, 400
BLUE = (22, 92, 122)
WHITE = (240, 240, 235)
random.seed(4)
img = Image.new("RGB", (W, H), BLUE)
d = ImageDraw.Draw(img)
# Рамка со «срезанными» углами.
m, c = 18, 26
pts = [(m + c, m), (W - m - c, m), (W - m, m + c), (W - m, H - m - c), (W - m - c, H - m),
       (m + c, H - m), (m, H - m - c), (m, m + c)]
d.line(pts + [pts[0]], fill=WHITE, width=6, joint="curve")
for x, y in ((10, 10), (W - 10, 10), (10, H - 10), (W - 10, H - 10)):            # заклёпки
    d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=(15, 60, 80))
d.line((W / 2, 70, W / 2, 260), fill=WHITE, width=5)                              # черта


def person(cx, dress):
    d.ellipse((cx - 17, 62, cx + 17, 96), fill=WHITE)                            # голова
    if dress:
        d.polygon([(cx - 22, 104), (cx + 22, 104), (cx + 40, 200), (cx - 40, 200)], fill=WHITE)
        for lx in (-12, 6):
            d.rectangle((cx + lx, 200, cx + lx + 9, 252), fill=WHITE)
    else:
        d.rounded_rectangle((cx - 25, 104, cx + 25, 190), radius=8, fill=WHITE)
        for lx in (-23, 3):
            d.rectangle((cx + lx, 186, cx + lx + 20, 254), fill=WHITE)
    for s in (-1, 1):                                                             # руки
        x0 = cx + s * (26 if not dress else 22)
        d.line((x0, 110, x0 + s * 14, 176), fill=WHITE, width=11)


person(W / 2 - 62, True)
person(W / 2 + 62, False)
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 52)
d.text((W / 2, 318), "ТУАЛЕТ", font=font, fill=WHITE, anchor="mm")
for _ in range(220):                                                              # потёртости
    x, y = random.randrange(W), random.randrange(H)
    d.point((x, y), fill=(60, 120, 150))
img.save(OUT)
print("DONE")
