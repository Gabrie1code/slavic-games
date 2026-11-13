"""Фоновая музыка лобби — несколько вариантов на выбор. Всё своё: звук собирается кодом из
синусов, шума и простых фильтров (никаких чужих записей и сэмплов) — можно использовать свободно.
Каждый вариант — бесшовная петля (хвосты нот заворачиваются в начало).

  disco  — «Ретро-диско»: бодрый ровный бит, пружинистый октавный бас, электропианино, синт-мелодия;
  bossa  — «Босса у телевизора»: мягкая босса-нова, септаккорды, флейта, щелчки по ободку;
  funk   — «Лёгкий фанк»: хлопки на 2 и 4, «клавинет» на слабые доли, прыгучий бас, орган;
  chip   — «Дворовый чиптюн»: весёлые арпеджио приглушёнными «квадратами», как старая приставка.

Запуск (Python 3 + numpy):
    python3 tools/audio/lobby_music.py disco out.wav [--rate 32000]
"""
import sys
import wave

import numpy as np

STYLE = sys.argv[1] if len(sys.argv) > 1 else "disco"
OUT = sys.argv[2] if len(sys.argv) > 2 else STYLE + ".wav"
RATE = int(sys.argv[sys.argv.index("--rate") + 1]) if "--rate" in sys.argv else 32000
rng = np.random.default_rng(7)

MAJOR = [0, 2, 4, 5, 7, 9, 11]


def hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)


# ---------------- Звуки ----------------

class Track:
    def __init__(self, bpm, bars):
        self.beat = 60.0 / bpm
        self.n = int(bars * 4 * self.beat * RATE)
        self.buf = np.zeros(self.n)

    def put(self, start_beat, sound, vol):
        start = int(start_beat * self.beat * RATE) % self.n
        idx = (start + np.arange(len(sound))) % self.n          # бесшовно: хвост — в начало
        np.add.at(self.buf, idx, sound * vol)


def env(length, attack=0.005, decay=3.0, release=0.05, sustain=None):
    t = np.arange(int(length * RATE)) / RATE
    e = np.minimum(1.0, t / attack) * np.exp(-t * decay)
    if sustain is not None:
        e = np.minimum(1.0, t / attack) * (sustain + (1 - sustain) * np.exp(-t * decay))
    tail = int(release * RATE)
    if tail and len(e) > tail:
        e[-tail:] *= np.linspace(1, 0, tail)
    return t, e


def epiano(f, length):
    t, e = env(length, 0.004, 2.2)
    bell = np.exp(-t * 9)
    return e * (np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t)
                + 0.18 * bell * np.sin(2 * np.pi * f * 7.0 * t))


def pluck(f, length, bright=0.5):
    t, e = env(length, 0.002, 5.0)
    return e * (np.sin(2 * np.pi * f * t) + bright * np.exp(-t * 14) * np.sin(6 * np.pi * f * t))


def bass(f, length, punch=0.6):
    t, e = env(length, 0.004, 3.5, 0.03)
    return e * (np.sin(2 * np.pi * f * t) + punch * np.exp(-t * 12) * np.sin(4 * np.pi * f * t))


def soft_square(f, length, decay=3.0):
    t, e = env(length, 0.004, decay)
    s = sum(np.sin(2 * np.pi * f * k * t) / k for k in (1, 3, 5, 7))   # квадрат без резкости
    return e * s * 0.7


def lead(f, length, vibrato=0.0):
    t, e = env(length, 0.02, 1.2, 0.06, sustain=0.6)
    ph = 2 * np.pi * f * t + vibrato * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t * 3)
    return e * (np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph))


def flute(f, length):
    t, e = env(length, 0.05, 0.6, 0.08, sustain=0.7)
    ph = 2 * np.pi * f * t + 0.012 * f * np.sin(2 * np.pi * 5 * t) / 5 * np.minimum(1, t * 2)
    breath = rng.normal(0, 0.04, len(t)) * e
    return e * (np.sin(ph) + 0.08 * np.sin(2 * ph)) + breath


def organ(f, length):
    t, e = env(length, 0.03, 0.2, 0.08, sustain=0.8)
    return e * (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(4 * np.pi * f * t)
                + 0.3 * np.sin(6 * np.pi * f * t))


def kick(length=0.35):
    t, e = env(length, 0.001, 9.0)
    f = 45 + 80 * np.exp(-t * 30)
    return e * np.sin(2 * np.pi * np.cumsum(f) / RATE)


def noise_hit(length, decay, color):
    t, e = env(length, 0.001, decay)
    n = rng.normal(0, 1, len(t))
    if color == "high":
        n = np.diff(n, prepend=0)          # выше — тоньше «тс»
    elif color == "mid":
        n = np.convolve(n, np.ones(3) / 3, "same")
    return n * e


