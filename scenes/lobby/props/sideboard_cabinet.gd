class_name SideboardCabinet
extends Node3D
## Сервант в гостиной (сама модель и столкновения — в Apartment): стеклянные дверцы наверху
## (не открываются) и правая дверца тумбы. «Подтвердить» у тумбы — открыть / закрыть дверцу.
## Сквозь открытую дверцу не пройти (у неё своё тело). Через OPEN_TIME сек после открытия тумба
## «восстанавливается»: дверца сама закрывается и, если молоток забрали, на полке лежит новый.
## Закрыть дверцу рукой можно в любой момент — но это не восстановление (новый молоток не появится).
## Внутри двойная полка, на нижней — молоток (Hammer).
## Узел ставится в точку серванта; координаты ниже — от неё (Blender → Godot: z = −y).

const DOOR := preload("res://assets/models/apartment/sideboard_door.glb")
const OPEN_TIME := 25.0
const OPEN_ANGLE := deg_to_rad(100.0)
## Петля правой дверцы тумбы (правый край, перед тумбой).
const HINGE := Vector3(0.975, 0.5, 0.255)
## Молоток лежит на нижней полке поперёк отделения.
const HAMMER_POS := Vector3(0.66, 0.122, 0.0)
const HAMMER_ROT := Vector3(0.0, 0.25, PI / 2.0) # лежит на боку, ручкой вправо, бойком влево
## Верх серванта со стеклом: x ±0.97, высота 0.95..2.14, передний край по z.
const GLASS_Z := 0.248
const GLASS_BOTTOM := 0.97
const GLASS_TOP := 2.13

## Молоток в тумбе (null — забрали, новый появится, когда дверца закроется).
var hammer: Hammer

var _door: Node3D
var _time := 0.0
## Дверца открыта (её открыли и ещё не закрыли — рукой или само восстановление).
var _door_open := false
## Когда тумба «восстановится» (−1 — не ждём).
var _restore_at := -1.0
var _restock_on_close := false


func _ready() -> void:
	_door = DOOR.instantiate() as Node3D
	_door.position = HINGE
	add_child(_door)
	# Тело дверцы: двигается вместе с ней, сквозь открытую не пройти.
	var body := AnimatableBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.95, 0.8, 0.03)
	shape.shape = box
	shape.position = Vector3(-0.475, 0.0, 0.0)
	body.add_child(shape)
	_door.add_child(body)
	_build_glass()
	_restock()


func _process(delta: float) -> void:
	_time += delta
	if _restore_at >= 0.0 and _time >= _restore_at: # восстановление: сама закрывается
		_restore_at = -1.0
		_door_open = false
		_restock_on_close = true
	var target := OPEN_ANGLE if _door_open else 0.0
	_door.rotation.y = move_toward(_door.rotation.y, target, delta * 4.0)
	if _restock_on_close and not _door_open and _door.rotation.y == 0.0:
		_restock_on_close = false
		if hammer == null or not is_instance_valid(hammer):
			_restock()


func is_open() -> bool:
	return _door_open


func can_open() -> bool:
	return not _door_open and _door.rotation.y == 0.0


## Закрыть рукой — когда дверца уже распахнулась.
func can_close() -> bool:
	return _door_open and _door.rotation.y > OPEN_ANGLE * 0.9


func open() -> void:
	if not can_open():
		return
	_door_open = true
	if _restore_at < 0.0:
		_restore_at = _time + OPEN_TIME # отсчёт до восстановления — с первого открытия


func close() -> void:
	if can_close():
		_door_open = false # просто закрыли: не восстановление, новый молоток не появится


## Взять молоток можно, когда дверца уже распахнулась.
func can_take() -> bool:
	return _door_open and hammer != null and is_instance_valid(hammer) \
		and hammer.state == Hammer.State.STORED and _door.rotation.y > OPEN_ANGLE * 0.6


func take_hammer() -> Hammer:
	var taken := hammer
	hammer = null
	return taken


## Где тумба (для зоны кнопки).
func front_point() -> Vector3:
	return to_global(Vector3(0.5, 0.5, 0.6))


func _restock() -> void:
	hammer = Hammer.new()
	add_child(hammer)
	hammer.store_in(self, HAMMER_POS, HAMMER_ROT)


## Две стеклянные дверцы в рамках перед полками с сервизом (не открываются).
func _build_glass() -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.82, 0.92, 0.96, 0.16)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.04
	glass.metallic = 0.2
	glass.metallic_specular = 0.8
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color(0.4, 0.2, 0.08)
	frame.roughness = 0.45
	var height := GLASS_TOP - GLASS_BOTTOM
	var mid_y := (GLASS_BOTTOM + GLASS_TOP) / 2.0
	for x: float in [-0.485, 0.485]:
		_box(Vector3(0.93, height - 0.05, 0.006), Vector3(x, mid_y, GLASS_Z), glass, false)
		for side: float in [-1.0, 1.0]:
			_box(Vector3(0.035, height, 0.025), Vector3(x + side * 0.47, mid_y, GLASS_Z), frame)
			_box(Vector3(0.97, 0.035, 0.025), Vector3(x, mid_y + side * (height / 2.0), GLASS_Z),
				frame)
		# Маленькая латунная ручка у середины (дверцы «закрыты на ключ» — не открываются).
		var knob := StandardMaterial3D.new()
		knob.albedo_color = Color(0.8, 0.65, 0.3)
		knob.metallic = 0.35
		knob.roughness = 0.3
		_box(Vector3(0.02, 0.06, 0.02), Vector3(x - signf(x) * 0.43, mid_y, GLASS_Z + 0.02), knob)


func _box(size: Vector3, pos: Vector3, mat: Material, shadow: bool = true) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	if not shadow:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
