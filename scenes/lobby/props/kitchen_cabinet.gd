class_name KitchenCabinet
extends Node3D
## Навесной шкафчик на кухне: правая дверца открывается («подтвердить» рядом, лицом к нему) и
## сама закрывается через OPEN_TIME сек (или закрыть рукой). Внутри — стопки и батон: часть
## модели, их не взять и не разбить. Модели — tools/blender/kitchen.py (kitchen_cabinet,
## kitchen_cabinet_door). Узел — в точке низа шкафчика на стене, «вперёд» — +Z.

const BODY := preload("res://assets/models/kitchen/kitchen_cabinet.glb")
const DOOR := preload("res://assets/models/kitchen/kitchen_cabinet_door.glb")
const OPEN_TIME := 10.0
const OPEN_ANGLE := deg_to_rad(100.0)
## Петля правой дверцы (правый край, перед шкафчиком) в координатах шкафчика.
const HINGE := Vector3(0.49, 0.0, 0.155)

var _door: Node3D
var _open := false
var _close_at := 0.0
var _time := 0.0


func _ready() -> void:
	add_child(BODY.instantiate())
	_door = DOOR.instantiate() as Node3D
	_door.position = HINGE
	add_child(_door)
	# Корпус твёрдый: о шкафчик стукаются, прыгая у стены.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.62, 0.32)
	shape.shape = box
	shape.position = Vector3(0, 0.31, 0)
	body.add_child(shape)
	add_child(body)


func _process(delta: float) -> void:
	_time += delta
	if _open and _time >= _close_at:
		_open = false # «восстановление»: дверца закрывается сама
	_door.rotation.y = move_toward(_door.rotation.y, OPEN_ANGLE if _open else 0.0, delta * 4.0)


func can_open() -> bool:
	return not _open and _door.rotation.y == 0.0


func can_close() -> bool:
	return _open and _door.rotation.y > OPEN_ANGLE * 0.9


func open() -> void:
	_open = true
	_close_at = _time + OPEN_TIME


func close() -> void:
	_open = false


## Куда подходить и смотреть (перед правой дверцей, на высоте её середины).
func front_point() -> Vector3:
	return to_global(Vector3(0.25, 0.3, 0.6))
