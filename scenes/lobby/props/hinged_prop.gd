class_name HingedProp
extends Node3D
## Вещь с дверцей на петле (шкафчик на кухне, духовка): «подтвердить» рядом — открыть / закрыть.
## Дверца плавно поворачивается вокруг оси петли: Y — вбок (шкафчик), X — вниз (духовка).
## open_time > 0 — дверца сама закрывается через столько секунд («восстановление»).
## Наследник в _ready ставит door (узел дверцы с началом на петле) и настройки.

## Узел дверцы (поворачивается).
var door: Node3D
var open_angle := deg_to_rad(100.0)
## Петля вертикальная (поворот вокруг Y) или горизонтальная снизу (вокруг X).
var swing_x := false
var open_time := 0.0
## Подсказки у кнопки.
var open_text := "Открыть"
var close_text := "Закрыть"
## Куда подходить и смотреть (в координатах вещи).
var front_offset := Vector3.ZERO

## Перезарядка: после открытия/закрытия столько секунд нельзя снова (духовка — 2 сек).
var cooldown := 0.0
var _ready_at := 0.0

var _open := false
var _close_at := 0.0
var _time := 0.0


func _process(delta: float) -> void:
	if door == null:
		return
	_time += delta
	if _open and open_time > 0.0 and _time >= _close_at:
		_open = false # «восстановление»: дверца закрывается сама
	var target := open_angle if _open else 0.0
	var now := door.rotation.x if swing_x else door.rotation.y
	now = move_toward(now, target, delta * 4.0)
	if swing_x:
		door.rotation.x = now
	else:
		door.rotation.y = now
	_door_moved(now / open_angle)


## Дверца повернулась: 0 — закрыта, 1 — открыта настежь (наследник может включать свет).
func _door_moved(_amount: float) -> void:
	pass


func _angle() -> float:
	return door.rotation.x if swing_x else door.rotation.y


func can_open() -> bool:
	return door != null and not _open and _angle() == 0.0 and _time >= _ready_at


func can_close() -> bool:
	return door != null and _open and _angle() > open_angle * 0.9 and _time >= _ready_at


func open() -> void:
	_open = true
	_close_at = _time + open_time
	_ready_at = _time + cooldown


func close() -> void:
	_open = false
	_ready_at = _time + cooldown


func front_point() -> Vector3:
	return to_global(front_offset)
