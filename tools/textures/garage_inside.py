"""Внутренность открытого гаража (картинка-заглушка за приоткрытой створкой, 512 × 384):
полумрак, задняя стена в перспективе, бетонный пол с масляным пятном, полки с банками и
канистрой, стопка шин, велосипед у стены, лампочка под потолком с тёплым пятном света.
Запуск: python3 tools/textures/garage_inside.py  →  assets/textures/garage/garage_inside.png
"""
from PIL import Image, ImageDraw, ImageFilter

W, H = 512, 384
img = Image.new("RGB", (W, H), (34, 31, 28))
d = ImageDraw.Draw(img)
# Перспектива: задняя стена — прямоугольник в середине, к краям — боковые стены, пол, потолок.
bx0, by0, bx1, by1 = 120, 70, 392, 290
d.polygon([(0, 0), (W, 0), (bx1, by0), (bx0, by0)], fill=(44, 40, 36))           # потолок
d.polygon([(0, H), (W, H), (bx1, by1), (bx0, by1)], fill=(78, 76, 72))           # пол
d.polygon([(0, 0), (bx0, by0), (bx0, by1), (0, H)], fill=(58, 54, 49))           # левая стена
d.polygon([(W, 0), (bx1, by0), (bx1, by1), (W, H)], fill=(52, 48, 44))           # правая стена
d.rectangle((bx0, by0, bx1, by1), fill=(66, 62, 56))                              # задняя стена
for y in range(by0 + 18, by1, 22):                                                # кирпичная кладка
    d.line((bx0, y, bx1, y), fill=(58, 54, 49), width=2)
d.ellipse((190, 310, 330, 350), fill=(52, 50, 48))                                # масляное пятно
# Полки на задней стене: банки, краска, канистра.
for sy in (150, 210):
    d.rectangle((bx0 + 10, sy, bx0 + 170, sy + 6), fill=(110, 80, 50))
x = bx0 + 18
for c in ((150, 60, 40), (60, 90, 140), (180, 160, 60), (90, 120, 70), (140, 140, 140)):
    d.rectangle((x, 122, x + 20, 150), fill=c)
    d.rectangle((x, 182, x + 22, 210), fill=tuple(int(v * 0.8) for v in c))
    x += 30
d.rectangle((bx0 + 120, 176, bx0 + 160, 210), fill=(170, 50, 35))                 # канистра
d.rectangle((bx0 + 146, 170, bx0 + 156, 177), fill=(140, 40, 30))
# Стопка шин справа.
for k in range(4):
    y = by1 + 30 - k * 26
    d.ellipse((300, y - 14, 420, y + 14), fill=(22, 22, 24), outline=(40, 40, 42), width=3)
    d.ellipse((335, y - 5, 385, y + 5), fill=(30, 28, 26))
# Велосипед у левой стены.
for cx in (60, 150):
    d.ellipse((cx - 38, 250, cx + 38, 326), outline=(25, 25, 25), width=5)
d.line((60, 288, 105, 252, 150, 288), fill=(150, 40, 40), width=5)
d.line((105, 252, 92, 232), fill=(150, 40, 40), width=5)
d.line((60, 288, 92, 232), fill=(150, 40, 40), width=4)
d.line((140, 238, 160, 238), fill=(30, 30, 30), width=5)
# Лампочка и тёплое пятно света.
d.line((256, 0, 256, 40), fill=(30, 30, 30), width=2)
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
g = ImageDraw.Draw(glow)
for r, a in ((170, 30), (110, 40), (60, 60)):
    g.ellipse((256 - r, 50 - r * 0.7, 256 + r, 50 + r * 0.9), fill=(255, 200, 120, a))
glow = glow.filter(ImageFilter.GaussianBlur(18))
img.paste(glow, (0, 0), glow)
d = ImageDraw.Draw(img)
d.ellipse((247, 38, 265, 58), fill=(255, 235, 170))
img = img.filter(ImageFilter.GaussianBlur(0.8))
img.save("assets/textures/garage/garage_inside.png")
print("saved garage_inside.png")
