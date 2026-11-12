class_name PlayerData
extends RefCounted
## Данные одного игрока в матче.
##
## Здесь только «чистые» данные, которые позже можно будет передавать по сети.
## Управление (PlayerInput) хранится отдельно и есть только у локальных игроков.

## Чем управляется игрок.
enum DeviceKind {
	KEYBOARD_WASD,   ## Левая половина клавиатуры: WASD + Пробел
	KEYBOARD_ARROWS, ## Правая половина клавиатуры: стрелки + Enter
	JOYPAD,          ## Геймпад (номер в joypad_id)
	REMOTE,          ## Игрок по сети (появится на этапе онлайна)
}

## Уникальный id игрока в рамках матча.
var id: int = 0
## Позиция игрока (0..MAX_PLAYERS-1): определяет цвет и место спавна.
var slot: int = 0
var display_name: String = ""
var color: Color = Color.WHITE

var device_kind: DeviceKind = DeviceKind.KEYBOARD_WASD
## Номер геймпада в Godot, если device_kind == JOYPAD.
var joypad_id: int = -1
## Сетевой peer, которому принадлежит игрок. 1 = хост / локальная игра.
var peer_id: int = 1

## Управление локального игрока. У сетевых игроков = null.
var input: PlayerInput = null


func is_local() -> bool:
	return device_kind != DeviceKind.REMOTE


func device_label() -> String:
	match device_kind:
		DeviceKind.KEYBOARD_WASD:
			return "Клавиатура WASD"
		DeviceKind.KEYBOARD_ARROWS:
			return "Клавиатура стрелки"
		DeviceKind.JOYPAD:
			return "Геймпад %d" % (joypad_id + 1)
		_:
			return "Сеть"
