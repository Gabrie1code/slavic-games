class_name ShelfClockHands
extends Node
## Стрелки будильника на полке показывают время компьютера. Узел кладётся внутрь вещи
## (Breakable с моделью shelf_clock): находит в ней ClockHour / ClockMinute и крутит их
## вокруг оси циферблата (локальная Z — смотрит из циферблата вперёд).

var _hour: Node3D
var _minute: Node3D


func _process(_delta: float) -> void:
	if _hour == null or not is_instance_valid(_hour):
		_hour = get_parent().find_child("ClockHour", true, false) as Node3D
		_minute = get_parent().find_child("ClockMinute", true, false) as Node3D
		if _hour == null:
			return
	var now := Time.get_time_dict_from_system()
	var minutes := float(now["minute"]) + float(now["second"]) / 60.0
	var hours := fmod(float(now["hour"]), 12.0) + minutes / 60.0
	# По часовой стрелке, если смотреть на циферблат спереди (с +Z): поворот вокруг Z — минус.
	_hour.rotation.z = -TAU * hours / 12.0
	if _minute:
		_minute.rotation.z = -TAU * minutes / 60.0
