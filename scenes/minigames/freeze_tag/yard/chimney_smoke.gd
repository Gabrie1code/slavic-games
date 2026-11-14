class_name ChimneySmoke
extends Node3D
## Дым из трубы ТЭЦ: клубы (картинка smoke_puff.png, всегда повёрнуты к игроку) по очереди
## выходят из трубы, поднимаются, растут, относятся ветром в сторону и тают. Узел ставится
## на верх трубы.

const PUFF := preload("res://assets/textures/sky/smoke_puff.png")
const PUFFS := 12
## Сколько живёт один клуб (сек), насколько поднимается и куда его сносит ветер (м).
const LIFE := 14.0
const RISE := 28.0
const WIND := Vector3(-30.0, 0, -14.0) # в сторону открытого неба (если смотреть со двора)
## Размер клуба: в начале и в конце (м).
const SIZE := Vector2(7.0, 26.0)

## Цвет дыма (в дождь — темнее).
var tint := Color(0.86, 0.86, 0.88)
var _puffs: Array[Sprite3D] = []
var _time := 0.0


func _ready() -> void:
	for i in PUFFS:
		var puff := Sprite3D.new()
		puff.texture = PUFF
		puff.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		puff.shaded = false
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.flip_h = i % 2 == 1
		add_child(puff)
		_puffs.append(puff)
	_process(0.0)


func _process(delta: float) -> void:
	_time += delta
	for i in _puffs.size():
		var t := fmod(_time / LIFE + float(i) / PUFFS, 1.0) # 0 — только вышел, 1 — растаял
		var puff := _puffs[i]
		puff.position = Vector3(WIND.x * t * t, RISE * sqrt(t), WIND.z * t)
		puff.pixel_size = lerpf(SIZE.x, SIZE.y, t) / float(PUFF.get_width())
		var alpha := minf(t / 0.08, 1.0) * (1.0 - smoothstep(0.55, 1.0, t))
		puff.modulate = Color(tint, alpha * 0.85)
