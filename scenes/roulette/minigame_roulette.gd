extends Control
## Рулетка мини-игр: карточки прокручиваются и останавливаются на случайной игре.
##
## Уже сыгранные в этой партии мини-игры участвуют в прокрутке, но выделены серым
## и выпасть не могут. Когда сыграны все — снова доступны все.

const CARD_SIZE := Vector2(300, 400)
const CARD_GAP := 30.0
const MIN_CARDS_IN_STRIP := 36
const SPIN_TIME := 4.5
const PLAYED_TINT := Color(0.4, 0.4, 0.4)
## Карточки, которые не выпали, после остановки рулетки (темнее сыгранных).
const NOT_PICKED_TINT := Color(0.22, 0.22, 0.22)
## Картинки карточек: <id мини-игры>.png. Размер — вертикальный 3:4 (например 900×1200).
const CARD_IMAGES_DIR := "res://assets/ui/minigames/"

var _strip: HBoxContainer
var _title: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if not MatchState.in_progress:
		# Запуск сцены напрямую (F6) для теста.
		if PlayerManager.players.is_empty():
			PlayerManager.add_local_player(PlayerData.DeviceKind.KEYBOARD_WASD)
		MatchState.start_new_match(5)

	# Серыми показываем игры, сыгранные ДО этого выбора.
	var played_before: Array[int] = MatchState.played_minigames.duplicate()
	if played_before.size() >= MatchState.MINIGAMES.size():
		played_before.clear()
	var picked := MatchState.pick_next_minigame()

	_build_ui(played_before)
	_spin.call_deferred(picked)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			MatchState.abort_to_lobby()


func _spin(picked: int) -> void:
	var count := MatchState.MINIGAMES.size()
	var reps := ceili(float(MIN_CARDS_IN_STRIP) / count)
	# Останавливаемся на нужной карточке ближе к концу ленты.
	var target_card := (reps - 2) * count + picked
	# Ждём, пока контейнер расставит карточки, и берём их настоящие места:
	# карточка может быть шире из-за длинного текста.
	await get_tree().process_frame
	await get_tree().process_frame
	var card := _strip.get_child(target_card) as Control
	var first := _strip.get_child(0) as Control
	var center := (_strip.get_parent() as Control).size.x / 2.0
	_strip.position.x = center - (first.position.x + first.size.x / 2.0)
	var target_x := center - (card.position.x + card.size.x / 2.0)

	# 1) Разгон и замедление — останавливаемся чуть-чуть не доехав или проехав.
	var miss := card.size.x * randf_range(0.18, 0.35) * (1.0 if randf() < 0.5 else -1.0)
	var tween := create_tween()
	tween.tween_property(_strip, "position:x", target_x + miss, SPIN_TIME) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tween.finished
	# 2) Короткая пауза и плавный «доводящий» рывок точно в центр.
	await get_tree().create_timer(0.15).timeout
	var snap := create_tween()
	snap.tween_property(_strip, "position:x", target_x, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await snap.finished

	# Выбор сделан: остальные карточки плавно темнеют — сильнее, чем «сыгранные» (PLAYED_TINT),
	# чтобы выбранная сразу бросалась в глаза.
	var dim := create_tween().set_parallel(true)
	for child in _strip.get_children():
		if child != card:
			dim.tween_property(child, "modulate", NOT_PICKED_TINT, 0.35)
	card.pivot_offset = card.size / 2.0
	var pulse := create_tween().set_loops(3)
	pulse.tween_property(card, "scale", Vector2.ONE * 1.12, 0.15)
	pulse.tween_property(card, "scale", Vector2.ONE, 0.15)
	var info: Dictionary = MatchState.MINIGAMES[picked]
	_title.text = "Мини-игра: %s!" % String(info["title"]).replace("\n", " ")
	await get_tree().create_timer(2.0).timeout
	SceneManager.change_scene(info["scene"])


func _build_ui(played_before: Array[int]) -> void:
	var background := ColorRect.new()
	background.color = Color("2b1d18")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_title = _label("Выбираем мини-игру...", 56, Color("f6c343"))
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.position.y = 90
	add_child(_title)

	var window := Control.new()
	window.clip_contents = true
	window.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	window.custom_minimum_size.y = CARD_SIZE.y + 40
	window.offset_top = -(CARD_SIZE.y + 40) / 2.0
	window.offset_bottom = (CARD_SIZE.y + 40) / 2.0
	add_child(window)

	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", int(CARD_GAP))
	_strip.position.y = 20
	window.add_child(_strip)

	var count := MatchState.MINIGAMES.size()
	var total := ceili(float(MIN_CARDS_IN_STRIP) / count) * count
	for i in total:
		var index := i % count
		_strip.add_child(_make_card(MatchState.MINIGAMES[index], played_before.has(index)))

	# Указатель по центру экрана: полоски над и под лентой.
	var center := get_viewport_rect().size / 2.0
	for top in [true, false]:
		var marker := ColorRect.new()
		marker.color = Color("f6c343")
		marker.size = Vector2(8, 46)
		var y := -(CARD_SIZE.y / 2.0 + 70) if top else CARD_SIZE.y / 2.0 + 24
		marker.position = center + Vector2(-4, y)
		add_child(marker)


func _make_card(info: Dictionary, played: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	panel.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = info["color"]
	style.set_corner_radius_all(18)
	style.set_border_width_all(6)
	style.border_color = Color("f6c343")
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var image_path := "%s%s.png" % [CARD_IMAGES_DIR, info.get("id", "")]
	if ResourceLoader.exists(image_path):
		# Карточка-картинка: изображение на всю карточку, название внизу на тёмной плашке.
		var stack := Control.new()
		panel.add_child(stack)
		var picture := TextureRect.new()
		picture.texture = load(image_path)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.set_anchors_preset(Control.PRESET_FULL_RECT)
		stack.add_child(picture)
		var plate := ColorRect.new()
		plate.color = Color(0, 0, 0, 0.6)
		plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		plate.offset_top = -86
		stack.add_child(plate)
		var title := _label(String(info["title"]).replace("\n", " "), 28, Color.WHITE)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.set_anchors_preset(Control.PRESET_FULL_RECT)
		plate.add_child(title)
	else:
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 20)
		panel.add_child(column)
		column.add_child(_label(info["title"], 40, Color.WHITE))
		column.add_child(_label(info["tagline"], 24, Color("f6e7a8")))
	if played:
		var stamp := _label("СЫГРАНО", 34, Color("ff6b5a"))
		panel.add_child(stamp)
		panel.modulate = PLAYED_TINT
	return panel


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	return label
