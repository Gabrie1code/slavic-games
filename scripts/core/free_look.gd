class_name FreeLook
extends RefCounted
## «Свободный взгляд» на Alt (как в PUBG / Rust): пока Alt зажат, мышь поворачивает только голову
## и камеру (влево/вправо до LIMIT), а тело продолжает идти по WASD туда же, куда шло.
## Отпустил Alt — взгляд плавно возвращается вперёд. Только для игрока на WASD с мышью.

## Насколько можно повернуть голову в каждую сторону (90° — всего 180°).
const LIMIT := PI / 2.0
## Скорость возврата взгляда вперёд (рад/сек).
const RETURN_SPEED := 7.0


static func held(p: PlayerData) -> bool:
	return p.device_kind == PlayerData.DeviceKind.KEYBOARD_WASD and Input.is_key_pressed(KEY_ALT)


## Каждый кадр: look_x — поворот мышью за кадр. Меняет character.head_yaw и возвращает,
## на сколько повернуть тело (при зажатом Alt — 0: тело не поворачивается).
static func step(character: PlayerCharacter, p: PlayerData, look_x: float, delta: float) -> float:
	if held(p):
		character.head_yaw = clampf(character.head_yaw - look_x, -LIMIT, LIMIT)
		return 0.0
	character.head_yaw = move_toward(character.head_yaw, 0.0, RETURN_SPEED * delta)
	return look_x
