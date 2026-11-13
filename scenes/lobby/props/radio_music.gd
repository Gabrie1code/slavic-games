class_name RadioMusic
extends AudioStreamPlayer
## Музыка из радио на полке. Не «3D-звук»: игроки смотрят через свои экраны (SubViewport), и
## 3D-звук там не слышно — раньше его слушала только общая камера под потолком, далеко от радио
## (поэтому музыки не было). Громкость считаем сами: чем ближе к радио глаза ближайшего игрока,
## тем громче. Включается и выключается кнопкой; разбили — замолкает, восстановилось — играет,
## если было включено.

const STREAM_PATH := "res://assets/audio/radio_music.wav"
const LOUD_DB := -6.0
## Общая громкость музыки: 10% от прежней (−20 дБ).
const VOLUME := 0.1
## Ближе NEAR м — в полную силу, дальше FAR м — не слышно.
const NEAR := 1.5
const FAR := 12.0

## Радио включено кнопкой (по умолчанию играет).
var switched_on := true

## Само радио на полке (Breakable).
var radio: Breakable


func _init(source: Breakable) -> void:
	radio = source
	var wav := load(STREAM_PATH) as AudioStreamWAV
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(wav.get_length() * wav.mix_rate)
	stream = wav
	volume_db = -80.0
	source.broken.connect(stop)
	source.restored.connect(_resume)


func _ready() -> void:
	_resume()


func _process(_delta: float) -> void:
	if not playing:
		return
	var dist := _listener_distance()
	var k := clampf(inverse_lerp(FAR, NEAR, dist), 0.0, 1.0)
	volume_db = LOUD_DB + linear_to_db(maxf(k * k * VOLUME, 0.0001))


## Кнопка у радио: выключить / включить.
func toggle() -> void:
	switched_on = not switched_on
	if switched_on:
		_resume()
	else:
		stop()


func _resume() -> void:
	if switched_on and is_inside_tree() and not radio.is_broken():
		play()


## Расстояние от радио до глаз ближайшего игрока (камеры от первого лица), иначе — до общей камеры.
func _listener_distance() -> float:
	var best := INF
	for node in get_tree().get_nodes_in_group(Mirror.VIEWER_GROUP):
		var camera := node as Camera3D
		if camera and camera.is_visible_in_tree():
			best = minf(best, camera.global_position.distance_to(radio.global_position))
	if best == INF:
		var main := get_viewport().get_camera_3d()
		if main:
			best = main.global_position.distance_to(radio.global_position) * 0.5
	return best
