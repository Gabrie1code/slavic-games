"""Плакаты для квартиры-лобби в духе советских плакатов (плоские цвета, крупные буквы,
диагональ). Всё придуманное, без чужих брендов: «К звёздам!», календарь-1991 с котёнком,
«Пейте кефир!», «Хоккей», ночной «Тишина! Соседи спят».

Запуск (Python с Pillow):
    python3 tools/textures/home_posters.py assets/textures/posters
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

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

# 5. «ТИШИНА! СОСЕДИ СПЯТ» — тёмный ночной плакат: синее небо, месяц, звёзды, хрущёвка
# с парой горящих окон. (Был жёлтый «Береги электроэнергию» — слишком яркий для стены.)
NIGHT = (14, 20, 46)
img = Image.new("RGB", (W, H), NIGHT)
d = ImageDraw.Draw(img)
for y in range(0, 470):                                              # небо светлеет к горизонту
    k = y / 470
    d.line((0, y, W, y), fill=(int(14 + 22 * k), int(20 + 26 * k), int(46 + 40 * k)))
for _ in range(70):
    x, y = random.randint(20, W - 20), random.randint(20, 380)
    r = random.choice((1, 1, 2))
    d.ellipse((x - r, y - r, x + r, y + r), fill=(235, 228, 200))
d.ellipse((330, 70, 440, 180), fill=(242, 226, 160))                 # месяц: круг минус круг
cut = Image.new("L", (W, H), 0)
ImageDraw.Draw(cut).ellipse((306, 52, 416, 162), fill=255)
sky = Image.new("RGB", (W, H))
sd = ImageDraw.Draw(sky)
for y in range(H):                                                   # то же небо, без звёзд
    k = min(y, 470) / 470
    sd.line((0, y, W, y), fill=(int(14 + 22 * k), int(20 + 26 * k), int(46 + 40 * k)))
img.paste(sky, (0, 0), cut)
d = ImageDraw.Draw(img)
BLD = (8, 10, 24)
d.rectangle((40, 250, 330, 470), fill=BLD)                           # хрущёвка
d.rectangle((300, 300, 480, 470), fill=(11, 14, 32))                 # дом подальше
lit = {(1, 2), (3, 0), (4, 3)}
for row in range(5):
    for col in range(6):
        x, y = 62 + col * 44, 268 + row * 40
        on = (row, col) in lit
        d.rectangle((x, y, x + 22, y + 24), fill=(240, 190, 90) if on else (24, 30, 56))
for row in range(4):
    for col in range(4):
        x, y = 318 + col * 40, 318 + row * 36
        d.rectangle((x, y, x + 18, y + 20), fill=(220, 170, 80) if (row, col) == (2, 1) else (22, 28, 50))
big_text(d, "ТИШИНА!", 540, 92, (242, 226, 160), BLD)
big_text(d, "СОСЕДИ СПЯТ", 615, 50, (215, 222, 240))
d.text((W / 2, 672), "ПОСЛЕ 23:00 — НЕ ШУМИ", font=font(24), fill=(170, 180, 210), anchor="mm")
finish(img, "home_night")

# 6. «БЕРЕГИ РАБОЧЕЕ ВРЕМЯ!» (на кухню) — зелёный фон, большие часы, красный рабочий с молотом.
img = Image.new("RGB", (W, H), (38, 112, 88))
d = ImageDraw.Draw(img)
big_text(d, "БЕРЕГИ РАБОЧЕЕ", 70, 46, (250, 236, 190), DARK)
big_text(d, "ВРЕМЯ!", 128, 64, (250, 236, 190), DARK)
cx, cy, r = 256, 360, 160
d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(240, 226, 186), outline=DARK, width=8)   # циферблат
for k in range(12):
    a = math.radians(k * 30)
    r0 = r - (34 if k % 3 == 0 else 22)
    d.line((cx + r0 * math.sin(a), cy - r0 * math.cos(a), cx + (r - 10) * math.sin(a),
            cy - (r - 10) * math.cos(a)), fill=DARK, width=8 if k % 3 == 0 else 4)
d.line((cx, cy, cx - 70, cy - 95), fill=DARK, width=12)              # часовая — к десяти
d.line((cx, cy, cx + 105, cy - 60), fill=DARK, width=8)              # минутная
d.ellipse((cx - 12, cy - 12, cx + 12, cy + 12), fill=RED)
# Красный рабочий с молотом перед часами (силуэт).
d.ellipse((150, 420, 210, 480), fill=RED)                            # голова
d.polygon([(120, 700), (130, 520), (175, 480), (230, 520), (240, 700)], fill=RED)
d.line((215, 520, 300, 455), fill=RED, width=22)                     # рука
d.line((290, 470, 330, 410), fill=(90, 50, 25), width=10)            # рукоять
d.polygon([(305, 395), (365, 420), (355, 440), (295, 415)], fill=DARK)  # молот
d.text((W / 2 + 70, 650), "МИНУТА ДОРОГА!", font=font(28), fill=(250, 236, 190), anchor="mm")
finish(img, "kitchen_time")

# 7. Старая фотография для рамки на полке (сепия): двое на фоне, белая кайма.
img = Image.new("RGB", (300, 400), (232, 220, 196))
d = ImageDraw.Draw(img)
d.rectangle((14, 14, 286, 386), fill=(150, 120, 86))
for y in range(14, 386):                                             # фон светлее кверху
    t = (y - 14) / 372
    d.line((14, y, 286, y), fill=(int(176 - 50 * t), int(146 - 44 * t), int(104 - 34 * t)))
for cx, h, shirt in ((110, 0, (96, 70, 48)), (190, 16, (70, 50, 36))):  # мужчина и женщина
    d.ellipse((cx - 30, 120 + h, cx + 30, 185 + h), fill=(214, 186, 150))  # лицо
    d.chord((cx - 34, 105 + h, cx + 34, 160 + h), 180, 360, fill=(60, 42, 30))  # волосы
    d.polygon([(cx - 60, 386), (cx - 48, 230 + h), (cx, 200 + h), (cx + 48, 230 + h),
               (cx + 60, 386)], fill=shirt)
img = img.filter(ImageFilter.GaussianBlur(1.2))
img.save(os.path.join(OUT, "shelf_photo.png"))
print("SAVED shelf_photo")
