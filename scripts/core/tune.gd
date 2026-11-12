class_name Tune
extends RefCounted
## Короткие мелодии «из граммофона», собранные прямо в коде (без звуковых файлов):
## каждая нота — мягкий тон с затуханием, чуть «скрипучий», как старая пластинка.

const RATE := 22050
## Частоты нот (Гц).
const C5 := 523.25
const D5 := 587.33
const E5 := 659.25
const G5 := 783.99
const A4 := 440.0
const A5 := 880.0
## Мелодии по три ноты (из них выбирается случайная).
const MELODIES: Array = [
	[E5, G5, A5], [A4, C5, E5], [G5, E5, C5], [D5, E5, G5], [C5, C5, G5],
]


## Собрать звук из нот (по note_time сек каждая).
static func make(notes: Array, note_time: float = 0.32) -> AudioStreamWAV:
	var samples_per_note := int(RATE * note_time)
	var data := PackedByteArray()
	data.resize(samples_per_note * notes.size() * 2)
	var offset := 0
	for freq: float in notes:
		for i in samples_per_note:
			var t := float(i) / RATE
			var envelope := minf(1.0, t * 60.0) * exp(-t * 6.0) # быстрая атака, плавное затухание
			var tone := sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 2.0 * t) * 0.2
			var crackle := (randf() - 0.5) * 0.04 # шорох пластинки
			var value := clampf((tone * envelope + crackle) * 0.5, -1.0, 1.0)
			data.encode_s16(offset, int(value * 32767.0))
			offset += 2
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream


static func random_melody() -> AudioStreamWAV:
	return make(MELODIES.pick_random())
