extends Control
## Мини-игра «Очередь за колбасой» (первая простая мини-игра на реакцию).
##
## Ждём, пока продавщица крикнет «КОЛБАСА!», и жмём свою кнопку быстрее всех.
## Нажал раньше времени — фальстарт, последнее место.

enum Phase { INTRO, WAIT, GO, DONE }

const GO_TIMEOUT := 2.5

var _phase := Phase.INTRO
var _go_time_ms := 0
var _pressed: Array[PlayerData] = []
var _false_starts: Array[PlayerData] = []
var _cards: Dictionary = {} # PlayerData.id -> Label

var _shout_label: Label
var _background: ColorRect


func _ready() -> void:
	if not MatchState.in_progress:
		# Запуск сцены напрямую (F6) для теста.
		if PlayerManager.players.is_empty():
			PlayerManager.add_local_player(PlayerData.DeviceKind.KEYBOARD_WASD)
			PlayerManager.add_local_player(PlayerData.DeviceKind.KEYBOARD_ARROWS)
		MatchState.start_new_match(1)
	_build_ui()
	_run.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			MatchState.abort_to_lobby()


func _process(_delta: float) -> void:
	if _phase != Phase.WAIT and _phase != Phase.GO:
		return
	for p in MatchState.turn_order():
		if p.input == null or _pressed.has(p) or _false_starts.has(p):
			continue
		if not p.input.is_just_pressed("confirm"):
			continue
		if _phase == Phase.WAIT:
			_false_starts.append(p)
			_set_card(p, "ФАЛЬСТАРТ!", Color("ff6b5a"))
		else:
			_pressed.append(p)
			var ms := Time.get_ticks_msec() - _go_time_ms
			_set_card(p, "%d-й в очереди\n%.2f сек" % [_pressed.size(), ms / 1000.0], Color("a8f0a0"))


func _run() -> void:
	_shout_label.text = "Приготовились..."
	await get_tree().create_timer(2.5).timeout

	_phase = Phase.WAIT
	_shout_label.text = "Ждём завоза..."
	await get_tree().create_timer(randf_range(1.5, 4.0)).timeout

	_phase = Phase.GO
	_go_time_ms = Time.get_ticks_msec()
	_shout_label.text = "КОЛБАСА!"
	_shout_label.add_theme_color_override("font_color", Color("ffe14d"))
	_background.color = Color("8c1c13")

	var waited := 0.0
	var total := MatchState.turn_order().size()
	while waited < GO_TIMEOUT and _pressed.size() + _false_starts.size() < total:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_phase = Phase.DONE

	# Места: кто нажал (по порядку) → кто не успел → фальстарты.
	var places: Array[PlayerData] = _pressed.duplicate()
	for p in MatchState.turn_order():
		if not places.has(p) and not _false_starts.has(p):
			places.append(p)
			_set_card(p, "Не успел...", Color(1, 1, 1, 0.6))
	places.append_array(_false_starts)

	_shout_label.text = "Колбасы хватило не всем!"
	_background.color = Color("3b2a22")
	for i in places.size():
		var reward: int = MatchState.MINIGAME_REWARDS[i] if i < MatchState.MINIGAME_REWARDS.size() else 0
		var card := _cards[places[i].id] as Label
		card.text += "\n%d место: +%d ₽" % [i + 1, reward]
	await get_tree().create_timer(3.0).timeout
	MatchState.finish_minigame(places)


func _set_card(p: PlayerData, text: String, color: Color) -> void:
	var card := _cards[p.id] as Label
	card.text = "%s\n%s" % [p.display_name, text]
	card.add_theme_color_override("font_color", color)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_background = ColorRect.new()
	_background.color = Color("3b2a22")
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 40)
	add_child(column)

	var title := _label("Очередь за колбасой", 56, Color("f6c343"))
	column.add_child(title)
	var rules := _label("Жми «Пробел» / «Enter» / «A», когда продавщица крикнет «КОЛБАСА!»\n"
		+ "Нажмёшь раньше — фальстарт и в конец очереди.", 24, Color.WHITE)
	column.add_child(rules)

	_shout_label = _label("", 110, Color.WHITE)
	column.add_child(_shout_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	for p in MatchState.turn_order():
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(260, 150)
		var style := StyleBoxFlat.new()
		style.bg_color = p.color.darkened(0.3)
		style.set_corner_radius_all(12)
		style.set_content_margin_all(12)
		panel.add_theme_stylebox_override("panel", style)
		var card := _label("%s\nЖдёт..." % p.display_name, 26, Color.WHITE)
		panel.add_child(card)
		row.add_child(panel)
		_cards[p.id] = card


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	return label
