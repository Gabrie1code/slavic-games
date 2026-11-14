"""Облака для неба вокруг дворов (прозрачный фон): объёмные — «плотность» из множества шапок
с шумом по краям, свет сверху (светлый верх, серо-голубая тень снизу и внутри), мягкие края.
  cloud_cumulus_a.png — большое кучевое «барашком»;
  cloud_cumulus_b.png — кучевое пошире, с плоским дном и несколькими шапками;
  cloud_cirrus.png    — перистые полосы-«хвосты» (высоко, полупрозрачные);
  cloud_stratus.png   — длинное слоистое облако-пелена;
  smoke_puff.png      — клуб дыма из трубы ТЭЦ (серый, мягкий; в игре растёт и тает).
Запуск (Python с Pillow и numpy):
    python3 tools/textures/sky_clouds.py assets/textures/sky
"""
import os
import sys

import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
LIT = np.array([1.0, 1.0, 1.0])
SHADE = np.array([0.6, 0.64, 0.72])


def value_noise(w, h, cell, rng):
    """Гладкий шум: случайная сетка, растянутая с плавной интерполяцией."""
    gw, gh = w // cell + 2, h // cell + 2
    grid = rng.random((gh, gw))
    ys, xs = np.mgrid[0:h, 0:w] / cell
    x0, y0 = xs.astype(int), ys.astype(int)
    fx, fy = xs - x0, ys - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = grid[y0, x0] * (1 - fx) + grid[y0, x0 + 1] * fx
    b = grid[y0 + 1, x0] * (1 - fx) + grid[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def fbm(w, h, rng, base=96, octaves=4):
    total, amp, norm = np.zeros((h, w)), 1.0, 0.0
    for k in range(octaves):
        total += value_noise(w, h, max(4, base >> k), rng) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def cloud(w, h, blobs, seed, flat_bottom=None, stretch=1.0, soft=(0.35, 0.7), noise=0.45,
          shade=0.85, alpha_max=0.96, tint=1.0):
    """blobs: (cx, cy, r) в долях картинки. Возвращает RGBA-картинку."""
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:h, 0:w]
    u, v = xs / w, ys / h
    dens = np.zeros((h, w))
    for cx, cy, r in blobs:
        d2 = ((u - cx) * w / (h * stretch)) ** 2 + (v - cy) ** 2
        dens += np.exp(-d2 / (r * r))
    n = fbm(w, h, rng)
    dens = dens * (1 - noise + noise * 2 * n)
    if flat_bottom is not None:                                         # плоское дно
        dens *= np.clip((flat_bottom - v) / 0.04, 0, 1)
    alpha = np.clip((dens - soft[0]) / (soft[1] - soft[0]), 0, 1)
    alpha = alpha * alpha * (3 - 2 * alpha)
    # Свет сверху: чем больше облака выше точки, тем она темнее (самотень).
    shift = int(h * 0.05)
    above = np.zeros_like(dens)
    above[shift:] = dens[:-shift]
    shadow = np.clip(above - 0.3, 0, 1) * 0.42 * shade                  # мягкая самотень
    top = max(0.0, min(b[1] - b[2] for b in blobs))
    bottom = np.clip((v - top) / max(0.05, 0.95 - top), 0, 1) ** 2 * 0.35  # низ облака серее
    light = np.clip(1 - shadow - bottom + n * 0.12, 0, 1)
    rgb = (SHADE[None, None, :] * (1 - light[..., None]) + LIT[None, None, :] * light[..., None]) * tint
    out = np.dstack([np.clip(rgb, 0, 1), alpha * alpha_max])
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def save(img, name):
    img.save(os.path.join(OUT, name + ".png"))
    print("SAVED", name)


rng = np.random.default_rng(5)


def cauliflower(cx, base_y, width, height, n, r0, r1):
    """Шапки по верхнему краю купола (как у кучевого облака-«кочана»)."""
    out = []
    for k in range(n):
        a = np.pi * (k + 0.5) / n
        out.append((cx + np.cos(a) * width * rng.uniform(0.85, 1.0),
                    base_y - np.sin(a) * height * rng.uniform(0.8, 1.0), rng.uniform(r0, r1)))
    return out


# Кучевое «барашком»: тело-купол, много шапок по верху, плоское дно.
blobs = [(0.5, 0.58, 0.2), (0.33, 0.64, 0.14), (0.67, 0.64, 0.15)]
blobs += cauliflower(0.5, 0.66, 0.3, 0.36, 22, 0.05, 0.09)
blobs += cauliflower(0.5, 0.62, 0.18, 0.22, 10, 0.06, 0.09)
save(cloud(1024, 512, blobs, 11, flat_bottom=0.84), "cloud_cumulus_a")

# Кучевое пошире: три купола рядом на общем плоском дне.
blobs = []
for cx, wd, ht in ((0.25, 0.14, 0.22), (0.5, 0.18, 0.3), (0.74, 0.13, 0.2)):
    blobs.append((cx, 0.68, wd * 0.8))
    blobs += cauliflower(cx, 0.72, wd, ht, 11, 0.04, 0.07)
save(cloud(1024, 512, blobs, 12, flat_bottom=0.8, stretch=1.2), "cloud_cumulus_b")

# Перистые: длинные мягкие волокна, полупрозрачные, почти без тени.
blobs = []
for k in range(6):
    y0 = rng.uniform(0.25, 0.8)
    x0 = rng.uniform(0.05, 0.25)
    for i in range(26):
        t = i / 25
        blobs.append((x0 + 0.65 * t, y0 - 0.12 * t * t + 0.02 * np.sin(t * 9 + k), 0.03 * (1 - t) + 0.02))
save(cloud(1024, 512, blobs, 13, stretch=3.0, soft=(0.2, 1.1), noise=0.7, shade=0.15,
           alpha_max=0.6), "cloud_cirrus")

blobs = [(0.05 + k * 0.1, 0.5 + rng.uniform(-0.05, 0.05), rng.uniform(0.09, 0.13)) for k in range(10)]
blobs += [(0.05 + k * 0.05, 0.42 + rng.uniform(-0.04, 0.02), 0.05) for k in range(19)]
save(cloud(1024, 512, blobs, 14, stretch=2.2, soft=(0.3, 0.8), shade=0.5, alpha_max=0.9), "cloud_stratus")

# Клуб дыма: серый, мягкий, без плоского дна.
blobs = [(0.5 + rng.uniform(-0.18, 0.18), 0.5 + rng.uniform(-0.16, 0.16), rng.uniform(0.13, 0.2)) for _ in range(9)]
save(cloud(512, 512, blobs, 16, soft=(0.3, 0.8), noise=0.55, shade=0.6, alpha_max=0.88, tint=0.86),
     "smoke_puff")
