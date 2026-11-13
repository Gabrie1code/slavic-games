"""Текстуры кухни (assets/textures/kitchen/):
  linoleum.png — линолеум: бежевые клетки с ромбиками (1 м на картинку);
  tiles.png    — белый кафель 15×15 см с серыми швами (0.6 м на картинку, 4×4 плитки);
  oilcloth.png — клеёнка на стол: красно-белая клетка с мелкими цветочками;
  soda.png     — этикетка пачки соды: красная рамка, жёлтая кайма, «Сода пищевая».
Запуск: python3 tools/textures/kitchen_textures.py
"""
import random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = "assets/textures/kitchen/"
random.seed(21)

# Линолеум: бежевые клетки двух оттенков с коричневой окантовкой и ромбиком в центре.
S = 512
img = Image.new("RGB", (S, S), (120, 84, 52))
d = ImageDraw.Draw(img)
q = S // 8
for i in range(8):
    for j in range(8):
        x0, y0 = i * q, j * q
        fill = (208, 186, 148) if (i + j) % 2 == 0 else (186, 160, 118)
        d.rectangle((x0 + 2, y0 + 2, x0 + q - 3, y0 + q - 3), fill=fill)
        cx, cy = x0 + q // 2, y0 + q // 2
        d.polygon([(cx, cy - 12), (cx + 12, cy), (cx, cy + 12), (cx - 12, cy)], fill=(150, 104, 64))
px = img.load()
for _ in range(12000):
    x, y = random.randrange(S), random.randrange(S)
    r, g, b = px[x, y]
    k = random.randint(-8, 8)
    px[x, y] = (max(0, min(255, r + k)), max(0, min(255, g + k)), max(0, min(255, b + k)))
img.filter(ImageFilter.GaussianBlur(0.4)).save(OUT + "linoleum.png")

# Кафель: 4×4 белые плитки, серые швы, лёгкий блик в углу каждой.
T = 512
img = Image.new("RGB", (T, T), (168, 170, 168))
d = ImageDraw.Draw(img)
n = 4
cell = T // n
for i in range(n):
    for j in range(n):
        x0, y0 = i * cell + 3, j * cell + 3
        base = random.randint(232, 244)
        d.rectangle((x0, y0, x0 + cell - 6, y0 + cell - 6), fill=(base, base, base - 4))
        d.rectangle((x0 + 6, y0 + 6, x0 + 26, y0 + 12), fill=(250, 250, 250))
img.save(OUT + "tiles.png")

# Клеёнка: красно-белая клетка, в белых клетках — мелкий цветочек.
C = 512
img = Image.new("RGB", (C, C), (250, 246, 236))
d = ImageDraw.Draw(img)
q = C // 8
for i in range(8):
    for j in range(8):
        x0, y0 = i * q, j * q
        if (i + j) % 2 == 0:
            d.rectangle((x0, y0, x0 + q - 1, y0 + q - 1), fill=(196, 40, 36))
        else:
            cx, cy = x0 + q // 2, y0 + q // 2
            for dx, dy in ((0, -7), (7, 0), (0, 7), (-7, 0)):
                d.ellipse((cx + dx - 5, cy + dy - 5, cx + dx + 5, cy + dy + 5), fill=(60, 120, 190))
            d.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), fill=(245, 200, 60))
img.save(OUT + "oilcloth.png")
# Этикетка соды: красный фон, оранжево-жёлтая кайма, белое поле с надписью.
B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
SW, SH = 250, 400
img = Image.new("RGB", (SW, SH), (200, 30, 22))
d = ImageDraw.Draw(img)
d.rounded_rectangle((18, 18, SW - 18, SH - 18), radius=26, fill=(250, 170, 20))
d.rounded_rectangle((32, 32, SW - 32, SH - 32), radius=20, fill=(255, 230, 40))
d.rounded_rectangle((44, 44, SW - 44, SH - 44), radius=16, fill=(250, 250, 245))
d.text((SW / 2, 170), "Сода", font=ImageFont.truetype(B, 52), fill=(25, 25, 25), anchor="mm")
d.text((SW / 2, 225), "пищевая", font=ImageFont.truetype(B, 26), fill=(25, 25, 25), anchor="mm")
img.save(OUT + "soda.png")
print("saved kitchen textures")
