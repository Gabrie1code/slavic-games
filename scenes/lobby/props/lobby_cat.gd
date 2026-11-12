class_name LobbyCat
extends Node3D
## Кот квартиры — рыжий Баггет (отсылка к настоящему коту одного из участников проекта).
## Бродит по всем комнатам (по точкам-«тропинкам» WAYPOINTS, чтобы не ходить
## сквозь мебель), иногда садится. Время от времени сам идёт на лежанку и спит (zZZ) —
## в это время (и пока идёт спать) его гладить нельзя. Иногда идёт к миске поесть: корм исчезает
## и через FOOD_RESPAWN сек снова насыпан (как разбитая посуда).
##
## Погладить: игрок рядом жмёт кнопку действия → сердечки, кот замирает и машет хвостом.
## Перезарядка общая на всех — PET_COOLDOWN секунд.

enum State { WALK, IDLE, PETTED, TO_BED, SLEEP, TO_FOOD, EAT }

const CAT_NAME := "Баггет"
const HEART := preload("res://assets/textures/fx/heart_pixel.png")

const PET_COOLDOWN := 5.0
const PET_REACH := 1.3
const SPEED := 0.9
const TURN_SPEED := 6.0
## Точки, между которыми кот ходит по прямой (координаты квартиры).
const WAYPOINTS: Array[Vector3] = [
	Vector3(-0.5, 0, -1.5),   # 0 центр гостиной
	Vector3(-0.5, 0, 0.9),    # 1
	Vector3(-0.4, 0, 2.9),    # 2 у передней стены
	Vector3(-3.0, 0, 2.6),    # 3 за диваном
	Vector3(-4.8, 0, 2.2),    # 4 у двери в игровую
	Vector3(-4.2, 0, -1.9),   # 5 у серванта
	Vector3(-2.6, 0, -2.2),   # 6 перед телевизором
	Vector3(2.6, 0, -1.0),    # 7 дверь в спальню (гостиная)
	Vector3(3.7, 0, -1.0),    # 8 дверь в спальню (спальня)
	Vector3(4.6, 0, -1.6),    # 9 у шкафа
	Vector3(6.0, 0, -0.4),    # 10 середина спальни
	Vector3(6.0, 0, 0.45),    # 11 у лежанки
	Vector3(-5.4, 0, 2.3),    # 12 дверь в игровую (гостиная)
	Vector3(-6.6, 0, 2.3),    # 13 дверь в игровую (игровая)
	Vector3(-8.5, 0, 1.7),    # 14 перед столом рулетки
	Vector3(-10.7, 0, 1.2),   # 15 у автомата
	Vector3(-11.05, 0, -0.4), # 16 у левой стены
	Vector3(-9.0, 0, -1.3),   # 17 за столом
	Vector3(-0.1, 0, 2.75),   # 18 у миски (гостиная, у стены между стулом и торшером)
]
const LINKS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5),
	Vector2i(5, 6), Vector2i(6, 0), Vector2i(0, 7), Vector2i(7, 8), Vector2i(8, 9),
	Vector2i(9, 10), Vector2i(10, 11), Vector2i(4, 12), Vector2i(12, 13), Vector2i(13, 14),
	Vector2i(14, 15), Vector2i(15, 16), Vector2i(16, 17), Vector2i(2, 18), Vector2i(1, 18),
]
const BED_POINT := 11
const BED_POS := Vector3(6.0, 0, 0.95)
const FOOD_POINT := 18
const BOWL_POS := Vector3(-0.1, 0, 3.15)
const EAT_TIME := 3.0
const FOOD_RESPAWN := 25.0

## Когда кота гладили в последний раз (общая перезарядка для всех игроков).
var last_pet_time := -100.0
var state := State.IDLE

var _point := 0
var _path: Array[int] = []
var _wait := 1.0
var _time := 0.0
var _parts: Dictionary = {}
var _model: Node3D
var _zzz: Label3D
var _food: Node3D
var _food_ready := true


