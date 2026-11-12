class_name PlayerInput
extends RefCounted
## Удобный доступ к управлению конкретного локального игрока.
##
## Игровой код спрашивает не «нажат ли Пробел», а «нажал ли ЭТОТ игрок confirm».
## Позже для сетевых игроков сюда же будет приходить ввод по сети.

const _MENU_ARROWS := {
	"move_up": "menu_arrow_up", "move_down": "menu_arrow_down",
	"move_left": "menu_arrow_left", "move_right": "menu_arrow_right",
	"confirm": "menu_arrow_confirm",
}

var slot: int
## Игрок на левой половине клавиатуры: в меню может пользоваться и стрелками/Enter,
## если на правой половине (стрелках) никто не играет.
var wasd_keyboard := false


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


## Нажатие в меню (примерочная, окна): как is_just_pressed, но игроку на WASD
## подходят ещё и стрелки с Enter, когда их не занял второй игрок.
func menu_just_pressed(action: String) -> bool:
	if is_just_pressed(action):
		return true
	if not wasd_keyboard or not _MENU_ARROWS.has(action):
		return false
	if PlayerManager.is_device_taken(PlayerData.DeviceKind.KEYBOARD_ARROWS):
		return false
	return Input.is_action_just_pressed(_MENU_ARROWS[action])


func _a(action: String) -> StringName:
	return InputSetup.action_name(slot, action)
