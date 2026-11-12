class_name PlayerInput
extends RefCounted
## Удобный доступ к управлению конкретного локального игрока.
##
## Игровой код спрашивает не «нажат ли Пробел», а «нажал ли ЭТОТ игрок confirm».
## Позже для сетевых игроков сюда же будет приходить ввод по сети.

var slot: int


func _init(p_slot: int) -> void:
	slot = p_slot


## Направление движения: x — влево/вправо, y — вверх(-1)/вниз(+1).
func get_move() -> Vector2:
	return Input.get_vector(
		_a("move_left"), _a("move_right"), _a("move_up"), _a("move_down"))


func is_pressed(action: String) -> bool:
	return Input.is_action_pressed(_a(action))


func is_just_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(_a(action))


func _a(action: String) -> StringName:
	return InputSetup.action_name(slot, action)
