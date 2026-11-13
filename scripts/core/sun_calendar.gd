class_name SunCalendar
extends RefCounted
## Восход и закат по дате — для России (считаем по Москве: широта 55.75° с. ш., долгота 37.6° в. д.,
## время UTC+3 круглый год, без перевода часов). Обычная астрономическая формула: склонение
## Солнца по дню года, часовой угол с поправкой на рефракцию (−0.833°) и «уравнение времени».
## Что получается (Москва): ~21 июня 3:45–21:18 (день 17.5 ч), ~21 декабря 8:58–15:58 (7 ч),
## середина ноября ~8:10–16:20. Чем ближе к зиме — тем позже светает и раньше темнеет.

const LATITUDE := 55.75
const LONGITUDE := 37.6
const UTC_OFFSET := 3.0


## Восход и закат (часы, местное время) на дату: Vector2(восход, закат).
static func sun_times(year: int, month: int, day: int) -> Vector2:
	var n := _day_of_year(year, month, day)
	var decl := deg_to_rad(23.44) * sin(TAU * (284.0 + n) / 365.0)
	var lat := deg_to_rad(LATITUDE)
	var cos_w := (sin(deg_to_rad(-0.833)) - sin(lat) * sin(decl)) / (cos(lat) * cos(decl))
	var half_day := rad_to_deg(acos(clampf(cos_w, -1.0, 1.0))) / 15.0 # часы от полудня
	var b := TAU * (n - 81.0) / 364.0
	var eot := 9.87 * sin(2.0 * b) - 7.53 * cos(b) - 1.5 * sin(b) # минуты
	var noon := 12.0 + (UTC_OFFSET * 15.0 - LONGITUDE) / 15.0 - eot / 60.0
	return Vector2(noon - half_day, noon + half_day)


## На сегодня по часам компьютера.
static func today() -> Vector2:
	var d := Time.get_date_dict_from_system()
	return sun_times(int(d["year"]), int(d["month"]), int(d["day"]))


static func _day_of_year(year: int, month: int, day: int) -> int:
	var days := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0:
		days[1] = 29
	var n := day
	for i in month - 1:
		n += int(days[i])
	return n
