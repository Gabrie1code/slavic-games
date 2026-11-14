class_name Nightstand
extends StaticBody3D
## Тумбочка в спальне с выдвижным ящиком. «Подтвердить» — ящик выдвигается и «ломается» на
## OPEN_TIME сек (кнопки открыть нет). В открытом ящике лежит баллончик — его можно взять.
## Когда ящик сам задвинется, в нём снова лежит баллончик (если прежний забрали — новый),
## так что баллончиков в квартире может быть несколько.
## С шансом JOKE_CHANCE вместо баллончика в ящике шутка (розовый «предмет» с пиксельной
## «цензурой» на кончике, наручники, пара презервативов) —
## взять нельзя; после следующего закрытия ящика — новая попытка.
## Модели — tools/blender/nightstand.py.

const BODY := preload("res://assets/models/apartment/nightstand_body.glb")
const DRAWER := preload("res://assets/models/apartment/nightstand_drawer.glb")
const OPEN_TIME := 25.0
const JOKE := preload("res://assets/models/apartment/drawer_joke.glb")
const JOKE_CHANCE := 0.1
const JOKE_POS := Vector3(0.0, 0.345, 0.02)
## «Цензура» над кончиком предмета: плашки из крупных пикселей (как в передачах, где что-то скрыто).
const CENSOR := preload("res://assets/textures/fx/censor_mosaic.png")
const CENSOR_SHADER := preload("res://scenes/lobby/props/censor_mosaic.gdshader")
const CENSOR_POS := Vector3(0.062, 0.052, 0.0) # чуть выше верха кончика (0.045)
const SLIDE := 0.25
## Баллончик лежит на боку на дне ящика (в координатах ящика).
## Ровно посередине ящика, поперёк (баллончик длиной ~0.19 м: дно слева, сопло справа).
const CAN_POS := Vector3(-0.097, 0.378, 0.035)
const CAN_ROT := Vector3(0.0, 0.0, -PI / 2.0)

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
		_joke.add_child(_make_censor())
		_drawer.add_child(_joke)
		return
	can = SprayCan.new()
	_drawer.add_child(can)
	can.store_in(_drawer, CAN_POS, CAN_ROT)


## «Цензура» вокруг кончика: плашки из крупных пикселей сверху и по бокам (видно и сверху, и
## присев), пиксели переливаются оттенками (censor_mosaic.gdshader). Сам предмет не меняется.
## Плашки: [размер, место, поворот] относительно CENSOR_POS (кончик — на 3 см ниже, у x ≈ 0).
static func _make_censor() -> Node3D:
	var root := Node3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = CENSOR_SHADER
	mat.set_shader_parameter("mosaic", CENSOR)
	var pieces: Array = [
		[Vector2(0.075, 0.06), Vector3(0, 0, 0), Vector3(-PI / 2, 0, 0)], # сверху
		[Vector2(0.045, 0.036), Vector3(-0.022, 0.003, 0.018), Vector3(-PI / 2, 0.35, 0)],
		[Vector2(0.065, 0.046), Vector3(0.004, -0.028, 0.031), Vector3.ZERO], # бока
		[Vector2(0.065, 0.046), Vector3(0.004, -0.028, -0.031), Vector3.ZERO],
		[Vector2(0.06, 0.046), Vector3(0.034, -0.028, 0), Vector3(0, PI / 2, 0)], # торец
	]
	for spec: Array in pieces:
		var piece := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = spec[0]
		piece.mesh = quad
		piece.material_override = mat
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.position = spec[1]
		piece.rotation = spec[2]
		root.add_child(piece)
	root.position = CENSOR_POS
	return root
