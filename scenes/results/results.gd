extends Control
## Итоги партии: таблица мест и победитель.

## Цвета мест: золото, серебро, бронза, остальные.
const PLACE_COLORS: Array[Color] = [
	Color("f6c343"), Color("d9d9d9"), Color("cd8a4b"), Color("9a8f86"),
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("2b1d18")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	add_child(column)

	if not MatchState.in_progress or MatchState.stats.is_empty():
		column.add_child(_label("Партия не найдена", 48, Color.WHITE))
		return

	var standings := MatchState.standings()
	var winner := standings[0]
	column.add_child(_label("ИТОГИ", 48, Color("f6c343")))
	column.add_child(_label("Победитель: %s!" % winner.display_name, 72, winner.color.lightened(0.3)))

	for i in standings.size():
		var p := standings[i]
		var s := MatchState.get_stats(p)
		var color := PLACE_COLORS[mini(i, PLACE_COLORS.size() - 1)]
		var line := "%d.  %s  —  дефицит: %d,  %d ₽" % [i + 1, p.display_name, s.deficit, s.coins]
		# Рубли из партии уходят в кошелёк игрока — на них покупают одежду на рынке.
		if not p.is_bot():
			PlayerManager.add_to_wallet(p, s.coins)
			line += "   → в кошелёк (всего %d ₽)" % PlayerManager.wallet(p)
		column.add_child(_label(line, 34, color))

	var hint := "Нажми свою кнопку подтверждения, чтобы вернуться в лобби"
	column.add_child(_label(hint, 22, Color(1, 1, 1, 0.6)))


func _process(_delta: float) -> void:
	for p in PlayerManager.players:
		if p.input and p.input.is_just_pressed("confirm"):
			MatchState.abort_to_lobby()
			return


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	return label
