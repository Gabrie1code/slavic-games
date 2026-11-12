"""Текстуры улицы для «Очереди за колбасой»: асфальт с трещинами и заплатками,
тротуарная плитка, дорожная разметка. Всё бесшовное (тайлится).

Запуск (Python с Pillow):
    python3 tools/textures/street_textures.py assets/textures/street
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/textures/street"
os.makedirs(OUT, exist_ok=True)
random.seed(7)
S = 512


def speckle(img, count, colors, size=(1, 3)):
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = random.randrange(S), random.randrange(S)
        r = random.randint(*size)
        c = random.choice(colors)
        for dx in (-S, 0, S):            # рисуем и за краем — чтобы шов не был виден
            for dy in (-S, 0, S):
                d.ellipse((x + dx, y + dy, x + dx + r, y + dy + r), fill=c)


def crack(d, x, y, steps, color, width=2):
    for _ in range(steps):
        nx, ny = x + random.randint(-14, 14), y + random.randint(4, 18)
        for dx in (-S, 0, S):
            for dy in (-S, 0, S):
                d.line((x + dx, y + dy, nx + dx, ny + dy), fill=color, width=width)
        x, y = nx, ny


# ---------- Асфальт ----------
img = Image.new("RGB", (S, S), (92, 92, 94))
speckle(img, 9000, [(70, 70, 72), (110, 110, 112), (84, 83, 86), (125, 124, 120)])
img = img.filter(ImageFilter.GaussianBlur(0.6))
d = ImageDraw.Draw(img)
# Заплатки — тёмные прямоугольники свежего асфальта.
for _ in range(3):
    x, y = random.randrange(S), random.randrange(S)
    w, h = random.randint(70, 150), random.randint(50, 110)
    for dx in (-S, 0, S):
        for dy in (-S, 0, S):
            d.rectangle((x + dx, y + dy, x + dx + w, y + dy + h), fill=(66, 66, 69),
                        outline=(52, 52, 55), width=3)
speckle(img, 2500, [(58, 58, 61), (78, 78, 80)])
d = ImageDraw.Draw(img)
for _ in range(5):
    crack(d, random.randrange(S), random.randrange(S), random.randint(5, 12), (45, 45, 47))
img.save(os.path.join(OUT, "asphalt.png"))

# ---------- Тротуарная плитка (советская квадратная 50×50) ----------
img = Image.new("RGB", (S, S), (150, 146, 138))
d = ImageDraw.Draw(img)
N = 4
cell = S // N
for i in range(N):
    for j in range(N):
        tone = random.randint(-14, 10)
        base = (158 + tone, 154 + tone, 146 + tone)
        d.rectangle((i * cell + 3, j * cell + 3, (i + 1) * cell - 4, (j + 1) * cell - 4), fill=base)
speckle(img, 6000, [(135, 131, 124), (170, 166, 158), (145, 141, 133)], size=(1, 2))
d = ImageDraw.Draw(img)
for i in range(N + 1):                    # швы между плитками
    d.line((i * cell, 0, i * cell, S), fill=(96, 92, 86), width=6)
    d.line((0, i * cell, S, i * cell), fill=(96, 92, 86), width=6)
for _ in range(4):                        # трещины в паре плиток
    crack(d, random.randrange(S), random.randrange(S), random.randint(3, 6), (110, 106, 100), 2)
# Плитка-«выщербина» — темнее и с травинками в шве.
d.rectangle((cell + 3, 2 * cell + 3, 2 * cell - 4, 3 * cell - 4), fill=(128, 124, 116))
for _ in range(40):
    x = random.choice([cell, 3 * cell]) + random.randint(-3, 3)
    y = random.randrange(S)
    d.line((x, y, x + random.randint(-4, 4), y - random.randint(4, 10)), fill=(90, 130, 60), width=2)
img = img.filter(ImageFilter.GaussianBlur(0.5))
img.save(os.path.join(OUT, "sidewalk.png"))

# ---------- Объявление на столбе («Колбасы нет!» — шутка) ----------
img = Image.new("RGB", (256, 320), (236, 230, 210))
d = ImageDraw.Draw(img)
try:
    from PIL import ImageFont
    big = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 34)
    small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 22)
except OSError:
    big = small = None
d.text((128, 50), "ОЧЕРЕДЬ", fill=(150, 30, 25), font=big, anchor="mm")
d.text((128, 92), "ЗА КОЛБАСОЙ", fill=(150, 30, 25), font=small, anchor="mm")
d.text((128, 150), "занимать", fill=(40, 40, 40), font=small, anchor="mm")
d.text((128, 180), "с 6:00", fill=(40, 40, 40), font=big, anchor="mm")
d.text((128, 240), "по 1 палке", fill=(40, 40, 40), font=small, anchor="mm")
d.text((128, 268), "в одни руки", fill=(40, 40, 40), font=small, anchor="mm")
for x in range(16, 256, 32):              # отрывные «язычки» снизу
    d.line((x, 290, x, 320), fill=(160, 150, 130), width=1)
img.save(os.path.join(OUT, "queue_notice.png"))
print("DONE")
