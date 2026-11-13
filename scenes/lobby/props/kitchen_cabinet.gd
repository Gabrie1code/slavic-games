class_name KitchenCabinet
extends HingedProp
## Навесной шкафчик на кухне: правая дверца открывается («подтвердить» рядом, лицом к нему) и
## сама закрывается через OPEN_TIME сек (или закрыть рукой). Внутри — стопки и батон: часть
## модели, их не взять и не разбить. Модели — tools/blender/kitchen.py (kitchen_cabinet,
## kitchen_cabinet_door). Узел — в точке низа шкафчика на стене, «вперёд» — +Z.

const BODY := preload("res://assets/models/kitchen/kitchen_cabinet.glb")
const DOOR := preload("res://assets/models/kitchen/kitchen_cabinet_door.glb")
const OPEN_TIME := 15.0
const OPEN_ANGLE := deg_to_rad(100.0)
## Петля правой дверцы (правый край, перед шкафчиком) в координатах шкафчика.
const HINGE := Vector3(0.49, 0.0, 0.155)


func _ready() -> void:
	add_child(BODY.instantiate())
	door = DOOR.instantiate() as Node3D
	door.position = HINGE
	add_child(door)
	open_angle = OPEN_ANGLE
	open_time = OPEN_TIME
	open_text = "Открыть шкафчик"
	close_text = "Закрыть шкафчик"
	front_offset = Vector3(0.25, 0.3, 0.35) # перед правой дверцей
	# Корпус твёрдый: о шкафчик стукаются, прыгая у стены.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.62, 0.32)
	shape.shape = box
	shape.position = Vector3(0, 0.31, 0)
	body.add_child(shape)
	add_child(body)
