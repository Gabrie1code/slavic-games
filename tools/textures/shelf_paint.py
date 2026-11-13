"""Роспись вещиц на полках (развёртка тела вращения: по ширине — вся окружность, по высоте —
снизу вверх; перед вещи — u = 0.75):
  matr_red.png / matr_green.png / matr_blue.png — матрёшки: сарафан, платок, лицо (глаза,
      румянец, губы, чёлка), жёлтый фартук с красным цветком и листиками, золотой поясок;
  vase_gzhel.png — ваза «гжель»: белая, синие пояски, цветы-завитки и точки.
Запуск: python3 tools/textures/shelf_paint.py
"""
import math
from PIL import Image, ImageDraw

OUT = "assets/textures/shelf/"
W, H = 1024, 512


def matr(name, body, scarf, scarf_dots):
    img = Image.new("RGB", (W, H), body)
    d = ImageDraw.Draw(img)
    belt = H * (1 - 0.083 / 0.141)                         # граница платка (z 0.083 из 0.141)
    d.rectangle((0, 0, W, belt), fill=scarf)
    for k in range(40):                                    # горошек на платке
        x = (k * 97) % W
        y = 10 + (k * 53) % int(belt - 30)
        d.ellipse((x - 5, y - 5, x + 5, y + 5), fill=scarf_dots)
    d.rectangle((0, belt - 6, W, belt + 6), fill=(230, 175, 40))          # поясок
    cx = W * 0.75
    # Лицо (овал) с чёлкой, глазами, румянцем, губами.
    fy0, fy1 = H * (1 - 0.122 / 0.141), H * (1 - 0.091 / 0.141)
    d.ellipse((cx - 95, fy0, cx + 95, fy1), fill=(245, 214, 180))
    d.chord((cx - 95, fy0 - 10, cx + 95, fy0 + 50), 180, 360, fill=(120, 70, 30))  # чёлка
    ey = fy0 + (fy1 - fy0) * 0.45
    for side in (-1, 1):
        d.ellipse((cx + side * 32 - 7, ey - 9, cx + side * 32 + 7, ey + 9), fill=(25, 20, 18))
        d.ellipse((cx + side * 52 - 18, ey + 14, cx + side * 52 + 18, ey + 34), fill=(240, 130, 130))
    d.ellipse((cx - 14, ey + 30, cx + 14, ey + 44), fill=(200, 30, 40))
    # Фартук и цветок.
    ay0, ay1 = H * (1 - 0.072 / 0.141), H - 30
    d.ellipse((cx - 130, ay0, cx + 130, ay1), fill=(250, 214, 70))
    fx, fy = cx, (ay0 + ay1) / 2 - 10
    for k in range(6):
        a = 2 * math.pi * k / 6
        px, py = fx + math.cos(a) * 34, fy + math.sin(a) * 30
        d.ellipse((px - 26, py - 22, px + 26, py + 22), fill=(205, 25, 30))
    d.ellipse((fx - 18, fy - 16, fx + 18, fy + 16), fill=(250, 214, 70))
    for side in (-1, 1):
        d.ellipse((fx + side * 80 - 32, fy + 50, fx + side * 80 + 32, fy + 72), fill=(40, 130, 50))
    d.line((fx, fy + 30, fx, ay1 - 20), fill=(40, 130, 50), width=8)
    img.save(OUT + name)


matr("matr_red.png", (200, 25, 20), (245, 190, 40), (205, 40, 30))
matr("matr_green.png", (30, 130, 55), (215, 30, 30), (250, 210, 60))
matr("matr_blue.png", (30, 70, 180), (245, 190, 40), (205, 40, 30))

# Гжель: высота вазы 0.165; пояски у дна (0.012), на плече (0.105), у горлышка (0.16).
COB = (25, 55, 160)
img = Image.new("RGB", (W, H), (246, 246, 242))
d = ImageDraw.Draw(img)


def zy(z):
    return H * (1 - z / 0.165)


for z in (0.012, 0.105, 0.158):
    d.rectangle((0, zy(z) - 7, W, zy(z) + 7), fill=COB)
for k in range(5):                                        # цветы-завитки по пузу вазы
    cx = (k + 0.5) * W / 5
    cy = zy(0.06)
    for j in range(5):
        a = 2 * math.pi * j / 5 - math.pi / 2
        px, py = cx + math.cos(a) * 26, cy + math.sin(a) * 34
        d.ellipse((px - 18, py - 24, px + 18, py + 24), fill=COB)
    d.ellipse((cx - 10, cy - 12, cx + 10, cy + 12), fill=(246, 246, 242))
    for side in (-1, 1):                                  # листики-мазки
        d.arc((cx + side * 40 - 50, cy - 10, cx + side * 40 + 50, cy + 90),
              200 if side < 0 else 280, 260 if side < 0 else 340, fill=COB, width=8)
    for j in range(3):                                    # точки между цветами
        px = cx + W / 10
        d.ellipse((px - 6, zy(0.085) + j * 26 - 6, px + 6, zy(0.085) + j * 26 + 6), fill=COB)
for k in range(16):                                       # мелкие точки на горлышке
    px = (k + 0.5) * W / 16
    d.ellipse((px - 5, zy(0.135) - 5, px + 5, zy(0.135) + 5), fill=COB)
img.save(OUT + "vase_gzhel.png")
print("saved shelf paint")
