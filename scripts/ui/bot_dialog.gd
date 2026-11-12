class_name BotDialog
extends PanelContainer
## Окно лобби «Добавить ботов на свободные места?»: число ботов со стрелками, «Назад» и «Начать».
## Само ничего не решает — сообщает лобби сигналами; число пишет лобби в count_label.

signal step_pressed(step: int)
signal back_pressed
signal start_pressed

var count_label: Label


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.07, 0.95)
	style.border_color = Color("f6c343")
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(32)
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	for line in [
		["Добавить ботов на свободные места?", 34, Color("f6c343")],
		["Сколько ботов:", 24, Color.WHITE],
	]:
		var label := Label.new()
		label.text = line[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", line[1])
		label.add_theme_color_override("font_color", line[2])
		column.add_child(label)

	# Число ботов со стрелками (стрелки можно нажимать мышью).
	var picker := HBoxContainer.new()
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	picker.add_theme_constant_override("separation", 24)
	column.add_child(picker)
	var left := _dialog_button("◀", 48)
	left.pressed.connect(func() -> void: step_pressed.emit(-1))
	picker.add_child(left)
	count_label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.custom_minimum_size.x = 260
	count_label.add_theme_font_size_override("font_size", 64)
	picker.add_child(count_label)
	var right := _dialog_button("▶", 48)
	right.pressed.connect(func() -> void: step_pressed.emit(1))
	picker.add_child(right)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	# Слева «Назад», справа «Начать» (как привычно: «вперёд» — справа).
	var back := _dialog_button("Назад", 30)
	back.pressed.connect(func() -> void: back_pressed.emit())
	buttons.add_child(back)
	var start := _dialog_button("Начать", 30)
	start.pressed.connect(func() -> void: start_pressed.emit())
	buttons.add_child(start)

	var hint := Label.new()
	hint.text = ("Влево/вправо — меньше/больше (по кругу)\n"
		+ "Пробел / Enter / A или Tab — начать · Q / Backspace / B или Esc — назад")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.modulate.a = 0.75
	column.add_child(hint)


func _dialog_button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(90, 64)
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("6a4318") if state == "hover" else Color("4a3020")
		style.border_color = Color("f6c343")
		style.set_border_width_all(2 if state == "normal" else 3)
		style.set_corner_radius_all(12)
		style.set_content_margin_all(12)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("f6c343"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	return button
