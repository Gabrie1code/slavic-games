"""Спокойная фоновая музыка для радио в квартире — без слов, своя (собирается из синусов кодом,
никаких чужих записей, авторских прав нет). Тёплое «электропианино» по аккордам Am–F–C–G,
мягкий бас, неспешная мелодия в ля-миноре, тихий шорох эфира; звук чуть «радийный» (глуше).
Петля бесшовная (хвосты нот заворачиваются в начало).

Запуск (обычный Python 3, без библиотек):
    python3 tools/audio/radio_music.py assets/audio/radio_music.wav
"""
import math
import random
import struct
import sys
import wave

OUT = sys.argv[1] if len(sys.argv) > 1 else "radio_music.wav"
RATE = 22050
BPM = 80
BEAT = 60.0 / BPM
random.seed(12)


def freq(note):
    """Номер ноты по MIDI → частота (A4 = 69 = 440 Гц)."""
    return 440.0 * 2 ** ((note - 69) / 12)


CHORDS = [  # (корень баса, ноты аккорда) — Am, F, C, G, и ещё раз с другим окончанием
    (45, [57, 60, 64]), (41, [57, 60, 65]), (48, [55, 60, 64]), (43, [55, 59, 62]),
    (45, [57, 60, 64]), (41, [57, 60, 65]), (43, [55, 59, 62]), (40, [56, 59, 64]),
]
BARS_PER_CHORD = 2
TOTAL_BEATS = len(CHORDS) * BARS_PER_CHORD * 4
N = int(TOTAL_BEATS * BEAT * RATE)
buf = [0.0] * N


def add_note(start_beat, f, length, volume, brightness=0.25, decay=2.5):
    start = int(start_beat * BEAT * RATE)
    count = int(length * RATE)
    for i in range(count):
        t = i / RATE
        env = min(1.0, t * 40) * math.exp(-t * decay)
        v = math.sin(math.tau * f * t) + brightness * math.sin(math.tau * f * 2 * t) \
            + 0.08 * math.sin(math.tau * f * 3 * t)
        buf[(start + i) % N] += v * env * volume                # хвост заворачивается в начало


PENTA = [57, 60, 62, 64, 67, 69, 72]                              # ля-минор пентатоника
for c, (root, chord) in enumerate(CHORDS):
    base = c * BARS_PER_CHORD * 4
    for bar in range(BARS_PER_CHORD):
        b = base + bar * 4
        for beat in (0, 2):                                       # аккорд — на 1 и 3 доли
            for k, n in enumerate(chord):
                add_note(b + beat + k * 0.03, freq(n), 2.2, 0.09)
        for beat in range(4):                                     # бас — каждую долю, мягко
            add_note(b + beat, freq(root - 12 if beat % 2 else root), 0.9, 0.16, 0.1, 4.0)
        # Мелодия: иногда восьмые, иногда пауза; ноты рядом с предыдущей — получается напевно.
        note = random.choice(PENTA)
        for step in range(8):
            if random.random() < 0.45:
                idx = max(0, min(len(PENTA) - 1, PENTA.index(note) + random.choice([-1, 0, 1, 1])))
                note = PENTA[idx]
                add_note(b + step * 0.5, freq(note + 12), 0.8, 0.07, 0.35, 3.5)

# Шорох эфира и «радийный» звук: тихий шум, простой фильтр низких частот.
for i in range(N):
    buf[i] += (random.random() - 0.5) * 0.012
lp = 0.0
for _ in range(2):
    for i in range(N):
        lp += (buf[i] - lp) * 0.35
        buf[i] = lp
peak = max(abs(v) for v in buf) or 1.0
with wave.open(OUT, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(b"".join(struct.pack("<h", int(v / peak * 0.8 * 32767)) for v in buf))
print("DONE", round(N / RATE, 1), "sec")
