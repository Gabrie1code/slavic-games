"""Плакаты для квартиры-лобби в духе советских плакатов (плоские цвета, крупные буквы,
диагональ). Всё придуманное, без чужих брендов: «К звёздам!», календарь-1991 с котёнком,
«Пейте кефир!», «Хоккей».

Запуск (Python с Pillow):
    python3 tools/textures/home_posters.py assets/textures/posters
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
random.seed(11)
os.makedirs(OUT, exist_ok=True)
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
W, H = 512, 720
PAPER = (236, 226, 200)
RED = (196, 40, 32)
DARK = (40, 30, 30)
random.seed(11)


def font(size, bold=True):
    return ImageFont.truetype(BOLD if bold else REG, size)


def big_text(d, text, y, size, fill, stroke=None):
    f = font(size)
    while d.textlength(text, font=f) > W - 70 and size > 20:
        size -= 4
        f = font(size)
    d.text((W / 2, y), text, font=f, fill=fill, anchor="mm",
           stroke_width=4 if stroke else 0, stroke_fill=stroke)


def finish(img, name):
    """Бумага: светлая кайма, потёртости (скотч — в игре, Apartment._poster)."""
    img = img.convert("RGBA")
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, W - 1, H - 1), outline=(245, 238, 218, 255), width=12)
    for _ in range(160):
        x, y = random.randint(0, W), random.randint(0, H)
        d.point((x, y), fill=(255, 250, 235, random.randint(40, 110)))
    # Скотч — в игре отдельными полосками поверх углов, заходящими на стену (Apartment._poster).
    img.save(os.path.join(OUT, name + ".png"))
    print("SAVED", name)


# 1. «К ЗВЁЗДАМ!» — красная диагональ, ракета, звёзды.
img = Image.new("RGB", (W, H), (20, 30, 70))
d = ImageDraw.Draw(img)
for _ in range(90):
    x, y = random.randint(0, W), random.randint(0, H)
    r = random.choice((1, 1, 2))
    d.ellipse((x - r, y - r, x + r, y + r), fill=(250, 240, 200))
d.polygon([(0, H), (0, H * 0.62), (W, H * 0.25), (W, H * 0.45), (0, H * 0.82)], fill=RED)
cx, cy = 300, 300                                                     # ракета по диагонали
ang = math.radians(-35)
def rot(px, py):
    return (cx + px * math.cos(ang) - py * math.sin(ang), cy + px * math.sin(ang) + py * math.cos(ang))
d.polygon([rot(-130, -28), rot(90, -28), rot(150, 0), rot(90, 28), rot(-130, 28)], fill=(235, 235, 230))
d.polygon([rot(150, 0), rot(90, -28), rot(90, 28)], fill=RED)
d.polygon([rot(-130, -28), rot(-170, -70), rot(-90, -28)], fill=RED)
d.polygon([rot(-130, 28), rot(-170, 70), rot(-90, 28)], fill=RED)
d.ellipse([*rot(40, -12), *rot(64, 12)], fill=(90, 160, 220))
for k in range(5):
    d.polygon([rot(-135, -18 + k * 8), rot(-220 - k * 12, -10 + k * 5), rot(-135, -10 + k * 8)],
              fill=(250, 190, 60))
big_text(d, "К ЗВЁЗДАМ!", 610, 78, (250, 235, 200), DARK)
d.text((W / 2, 668), "МЕЧТАЙ  •  УЧИСЬ  •  ЛЕТАЙ", font=font(22), fill=(250, 235, 200), anchor="mm")
finish(img, "home_space")

# 2. Календарь 1991 с котёнком.
img = Image.new("RGB", (W, H), PAPER)
d = ImageDraw.Draw(img)
d.rectangle((36, 40, W - 36, 400), fill=(150, 190, 210))
d.ellipse((150, 170, 360, 360), fill=(230, 150, 70))                 # котёнок: тело
d.ellipse((190, 110, 320, 230), fill=(235, 160, 80))                 # голова
d.polygon([(200, 140), (215, 85), (245, 125)], fill=(235, 160, 80))  # уши
d.polygon([(310, 140), (295, 85), (265, 125)], fill=(235, 160, 80))
for ex in (230, 280):
    d.ellipse((ex - 12, 155, ex + 12, 182), fill=(40, 40, 40))
    d.ellipse((ex - 5, 160, ex + 1, 168), fill=(255, 255, 255))
d.polygon([(250, 190), (262, 190), (256, 199)], fill=(220, 90, 100))
for side in (-1, 1):
    for k in range(3):
        d.line((256 + side * 20, 200 + k * 6, 256 + side * 70, 192 + k * 12), fill=(60, 50, 40), width=2)
d.ellipse((330, 300, 390, 360), fill=(200, 60, 60))                  # клубок
d.line((360, 330, 420, 390), fill=(200, 60, 60), width=3)
big_text(d, "1991", 455, 84, RED)
months = ["ЯНВ", "ФЕВ", "МАР", "АПР", "МАЙ", "ИЮН", "ИЮЛ", "АВГ", "СЕН", "ОКТ", "НОЯ", "ДЕК"]
for i, m in enumerate(months):
    x = 58 + (i % 4) * 106
    y = 520 + (i // 4) * 62
    d.text((x, y), m, font=font(18), fill=RED if i in (4, 10) else DARK, anchor="lm")
    for k in range(7):
        d.rectangle((x + k * 11, y + 16, x + k * 11 + 7, y + 22), fill=(120, 110, 100))
finish(img, "home_calendar")

# 3. «ПЕЙТЕ КЕФИР!» — бутылка с зелёной крышкой из фольги.
img = Image.new("RGB", (W, H), (245, 205, 70))
d = ImageDraw.Draw(img)
for k in range(12):                                                  # лучи
    a0 = math.radians(k * 30)
    a1 = math.radians(k * 30 + 15)
    d.polygon([(W / 2, 330), (W / 2 + 600 * math.cos(a0), 330 + 600 * math.sin(a0)),
               (W / 2 + 600 * math.cos(a1), 330 + 600 * math.sin(a1))], fill=(250, 220, 110))
d.rounded_rectangle((190, 200, 322, 520), radius=40, fill=(250, 250, 245), outline=DARK, width=5)
d.rectangle((215, 140, 297, 215), fill=(250, 250, 245), outline=DARK, width=5)
d.rectangle((210, 120, 302, 150), fill=(60, 150, 80), outline=DARK, width=4)
d.rectangle((200, 330, 312, 420), fill=(60, 150, 80))
d.text((256, 375), "КЕФИР", font=font(26), fill=(250, 250, 245), anchor="mm")
big_text(d, "ПЕЙТЕ", 70, 72, RED, DARK)
big_text(d, "КЕФИР!", 600, 86, RED, DARK)
d.text((W / 2, 670), "ПОЛЕЗНО  И  ВКУСНО", font=font(24), fill=DARK, anchor="mm")
finish(img, "home_kefir")

# 4. «ХОККЕЙ» — силуэт хоккеиста, шайба, лёд.
img = Image.new("RGB", (W, H), (225, 238, 245))
d = ImageDraw.Draw(img)
d.polygon([(0, 0), (W, 0), (W, 220), (0, 360)], fill=RED)
skater = [(250, 170), (290, 190), (300, 260), (350, 330), (330, 345), (290, 300), (270, 360),
          (330, 470), (380, 480), (375, 495), (300, 495), (240, 380), (200, 470), (230, 490),
          (160, 495), (190, 380), (220, 270), (180, 300), (165, 285), (215, 220)]
d.polygon(skater, fill=(30, 40, 80))
d.ellipse((235, 120, 285, 172), fill=(30, 40, 80))                   # голова в шлеме
d.line((330, 340, 420, 470), fill=(110, 70, 30), width=9)            # клюшка
d.line((420, 470, 470, 470), fill=(110, 70, 30), width=11)
d.ellipse((470, 478, 500, 492), fill=(20, 20, 20))                   # шайба
for k in range(6):
    d.line((60 + k * 40, 540, 160 + k * 50, 520), fill=(190, 210, 225), width=3)
big_text(d, "ХОККЕЙ", 610, 92, RED, DARK)
d.text((W / 2, 672), "ТРУС НЕ ИГРАЕТ В ХОККЕЙ!", font=font(24), fill=DARK, anchor="mm")
finish(img, "home_hockey")

# 5. «БЕРЕГИ ЭЛЕКТРОЭНЕРГИЮ!» — жёлтый фон, большая лампочка, рука у выключателя.
img = Image.new("RGB", (W, H), (245, 205, 70))
d = ImageDraw.Draw(img)
for k in range(12):                                                  # лучи от лампочки
    a = math.radians(k * 30 + 15)
    d.polygon([(256, 250), (256 + 330 * math.cos(a - 0.08), 250 + 330 * math.sin(a - 0.08)),
               (256 + 330 * math.cos(a + 0.08), 250 + 330 * math.sin(a + 0.08))],
              fill=(250, 222, 110))
d.ellipse((166, 120, 346, 300), fill=(255, 250, 225), outline=DARK, width=6)   # колба
d.polygon([(206, 285), (306, 285), (290, 330), (222, 330)], fill=(255, 250, 225), outline=DARK)
for y in range(332, 380, 12):                                        # цоколь
    d.rectangle((222, y, 290, y + 8), fill=(150, 150, 150), outline=DARK)
d.line((236, 290, 246, 200, 256, 230, 266, 200, 276, 290), fill=(220, 120, 30), width=5)  # нить
# Выключатель и палец, который его выключает.
d.rounded_rectangle((330, 400, 410, 500), radius=10, fill=(240, 236, 226), outline=DARK, width=4)
d.rectangle((358, 420, 382, 452), fill=RED)
d.polygon([(470, 470), (395, 440), (380, 446), (386, 456), (470, 500)], fill=(240, 190, 150),
          outline=DARK)
big_text(d, "БЕРЕГИ", 560, 80, RED, DARK)
big_text(d, "ЭЛЕКТРОЭНЕРГИЮ!", 630, 54, DARK)
d.text((W / 2, 680), "УХОДЯ — ГАСИ СВЕТ", font=font(24), fill=DARK, anchor="mm")
finish(img, "home_energy")
