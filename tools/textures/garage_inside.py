"""Внутренность открытого гаража — картинка-заглушка за приоткрытой створкой (512 × 384).
Общее: полумрак, задняя стена из кирпича в перспективе, бетонный пол с масляным пятном,
лампочка под потолком с тёплым светом. Три варианта начинки:
  a — «мастерская»: велосипед (руль, седло, педали, спицы), верстак с тисками, инструменты на
      щите, стопка шин (видны протектор и бока);
  b — «кладовка»: стеллаж с банками солений и краской, мешки картошки, лыжи и санки, шина
      стоит на ребре (видна дыра в середине);
  c — «машина»: задок старой легковушки с фонарями и номером, ящик с инструментами, канистра,
      колёса на стене.
Рисуется вдвое крупнее и уменьшается — края ровные.
Запуск: python3 tools/textures/garage_inside.py [a|b|c] [путь.png]
  по умолчанию a → assets/textures/garage/garage_inside.png
"""
import sys
from PIL import Image, ImageDraw, ImageFilter

K = 2
W, H = 512 * K, 384 * K
VARIANT = sys.argv[1] if len(sys.argv) > 1 else "a"
OUT = sys.argv[2] if len(sys.argv) > 2 else "assets/textures/garage/garage_inside.png"
img = Image.new("RGB", (W, H), (34, 31, 28))
d = ImageDraw.Draw(img)


def s(*v):
    """Координаты в «маленьких» пикселях (512 × 384) → в большие."""
    return [int(x * K) for x in v]


# ---------------- Комната ----------------
bx0, by0, bx1, by1 = 120, 70, 392, 290
d.polygon([tuple(s(0, 0)), tuple(s(512, 0)), tuple(s(bx1, by0)), tuple(s(bx0, by0))], fill=(44, 40, 36))
d.polygon([tuple(s(0, 384)), tuple(s(512, 384)), tuple(s(bx1, by1)), tuple(s(bx0, by1))], fill=(84, 82, 78))
d.polygon([tuple(s(0, 0)), tuple(s(bx0, by0)), tuple(s(bx0, by1)), tuple(s(0, 384))], fill=(60, 56, 51))
d.polygon([tuple(s(512, 0)), tuple(s(bx1, by0)), tuple(s(bx1, by1)), tuple(s(512, 384))], fill=(54, 50, 46))
d.rectangle(s(bx0, by0, bx1, by1), fill=(70, 64, 58))
for i, y in enumerate(range(by0 + 14, by1, 14)):                                   # кирпичи
    d.line(s(bx0, y, bx1, y), fill=(60, 55, 50), width=K)
    for x in range(bx0 + (i % 2) * 14, bx1, 28):
        d.line(s(x, y - 14, x, y), fill=(60, 55, 50), width=K)
d.ellipse(s(200, 318, 330, 352), fill=(62, 60, 58))                               # масляное пятно


# ---------------- Предметы ----------------
def tire_stack(x, y, n, w=120, h=26):
    """Шины лежат стопкой (вид спереди): у каждой — бок, протектор с канавками и тень сверху."""
    for k in range(n):
        top = y - (k + 1) * h
        d.rounded_rectangle(s(x, top, x + w, top + h), radius=10 * K, fill=(26, 26, 28),
                            outline=(14, 14, 15), width=K)
        for gx in range(x + 8, x + w - 6, 9):                                   # протектор
            d.line(s(gx, top + 6, gx + 4, top + h - 6), fill=(40, 40, 43), width=2 * K)
        d.line(s(x + 6, top + 3, x + w - 6, top + 3), fill=(48, 48, 50), width=K)  # блик на ребре
    d.ellipse(s(x + 10, y - n * h - 10, x + w - 10, y - n * h + 10), fill=(20, 20, 22),
              outline=(40, 40, 42), width=2 * K)                                 # верх стопки
    d.ellipse(s(x + 38, y - n * h - 4, x + w - 38, y - n * h + 4), fill=(10, 10, 10))


def tire_upright(cx, cy, r):
    """Шина на ребре (вид сбоку): чёрное кольцо, протектор по краю, дыра в середине."""
    d.ellipse(s(cx - r, cy - r, cx + r, cy + r), fill=(26, 26, 28))
    for k in range(28):
        import math
        a = k * math.tau / 28
        x0, y0 = cx + math.cos(a) * (r - 2), cy + math.sin(a) * (r - 2)
        x1, y1 = cx + math.cos(a) * (r - 7), cy + math.sin(a) * (r - 7)
        d.line(s(x0, y0, x1, y1), fill=(44, 44, 46), width=2 * K)
    d.ellipse(s(cx - r * 0.72, cy - r * 0.72, cx + r * 0.72, cy + r * 0.72), outline=(40, 40, 42), width=K)
    d.ellipse(s(cx - r * 0.5, cy - r * 0.5, cx + r * 0.5, cy + r * 0.5), fill=(66, 62, 56))