def clap():
    s = noise_hit(0.2, 18, "mid")
    for d in (0.01, 0.02):
        s[int(d * RATE):] += noise_hit(0.2, 25, "mid")[: len(s) - int(d * RATE)] * 0.6
    return s


def rim():
    t, e = env(0.06, 0.0005, 60)
    return e * (np.sin(2 * np.pi * 1700 * t) + 0.5 * np.sin(2 * np.pi * 850 * t))


# ---------------- Музыкальные помощники ----------------

def chord_notes(root, kind):
    shape = {"maj": [0, 4, 7], "min": [0, 3, 7], "maj7": [0, 4, 7, 11], "min7": [0, 3, 7, 10],
             "dom7": [0, 4, 7, 10]}[kind]
    return [root + s for s in shape]


def melody(track, chords, motif, octave, voice, vol, key=60, start_bar=0, bars=None, beats_per=4):
    """Мотив (доля, длина в долях, ступень от первой ноты аккорда по мажорной гамме) повторяется
    на каждом аккорде — мелодия «следует» гармонии и легко запоминается."""
    bars = bars or len(chords)
    for b in range(bars):
        root, _ = chords[(start_bar + b) % len(chords)]
        degree0 = min(range(7), key=lambda d: abs((key + MAJOR[d]) % 12 - root % 12))
        for beat, length, step in motif[b % len(motif)]:
            d = degree0 + step
            note = key + 12 * (d // 7) + MAJOR[d % 7] + 12 * octave
            track.put((start_bar + b) * beats_per + beat, voice(hz(note), length * track.beat + 0.1),
                      vol)


def lowpass(x, a):
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):                # медленно, но надёжно; хватает на минуту музыки
        acc += (x[i] - acc) * a
        y[i] = acc
    return y


def room(x, delay=0.11, fb=0.28, mix=0.22):
    """Немного «комнаты»: несколько затухающих повторов (заворачиваются в начало петли)."""
    out = x.copy()
    d = int(delay * RATE)
    echo = x.copy()
    for k in range(1, 5):
        echo = np.roll(echo, d) * fb
        out += echo * mix * (1.0 / k)
    return out


# ---------------- Варианты ----------------

def style_disco():
    chords = [(48, "maj"), (45, "min"), (41, "maj"), (43, "maj")] * 2 + \
             [(50, "min"), (43, "maj"), (40, "min"), (45, "min"), (41, "maj"), (43, "maj"),
              (48, "maj"), (43, "maj")]
    tr = Track(112, 32)
    for bar in range(32):
        root, kind = chords[bar % 16]
        b = bar * 4
        for beat in range(4):
            tr.put(b + beat, kick(), 0.55)
            tr.put(b + beat + 0.5, noise_hit(0.08, 45, "high"), 0.07)       # хэт на слабую долю
            tr.put(b + beat + 0.5, bass(hz(root - 12 + 12), 0.2), 0.22)    # октавный бас
            tr.put(b + beat, bass(hz(root - 12), 0.22), 0.3)
        for beat in (1, 3):
            tr.put(b + beat, clap(), 0.16)
        for k, n in enumerate(chord_notes(root + 12, kind)):
            for beat in (0.5, 1.5, 2.5, 3.5):                              # «чак» на слабые
                tr.put(b + beat + k * 0.01, epiano(hz(n), 0.35), 0.05)
    motif = [[(0, 0.5, 4), (0.5, 0.5, 2), (1, 1, 0), (2.5, 0.5, 2), (3, 1, 4)],
             [(0, 1.5, 5), (1.5, 0.5, 4), (2, 0.5, 2), (2.5, 1.5, 0)],
             [(0, 0.5, 2), (0.5, 0.5, 4), (1, 0.5, 5), (1.5, 1.5, 7), (3.5, 0.5, 5)],
             [(0, 1, 4), (1, 1, 2), (2, 2, 1)]]
    melody(tr, chords, motif, 1, lambda f, l: lead(f, l, 0.2), 0.09, start_bar=8, bars=24)
    return tr, 0.5


