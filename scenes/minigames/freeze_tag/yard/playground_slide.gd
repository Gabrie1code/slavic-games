class_name PlaygroundSlide
extends Node3D
## Металлическая горка. У лесенки нажать «подтвердить» — персонаж сам забирается наверх
## и скатывается вниз, на выходе получает ускорение. Пока едет — водящий его не заморозит.
##
## Модель лежит вдоль локальной X: лесенка на +X, скат к −X.

signal ride_finished(character: PlayerCharacter)

const SCENE := preload("res://assets/models/playground/slide.glb")
const USE_RADIUS := 1.1
const BOOST := 10.0
## Путь катания (локальные координаты): подойти к лесенке → наверх → площадка → вниз → выход.
const PATH: Array[Vector3] = [
	Vector3(2.3, 0, 0), Vector3(1.75, 0.8, 0), Vector3(1.35, 1.64, 0),
	Vector3(0.85, 1.64, 0), Vector3(-1.5, 0.3, 0), Vector3(-2.3, 0, 0),
]
## Сколько секунд на каждый отрезок пути (лезть медленно, катиться быстро).
const TIMES: Array[float] = [0.45, 0.45, 0.25, 0.5, 0.15]

## Кто сейчас на горке.
var riders: Array[PlayerCharacter] = []


func _ready() -> void:
	add_child(SCENE.instantiate())
	# Твёрдая только башенка с лесенкой; под скатом можно пробегать.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 1.7, 0.8)
	shape.shape = box
	shape.position = Vector3(1.35, 0.85, 0)
	body.add_child(shape)
	add_child(body)
	var badge := ZoneBadge.new().setup("zone_slide", 2.8)
	badge.position += Vector3(1.3, 0, 0)
	add_child(badge)


## Точка у лесенки (в мире): отсюда можно залезть.
func stairs_point() -> Vector3:
	return to_global(PATH[0])


func can_ride(character: PlayerCharacter) -> bool:
	var pos := character.global_position
	var stairs := stairs_point()
	var dist := Vector2(pos.x - stairs.x, pos.z - stairs.z).length()
	return not riders.has(character) and dist < USE_RADIUS


## Прокатиться: физика персонажа выключается, он едет по пути, на выходе — толчок вперёд.
func ride(character: PlayerCharacter) -> void:
	riders.append(character)
	character.input_enabled = false
	character.set_physics_process(false)
	character.velocity = Vector3.ZERO
	var exit_dir := (to_global(PATH[PATH.size() - 1]) - to_global(PATH[PATH.size() - 2]))
	exit_dir.y = 0.0
	exit_dir = exit_dir.normalized()
	# Лицом к скату (скат идёт к −X горки; персонаж смотрит по своей −Z).
	var down := -global_basis.x
	character.rotation.y = atan2(-down.x, -down.z)
	var tween := create_tween()
	tween.tween_property(character, "global_position", to_global(PATH[0]), 0.12)
	for i in range(1, PATH.size()):
		var step := tween.tween_property(character, "global_position", to_global(PATH[i]), TIMES[i - 1])
		if i == 4:
			step.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN) # разгон по скату
	tween.tween_callback(func() -> void:
		riders.erase(character)
		if not is_instance_valid(character):
			return
		character.set_physics_process(true)
		character.apply_knockback(exit_dir * BOOST)
		ride_finished.emit(character))