func _ready() -> void:
	_model = (load("res://assets/models/apartment/cat.glb") as PackedScene).instantiate()
	add_child(_model)
	for part in ["CatBody", "CatHead", "CatTail", "LegFL", "LegFR", "LegBL", "LegBR"]:
		_parts[part] = _model.find_child(part, true, false)
	var bed_scene := load("res://assets/models/apartment/cat_bed.glb") as PackedScene
	var bed := bed_scene.instantiate() as Node3D
	bed.top_level = true
	add_child(bed)
	bed.position = BED_POS
	var bowl_scene := load("res://assets/models/apartment/cat_bowl.glb") as PackedScene
	var bowl := bowl_scene.instantiate() as Node3D
	bowl.top_level = true
	add_child(bowl)
	bowl.position = BOWL_POS
	var food_scene := load("res://assets/models/apartment/cat_food.glb") as PackedScene
	_food = food_scene.instantiate() as Node3D
	bowl.add_child(_food)
	_zzz = Label3D.new()
	_zzz.text = "z Z Z"
	_zzz.font_size = 48
	_zzz.outline_size = 10
	_zzz.modulate = Color(0.75, 0.85, 1.0)
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zzz.position = Vector3(0, 0.75, 0)
	_zzz.visible = false
	add_child(_zzz)
	var name_label := Label3D.new()
	name_label.text = CAT_NAME
	name_label.font_size = 32
	name_label.outline_size = 8
	name_label.modulate = Color(1.0, 0.72, 0.35)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.position = Vector3(0, 0.62, 0)
	add_child(name_label)
	_point = randi() % WAYPOINTS.size()
	position = WAYPOINTS[_point]


func _process(delta: float) -> void:
	_time += delta
	match state:
		State.WALK, State.TO_BED, State.TO_FOOD:
			_walk(delta)
		State.EAT:
			_wait -= delta
			if _wait <= 0.0:
				_finish_eating()
		State.IDLE, State.PETTED:
			_wait -= delta
			if _wait <= 0.0:
				_decide()
		State.SLEEP:
			_wait -= delta
			_zzz.position.y = 0.92 + sin(_time * 1.5) * 0.05
			if _wait <= 0.0:
				_wake_up()
	_animate(delta)


## Можно ли сейчас погладить (кот не спит, не идёт спать, перезарядка прошла).
func can_pet() -> bool:
	return state != State.SLEEP and state != State.TO_BED and cooldown_left() <= 0.0


func cooldown_left() -> float:
	return maxf(0.0, PET_COOLDOWN - (_now() - last_pet_time))


func is_sleepy() -> bool:
	return state == State.SLEEP or state == State.TO_BED


## Погладить: кот замирает, машет хвостом, вылетают сердечки.
func pet() -> bool:
	if not can_pet():
		return false
	last_pet_time = _now()
	state = State.PETTED
	_wait = 1.6
	for i in 3:
		_spawn_heart(i * 0.15)
	return true


# ---------------- Поведение ----------------

func _decide() -> void:
	# Проголодался — идёт к миске (если корм насыпан).
	if _food_ready and randf() < 0.18:
		_path = _route(_point, FOOD_POINT)
		if _path.is_empty():
			_path.append(FOOD_POINT)
		state = State.TO_FOOD
		return
	# Иногда кот сам уходит спать.
	if randf() < 0.15:
		_path = _route(_point, BED_POINT)
		if _path.is_empty():
			_path.append(BED_POINT) # уже рядом — просто дойти до лежанки
		state = State.TO_BED
		return
	if randf() < 0.3:
		state = State.IDLE # посидит ещё
		_wait = randf_range(1.5, 4.0)
		return
	var neighbours := _neighbours(_point)
	_path.clear()
	_path.append(neighbours.pick_random())
	state = State.WALK


func _walk(delta: float) -> void:
	if _path.is_empty():
		_arrive()
		return
	var target: Vector3 = WAYPOINTS[_path[0]]
	if state == State.TO_BED and _path.size() == 1 and _path[0] == BED_POINT:
		target = BED_POS
	var to := target - position
	to.y = 0.0
	if to.length() < 0.05:
		_point = _path.pop_front()
		if _path.is_empty():
			_arrive()
		return
	var step := minf(SPEED * delta, to.length())
	position += to.normalized() * step
	# Кот смотрит по -Z (как и персонажи): поворачиваемся плавно.
	var yaw := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, TURN_SPEED * delta))


func _arrive() -> void:
	if state == State.TO_FOOD:
		state = State.EAT
		_wait = EAT_TIME
		var to_bowl := BOWL_POS - position
		rotation.y = atan2(-to_bowl.x, -to_bowl.z) # мордой к миске
		return
	if state == State.TO_BED:
		state = State.SLEEP
		_wait = randf_range(20.0, 40.0)
		_zzz.visible = true
		return
	state = State.IDLE
	_wait = randf_range(1.0, 4.0)


