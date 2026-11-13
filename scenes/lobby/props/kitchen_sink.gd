class_name KitchenSink
extends Sink
## Мойка на кухне: всё как у рукомойника в туалете (Sink) — «подтвердить» у кранов: вентили
## (красная метка — горячая, синяя — холодная) крутятся, бьёт струя, прямоугольная стальная чаша
## наполняется, с персонажа смывается краска; раз в 15 сек каждому. Губка — как в туалете: лежит
## на столешнице справа от чаши, взяли — новая через 15 сек.
## Модель — tools/blender/kitchen.py (kitchen_sink: KitchenSinkBody, TapHot, TapCold, SinkWater).
## Координаты — модели (мойка смотрит на +Z, чаша слева: x −0.36..0.06).

const KITCHEN_MODEL := preload("res://assets/models/kitchen/kitchen_sink.glb")


func _init() -> void:
	model_scene = KITCHEN_MODEL
	nozzle = Vector3(-0.15, 1.015, -0.045)
	water_low = 0.66
	water_high = 0.8
	funnel = false
	front_offset = Vector3(-0.15, 0.9, 0.35)
	stand_offset = Vector3(-0.15, 0, 0.8)
	body_size = Vector3(1.0, 0.87, 0.62)
	body_center = Vector3(0, 0.435, 0)
	sponge_spot = Vector3(0.2, 0.862, 0.12) # столешница справа от чаши, ближе к краю
