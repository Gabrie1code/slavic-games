class_name BotInput
extends PlayerInput
## «Виртуальный геймпад» бота.
##
## Мозги бота (в каждой мини-игре свои) двигают стик и нажимают кнопки,
## а игровой код читает их точно так же, как ввод живого игрока.
## Нажатие видно игровому коду в следующем кадре (и в обычном, и в физическом).

## Положение «стика»: как у get_move() живого игрока.
var move := Vector2.ZERO

var _held: Dictionary = {} # действие -> зажато ли
var _pressed_frame: Dictionary = {} # действие -> номер кадра нажатия
var _pressed_physics_frame: Dictionary = {} # действие -> номер физического кадра


func _init() -> void:
	super(-1)


func get_move() -> Vector2:
	return move.limit_length(1.0)


func is_pressed(action: String) -> bool:
	return _held.get(action, false) or is_just_pressed(action)


func is_just_pressed(action: String) -> bool:
	if Engine.is_in_physics_frame():
		return _pressed_physics_frame.get(action, -10) == Engine.get_physics_frames() - 1
	return _pressed_frame.get(action, -10) == Engine.get_process_frames() - 1


## Короткое нажатие кнопки.
func press(action: String) -> void:
	_pressed_frame[action] = Engine.get_process_frames()
	_pressed_physics_frame[action] = Engine.get_physics_frames()


## Зажать или отпустить кнопку (например, для удержания в «Морожке»).
func hold(action: String, on: bool) -> void:
	if on and not _held.get(action, false):
		press(action)
	_held[action] = on
