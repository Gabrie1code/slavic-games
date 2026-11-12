"""Надписи на воротах гаражей: граффити «из баллончика» (обводка, блик, ореол краски, подтёки)
и эмалированные таблички с номерами. Вместо мыльных Label3D — чёткие картинки с прозрачностью.

Запуск (Python с Pillow):
    python3 tools/textures/garage_decals.py assets/textures/garage
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
random.seed(11)


def fit_font(draw, lines, max_w, max_h, start=260):
    size = start
    while size > 20:
        font = ImageFont.truetype(FONT, size)
        widths = [draw.textlength(line, font=font) for line in lines]
        height = size * 1.1 * len(lines)
        if max(widths) <= max_w and height <= max_h:
            return font
        size -= 6
    return ImageFont.truetype(FONT, size)


def graffiti(name, text, fill, outline=(15, 12, 12), tilt=-4):
    w, h = 1024, 512
    lines = text.split("\n")
    probe = ImageDraw.Draw(Image.new("RGBA", (w, h)))
    font = fit_font(probe, lines, w * 0.86, h * 0.72)
    line_h = font.size * 1.1
    top = (h - line_h * len(lines)) / 2 + font.size * 0.55
    # Ореол распылённой краски.
    halo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    for i, line in enumerate(lines):
        hd.text((w / 2, top + i * line_h), line, font=font, fill=fill + (110,), anchor="mm",
                stroke_width=int(font.size * 0.16), stroke_fill=fill + (110,))
    halo = halo.filter(ImageFilter.GaussianBlur(14))
    art = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(art)
    for i, line in enumerate(lines):
        y = top + i * line_h
        d.text((w / 2, y), line, font=font, fill=fill + (255,), anchor="mm",
               stroke_width=int(font.size * 0.09), stroke_fill=outline + (255,))
    # Подтёки краски вниз от букв.
    bbox = art.getbbox()
    if bbox:
        for _ in range(9):
            x = random.randint(bbox[0] + 20, bbox[2] - 20)
            column = [art.getpixel((x, y))[3] for y in range(bbox[1], bbox[3])]
            if not any(a > 200 for a in column):
                continue
            y0 = bbox[1] + max(i for i, a in enumerate(column) if a > 200)
            length = random.randint(25, 80)
            d.line((x, y0 - 4, x, y0 + length), fill=fill + (255,), width=7)
            d.ellipse((x - 6, y0 + length - 6, x + 6, y0 + length + 6), fill=fill + (255,))
    # Белый блик на буквах (полоска сверху каждой строки).
    shine = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shine)
    for i, line in enumerate(lines):
        sd.text((w / 2 - 3, top + i * line_h - 5), line, font=font, fill=(255, 255, 255, 70), anchor="mm")
    mask = art.split()[3]
    shine.putalpha(Image.composite(shine.split()[3], Image.new("L", (w, h), 0), mask))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(halo)
    out.alpha_composite(art)
    out.alpha_composite(shine)
    out = out.rotate(tilt, resample=Image.BICUBIC)
    out.save(os.path.join(OUT, name + ".png"))


def plate(number):
    w, h = 512, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((6, 6, w - 6, h - 6), radius=26, fill=(238, 236, 228, 255), outline=(30, 40, 70, 255),
                        width=14)
    d.rounded_rectangle((26, 26, w - 26, h - 26), radius=14, outline=(30, 40, 70, 255), width=4)
    font = ImageFont.truetype(FONT, 150)
    d.text((w / 2, h / 2 + 6), "№%d" % number, font=font, fill=(30, 40, 70, 255), anchor="mm")
    for x in (40, w - 40):                                                      # винтики
        d.ellipse((x - 9, h / 2 - 9, x + 9, h / 2 + 9), fill=(150, 150, 150, 255), outline=(80, 80, 80, 255))
    img.save(os.path.join(OUT, "plate_%d.png" % number))


graffiti("graffiti_tsoi", "ЦОЙ ЖИВ", (240, 240, 235), tilt=-5)
graffiti("graffiti_spartak", "СПАРТАК —\nЧЕМПИОН", (220, 40, 40), tilt=3)
graffiti("graffiti_vasya", "Здесь был\nВася", (70, 150, 255), tilt=-3)
graffiti("graffiti_kino", "КИНО", (255, 210, 40), tilt=6)
for n in (17, 18, 21, 23):
    plate(n)
print("DONE")
