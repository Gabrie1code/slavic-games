extends CanvasLayer
## Смена сцен с затемнением (автозагрузка SceneManager).
##
## Использование: SceneManager.change_scene("res://scenes/.../scene.tscn")

var _fade: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


func change_scene(path: String, fade_time: float = 0.3) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP

	await _tween_fade(1.0, fade_time)
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Не удалось загрузить сцену %s (ошибка %d)" % [path, err])
	# Смена сцены происходит в конце кадра — ждём, пока новая сцена появится.
	await get_tree().process_frame
	await get_tree().process_frame
	await _tween_fade(0.0, fade_time)

	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _tween_fade(target: float, time: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", target, time)
	await tween.finished
