"""Текстуры эффектов: снежинка (искры льда в «Морожке») и жёлтая вспышка-лучики
(лучики у головы того, кто размораживает).

Запуск (Python с Pillow):
    python3 tools/textures/fx_textures.py assets/textures/fx
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def snowflake():
    size = 256
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size / 2
    for i in range(6):
        a = math.radians(i * 60)
        ex, ey = c + math.cos(a) * 110, c + math.sin(a) * 110
        d.line((c, c, ex, ey), fill=(255, 255, 255, 255), width=14)
        for t, ln in ((0.55, 34), (0.8, 24)):                              # веточки
            px, py = c + math.cos(a) * 110 * t, c + math.sin(a) * 110 * t
            for s in (-1, 1):
                b = a + s * math.radians(45)
                d.line((px, py, px + math.cos(b) * ln, py + math.sin(b) * ln), fill=(255, 255, 255, 255),
                       width=10)
    glow = img.filter(ImageFilter.GaussianBlur(8))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(img)
    out.save(os.path.join(OUT, "snowflake.png"))


def alert():
    """Жёлтая «вспышка» у головы — три лучика веером (без восклицательного знака)."""
    size = 256
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    yellow = (255, 205, 35, 255)
    cx, cy = 40, 200                                                        # центр веера — у головы
    for a in (-80, -45, -10):
        r = math.radians(a)
        x0, y0 = cx + math.cos(r) * 90, cy + math.sin(r) * 90
        x1, y1 = cx + math.cos(r) * 190, cy + math.sin(r) * 190
        d.line((x0, y0, x1, y1), fill=(60, 40, 5, 255), width=40)
        d.line((x0, y0, x1, y1), fill=yellow, width=26)
    img.save(os.path.join(OUT, "alert.png"))


snowflake()
alert()
print("DONE")
