"""Текстуры казино: сукно стола рулетки и колесо.

Разметка сукна в долях (u — по длине стола, v — по ширине) совпадает с Roulette.layout_*
в scripts/core/roulette.gd — по ней на сукно ставятся фишки.

Запуск (обычный Python с Pillow):
    python3 tools/textures/casino_textures.py assets/textures/casino
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

RED_NUMBERS = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}
WHEEL = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20,
         14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]

FELT = (24, 96, 52)
FELT_DARK = (21, 86, 47)
GOLD = (214, 172, 82)
RED = (178, 28, 24)
BLACK = (22, 22, 24)
GREEN = (30, 140, 60)
WHITE = (240, 236, 222)

# Разметка (доли): зеро, сетка 12×3, нижний ряд из 4 «внешних» ставок.
ZERO_U = (0.03, 0.10)
GRID_U = (0.10, 0.94)
GRID_V = (0.05, 0.70)
OUT_V = (0.74, 0.95)


def felt():
    w, h = 2400, 1000
    img = Image.new("RGB", (w, h), FELT)
    d = ImageDraw.Draw(img)
    num_font = ImageFont.truetype(FONT, 54)
    word_font = ImageFont.truetype(FONT, 50)
    # потёртости сукна — пятна чуть темнее
    for i in range(160):
        x, y = (i * 733) % w, (i * 397) % h
        r = 30 + (i * 13) % 50
        d.ellipse((x - r, y - r, x + r, y + r), fill=FELT_DARK if i % 3 == 0 else FELT)
    px = lambda u: int(u * w)
    py = lambda v: int(v * h)
    line = dict(outline=GOLD, width=6)
    # Зеро
    d.rectangle((px(ZERO_U[0]), py(GRID_V[0]), px(ZERO_U[1]), py(GRID_V[1])), fill=FELT, **line)
    cx, cy = px(sum(ZERO_U) / 2), py(sum(GRID_V) / 2)
    d.ellipse((cx - 55, cy - 80, cx + 55, cy + 80), fill=GREEN, outline=GOLD, width=4)
    d.text((cx, cy), "0", font=num_font, fill=WHITE, anchor="mm")
    # Числа
    cw = (GRID_U[1] - GRID_U[0]) / 12
    rh = (GRID_V[1] - GRID_V[0]) / 3
    for n in range(1, 37):
        col, row = (n - 1) // 3, 2 - (n - 1) % 3
        u0, v0 = GRID_U[0] + col * cw, GRID_V[0] + row * rh
        d.rectangle((px(u0), py(v0), px(u0 + cw), py(v0 + rh)), **line)
        cx, cy = px(u0 + cw / 2), py(v0 + rh / 2)
        color = RED if n in RED_NUMBERS else BLACK
        d.ellipse((cx - 62, cy - 78, cx + 62, cy + 78), fill=color)
        d.text((cx, cy), str(n), font=num_font, fill=WHITE, anchor="mm")
    # Нижний ряд: ЧЁТ, КРАСНОЕ, ЧЁРНОЕ, НЕЧЁТ
    ow = (GRID_U[1] - GRID_U[0]) / 4
    for i, (text, fill) in enumerate([("ЧЁТ", None), ("", RED), ("", BLACK), ("НЕЧЁТ", None)]):
        u0 = GRID_U[0] + i * ow
        d.rectangle((px(u0), py(OUT_V[0]), px(u0 + ow), py(OUT_V[1])), **line)
        cx, cy = px(u0 + ow / 2), py(sum(OUT_V) / 2)
        if fill:
            s = 70
            d.polygon([(cx - 2 * s, cy), (cx, cy - s), (cx + 2 * s, cy), (cx, cy + s)], fill=fill,
                      outline=GOLD)
        else:
            d.text((cx, cy), text, font=word_font, fill=WHITE, anchor="mm")
    img.save(os.path.join(OUT, "felt.png"))


def wheel():
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size / 2
    num_font = ImageFont.truetype(FONT, 34)
    d.ellipse((0, 0, size, size), fill=(92, 52, 24, 255))                     # деревянный обод
    r_out, r_in = c * 0.93, c * 0.66
    step = 360 / 37
    for i, n in enumerate(WHEEL):
        # 0° — вверх, по часовой стрелке (как в roulette.gd: pocket_angle).
        a0, a1 = -90 + (i - 0.5) * step, -90 + (i + 0.5) * step
        color = GREEN if n == 0 else (RED if n in RED_NUMBERS else BLACK)
        d.pieslice((c - r_out, c - r_out, c + r_out, c + r_out), a0, a1, fill=color + (255,),
                   outline=GOLD + (255,), width=3)
    d.ellipse((c - r_in, c - r_in, c + r_in, c + r_in), fill=(150, 30, 26, 255), outline=GOLD + (255,),
              width=6)
    for i in range(8):                                                        # «спицы» конуса
        a = math.radians(i * 45)
        d.line((c, c, c + math.cos(a) * r_in, c + math.sin(a) * r_in), fill=(120, 22, 20, 255), width=8)
    d.ellipse((c - 70, c - 70, c + 70, c + 70), fill=GOLD + (255,))
    # Числа — каждое повернуть по радиусу.
    for i, n in enumerate(WHEEL):
        ang = i * step
        txt = Image.new("RGBA", (80, 50), (0, 0, 0, 0))
        ImageDraw.Draw(txt).text((40, 25), str(n), font=num_font, fill=WHITE + (255,), anchor="mm")
        txt = txt.rotate(-ang, expand=True, resample=Image.BICUBIC)
        rad = math.radians(ang - 90)
        x = c + math.cos(rad) * (r_out - 34) - txt.width / 2
        y = c + math.sin(rad) * (r_out - 34) - txt.height / 2
        img.alpha_composite(txt, (int(x), int(y)))
    img.save(os.path.join(OUT, "wheel.png"))


felt()
wheel()
print("DONE")