## Поел: корм пропал, через FOOD_RESPAWN сек снова насыпан (вырастает из миски).
func _finish_eating() -> void:
	state = State.IDLE
	_wait = 1.0
	if not _food_ready:
		return
	_food_ready = false
	_food.visible = false
	await get_tree().create_timer(FOOD_RESPAWN).timeout
	if not is_inside_tree():
		return
	_food.visible = true
	_food.scale = Vector3.ONE * 0.01
	create_tween().tween_property(_food, "scale", Vector3.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_food_ready = true


func _wake_up() -> void:
	_zzz.visible = false
	state = State.IDLE
	_wait = 1.0
	position = WAYPOINTS[BED_POINT]


## Кратчайший путь по точкам (поиск в ширину). Без начальной точки.
func _route(from: int, to: int) -> Array[int]:
	var came: Dictionary = {from: -1}
	var queue: Array[int] = [from]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current == to:
			break
		for next in _neighbours(current):
			if not came.has(next):
				came[next] = current
				queue.append(next)
	var path: Array[int] = []
	var node := to
	while node != from and came.has(node):
		path.push_front(node)
		node = came[node]
	return path


func _neighbours(point: int) -> Array[int]:
	var result: Array[int] = []
	for link in LINKS:
		if link.x == point:
			result.append(link.y)
		elif link.y == point:
			result.append(link.x)
	return result


# ---------------- Анимация ----------------

func _animate(delta: float) -> void:
	var walking := state == State.WALK or state == State.TO_BED or state == State.TO_FOOD
	var sleeping := state == State.SLEEP
	var phase := _time * 9.0
	var legs := {"LegFL": 0.0, "LegFR": PI, "LegBL": PI, "LegBR": 0.0}
	for leg: String in legs:
		var node := _parts[leg] as Node3D
		var angle := sin(phase + float(legs[leg])) * 0.5 if walking else 0.0
		if sleeping:
			angle = 1.45 if leg.begins_with("LegF") else -1.45 # лапы поджаты
		node.rotation.x = lerpf(node.rotation.x, angle, minf(1.0, delta * 12.0))
	# Спит — лежит ниже (на подушке лежанки), голова на лапах.
	var drop := -0.05 if sleeping else (absf(sin(phase)) * 0.015 if walking else 0.0)
	_model.position.y = lerpf(_model.position.y, drop, minf(1.0, delta * 6.0))
	var head := _parts["CatHead"] as Node3D
	var nod := -0.35 if sleeping else (sin(_time * 1.3) * 0.08)
	if state == State.EAT:
		nod = -0.55 + absf(sin(_time * 7.0)) * 0.2 # ест: голова в миске, кивает
	head.rotation.x = lerpf(head.rotation.x, nod, minf(1.0, delta * 5.0))
	var tail := _parts["CatTail"] as Node3D
	var wag := 0.15
	if state == State.PETTED:
		wag = 0.6
	elif sleeping:
		wag = 0.05
	tail.rotation.z = sin(_time * (8.0 if state == State.PETTED else 2.5)) * wag


## Маленькое пиксельное сердечко (как в Minecraft): всплывает, покачиваясь, и тает.
func _spawn_heart(delay: float) -> void:
	var heart := Sprite3D.new()
	heart.texture = HEART
	heart.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # пиксели чёткие
	heart.pixel_size = 0.016 # 9 пикселей ≈ 14 см
	heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heart.shaded = false
	heart.position = Vector3(randf_range(-0.15, 0.15), 0.5, randf_range(-0.15, 0.15))
	heart.modulate.a = 0.0
	add_child(heart)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(heart, "modulate:a", 1.0, 0.1).set_delay(delay)
	tween.tween_property(heart, "position:y", 1.05, 1.0).set_delay(delay)
	tween.tween_property(heart, "position:x", heart.position.x + randf_range(-0.12, 0.12), 1.0) \
		.set_delay(delay).set_trans(Tween.TRANS_SINE)
	tween.tween_property(heart, "modulate:a", 0.0, 0.3).set_delay(delay + 0.7)
	tween.chain().tween_callback(heart.queue_free)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
