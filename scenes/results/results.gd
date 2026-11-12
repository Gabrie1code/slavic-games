extends Control
## Итоги партии: 3D-пьедестал (PodiumStage) — персонажи игроков с кубками радуются
## каждый по-своему; под ним — ник («(вы)» у живых игроков) и «Заработал: N ₽»,
## рубли уходят в кошелёк.
## Кнопка «Вернуться в лобби» (мышью) или кнопка подтверждения игрока.

## Цвета мест: золото, серебро, бронза, остальные.
const PLACE_COLORS: Array[Color] = [
	Color("f6c343"), Color("d9d9d9"), Color("cd8a4b"), Color("9a8f86"),
]
## Порядок колонок на пьедестале: слева 2-е, в центре 1-е, справа 3-е.
const PODIUM_ORDER: Array[int] = [1, 0, 2]
## Первые доли секунды кнопки не слушаем (нажатие из мини-игры не должно сразу закрыть итоги).
const INPUT_DELAY := 0.8

var _time := 0.0
var _button: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # кнопку «Вернуться в лобби» жмут мышью
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("2b1d18")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	if not MatchState.in_progress or MatchState.stats.is_empty():
		column.add_child(_label("Партия не найдена", 48, Color.WHITE))
		_add_button(column)
		return

	var standings := MatchState.standings()
	column.add_child(_label("ИТОГИ ПАРТИИ", 40, Color("f6c343")))
	column.add_child(_label("Победитель: %s!" % standings[0].display_name, 64,
		standings[0].color.lightened(0.3)))

	var stage := PodiumStage.new()
	stage.custom_minimum_size = Vector2(1500, 520)
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage.setup(standings)
	column.add_child(stage)
	var podium := HBoxContainer.new()
	podium.alignment = BoxContainer.ALIGNMENT_CENTER
	# Колонки подписей стоят под своими ступенями (шаг 168 px = 1.55 м на пьедестале).
	podium.add_theme_constant_override("separation", 10)
	column.add_child(podium)
	for place in PODIUM_ORDER:
		if place < standings.size():
			podium.add_child(_stats_column(standings[place], place))

	# Четвёртое место и дальше — строкой под пьедесталом.
	for place in range(3, standings.size()):
		var p := standings[place]
		var s := MatchState.get_stats(p)
		var line := "%d.  %s  —  заработал: %d ₽" % [place + 1, _shown_name(p), s.coins]
		column.add_child(_label(line + _wallet_note(p, s.coins), 26, PLACE_COLORS[3]))

	_add_button(column)


func _process(delta: float) -> void:
	_time += delta
	if _time < INPUT_DELAY:
		return
	for p in PlayerManager.players:
		if p.input and p.input.is_just_pressed("confirm"):
			_back_to_lobby()
			return


## Подпись под ступенью: ник (цветом игрока), сколько заработал, прибавка в кошелёк.
func _stats_column(p: PlayerData, place: int) -> VBoxContainer:
	var s := MatchState.get_stats(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.custom_minimum_size.x = 158
	box.add_child(_label(_shown_name(p), 30, p.color.lightened(0.3)))
	box.add_child(_label("Заработал: %d ₽" % s.coins, 22, PLACE_COLORS[place]))
	var note := _wallet_note(p, s.coins)
	if note != "":
		box.add_child(_label(note.strip_edges().replace(" (", "\n("), 18, Color("8fd694")))
	return box


## Ник для итогов: у живого игрока (не бота) — с пометкой «(вы)».
func _shown_name(p: PlayerData) -> String:
	return p.display_name if p.is_bot() else "%s (вы)" % p.display_name


## Рубли из партии уходят в кошелёк живого игрока (на них покупают одежду).
func _wallet_note(p: PlayerData, coins: int) -> String:
	if p.is_bot():
		return ""
	PlayerManager.add_to_wallet(p, coins)
	return "   +%d ₽ в кошелёк (всего %d ₽)" % [coins, PlayerManager.wallet(p)]


func _add_button(column: VBoxContainer) -> void:
	_add_confetti() # поверх пьедестала (кнопку не закрывает: частицы мышь не ловят)
	var holder := CenterContainer.new()
	column.add_child(holder)
	_button = Button.new()
	_button.text = "Вернуться в лобби"
	_button.focus_mode = Control.FOCUS_NONE
	_button.custom_minimum_size = Vector2(380, 70)
	_button.add_theme_font_size_override("font_size", 32)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("8a5a12") if state == "normal" else Color("a8701a")
		style.border_color = Color("f6c343")
		style.set_border_width_all(4)
		style.set_corner_radius_all(16)
		_button.add_theme_stylebox_override(state, style)
	_button.add_theme_color_override("font_color", Color.WHITE)
	_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_button.pressed.connect(_back_to_lobby)
	holder.add_child(_button)
	column.add_child(_label("или нажми свою кнопку подтверждения (Пробел / Enter / A)", 20,
		Color(1, 1, 1, 0.55)))


func _back_to_lobby() -> void:
	set_process(false)
	if _button:
		_button.disabled = true
	MatchState.abort_to_lobby()


## Конфетти сыплется сверху — праздник же.
func _add_confetti() -> void:
	var confetti := CPUParticles2D.new()
	confetti.amount = 90
	confetti.lifetime = 6.0
	confetti.preprocess = 3.0
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(1100, 10)
	confetti.position = Vector2(960, -20)
	confetti.direction = Vector2(0, 1)
	confetti.spread = 25.0
	confetti.gravity = Vector2(0, 60)
	confetti.initial_velocity_min = 40.0
	confetti.initial_velocity_max = 120.0
	confetti.angular_velocity_min = -200.0
	confetti.angular_velocity_max = 200.0
	confetti.scale_amount_min = 6.0
	confetti.scale_amount_max = 11.0
	var colors := Gradient.new()
	colors.set_color(0, Color("f6c343"))
	colors.set_color(1, Color("ff6b5a"))
	colors.add_point(0.33, Color("8fd694"))
	colors.add_point(0.66, Color("6fb3ff"))
	confetti.color_initial_ramp = colors
	add_child(confetti)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	return label