def bicycle(x, y, color=(170, 40, 40)):
    """Велосипед боком: колёса со спицами, рама-треугольник, вилка, руль, седло, педали."""
    import math
    rear, front = (x, y), (x + 92, y)
    for cx, cy in (rear, front):
        d.ellipse(s(cx - 30, cy - 30, cx + 30, cy + 30), outline=(22, 22, 22), width=4 * K)
        for k in range(10):
            a = k * math.pi / 10
            d.line(s(cx - math.cos(a) * 27, cy - math.sin(a) * 27, cx + math.cos(a) * 27,
                     cy + math.sin(a) * 27), fill=(120, 120, 120), width=K)
        d.ellipse(s(cx - 3, cy - 3, cx + 3, cy + 3), fill=(150, 150, 150))
    crank = (x + 40, y)
    seat_top = (x + 32, y - 40)
    head = (x + 80, y - 38)
    for a, b in ((rear, crank), (crank, seat_top), (rear, seat_top), (seat_top, head), (crank, head),
                 (head, front)):
        d.line(s(*a, *b), fill=color, width=4 * K)
    d.line(s(x + 30, y - 40, x + 28, y - 50), fill=(60, 60, 60), width=3 * K)          # подседельный штырь
    d.polygon([tuple(s(x + 14, y - 52)), tuple(s(x + 42, y - 54)), tuple(s(x + 36, y - 48)),
               tuple(s(x + 16, y - 47))], fill=(30, 26, 22))                         # седло
    d.line(s(*head, x + 76, y - 54), fill=(80, 80, 80), width=3 * K)                 # вынос руля
    d.line(s(x + 70, y - 56, x + 88, y - 52), fill=(80, 80, 80), width=3 * K)        # руль
    d.line(s(x + 86, y - 53, x + 92, y - 50), fill=(30, 30, 30), width=4 * K)        # ручка
    d.ellipse(s(crank[0] - 8, crank[1] - 8, crank[0] + 8, crank[1] + 8), outline=(140, 140, 140), width=2 * K)
    d.line(s(crank[0], crank[1], crank[0] + 10, crank[1] + 12), fill=(140, 140, 140), width=2 * K)
    d.rectangle(s(crank[0] + 6, crank[1] + 11, crank[0] + 16, crank[1] + 15), fill=(30, 30, 30))  # педаль
    d.line(s(rear[0] - 2, rear[1] - 33, rear[0] + 26, rear[1] - 33), fill=(90, 90, 95), width=2 * K)  # багажник


def shelves(x0, x1, ys):
    for sy in ys:
        d.rectangle(s(x0, sy, x1, sy + 5), fill=(110, 80, 50))
    for sx in (x0, x1 - 5):
        d.rectangle(s(sx, ys[0] - 50, sx + 5, ys[-1] + 5), fill=(95, 70, 45))


def jar(x, y, fill, w=18, h=28):
    d.rounded_rectangle(s(x, y - h, x + w, y), radius=4 * K, fill=fill, outline=(170, 180, 185), width=K)
    d.rectangle(s(x + 2, y - h - 5, x + w - 2, y - h), fill=(180, 180, 185))         # крышка


# ---------------- Варианты ----------------
if VARIANT == "a":                                       # мастерская
    d.rectangle(s(bx0 + 10, 96, bx0 + 150, 170), fill=(120, 95, 60))                # щит для инструментов
    for hx, kind in ((bx0 + 22, "hammer"), (bx0 + 52, "saw"), (bx0 + 92, "wrench"), (bx0 + 122, "pliers")):
        if kind == "hammer":
            d.line(s(hx, 104, hx, 150), fill=(150, 110, 60), width=3 * K)
            d.rectangle(s(hx - 9, 102, hx + 9, 110), fill=(90, 90, 95))
        elif kind == "saw":
            d.polygon([tuple(s(hx, 104)), tuple(s(hx + 30, 108)), tuple(s(hx + 30, 120)),
                       tuple(s(hx, 132))], fill=(170, 170, 175))
            d.rectangle(s(hx - 8, 102, hx + 2, 134), fill=(140, 90, 45))
        elif kind == "wrench":
            d.line(s(hx, 106, hx, 156), fill=(160, 160, 165), width=3 * K)
            d.ellipse(s(hx - 6, 100, hx + 6, 112), outline=(160, 160, 165), width=2 * K)
        else:
            d.line(s(hx - 4, 106, hx + 2, 150), fill=(170, 50, 40), width=3 * K)
            d.line(s(hx + 4, 106, hx - 2, 150), fill=(170, 50, 40), width=3 * K)
    d.rectangle(s(bx0 + 4, 196, bx0 + 170, 206), fill=(120, 85, 50))                # верстак
    for lx in (bx0 + 10, bx0 + 160):
        d.rectangle(s(lx, 206, lx + 6, 262), fill=(100, 72, 45))
    d.rectangle(s(bx0 + 130, 182, bx0 + 160, 196), fill=(70, 90, 110))              # тиски
    d.rectangle(s(bx0 + 40, 186, bx0 + 70, 196), fill=(170, 50, 35))                # ящик
    tire_stack(300, 300, 4)
    bicycle(36, 300)
