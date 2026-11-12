class_name ConfirmDialog
extends PanelContainer
## Окно подтверждения покупки: «Купить «Ушанка» за 250 ₽?» — [Да] [Нет].
##
## Управление кнопками устройства игрока: влево/вправо — выбор, подтвердить — нажать,
## отмена — «Нет». Мышью — просто клик. Владелец окна вызывает handle_input() каждый кадр.

signal answered(yes: bool)

const GOLD := Color("f6c343")

var _focus := 0 # 0 — «Да», 1 — «Нет»
var _buttons: Array[Button] = []
var _label: Label


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.05, 0.97)
	style.border_color = GOLD
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	add_child(column)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = 420
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color.WHITE)
	column.add_child(_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	for i in 2:
		var button := Button.new()
		button.text = "Да, купить" if i == 0 else "Нет"
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(170, 56)
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(_answer.bind(i == 0))
		button.mouse_entered.connect(func() -> void:
			_focus = i
			_restyle())
		row.add_child(button)
		_buttons.append(button)
	_restyle()


## Показать вопрос (текст), выбор по умолчанию — «Да».
func ask(text: String) -> void:
	_label.text = text
	_focus = 0
	_restyle()
	visible = true


## Кнопки игрока. Возвращает true, если окно забрало нажатие.
func handle_input(input: PlayerInput) -> bool:
	if not visible or input == null:
		return false
	if input.menu_just_pressed("move_left") or input.menu_just_pressed("move_right"):
		_focus = 1 - _focus
		_restyle()
	elif input.menu_just_pressed("confirm"):
		_answer(_focus == 0)
	elif input.is_just_pressed("cancel"):
		_answer(false)
	return true


func _answer(yes: bool) -> void:
	visible = false
	answered.emit(yes)


func _restyle() -> void:
	for i in _buttons.size():
		var focused := i == _focus
		var base := Color("8a5a12") if i == 0 else Color("4a3020")
		for state in ["normal", "hover", "pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = base.lightened(0.15) if focused else base
			style.border_color = GOLD if focused else base.lightened(0.3)
			style.set_border_width_all(5 if focused else 2)
			style.set_corner_radius_all(12)
			_buttons[i].add_theme_stylebox_override(state, style)
		_buttons[i].add_theme_color_override("font_color", Color.WHITE)
		_buttons[i].add_theme_color_override("font_hover_color", Color.WHITE)
