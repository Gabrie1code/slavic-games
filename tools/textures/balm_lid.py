"""Крышка баночки бальзама «Звёздочка» (пародия, без настоящей марки): красный ободок с
золотой надписью по кругу, золотое кольцо, светло-зелёный круг с лучиками, тёмно-зелёный
круг и золотая звезда, внизу красная ленточка «ОТ ВСЕГО».
Запуск: python3 tools/textures/balm_lid.py  →  assets/textures/kitchen/balm_lid.png
"""
import math
from PIL import Image, ImageDraw, ImageFont

S = 512
C = S / 2
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
RED = (196, 22, 30)
GOLD = (232, 190, 60)
GREEN_L = (196, 226, 190)
GREEN = (30, 120, 70)
img = Image.new("RGB", (S, S), RED)
d = ImageDraw.Draw(img)


def ring(r, fill):
    d.ellipse((C - r, C - r, C + r, C + r), fill=fill)


ring(C, RED)
ring(C * 0.80, GOLD)
ring(C * 0.76, GREEN_L)
for k in range(120):                                                 # лучики
    a = k * math.tau / 120
    d.line((C + math.cos(a) * C * 0.47, C + math.sin(a) * C * 0.47,
            C + math.cos(a) * C * 0.74, C + math.sin(a) * C * 0.74), fill=(120, 180, 130), width=2)
ring(C * 0.47, GREEN)
pts = []
for k in range(10):                                                  # звезда
    a = -math.pi / 2 + k * math.pi / 5
    r = C * (0.42 if k % 2 == 0 else 0.17)
    pts.append((C + math.cos(a) * r, C + 6 + math.sin(a) * r))
d.polygon(pts, fill=GOLD)
# Надпись по кругу сверху: каждая буква повёрнута по касательной.
font = ImageFont.truetype(BOLD, 40)
text = "БАЛЬЗАМ · ЗВЁЗДОЧКА"
span = math.radians(200)
for i, ch in enumerate(text):
    a = -math.pi / 2 - span / 2 + span * (i + 0.5) / len(text)
    tile = Image.new("RGBA", (60, 60), (0, 0, 0, 0))
    ImageDraw.Draw(tile).text((30, 30), ch, font=font, fill=GOLD, anchor="mm")
    tile = tile.rotate(-math.degrees(a) - 90, resample=Image.BICUBIC)
    x, y = C + math.cos(a) * C * 0.895, C + math.sin(a) * C * 0.895
    img.paste(tile, (int(x - 30), int(y - 30)), tile)
# Ленточка снизу.
d.rounded_rectangle((C - 150, C + 150, C + 150, C + 205), radius=16, fill=RED, outline=GOLD, width=5)
d.text((C, C + 178), "ОТ ВСЕГО", font=ImageFont.truetype(BOLD, 34), fill=(250, 240, 220), anchor="mm")
img.save("assets/textures/kitchen/balm_lid.png")
print("saved balm_lid.png")
