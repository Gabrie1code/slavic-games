"""Мусор в открытом баке, вид сверху (256 × 256): тёмная масса, а на ней обрывки газет,
пакеты разных цветов, картон, кожура, бутылочные крышки — всё вперемешку, без сплошной черноты.
Запуск: python3 tools/textures/trash_fill.py  →  assets/textures/garage/trash_fill.png
"""
import random
from PIL import Image, ImageDraw, ImageFilter

T = 256
random.seed(12)
img = Image.new("RGB", (T, T), (78, 70, 58))
d = ImageDraw.Draw(img)
for _ in range(400):                                                    # мелкий сор
    x, y = random.randint(0, T), random.randint(0, T)
    c = random.randint(50, 110)
    d.ellipse((x, y, x + random.randint(3, 9), y + random.randint(3, 9)), fill=(c, c - 8, c - 18))
colors = [(30, 30, 34), (40, 60, 120), (200, 200, 195), (150, 110, 70), (190, 185, 160), (60, 110, 60),
          (170, 60, 50), (210, 180, 60), (120, 120, 125)]
for _ in range(55):                                                     # крупные куски
    x, y = random.randint(-20, T), random.randint(-20, T)
    w, h = random.randint(14, 46), random.randint(10, 34)
    c = random.choice(colors)
    kind = random.random()
    if kind < 0.4:                                                      # пакет — мятое пятно
        d.ellipse((x, y, x + w, y + h), fill=c)
        d.arc((x + 3, y + 3, x + w - 3, y + h - 3), 200, 320, fill=tuple(min(255, v + 40) for v in c), width=2)
    elif kind < 0.75:                                                   # бумага / картон
        pts = [(x + random.randint(0, 8), y), (x + w, y + random.randint(0, 8)),
               (x + w - random.randint(0, 8), y + h), (x, y + h - random.randint(0, 8))]
        d.polygon(pts, fill=c)
        if c in ((200, 200, 195), (190, 185, 160)):                     # строчки газеты
            for ly in range(y + 4, y + h - 2, 4):
                d.line((x + 4, ly, x + w - 6, ly), fill=(140, 140, 135))
    else:                                                               # кожура / крышки
        d.ellipse((x, y, x + 8, y + 8), fill=c)
img = img.filter(ImageFilter.GaussianBlur(0.7))
img.save("assets/textures/garage/trash_fill.png")
print("saved trash_fill.png")
