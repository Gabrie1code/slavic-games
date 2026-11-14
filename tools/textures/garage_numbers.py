"""Таблички с номерами гаражей (как номер квартиры): атлас 6 × 1, белая эмаль, синяя кайма,
чёрные цифры. Номер приоткрытого (4-го) гаража — 57.
Запуск: python3 tools/textures/garage_numbers.py  →  assets/textures/city/garage_numbers.png
"""
from PIL import Image, ImageDraw, ImageFont

NUMBERS = [12, 34, 41, 57, 63, 78]
CW, CH = 200, 120
img = Image.new("RGB", (CW * len(NUMBERS), CH), (240, 238, 230))
d = ImageDraw.Draw(img)
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 78)
for i, n in enumerate(NUMBERS):
    x0 = i * CW
    d.rounded_rectangle((x0 + 6, 6, x0 + CW - 6, CH - 6), 12, outline=(30, 60, 140), width=8)
    d.text((x0 + CW / 2, CH / 2 + 2), str(n), font=font, fill=(20, 20, 24), anchor="mm")
img.save("assets/textures/city/garage_numbers.png")
print("saved garage_numbers.png")
