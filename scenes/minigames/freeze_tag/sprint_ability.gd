class_name SprintAbility
extends RefCounted
## Спринт в «Морожке»: Shift (LB/левый стик) — на SPRINT_TIME сек скорость +bonus
## (бегущим +50%, водящему +15%), потом перезарядка COOLDOWN сек. Бот жмёт сам.

const BONUS := 0.5
const SPRINT_TIME := 3.0
const COOLDOWN := 15.0

## Сколько ещё бежит быстро и сколько ждать до следующего спринта (сек).
var left := 0.0
## Прибавка к скорости во время спринта (0.5 = +50%).
var bonus := BONUS
var cooldown := 0.0


func ready() -> bool:
	return cooldown <= 0.0


## Каждый кадр: таймеры, нажатие, скорость персонажа. base_speed — обычная скорость бегущего.
## Возвращает true в тот кадр, когда спринт включился (для эффекта).
func update(delta: float, character: PlayerCharacter, input: PlayerInput, base_speed: float,
		allowed: bool) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	var started := false
	if left > 0.0:
		left = maxf(0.0, left - delta)
	elif allowed and ready() and input != null and input.is_just_pressed("sprint"):
		left = SPRINT_TIME
		cooldown = COOLDOWN
		started = true
	character.speed = base_speed * (1.0 + bonus if left > 0.0 else 1.0)
	return started


## Короткая подпись для таблицы очков: «⚡ готов», «⚡ бежит!», «⚡ 12 с».
func status() -> String:
	if left > 0.0:
		return "спринт!"
	if ready():
		return "спринт готов"
	return "спринт %d с" % ceili(cooldown)