elif VARIANT == "b":                                     # кладовка
    shelves(bx0 + 8, bx0 + 170, (150, 205, 258))
    cols = [(150, 60, 50), (90, 140, 70), (200, 150, 60), (160, 40, 60), (110, 150, 80)]
    for i, sy in enumerate((150, 205, 258)):
        for k in range(6):
            jar(bx0 + 16 + k * 25, sy, cols[(k + i) % len(cols)])
    for k, cx in enumerate((300, 340, 378)):                                         # мешки картошки
        d.ellipse(s(cx - 26, 268 - k % 2 * 6, cx + 26, 330), fill=(150, 120, 80), outline=(110, 85, 55), width=K)
        d.polygon([tuple(s(cx - 8, 272 - k % 2 * 6)), tuple(s(cx, 258 - k % 2 * 6)),
                   tuple(s(cx + 8, 272 - k % 2 * 6))], fill=(130, 100, 65))
    for k, x in enumerate((bx1 - 20, bx1 - 8)):                                      # лыжи у стены
        d.line(s(x, 90, x - 6, 280), fill=((40, 80, 150), (170, 50, 40))[k], width=4 * K)
        d.arc(s(x - 10, 82, x + 6, 98), 180, 300, fill=((40, 80, 150), (170, 50, 40))[k], width=4 * K)
    d.rectangle(s(30, 300, 140, 308), fill=(140, 100, 60))                           # санки
    for x in (40, 128):
        d.line(s(x, 308, x - 6, 330), fill=(150, 150, 155), width=3 * K)
    d.line(s(26, 330, 140, 330), fill=(150, 150, 155), width=3 * K)
    tire_upright(196, 288, 40)
else:                                                    # машина
    d.rectangle(s(bx0 + 30, 170, bx1 - 30, 300), fill=(150, 160, 175))               # задок машины
    d.polygon([tuple(s(bx0 + 50, 170)), tuple(s(bx1 - 50, 170)), tuple(s(bx1 - 70, 120)),
               tuple(s(bx0 + 70, 120))], fill=(135, 145, 160))
    d.polygon([tuple(s(bx0 + 76, 165)), tuple(s(bx1 - 76, 165)), tuple(s(bx1 - 90, 128)),
               tuple(s(bx0 + 90, 128))], fill=(60, 70, 85))                         # заднее стекло
    for fx in (bx0 + 38, bx1 - 78):                                                  # фонари
        d.rectangle(s(fx, 196, fx + 40, 214), fill=(170, 40, 35))
        d.rectangle(s(fx + 28, 196, fx + 40, 214), fill=(210, 140, 50))
    d.rectangle(s(226, 236, 286, 254), fill=(225, 225, 215), outline=(30, 30, 30), width=K)  # номер
    d.text(s(232, 240), "Б 12-34", fill=(20, 20, 20))
    d.rectangle(s(bx0 + 24, 266, bx1 - 24, 280), fill=(90, 95, 100))                 # бампер
    for wx in (bx0 + 50, bx1 - 90):
        d.rectangle(s(wx, 290, wx + 40, 306), fill=(20, 20, 22))                     # колёса
    for cx in (60, 452):                                                              # колёса на стенах
        tire_upright(cx, 150, 32)
    d.rectangle(s(30, 300, 110, 340), fill=(170, 50, 35))                            # ящик с инструментами
    d.rectangle(s(30, 296, 110, 304), fill=(140, 40, 30))
    d.line(s(56, 290, 84, 290), fill=(60, 60, 60), width=3 * K)
    d.rectangle(s(420, 296, 466, 340), fill=(40, 90, 50))                            # канистра
    d.rectangle(s(446, 288, 458, 297), fill=(30, 70, 40))

# ---------------- Лампочка и свет ----------------
d.line(s(256, 0, 256, 40), fill=(30, 30, 30), width=2 * K)
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
g = ImageDraw.Draw(glow)
for r, a in ((170, 30), (110, 40), (60, 60)):
    g.ellipse(s(256 - r, 50 - r * 0.7, 256 + r, 50 + r * 0.9), fill=(255, 200, 120, a))
glow = glow.filter(ImageFilter.GaussianBlur(18 * K))
img.paste(glow, (0, 0), glow)
d = ImageDraw.Draw(img)
d.ellipse(s(247, 38, 265, 58), fill=(255, 235, 170))
img = img.resize((512, 384), Image.LANCZOS)
img.save(OUT)
print("saved", OUT)
