"""Значки-«кнопки» над зонами лобби: круглая иконка + короткое слово на цветной плашке.

Запуск (Python с Pillow):
    python3 tools/textures/prompt_badges.py assets/ui/prompts
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 64)
S = 2  # рисуем вдвое крупнее и уменьшаем — края гладкие


def badge(name, text, color, icon):
    h = 150 * S
    pad = 18 * S
    tw = int(ImageFont.truetype(FONT.path, 64 * S).getlength(text))
    w = h + tw + pad * 3
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    dark = tuple(int(c * 0.55) for c in color)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=h // 2, fill=dark + (235,), outline=(255, 255, 255, 255),
                        width=6 * S)
    # Круглая «кнопка» слева.
    r = h // 2 - pad
    cx, cy = h // 2, h // 2
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color + (255,), outline=(255, 255, 255, 255), width=5 * S)
    icon(d, cx, cy, r * 0.55)
    font = ImageFont.truetype(FONT.path, 64 * S)
    d.text((h + pad, h // 2), text, font=font, fill=(255, 255, 255, 255), anchor="lm")
    img = img.resize((w // S, h // S), Image.LANCZOS)
    img.save(os.path.join(OUT, name + ".png"))


def play(d, cx, cy, s):
    d.polygon([(cx - s * 0.7, cy - s), (cx - s * 0.7, cy + s), (cx + s, cy)], fill="white")


def hanger(d, cx, cy, s):
    w = int(s * 0.22)
    d.line((cx - s, cy + s * 0.6, cx, cy - s * 0.1, cx + s, cy + s * 0.6, cx - s, cy + s * 0.6), fill="white",
           width=w, joint="curve")
    d.arc((cx - s * 0.3, cy - s * 0.9, cx + s * 0.3, cy - s * 0.1), 180, 90, fill="white", width=w)


def chip(d, cx, cy, s):
    d.ellipse((cx - s, cy - s, cx + s, cy + s), outline="white", width=int(s * 0.22))
    d.ellipse((cx - s * 0.35, cy - s * 0.35, cx + s * 0.35, cy + s * 0.35), fill="white")


def slide(d, cx, cy, s):
    w = int(s * 0.22)
    d.line((cx - s, cy + s * 0.8, cx + s * 0.4, cy - s * 0.6, cx + s * 0.4, cy + s * 0.8), fill="white", width=w)
    for k in range(3):
        y = cy - s * 0.2 + k * s * 0.35
        d.line((cx + s * 0.4, y, cx + s * 0.9, y), fill="white", width=w // 2)


def swing(d, cx, cy, s):
    w = int(s * 0.2)
    d.line((cx - s, cy - s * 0.8, cx + s, cy - s * 0.8), fill="white", width=w)
    d.line((cx - s * 0.45, cy - s * 0.8, cx - s * 0.45, cy + s * 0.5), fill="white", width=w // 2)
    d.line((cx + s * 0.45, cy - s * 0.8, cx + s * 0.45, cy + s * 0.5), fill="white", width=w // 2)
    d.rectangle((cx - s * 0.65, cy + s * 0.45, cx + s * 0.65, cy + s * 0.75), fill="white")


badge("zone_play", "ИГРАТЬ", (70, 170, 90), play)
badge("zone_wardrobe", "ШКАФ", (215, 150, 40), hanger)
badge("zone_rubgame", "ИГРА НА РУБЛИ", (210, 60, 140), chip)
badge("zone_slide", "ГОРКА", (60, 120, 210), slide)
badge("zone_swing", "КАЧЕЛИ", (225, 120, 40), swing)
print("DONE")
