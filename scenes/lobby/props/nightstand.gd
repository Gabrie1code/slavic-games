class_name Nightstand
extends StaticBody3D
## Тумбочка в спальне с выдвижным ящиком. «Подтвердить» — ящик выдвигается и «ломается» на
## OPEN_TIME сек (кнопки открыть нет). В открытом ящике лежит баллончик — его можно взять.
## Когда ящик сам задвинется, в нём снова лежит баллончик (если прежний забрали — новый),
## так что баллончиков в квартире может быть несколько.
## С шансом JOKE_CHANCE вместо баллончика в ящике шутка (розовый «предмет» и наручники) —
## взять нельзя; после следующего закрытия ящика — новая попытка.
## Модели — tools/blender/nightstand.py.

const BODY := preload("res://assets/models/apartment/nightstand_body.glb")
const DRAWER := preload("res://assets/models/apartment/nightstand_drawer.glb")
const OPEN_TIME := 25.0
const JOKE := preload("res://assets/models/apartment/drawer_joke.glb")
const JOKE_CHANCE := 0.1
const JOKE_POS := Vector3(0.0, 0.345, 0.02)
const SLIDE := 0.25
## Баллончик лежит на боку на дне ящика (в координатах ящика).
const CAN_POS := Vector3(-0.1, 0.378, 0.02)
const CAN_ROT := Vector3(0.0, 0.3, -PI / 2.0)

## Баллончик в ящике (null — забрали, новый появится, когда ящик задвинется).
var can: SprayCan

var _drawer: Node3D
## Шутка в ящике вместо баллончика (null — её нет).
var _joke: Node3D
## Ящик открывали — когда закроется, содержимое обновится.
var _restock_on_close := false
var _time := 0.0
var _open_until := -1.0


func _ready() -> void:
	add_child(BODY.instantiate())
	_drawer = DRAWER.instantiate() as Node3D
	add_child(_drawer)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45, 0.6, 0.4)
	shape.shape = box
	shape.position.y = 0.3
	add_child(shape)
	_restock()


func _process(delta: float) -> void:
	_time += delta
	var target := SLIDE if is_open() else 0.0
	_drawer.position.z = move_toward(_drawer.position.z, target, delta * 1.2)
	if _restock_on_close and not is_open() and _drawer.position.z == 0.0:
		_restock_on_close = false
		if can == null or _joke != null:
			_restock()


func is_open() -> bool:
	return _time < _open_until


## Открыть можно, только когда ящик закрыт (открытый «сломан» на OPEN_TIME сек).
func can_open() -> bool:
	return not is_open() and _drawer.position.z == 0.0


func open() -> void:
	if can_open():
		_open_until = _time + OPEN_TIME
		_restock_on_close = true


## Взять баллончик можно из открытого (уже выдвинутого) ящика.
func can_take() -> bool:
	return is_open() and can != null and _drawer.position.z > SLIDE * 0.6


## Забрать баллончик из ящика (дальше им распоряжается тот, кто взял).
func take_can() -> SprayCan:
	var taken := can
	can = null
	return taken


## В открытом ящике шутка вместо баллончика.
func shows_joke() -> bool:
	return is_open() and _joke != null


## Где ящик (для зоны кнопки).
func front_point() -> Vector3:
	return to_global(Vector3(0, 0.4, 0.3))


func _restock() -> void:
	if _joke:
		_joke.queue_free()
		_joke = null
	if randf() < JOKE_CHANCE:
		_joke = JOKE.instantiate() as Node3D
		_joke.position = JOKE_POS
		_joke.rotation.y = randf_range(-0.3, 0.3)
		_drawer.add_child(_joke)
		return
	can = SprayCan.new()
	_drawer.add_child(can)
	can.store_in(_drawer, CAN_POS, CAN_ROT)
