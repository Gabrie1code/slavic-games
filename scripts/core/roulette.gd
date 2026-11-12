class_name Roulette
extends RefCounted
## Правила рулетки (европейская, одно зеро) и разметка сукна.
##
## Выплаты (сколько фишек вернётся за одну поставленную, вместе с ней самой):
##   красное / чёрное / чёт / нечёт — ×2, зеро — ×14, конкретное число — ×36.
## Если выпало зеро, ставки на цвет и чёт/нечёт проигрывают.
##
## Разметка сукна в долях текстуры (u — вдоль стола, v — поперёк) совпадает
## с tools/textures/rubgame_textures.py: по ней на сукно кладутся фишки.

enum Bet { RED, BLACK, ZERO, EVEN, ODD, NUMBER }

const BET_NAMES := {
	Bet.RED: "Красное", Bet.BLACK: "Чёрное", Bet.ZERO: "Зеро",
	Bet.EVEN: "Чёт", Bet.ODD: "Нечёт", Bet.NUMBER: "Число",
}
const RED_NUMBERS: Array[int] = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
## Порядок чисел на колесе по часовой стрелке, начиная сверху.
const WHEEL: Array[int] = [
	0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
	5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26,
]
## Разметка сукна (доли текстуры).
const ZERO_U := Vector2(0.03, 0.10)
const GRID_U := Vector2(0.10, 0.94)
const GRID_V := Vector2(0.05, 0.70)
const OUT_V := Vector2(0.74, 0.95)


static func is_red(n: int) -> bool:
	return RED_NUMBERS.has(n)


## Цвет числа словами: «красное», «чёрное» или «зеро».
static func color_name(n: int) -> String:
	if n == 0:
		return "зеро"
	return "красное" if is_red(n) else "чёрное"


## Во сколько раз вернётся ставка (0 — проиграла).
static func payout(bet: int, number: int, result: int) -> int:
	match bet:
		Bet.RED:
			return 2 if result != 0 and is_red(result) else 0
		Bet.BLACK:
			return 2 if result != 0 and not is_red(result) else 0
		Bet.ZERO:
			return 14 if result == 0 else 0
		Bet.EVEN:
			return 2 if result != 0 and result % 2 == 0 else 0
		Bet.ODD:
			return 2 if result % 2 == 1 else 0
		Bet.NUMBER:
			return 36 if result == number else 0
	return 0


## Множитель ставки словами для интерфейса.
static func multiplier(bet: int) -> int:
	match bet:
		Bet.ZERO:
			return 14
		Bet.NUMBER:
			return 36
	return 2


## Подпись ставки: «Красное», «Число 17».
static func bet_title(bet: int, number: int) -> String:
	if bet == Bet.NUMBER:
		return "Число %d" % number
	return BET_NAMES[bet]


## Угол кармана с числом на колесе: 0 — вверх, по часовой стрелке (в радианах).
static func pocket_angle(n: int) -> float:
	return WHEEL.find(n) * TAU / WHEEL.size()


## Где на сукне лежат фишки этой ставки (доли текстуры: x — u, y — v).
static func layout_uv(bet: int, number: int) -> Vector2:
	var out_w := (GRID_U.y - GRID_U.x) / 4.0
	var out_v := (OUT_V.x + OUT_V.y) / 2.0
	match bet:
		Bet.ZERO:
			return Vector2((ZERO_U.x + ZERO_U.y) / 2.0, (GRID_V.x + GRID_V.y) / 2.0)
		Bet.EVEN:
			return Vector2(GRID_U.x + out_w * 0.5, out_v)
		Bet.RED:
			return Vector2(GRID_U.x + out_w * 1.5, out_v)
		Bet.BLACK:
			return Vector2(GRID_U.x + out_w * 2.5, out_v)
		Bet.ODD:
			return Vector2(GRID_U.x + out_w * 3.5, out_v)
	# Число: столбец (n-1)/3, ряд 2-(n-1)%3 (ряд 0 — дальний от игрока край).
	var cell_w := (GRID_U.y - GRID_U.x) / 12.0
	var cell_h := (GRID_V.y - GRID_V.x) / 3.0
	var col := (number - 1) / 3
	var row := 2 - (number - 1) % 3
	return Vector2(GRID_U.x + cell_w * (col + 0.5), GRID_V.x + cell_h * (row + 0.5))
