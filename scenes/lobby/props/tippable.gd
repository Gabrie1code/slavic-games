class_name Tippable
extends RigidBody3D
## Вещь, которую можно толкнуть и опрокинуть (стулья, торшер).
## Если её сдвинули, через RESET_TIME секунд она сама возвращается на место.

const RESET_TIME := 12.0

## Какой разгон нужен персонажу, чтобы уронить вещь (PlayerCharacter.run_up): чем больше вещь,
## тем больше. Аккуратно подошёл — просто упёрся.
var run_up_needed := 0.4
## На чём вещь стоит (книга на табурете): пока опора не вернулась на место, вещь тоже не
## возвращается — иначе книга появилась бы в воздухе над пустым местом и снова упала.
var support: Tippable
## Высота вещи (для прицела удара: попасть можно по всей высоте, а не только у основания).
var height := 0.5
## Кулаком не сдвинуть — только молотком (торшер у дивана).
var hammer_only := false

var _home: Transform3D
var _model: Node3D
var _away_time := 0.0


## scene — модель, size — размер коробки столкновений, center_y — её центр по высоте.
func setup(scene: PackedScene, size: Vector3, center_y: float, body_mass: float = 4.0) -> void:
	setup_model(scene.instantiate() as Node3D, size, center_y, body_mass)


## То же, но модель уже собрана (например, кодом — книга из коробок).
func setup_model(model: Node3D, size: Vector3, center_y: float, body_mass: float = 4.0) -> void:
	_model = model
	add_child(_model)
	add_to_group("tippable")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = center_y
	add_child(shape)
	mass = body_mass
	height = size.y
	continuous_cd = true # падая, не проваливается в пол
	run_up_needed = clampf(0.15 + maxf(size.x, maxf(size.y, size.z)) * 0.6, 0.3, 1.4)
	# Центр масс пониже — чтобы вещь падала, но не кувыркалась бесконечно.
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, center_y * 0.6, 0)


## Ещё одна коробка столкновений (абажур торшера шире стойки — иначе, упав, уходил в пол).
func add_box(size: Vector3, center: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	add_child(shape)
	height = maxf(height, center.y + size.y / 2.0)


func _ready() -> void:
	_home = global_transform


## Стоит на своём месте (не повалена и не «возвращается»): с ней можно что-то делать.
func is_at_home() -> bool:
	return not freeze and _away_time == 0.0 \
		and global_position.distance_to(_home.origin) < 0.25 and global_basis.y.dot(Vector3.UP) > 0.95


func _physics_process(delta: float) -> void:
	var moved := global_position.distance_to(_home.origin) > 0.25 \
		or global_basis.y.dot(Vector3.UP) < 0.95
	_away_time = _away_time + delta if moved else 0.0
	if _away_time > RESET_TIME and (support == null or support.is_at_home()):
		_away_time = 0.0
		_return_home()


func _return_home() -> void:
	freeze = true
	global_transform = _home
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	# Масштабируем только модель: физическое тело масштабировать нельзя.
	_model.scale = Vector3.ONE * 0.01
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: freeze = false)
