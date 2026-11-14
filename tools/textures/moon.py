"""Луна для неба за окном: «реалистичный месяц» (вариант 2, выбран владельцем) — освещена
левая часть, на ней тёмные «моря» и мягкие кратеры; неосвещённая часть еле видна
(пепельный свет). Прозрачный фон.
Запуск: python3 tools/textures/moon.py  →  assets/textures/window/moon.png
"""
import numpy as np
from PIL import Image

N = 256
R = N / 2 - 4
ys, xs = np.mgrid[0:N, 0:N]
x, y = (xs - N / 2) / R, (ys - N / 2) / R
r = np.hypot(x, y)
rng = np.random.default_rng(4)


def noise(cell):
    g = rng.random((N // cell + 2, N // cell + 2))
    X, Y = xs / cell, ys / cell
    x0, y0 = X.astype(int), Y.astype(int)
    fx, fy = X - x0, Y - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = g[y0, x0] * (1 - fx) + g[y0, x0 + 1] * fx
    b = g[y0 + 1, x0] * (1 - fx) + g[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def sm(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


disc = 1 - sm(0.97, 1.0, r)
sphere = np.sqrt(np.clip(1 - r * r, 0, 1))
maria = sm(0.55, 0.72, noise(48) * 0.6 + noise(20) * 0.4)
craters = np.zeros_like(r)
for _ in range(18):                                                   # мягкие кратеры
    px, py, s = rng.uniform(-0.85, 0.85), rng.uniform(-0.85, 0.85), rng.uniform(0.04, 0.12)
    d = np.hypot(x - px, y - py) / s
    craters += np.exp(-((d - 1) ** 2) / 0.06) * 0.12 - np.exp(-(d ** 2) / 0.5) * 0.08
surface = 0.84 - 0.24 * maria + craters + (noise(6) - 0.5) * 0.05
lx = np.array([-0.85, 0.15, 0.5])
lx /= np.linalg.norm(lx)
light = sm(0.0, 0.22, np.clip(x * lx[0] - y * lx[1] + sphere * lx[2], 0, 1))
lit = np.array([0.96, 0.94, 0.86])[None, None] * (surface * (0.06 + 0.94 * light))[..., None]
ash = np.array([0.16, 0.18, 0.27]) * (1 - light)[..., None] * (0.7 + 0.3 * surface[..., None])
rgb = np.clip(lit + ash, 0, 1)
img = np.dstack([rgb, disc])
Image.fromarray((img * 255).astype(np.uint8), "RGBA").save("assets/textures/window/moon.png")
print("saved moon.png")
