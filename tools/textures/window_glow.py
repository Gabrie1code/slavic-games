"""Светящиеся окна домов напротив (ночь за окном гостиной): атлас 4 узора 128×128 в ряд —
assets/textures/window/window_glow.png. Тёплый оранжево-жёлтый свет как на фото вечерней
деревни: середина светлее (жёлтая), к краям — гуще оранжевый; тёмный переплёт — вертикальная
рама посередине и форточка сверху.
  0 — просто свет; 1 — шторы по бокам; 2 — тюль с узором; 3 — горшки с цветами на подоконнике.
Запуск: python3 tools/textures/window_glow.py
"""
import math
import random
from PIL import Image, ImageDraw, ImageFilter

T = 128
FRAME = (52, 30, 18)
OUT = "assets/textures/window/window_glow.png"


def glow(x, y):
    """Свет: от жёлтого в центре к густо-оранжевому по краям."""
    dx, dy = (x - T / 2) / (T / 2), (y - T * 0.45) / (T / 2)
    d = min(1.0, math.hypot(dx * 0.9, dy))
    c0, c1 = (255, 214, 120), (232, 112, 30)
    return tuple(int(a + (b - a) * d ** 1.4) for a, b in zip(c0, c1))


def base():
    img = Image.new("RGB", (T, T))
    px = img.load()
    for y in range(T):
        for x in range(T):
            px[x, y] = glow(x, y)
    return img


def frame(img):
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, T - 1, T - 1], outline=FRAME, width=4)               # рама по краю
    d.rectangle([T // 2 - 3, 0, T // 2 + 2, T], fill=FRAME)                 # средняя стойка
    d.rectangle([0, 34, T, 38], fill=FRAME)                                 # форточки сверху
    return img


def curtains(img):
    px = img.load()
    for y in range(T):
        w = int(26 - 8 * y / T)                     # шторы внизу подхвачены — чуть уже
        for i in range(w):
            fold = 0.72 + 0.28 * math.sin(i * 0.8)
            col = (int(178 * fold), int(58 * fold), int(24 * fold))
            px[i, y] = col
            px[T - 1 - i, y] = col
    return img


def tulle(img):
    px = img.load()
    for y in range(T):
        for x in range(T):
            if (x // 4 + y // 4) % 2 == 0 and (x * 7 + y * 3) % 11 < 6:
                r, g, b = px[x, y]
                px[x, y] = (min(255, r + 18), min(255, g + 22), min(255, b + 18))
    return img.filter(ImageFilter.GaussianBlur(0.6))


def plants(img):
    d = ImageDraw.Draw(img)
    dark = (70, 30, 12)
    for cx, h in ((26, 34), (70, 22), (100, 28)):
        d.rectangle([cx - 8, T - 16, cx + 8, T - 4], fill=dark)                # горшок
        for k in range(6):                                                   # листья
            a = math.radians(-150 + k * 24)
            d.line([(cx, T - 16), (cx + math.cos(a) * h * 0.6, T - 16 + math.sin(a) * h)],
                   fill=dark, width=3)
    return img


random.seed(5)
atlas = Image.new("RGB", (T * 4, T))
for k, extra in enumerate([None, curtains, tulle, plants]):
    tile = base()
    if extra:
        tile = extra(tile)
    atlas.paste(frame(tile), (k * T, 0))
atlas.save(OUT)
print("saved", OUT)
