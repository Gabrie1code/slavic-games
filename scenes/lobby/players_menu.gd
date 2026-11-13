class_name PlayersMenu
extends CenterContainer
## Меню игроков в лобби: появляется, пока зажат Tab (или Back/Select на геймпаде).
## Вместо постоянной полоски слотов внизу экрана. В каждой строке: цвет, имя, чем управляет,
## кошелёк и «готов» у телевизора; пустые места — подсказка, как войти.
## Сам узел растянут на весь экран и ставит панель ровно по центру (CenterContainer).

const ROW_HEIGHT := 58
const FADE_SPEED := 10.0

## Готов ли игрок (лобби передаёт свою проверку по отметкам у телевизора).
var is_ready: Callable

var _rows: VBoxContainer
var _title: Label
var _refresh_left := 0.0


func _ready() -> void:
	# Именно «якоря И отступы»: set_anchors_preset внутри дерева сохраняет старый размер (0×0),
	# и меню оставалось в левом верхнем углу.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.05, 0.88)
	style.border_color = Color("f6c343")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	_title = _label("", 28, Color("f6c343"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	column.add_child(_rows)
	var footer := _label("Войти: Пробел (WASD) · Enter (стрелки) · A (геймпад)\n"
		+ "Выйти: Q / Backspace / B", 15, Color(1, 1, 1, 0.55))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(footer)
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	var held := _held()
	modulate.a = move_toward(modulate.a, 1.0 if held else 0.0, delta * FADE_SPEED)
	visible = modulate.a > 0.01
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.25
		_refresh()


func _held() -> bool:
	if Input.is_key_pressed(KEY_TAB):
		return true
	for pad in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_BACK):
			return true
	return false


func _refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var count := 0
	for slot in PlayerManager.MAX_PLAYERS:
		var p := PlayerManager.get_by_slot(slot)
		if p:
			count += 1
		_rows.add_child(_row(slot, p))
	_title.text = "Игроки  %d / %d" % [count, PlayerManager.MAX_PLAYERS]


func _row(slot: int, p: PlayerData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = ROW_HEIGHT
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	style.bg_color = p.color.darkened(0.55) if p else Color(1, 1, 1, 0.05)
	if p:
		style.border_color = p.color
		style.border_width_left = 6
	panel.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	panel.add_child(line)
	line.add_child(_label("%d" % (slot + 1), 20, Color(1, 1, 1, 0.45)))
	if p == null:
		line.add_child(_label("Свободно", 20, Color(1, 1, 1, 0.4)))
		return panel
	var swatch := ColorRect.new()
	swatch.color = p.color
	swatch.custom_minimum_size = Vector2(22, 22)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(swatch)
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 0)
	name_box.add_child(_label(p.display_name, 21, Color.WHITE))
	name_box.add_child(_label(p.device_label(), 14, Color(1, 1, 1, 0.6)))
	line.add_child(name_box)
	if not p.is_bot():
		line.add_child(_label("%d ₽" % PlayerManager.wallet(p), 19, Color("f6c343")))
	var ready := is_ready.is_valid() and bool(is_ready.call(p))
	line.add_child(_label("ГОТОВ" if ready else "—", 17,
		Color("8fd694") if ready else Color(1, 1, 1, 0.35)))
	return panel


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
