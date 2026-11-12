class_name MoneyLabel
extends VBoxContainer
## Баланс в рублях: значок монеты + сумма. При изменении цифры «отматываются»,
## как на счётчике, а под балансом всплывает «-100» (красным) или «+50» (зелёным).

const ICON := preload("res://assets/ui/icons/ruble.png")
const COUNT_TIME := 0.7

var _amount := 0
var _shown := 0.0
var _number: Label
var _delta: Label
var _icon: TextureRect
var _tween: Tween


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_icon = TextureRect.new()
	_icon.texture = ICON
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(48, 48)
	row.add_child(_icon)
	_number = _make_label(Color("f6c343"))
	row.add_child(_number)
	_delta = _make_label(Color.WHITE)
	_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_delta.modulate.a = 0.0
	add_child(_delta)
	set_font_size(36)


func set_font_size(font_size: int) -> void:
	_number.add_theme_font_size_override("font_size", font_size)
	_delta.add_theme_font_size_override("font_size", int(font_size * 0.7))
	_icon.custom_minimum_size = Vector2.ONE * font_size * 1.3


## Задать сумму. animate=false — сразу, без счётчика (например, при открытии окна).
func set_amount(value: int, animate: bool = true) -> void:
	var diff := value - _amount
	_amount = value
	if not animate or diff == 0:
		_shown = value
		_number.text = "%d ₽" % value
		return
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_show_value, _shown, float(value), COUNT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Всплывающая разница под балансом.
	_delta.text = ("+%d ₽" % diff) if diff > 0 else ("%d ₽" % diff)
	_delta.add_theme_color_override("font_color", Color("8fd694") if diff > 0 else Color("ff6b5a"))
	_delta.modulate.a = 1.0
	_delta.position.y = 0.0
	_tween.tween_property(_delta, "modulate:a", 0.0, 0.6).set_delay(1.2)
	# Цифры «подпрыгивают» на старте отсчёта.
	_number.pivot_offset = _number.size / 2.0
	_number.scale = Vector2.ONE * 1.15
	_tween.tween_property(_number, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)


func _show_value(value: float) -> void:
	_shown = value
	_number.text = "%d ₽" % roundi(value)


func _make_label(color: Color) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
