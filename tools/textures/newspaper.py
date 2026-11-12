"""Газета на гвозде в туалете: шапка «КРИВДА» (пародия на советские газеты), заголовок,
колонки текста «строчками», фото-блок. Пожелтевшая бумага.

Запуск (Python с Pillow):
    python3 tools/textures/newspaper.py assets/textures/toilet/newspaper.png
"""
import random
import sys

from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "newspaper.png"
W, H = 360, 480
random.seed(2)
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
img = Image.new("RGB", (W, H), (222, 214, 190))
d = ImageDraw.Draw(img)
d.text((W / 2, 40), "КРИВДА", font=ImageFont.truetype(BOLD, 50), fill=(30, 28, 26), anchor="mm")
d.polygon([(22, 22), (30, 44), (8, 30), (36, 30), (14, 44)], fill=(170, 30, 25))   # звёздочка
d.line((14, 76, W - 14, 76), fill=(40, 38, 35), width=3)
d.text((W / 2, 88), "№ 17 · ЦЕНА 3 КОП. · СРЕДА", font=ImageFont.truetype(SANS, 12),
       fill=(60, 55, 50), anchor="mm")
d.line((14, 100, W - 14, 100), fill=(40, 38, 35), width=1)
d.text((W / 2, 128), "ДЕФИЦИТ ПОБЕЖДЁН!", font=ImageFont.truetype(SANS, 21), fill=(30, 28, 26),
       anchor="mm")
d.rectangle((18, 150, 190, 270), fill=(150, 145, 130))                          # фото
d.rectangle((26, 158, 182, 262), fill=(120, 115, 100))
d.ellipse((70, 180, 130, 240), fill=(95, 90, 80))
# Колонки текста: справа от фото, ниже — две колонки на всю ширину.
blocks = [(200, W - 18, 152, 270), (18, W / 2 - 8, 284, H - 20), (W / 2 + 8, W - 18, 284, H - 20)]
for x0, x1, y0, y1 in blocks:
    for y in range(int(y0), int(y1), 10):
        x_end = x1 - random.randint(10, 50) if random.random() < 0.15 else x1
        d.line((x0, y, x_end, y), fill=(105, 100, 92), width=3)
img.save(OUT)
print("DONE")