def style_bossa():
    chords = [(41, "maj7"), (40, "min7"), (38, "min7"), (43, "dom7"),
              (48, "maj7"), (45, "min7"), (38, "min7"), (43, "dom7")]
    tr = Track(128, 32)
    for bar in range(32):
        root, kind = chords[(bar // 2) % 8]
        b = bar * 4
        notes = chord_notes(root + 12, kind)
        for beat in (0, 1.5, 2.5, 3.5) if bar % 2 == 0 else (0.5, 1.5, 2.5):
            for k, n in enumerate(notes):
                tr.put(b + beat + k * 0.012, pluck(hz(n), 0.6, 0.35), 0.06)
        tr.put(b, bass(hz(root - 12), 0.9, 0.2), 0.32)                   # бас босса-новы: 1 и «и» 2
        tr.put(b + 1.5, bass(hz(root - 5), 0.5, 0.2), 0.26)
        tr.put(b + 2, bass(hz(root - 12), 0.9, 0.2), 0.3)
        tr.put(b + 3.5, bass(hz(root - 5), 0.5, 0.2), 0.24)
        for beat in (0, 1.5, 3) if bar % 2 == 0 else (1, 2.5):
            tr.put(b + beat, rim(), 0.08)
        for beat in np.arange(0, 4, 0.5):
            tr.put(b + beat, noise_hit(0.05, 60, "high"), 0.025 + 0.02 * (beat % 1 == 0))
    motif = [[(0, 1, 4), (1, 0.5, 2), (1.5, 2.5, 6)],
             [(0.5, 0.5, 4), (1, 0.5, 3), (1.5, 0.5, 2), (2, 2, 0)]]
    melody(tr, [c for c in chords for _ in (0, 1)], motif, 1, flute, 0.09, key=60, start_bar=4,
           bars=28)
    return tr, 0.45


def style_funk():
    chords = [(45, "min7"), (45, "min7"), (50, "dom7"), (50, "dom7"),
              (45, "min7"), (45, "min7"), (52, "min7"), (50, "dom7")]
    tr = Track(100, 32)
    for bar in range(32):
        root, kind = chords[bar % 8]
        b = bar * 4
        tr.put(b, kick(), 0.5)
        tr.put(b + 2.75, kick(), 0.35)
        tr.put(b + 2, kick(), 0.45)
        for beat in (1, 3):
            tr.put(b + beat, clap(), 0.2)
        for beat in np.arange(0, 4, 0.25):
            tr.put(b + beat, noise_hit(0.04, 70, "high"), 0.02 + 0.025 * (beat % 0.5 == 0))
        line = [(0, 0), (0.75, 12), (1.5, 7), (2, 0), (2.5, 10), (3, 12), (3.5, 7)]
        for beat, step in line:
            tr.put(b + beat, bass(hz(root - 12 + step), 0.22, 0.9), 0.28)
        for beat in (0.5, 1.25, 2.5, 3.25):                               # «клавинет»
            for n in chord_notes(root + 12, kind):
                tr.put(b + beat, pluck(hz(n), 0.18, 0.9), 0.045)
        for n in chord_notes(root + 24, kind)[:3]:
            tr.put(b, organ(hz(n), 4 * tr.beat), 0.025)
    motif = [[(0, 0.5, 4), (0.75, 0.25, 5), (1, 1, 4), (2.5, 0.5, 2), (3, 0.5, 4)],
             [(0, 0.5, 6), (0.5, 0.5, 4), (1, 1.5, 2), (3, 0.5, 1)]]
    melody(tr, chords, motif, 1, lambda f, l: lead(f, l, 0.35), 0.075, key=60, start_bar=8,
           bars=24)
    return tr, 0.5


def style_chip():
    chords = [(48, "maj"), (43, "maj"), (45, "min"), (41, "maj"),
              (48, "maj"), (43, "maj"), (41, "maj"), (43, "maj")]
    tr = Track(120, 32)
    for bar in range(32):
        root, kind = chords[bar % 8]
        b = bar * 4
        notes = chord_notes(root + 12, kind) + [root + 24]
        for k, beat in enumerate(np.arange(0, 4, 0.25)):                  # арпеджио 16-ми
            tr.put(b + beat, soft_square(hz(notes[[0, 1, 2, 3, 2, 1][k % 6]]), 0.14, 8), 0.035)
        for beat in range(4):
            tr.put(b + beat, soft_square(hz(root - 12 + (7 if beat % 2 else 0)), 0.3, 6), 0.11)
            tr.put(b + beat + 0.5, noise_hit(0.04, 70, "high"), 0.04)
        tr.put(b, kick(0.25), 0.4)
        tr.put(b + 2, noise_hit(0.12, 30, "mid"), 0.12)
    motif = [[(0, 0.5, 0), (0.5, 0.5, 2), (1, 0.5, 4), (1.5, 0.5, 7), (2, 1.5, 4)],
             [(0, 0.5, 5), (0.5, 0.5, 4), (1, 0.5, 2), (1.5, 0.5, 4), (2, 2, 2)]]
    melody(tr, chords, motif, 1, lambda f, l: soft_square(f, l, 1.5), 0.07, start_bar=8, bars=24)
    return tr, 0.55


track, softness = {"disco": style_disco, "bossa": style_bossa, "funk": style_funk,
                   "chip": style_chip}[STYLE]()
mix = room(lowpass(track.buf, softness))       # тёплый, не режущий звук + немного комнаты
mix = np.tanh(mix / (np.max(np.abs(mix)) + 1e-9) * 1.6) # мягкое сжатие
mix = mix / np.max(np.abs(mix)) * 0.85
with wave.open(OUT, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes((mix * 32767).astype("<i2").tobytes())
print("DONE", STYLE, round(track.n / RATE, 1), "sec")
