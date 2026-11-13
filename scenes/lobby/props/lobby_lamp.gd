class_name LobbyLamp
extends RefCounted
## Светильник квартиры, который зависит от времени суток за окном (WindowView.is_dark):
## утром и днём сам не горит — кнопкой можно включить на OVERRIDE_TIME сек; вечером и ночью
## горит — кнопкой можно выключить на то же время. Нажать ещё раз — сразу вернуть как было.
## Гаснет сразу, загорается плавно (FADE сек). Повален или разбит — не горит.

const OVERRIDE_TIME := 20.0
const FADE := 1.5
const BULB_OFF := Color(0.3, 0.27, 0.22)
const BULB_ON := Color(1.0, 0.92, 0.7)

## 0 — не горит, 1 — горит в полную силу.
var level := 0.0

var _light: OmniLight3D
var _energy := 1.0
var _bulb_mat: StandardMaterial3D
var _override_left := 0.0
var _was_dark := false


func _init(light: OmniLight3D, bulb_mat: StandardMaterial3D) -> void:
	_light = light
	_energy = light.light_energy
	_bulb_mat = bulb_mat
	_apply()


## dark — на улице вечер/ночь; available — светильник цел и стоит на месте.
func update(delta: float, dark: bool, available: bool) -> void:
	_override_left = maxf(0.0, _override_left - delta)
	if dark != _was_dark: # наступил вечер / утро — ручное включение-выключение сбрасывается
		_was_dark = dark
		_override_left = 0.0
	if not available:
		_override_left = 0.0
	var on := available and (dark != (_override_left > 0.0))
	var target := 1.0 if on else 0.0
	level = target if target < level else move_toward(level, target, delta / FADE)
	_apply()


## Нажали кнопку: включить днём / выключить вечером на время (повторно — отменить).
func toggle() -> void:
	_override_left = 0.0 if _override_left > 0.0 else OVERRIDE_TIME


func is_on() -> bool:
	return level > 0.5


func _apply() -> void:
	_light.light_energy = _energy * level
	_light.visible = level > 0.01
	_bulb_mat.albedo_color = BULB_OFF.lerp(BULB_ON, level)
