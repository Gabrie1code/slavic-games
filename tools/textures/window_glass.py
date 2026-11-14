"""Стекло обычных окон новых домов (атлас 4 × 2 = 8 вариантов, 256 × 256): отражение неба,
блики и приглушённо — комната за стеклом: обои с узором, шкаф, люстра, ковёр на стене,
полки с книгами, телевизор, кухонные шкафчики, тёмная комната. Однотонного голубого нет.
Запуск: python3 tools/textures/window_glass.py  →  assets/textures/city/window_glass.png
"""
import random
from PIL import Image, ImageDraw, ImageFilter

T = 256
img = Image.new("RGB", (T * 4, T * 2))
random.seed(77)


def tile(k):
    wall = random.choice([(150, 120, 90), (120, 130, 110), (140, 110, 120), (110, 120, 140)])
    t = Image.new("RGB", (T, T), tuple(int(c * 0.6) for c in wall))
    d = ImageDraw.Draw(t)
    dim = lambda c: tuple(int(v * 0.5 + 25) for v in c)
    if k in (0, 4):                                                     # обои с узором
        for y in range(10, T, 36):
            for x in range(10 + (y // 36 % 2) * 18, T, 36):
                d.ellipse((x, y, x + 8, y + 8), fill=dim((200, 190, 150)))
    if k == 0:                                                          # шкаф
        d.rectangle((140, 60, 250, 256), fill=dim((120, 80, 45)), outline=dim((70, 45, 25)), width=5)
    elif k == 1:                                                        # люстра
        d.line((128, 0, 128, 50), fill=dim((60, 60, 60)), width=3)
        d.polygon([(90, 50), (166, 50), (150, 85), (106, 85)], fill=dim((240, 220, 150)))
    elif k == 2:                                                        # ковёр на стене
        d.rectangle((40, 40, 220, 200), fill=dim((150, 40, 45)))
        d.rectangle((60, 60, 200, 180), outline=dim((220, 180, 90)), width=6)
        d.polygon([(130, 75), (180, 120), (130, 165), (80, 120)], outline=dim((40, 60, 120)), width=6)
    elif k == 3:                                                        # полки с книгами
        for sy in (90, 160, 230):
            d.rectangle((0, sy, 256, sy + 6), fill=dim((110, 80, 50)))
            x = 6
            while x < 240:
                w = random.randint(8, 16)
                d.rectangle((x, sy - random.randint(34, 52), x + w, sy),
                            fill=dim(random.choice([(170, 50, 40), (50, 90, 150), (60, 120, 60), (200, 170, 80)])))
                x += w + 2
    elif k == 4:                                                        # телевизор с голубым экраном
        d.rectangle((70, 130, 190, 230), fill=dim((60, 45, 30)))
        d.rectangle((84, 142, 176, 210), fill=(120, 160, 210))
    elif k == 5:                                                        # кухонные шкафчики
        d.rectangle((0, 20, 256, 110), fill=dim((220, 215, 200)))
        for x in range(0, 256, 64):
            d.rectangle((x + 4, 24, x + 60, 106), outline=dim((150, 140, 120)), width=4)
        d.rectangle((0, 170, 256, 256), fill=dim((200, 195, 180)))
    elif k == 6:                                                        # тёмная комната
        d.rectangle((0, 0, 256, 256), fill=(35, 38, 45))
    else:                                                               # фикус и торшер
        d.ellipse((30, 90, 130, 200), fill=dim((60, 120, 60)))
        d.rectangle((70, 195, 95, 256), fill=dim((150, 80, 40)))
        d.line((190, 256, 190, 110), fill=dim((80, 80, 80)), width=5)
        d.polygon([(160, 110), (220, 110), (205, 70), (175, 70)], fill=dim((230, 200, 120)))
    t = t.filter(ImageFilter.GaussianBlur(1.8))
    sky = Image.new("RGB", (T, T))                                      # отражение неба поверх
    sd = ImageDraw.Draw(sky)
    for y in range(T):
        f = y / T
        sd.line((0, y, T, y), fill=(int(170 - 70 * f), int(195 - 70 * f), int(215 - 60 * f)))
    t = Image.blend(t, sky, 0.35)
    gl = Image.new("RGBA", (T, T), (0, 0, 0, 0))                        # косые блики
    g = ImageDraw.Draw(gl)
    for _ in range(random.randint(1, 2)):
        x = random.randint(-40, 220)
        w = random.randint(12, 34)
        g.polygon([(x, 0), (x + w, 0), (x + w - 80, T), (x - 80, T)], fill=(255, 255, 255, 55))
    t.paste(gl, (0, 0), gl)
    return t


for k in range(8):
    img.paste(tile(k), ((k % 4) * T, (k // 4) * T))
img.save("assets/textures/city/window_glass.png")
print("saved window_glass.png")
