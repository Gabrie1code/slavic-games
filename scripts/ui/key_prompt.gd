class_name KeyPrompt
extends VBoxContainer
## Подсказка действия «как в играх»: значок кнопки + короткое действие на тёмной плашке.
##   [Пробел]  Сесть на диван
## Клавиша клавиатуры — светлая «клавиша» с тенью, кнопка геймпада — цветной кружок
## (A — зелёный, B — красный, X — синий, Y — жёлтый). Недоступное действие — серое.
##
## set_entries([{"key": "Пробел", "text": "Сесть", "off": false}, ...]) — по строке на действие.

const PAD_COLORS := {
	"A": Color("5cb85c"), "B": Color("d9534f"), "X": Color("3b7dd8"), "Y": Color("e8b923"),
}

var font_size := 24

var _last := "" # чтобы не пересобирать одинаковую подсказку каждый кадр


func _init() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Показать действия. Пустой список — спрятать подсказку.
func set_entries(entries: Array) -> void:
	var signature := str(entries)
	if signature == _last:
		return
	_last = signature
	for child in get_children():
		child.queue_free()
	visible = not entries.is_empty()
	for entry: Dictionary in entries:
		add_child(_row(entry.get("key", ""), entry.get("text", ""), entry.get("off", false)))


func _row(key: String, text: String, off: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.modulate = Color(1, 1, 1, 0.55) if off else Color.WHITE
	row.add_child(_key_cap(key, off))
	var pill := PanelContainer.new()
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color(0.05, 0.05, 0.07, 0.72)
	pill_style.set_corner_radius_all(8)
	pill_style.content_margin_left = 12
	pill_style.content_margin_right = 12
	pill_style.content_margin_top = 4
	pill_style.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", pill_style)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7) if off else Color.WHITE)
	pill.add_child(label)
	row.add_child(pill)
	return row


## Значок кнопки: кружок для геймпада, «клавиша» для клавиатуры и мыши.
func _key_cap(key: String, off: bool) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	var label := Label.new()
	label.text = key
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(font_size * 0.9))
	var side := font_size * 1.6
	if PAD_COLORS.has(key):
		style.bg_color = Color(0.3, 0.3, 0.3) if off else PAD_COLORS[key]
		style.set_corner_radius_all(int(side))
		style.border_color = Color(1, 1, 1, 0.85)
		style.set_border_width_all(2)
		label.add_theme_color_override("font_color", Color.WHITE)
		cap.custom_minimum_size = Vector2(side, side)
	else:
		style.bg_color = Color(0.93, 0.93, 0.9)
		style.set_corner_radius_all(6)
		style.border_color = Color(0.55, 0.55, 0.52)
		style.border_width_bottom = 4 # «клавиша» с объёмом
		style.content_margin_left = 10
		style.content_margin_right = 10
		label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
		cap.custom_minimum_size = Vector2(side, side)
	cap.add_theme_stylebox_override("panel", style)
	cap.add_child(label)
	return cap
