"""Ретро-постеры игровых автоматов 80-х для комнаты «игра на рубли» (придуманные игры, в духе
старых аркадных плакатов: сочные цвета, полосатое солнце, пиксельные герои, «15 коп.»).

Запуск (Python с Pillow):
    python3 tools/textures/posters.py assets/textures/posters
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
W, H = 512, 768
random.seed(3)


def gradient(top, bottom):
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        d.line((0, y, W, y), fill=tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)))
    return img


def pixel_sprite(d, rows, x0, y0, px, colors):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in colors:
                d.rectangle((x0 + x * px, y0 + y * px, x0 + (x + 1) * px - 1, y0 + (y + 1) * px - 1),
                            fill=colors[ch])


def title(img, text, y, size, fill, outline, shadow=(20, 10, 30)):
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(BOLD, size)
    while d.textlength(text.split("\n")[0], font=font) > W - 60 and size > 20:
        size -= 4
        font = ImageFont.truetype(BOLD, size)
    d.multiline_text((W / 2 + 6, y + 6), text, font=font, fill=shadow, anchor="ma", align="center",
                     spacing=4, stroke_width=8, stroke_fill=shadow)
    d.multiline_text((W / 2, y), text, font=font, fill=fill, anchor="ma", align="center", spacing=4,
                     stroke_width=8, stroke_fill=outline)


def footer(img, text, color=(255, 230, 120)):
    d = ImageDraw.Draw(img)
    d.rectangle((0, H - 70, W, H), fill=(20, 15, 25))
    d.text((W / 2, H - 35), text, font=ImageFont.truetype(BOLD, 30), fill=color, anchor="mm")


def finish(img, name):
    """Старая бумага: светлая рамка, лёгкая потёртость (скотч — в игре, Apartment._poster)."""
    img = img.convert("RGBA")
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, W - 1, H - 1), outline=(245, 235, 210, 255), width=14)
    for _ in range(140):                                                       # потёртости
        x, y = random.randint(0, W), random.randint(0, H)
        d.point((x, y), fill=(255, 250, 235, random.randint(40, 110)))
    # Скотча на картинке нет: в игре он — отдельные полоски поверх углов, заходящие на стену
    # (Apartment._poster); нарисованный обрезался краем листа.
    img.save(os.path.join(OUT, name + ".png"))


def stars(d, n, color=(255, 255, 255)):
    for _ in range(n):
        x, y = random.randint(0, W), random.randint(0, H)
        r = random.choice((1, 1, 2))
        d.ellipse((x - r, y - r, x + r, y + r), fill=color)


# 1. «ЗВЁЗДНЫЙ РЕЙС» — космос, полосатая планета, пиксельная ракета.
img = gradient((10, 5, 45), (70, 20, 110))
d = ImageDraw.Draw(img)
stars(d, 160)
d.ellipse((260, 380, 560, 680), fill=(255, 120, 60))
for k in range(6):
    d.rectangle((260, 430 + k * 40, 560, 445 + k * 40), fill=(255, 90 + k * 15, 50))
d.ellipse((180, 500, 620, 560), outline=(255, 220, 120), width=10)
rocket = ["...rr...", "..rwwr..", "..wbbw..", "..wwww..", ".rwwwwr.", "rrwwwwrr", "r.yooy.r", "...oo..."]
pixel_sprite(d, rocket, 90, 330, 18, {"r": (230, 40, 50), "w": (240, 240, 245), "b": (80, 170, 255),
                                      "y": (255, 220, 60), "o": (255, 140, 30)})
title(img, "ЗВЁЗДНЫЙ\nРЕЙС", 60, 92, (255, 230, 60), (220, 40, 60))
footer(img, "АВТОМАТ • 15 КОП.")
finish(img, "poster_star_flight")

# 2. «ПОДВОДНАЯ ОХОТА» — море, перископ, силуэты кораблей.
img = gradient((40, 140, 200), (5, 30, 80))
d = ImageDraw.Draw(img)
d.rectangle((0, 300, W, 306), fill=(200, 240, 255))
for x0 in (70, 300):
    d.polygon([(x0, 300), (x0 + 150, 300), (x0 + 125, 330), (x0 + 25, 330)], fill=(30, 40, 60))
    d.rectangle((x0 + 60, 270, x0 + 95, 300), fill=(30, 40, 60))
cx, cy, r = 256, 520, 150
d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 255, 255), width=8)
d.line((cx - r, cy, cx + r, cy), fill=(255, 255, 255), width=4)
d.line((cx, cy - r, cx, cy + r), fill=(255, 255, 255), width=4)
for _ in range(25):                                                             # пузырьки
    x, y, rr = random.randint(20, W - 20), random.randint(340, 700), random.randint(4, 12)
    d.ellipse((x - rr, y - rr, x + rr, y + rr), outline=(180, 230, 255), width=3)
title(img, "ПОДВОДНАЯ\nОХОТА", 50, 84, (120, 255, 200), (10, 60, 90))
footer(img, "АВТОМАТ • 15 КОП.")
finish(img, "poster_sub_hunt")

# 3. «ГОНКА-85» — полосатый закат, дорога в перспективе, пиксельная машина.
img = gradient((255, 90, 140), (60, 10, 80))
d = ImageDraw.Draw(img)
for k in range(7):                                                              # полосатое солнце
    y0 = 250 + k * 22
    d.chord((106, 160, 406, 460), 180, 360, fill=(255, 200 - k * 12, 60))
    d.rectangle((106, y0 + 14, 406, y0 + 14 + k), fill=(255, 90, 140))
d.rectangle((0, 330, W, H), fill=(40, 10, 70))
for k in range(12):                                                             # сетка-дорога
    y = 330 + k * k * 4
    d.line((0, y, W, y), fill=(255, 80, 200), width=2)
for x in range(-600, W + 600, 90):
    d.line((W / 2, 330, x, H), fill=(255, 80, 200), width=2)
car = ["..rrrrrr..", ".rbbbbbbr.", "rrrrrrrrrr", "rwrrrrrrwr", ".kk....kk."]
pixel_sprite(d, car, 166, 560, 18, {"r": (60, 220, 255), "b": (20, 40, 80), "w": (255, 240, 120),
                                    "k": (10, 10, 15)})
title(img, "ГОНКА-85", 60, 96, (255, 245, 120), (120, 20, 120))
footer(img, "АВТОМАТ • 15 КОП.")
finish(img, "poster_race")

# 4. «ВОЗДУШНЫЙ БОЙ» — небо, облака, пиксельный самолёт и вспышки.
img = gradient((90, 180, 255), (200, 235, 255))
d = ImageDraw.Draw(img)
for cx, cy, s in ((120, 330, 1.0), (390, 420, 1.3), (230, 620, 0.9)):         # облака
    for k in range(5):
        rr = int(45 * s)
        x = cx + int((k - 2) * 35 * s)
        d.ellipse((x - rr, cy - rr * 0.6, x + rr, cy + rr * 0.6), fill=(255, 255, 255))
plane = ["....g.....", "....gg....", "gggggggggg", ".ggwwwggg.", "....gg....", "...gggg..."]
pixel_sprite(d, plane, 150, 430, 22, {"g": (60, 120, 60), "w": (230, 240, 255)})
for bx, by in ((390, 300), (100, 560)):                                         # вспышки
    for k in range(8):
        a = k * math.pi / 4
        d.line((bx, by, bx + math.cos(a) * 45, by + math.sin(a) * 45), fill=(255, 170, 30), width=8)
    d.ellipse((bx - 18, by - 18, bx + 18, by + 18), fill=(255, 240, 120))
title(img, "ВОЗДУШНЫЙ\nБОЙ", 50, 86, (255, 90, 70), (30, 40, 90))
footer(img, "АВТОМАТ • 15 КОП.")
finish(img, "poster_air_battle")
print("DONE")
