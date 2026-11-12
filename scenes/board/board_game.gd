extends Node3D
## Игра на доске: ходы по очереди, кубик, развилки, клетки, ларёк «Дефицит».
##
## Порядок раунда: каждый игрок по очереди бросает кубик и ходит.
## Когда походили все — запускается мини-игра. После неё доска загружается снова
## и продолжает с того же места (всё состояние хранится в MatchState).

const CHARACTER_SCENE := preload("res://scenes/characters/test_character.tscn")
const DICE_SCENE := preload("res://assets/models/props/dice.glb")
const BOTTLE_SCENE := preload("res://assets/models/props/bottle.glb")
## Сколько ждать броска кубика, потом он бросается сам.
const ROLL_TIMEOUT := 15.0
const DICE_HEIGHT := 2.9
## Поворот кубика (в градусах), при котором грань с числом смотрит на камеру.
const DICE_FACES := {
	1: Vector3(0, 0, 0), 2: Vector3(0, -90, 0), 3: Vector3(90, 0, 0),
	4: Vector3(-90, 0, 0), 5: Vector3(0, 90, 0), 6: Vector3(0, 180, 0),
}
const DEFAULT_ROUNDS := 5
const CAMERA_OFFSET := Vector3(0, 9.0, 8.0)
const HOP_TIME := 0.28

const BLUE_COINS := 3
const RED_COINS := -3
## Случайные события: текст и изменение рублей.
const EVENTS := [
	["Сдал бутылки", 4],
	["Нашёл трёшку в кармане куртки", 3],
	["Бабушка дала на мороженое", 2],
	["Выиграл в «Спортлото»", 8],
	["Обсчитали в гастрономе", -4],
	["Поймал контролёр в трамвае", -3],
	["Кассета зажевалась, купил новую", -5],
]

var _spaces: Array[BoardSpace] = []
var _pawns: Dictionary = {} # PlayerData.id -> персонаж
var _camera_target: Node3D
## Кубик: «стержень» всегда повёрнут к камере, внутри него крутится сам кубик.
var _dice_pivot: Node3D
var _dice: Node3D
var _dice_spinning := false
var _bottle: Node3D
var _timer_bar: ProgressBar
## Крупный кубик в углу экрана — главное отображение выпавшего числа.
var _hud_panel: PanelContainer
var _hud_dice: Node3D
var _hud_spinning := false
var _hud_number: Label
var _hud_steps: Label

var _round_label: Label
var _message_label: Label
var _score_labels: Dictionary = {} # PlayerData.id -> Label с балансом
var _score_panels: Dictionary = {} # PlayerData.id -> PanelContainer карточки

@onready var _camera: Camera3D = $Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _spaces_root: Node3D = $Spaces
@onready var _pawns_root: Node3D = $Pawns
@onready var _ui: CanvasLayer = $UI


func _ready() -> void:
	_sun.rotation_degrees = Vector3(-55, -35, 0)
	_ensure_match_started()

	_spaces = BoardLayout.build(_spaces_root)
	if MatchState.deficit_space < 0:
		MatchState.deficit_space = _random_kiosk_space(-1)
	_spaces[MatchState.deficit_space].set_kiosk(true)

	for p in MatchState.turn_order():
		var pawn := CHARACTER_SCENE.instantiate()
		var space := _spaces[MatchState.get_stats(p).space_index]
		pawn.setup(p, space.stand_position(p.slot))
		_pawns_root.add_child(pawn)
		# На доске фишки двигаем сами, без физики. Выключаем после add_child,
		# иначе Godot включит обработку обратно при входе в сцену.
		pawn.set_physics_process(false)
		_pawns[p.id] = pawn

	_dice_pivot = Node3D.new()
	_dice_pivot.visible = false
	add_child(_dice_pivot)
	_dice = DICE_SCENE.instantiate()
	_dice_pivot.add_child(_dice)
	_bottle = BOTTLE_SCENE.instantiate()
	_bottle.scale = Vector3.ONE * 2.2
	_bottle.visible = false
	add_child(_bottle)

	_build_ui()
	_build_hud_dice()
	_update_ui()
	_camera.look_at_from_position(CAMERA_OFFSET * 1.8, Vector3.ZERO)
	_run_round.call_deferred()


func _process(delta: float) -> void:
	if _dice_pivot.visible:
		# Грань кубика всегда видна с камеры.
		_dice_pivot.look_at(_dice_pivot.global_position * 2.0 - _camera.global_position)
		if _dice_spinning:
			_dice.rotate(Vector3(1.0, 0.8, 0.3).normalized(), delta * 9.0)
	if _hud_spinning:
		_hud_dice.rotate(Vector3(0.7, 1.0, 0.2).normalized(), delta * 7.0)
	if _camera_target:
		var target_pos := _camera_target.global_position + CAMERA_OFFSET
		_camera.global_position = _camera.global_position.lerp(target_pos, minf(1.0, 4.0 * delta))
		_camera.look_at(_camera.global_position - CAMERA_OFFSET)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			MatchState.abort_to_lobby()


## Если сцену доски запустили напрямую (F6), создаём тестовую партию.
func _ensure_match_started() -> void:
	if MatchState.in_progress:
		return
	if PlayerManager.players.is_empty():
		PlayerManager.add_local_player(PlayerData.DeviceKind.KEYBOARD_WASD)
		PlayerManager.add_local_player(PlayerData.DeviceKind.KEYBOARD_ARROWS)
	MatchState.start_new_match(DEFAULT_ROUNDS)


# ---------------- Ход игры ----------------

func _run_round() -> void:
	await _show_message("Раунд %d из %d" % [MatchState.current_round, MatchState.rounds_total], 1.2)
	var order := MatchState.turn_order()
	while MatchState.turn_index < order.size():
		await _play_turn(order[MatchState.turn_index])
		MatchState.turn_index += 1
	_camera_target = null
	await _show_message("Все походили. Время мини-игры!", 1.5)
	SceneManager.change_scene(MatchState.SCENE_ROULETTE)


func _play_turn(p: PlayerData) -> void:
	var pawn: Node3D = _pawns[p.id]
	var stats := MatchState.get_stats(p)
	_camera_target = pawn
	_highlight_score(p)

	# Кубик крутится над головой. Жмёшь — бросается. Не жмёшь 15 сек — бросается сам.
	if p.is_bot():
		_set_message("Ходит %s (бот)..." % p.display_name)
		_bot_press_later(p, "confirm", randf_range(0.8, 1.4))
	else:
		_set_message("Ходит %s. Жми «%s», чтобы бросить кубик!" % [p.display_name, _confirm_hint(p)])
	_dice_pivot.global_position = pawn.global_position + Vector3.UP * DICE_HEIGHT
	_dice_pivot.visible = true
	_dice_spinning = true
	_hud_start_spin(p)
	_timer_bar.visible = not p.is_bot()
	var waited := 0.0
	await get_tree().process_frame
	while not p.input.is_just_pressed("confirm") and waited < ROLL_TIMEOUT:
		waited += get_process_delta_time()
		_timer_bar.value = 1.0 - waited / ROLL_TIMEOUT
		await get_tree().process_frame
	_timer_bar.visible = false
	var roll := randi_range(1, 6)
	await _throw_dice(roll)
	_set_message("%s: выпало %d!" % [p.display_name, roll])
	await get_tree().create_timer(0.6).timeout
	# Кубик над головой исчезает до того, как фишка пойдёт: дальше шаги
	# показывает только крупный кубик слева. Так над фишкой не бывает двух
	# предметов сразу (кубика и бутылочки на развилке).
	await _hide_dice()

	var steps := roll
	_hud_steps.text = "Осталось шагов: %d" % steps
	while steps > 0:
		var current := _spaces[stats.space_index]
		var target := current.next[0]
		if current.next.size() > 1:
			target = await _choose_path(p, current)
		await _hop(pawn, target.stand_position(p.slot))
		stats.space_index = target.index
		steps -= 1
		_hud_steps.text = "Осталось шагов: %d" % steps if steps > 0 else "Пришли!"
		# Проходя мимо ларька, можно купить дефицит.
		if target.index == MatchState.deficit_space:
			await _offer_deficit(p)

	await _apply_space(p, _spaces[stats.space_index])
	_update_ui()


## Развилка: крутим бутылочку — горлышко случайно указывает путь.
func _choose_path(_p: PlayerData, from: BoardSpace) -> BoardSpace:
	var options := from.next
	var chosen := randi() % options.size()
	_set_message("Развилка! Крутим бутылочку...")
	_bottle.global_position = from.global_position + Vector3.UP * 0.7
	_bottle.rotation = Vector3.ZERO
	_bottle.visible = true
	# Горлышко (−Z бутылки) должно смотреть на выбранную клетку.
	var dir := options[chosen].global_position - from.global_position
	var target_yaw := atan2(-dir.x, -dir.z) + TAU * randi_range(4, 6)
	var tween := create_tween()
	tween.tween_property(_bottle, "rotation:y", target_yaw, 2.4) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tween.finished
	options[chosen].set_highlight(true)
	var way := "срезкой!" if chosen > 0 else "по кругу!"
	await _show_message("Бутылочка указала: идём %s" % way, 1.0)
	options[chosen].set_highlight(false)
	_bottle.visible = false
	return options[chosen]


## Кубик над фишкой «схлопывается» и прячется.
func _hide_dice() -> void:
	var tween := create_tween()
	tween.tween_property(_dice_pivot, "scale", Vector3.ONE * 0.01, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	_dice_pivot.visible = false
	_dice_pivot.scale = Vector3.ONE


## Бросок: кубик подпрыгивает, кувыркается и встаёт выпавшей гранью к камере.
func _throw_dice(value: int) -> void:
	_dice_spinning = false
	var start_y := _dice_pivot.position.y
	var up := create_tween()
	up.tween_property(_dice_pivot, "position:y", start_y + 1.2, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.parallel().tween_method(func(t: float) -> void:
		_dice.rotate(Vector3(0.6, 1.0, 0.2).normalized(), t * 0.5), 0.0, 1.0, 0.25)
	await up.finished
	var down := create_tween()
	down.tween_property(_dice_pivot, "position:y", start_y, 0.3) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_hud_show_value(value)
	await _show_dice_face(value, 0.35)
	# Ждём падения, только если оно ещё идёт: ожидание уже завершившегося
	# твина никогда не закончится — из-за этого фишки раньше «зависали».
	if down.is_running():
		await down.finished


# ---------------- Крупный кубик в углу ----------------

func _hud_start_spin(p: PlayerData) -> void:
	_hud_panel.visible = true
	var style := _hud_panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = p.color
	_hud_spinning = true
	_hud_number.text = "?"
	_hud_steps.text = p.display_name


func _hud_show_value(value: int) -> void:
	_hud_spinning = false
	var from := _hud_dice.quaternion
	var to := Quaternion.from_euler((DICE_FACES[value] as Vector3) * (PI / 180.0))
	var tween := create_tween()
	var turn := func(t: float) -> void: _hud_dice.quaternion = from.slerp(to, t)
	tween.tween_method(turn, 0.0, 1.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hud_number.text = str(value)
	_hud_number.pivot_offset = _hud_number.size / 2.0
	_hud_number.scale = Vector2.ONE * 1.8
	create_tween().tween_property(_hud_number, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_hud_dice() -> void:
	_hud_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.06, 0.88)
	style.border_color = Color("f6c343")
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(14)
	_hud_panel.add_theme_stylebox_override("panel", style)
	_hud_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_hud_panel.position = Vector2(28, -190)
	_hud_panel.visible = false
	_ui.add_child(_hud_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_hud_panel.add_child(column)
	var caption := _make_label(20)
	caption.text = "КУБИК"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.modulate = Color("c9b98f")
	column.add_child(caption)

	# Кубик крупным планом: свой маленький 3D-мир.
	var view := SubViewportContainer.new()
	view.custom_minimum_size = Vector2(200, 200)
	view.stretch = true
	column.add_child(view)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	view.add_child(viewport)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	viewport.add_child(light)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.95, 0.88)
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	_hud_dice = DICE_SCENE.instantiate()
	viewport.add_child(_hud_dice)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 1.25)
	cam.fov = 40.0
	viewport.add_child(cam)

	_hud_number = _make_label(72)
	_hud_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_number.add_theme_color_override("font_color", Color("f6c343"))
	_hud_number.add_theme_constant_override("outline_size", 16)
	column.add_child(_hud_number)
	_hud_steps = _make_label(20)
	_hud_steps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hud_steps)


## Плавно повернуть кубик гранью value к камере.
func _show_dice_face(value: int, time: float) -> void:
	var from := _dice.quaternion
	var to := Quaternion.from_euler((DICE_FACES[value] as Vector3) * (PI / 180.0))
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: _dice.quaternion = from.slerp(to, t), 0.0, 1.0, time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished


func _offer_deficit(p: PlayerData) -> void:
	var stats := MatchState.get_stats(p)
	if stats.coins < MatchState.DEFICIT_PRICE:
		await _show_message("Ларёк «Дефицит»: нужно %d ₽, а у тебя %d. Не хватает!" % [
			MatchState.DEFICIT_PRICE, stats.coins], 1.6)
		return

	_set_message("Купить ДЕФИЦИТ за %d ₽?  «%s» — да,  «%s» — нет" % [
		MatchState.DEFICIT_PRICE, _confirm_hint(p), _cancel_hint(p)])
	_bot_press_later(p, "confirm", 0.9) # бот всегда покупает
	await get_tree().process_frame
	while true:
		if p.input.is_just_pressed("confirm"):
			break
		if p.input.is_just_pressed("cancel"):
			return
		await get_tree().process_frame

	MatchState.add_coins(p, -MatchState.DEFICIT_PRICE)
	stats.deficit += 1
	_update_ui()
	await _show_message("%s достал дефицит! Ларёк переезжает..." % p.display_name, 1.6)
	_spaces[MatchState.deficit_space].set_kiosk(false)
	MatchState.deficit_space = _random_kiosk_space(MatchState.deficit_space)
	_spaces[MatchState.deficit_space].set_kiosk(true)


func _apply_space(p: PlayerData, space: BoardSpace) -> void:
	match space.type:
		BoardSpace.Type.BLUE:
			MatchState.add_coins(p, BLUE_COINS)
			_update_ui()
			await _show_message("+%d ₽" % BLUE_COINS, 0.9)
		BoardSpace.Type.RED:
			var lost := MatchState.add_coins(p, RED_COINS)
			_update_ui()
			await _show_message("%d ₽" % lost if lost != 0 else "Красная клетка, но терять нечего", 0.9)
		BoardSpace.Type.EVENT:
			var event: Array = EVENTS.pick_random()
			var change := MatchState.add_coins(p, event[1])
			_update_ui()
			await _show_message("%s!  %+d ₽" % [event[0], change], 1.8)
		_:
			await get_tree().create_timer(0.3).timeout


## Прыжок фишки на соседнюю клетку по дуге.
func _hop(pawn: Node3D, to: Vector3) -> void:
	var from := pawn.global_position
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if flat.length() > 0.01:
		pawn.rotation.y = atan2(-flat.x, -flat.z)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		pawn.global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 0.8,
		0.0, 1.0, HOP_TIME)
	await tween.finished


## Бот «нажимает» кнопку через delay секунд — так же, как живой игрок.
## Для людей ничего не делает.
func _bot_press_later(p: PlayerData, action: String, delay: float) -> void:
	if not p.is_bot():
		return
	await get_tree().create_timer(delay).timeout
	p.bot_input().press(action)


func _random_kiosk_space(exclude: int) -> int:
	var candidates: Array[int] = []
	for s in _spaces:
		if s.kiosk_allowed and s.type != BoardSpace.Type.START and s.index != exclude:
			candidates.append(s.index)
	return candidates.pick_random()


# ---------------- Интерфейс ----------------

func _confirm_hint(p: PlayerData) -> String:
	match p.device_kind:
		PlayerData.DeviceKind.BOT:
			return "—"
		PlayerData.DeviceKind.KEYBOARD_WASD:
			return "Пробел"
		PlayerData.DeviceKind.KEYBOARD_ARROWS:
			return "Enter"
		_:
			return "A"


func _cancel_hint(p: PlayerData) -> String:
	match p.device_kind:
		PlayerData.DeviceKind.KEYBOARD_WASD:
			return "Q"
		PlayerData.DeviceKind.KEYBOARD_ARROWS:
			return "Backspace"
		_:
			return "B"


func _set_message(text: String) -> void:
	_message_label.text = text


func _show_message(text: String, seconds: float) -> void:
	_set_message(text)
	await get_tree().create_timer(seconds).timeout


func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 28)
	_ui.add_child(root)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	column.add_child(top)

	_round_label = _make_label(30)
	_round_label.custom_minimum_size.x = 260
	top.add_child(_round_label)

	# Карточка игрока: слева живой «портрет на паспорт», правее ник и ниже баланс.
	for p in MatchState.turn_order():
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(230, 0)
		var style := StyleBoxFlat.new()
		style.bg_color = p.color.darkened(0.35)
		style.set_corner_radius_all(10)
		style.set_content_margin_all(8)
		style.border_color = Color("f6c343")
		panel.add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		var photo_frame := PanelContainer.new()
		var photo_style := StyleBoxFlat.new()
		photo_style.bg_color = Color("e9e2cf") # светлый фон, как у фото на паспорт
		photo_style.set_corner_radius_all(6)
		photo_frame.add_theme_stylebox_override("panel", photo_style)
		photo_frame.add_child(PlayerPortrait.new().setup(p, 64))
		row.add_child(photo_frame)
		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(texts)
		var name_label := _make_label(22)
		name_label.text = p.display_name
		texts.add_child(name_label)
		var label := _make_label(22)
		label.add_theme_color_override("font_color", Color("f6c343"))
		texts.add_child(label)
		top.add_child(panel)
		_score_labels[p.id] = label
		_score_panels[p.id] = panel

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	_timer_bar = ProgressBar.new()
	_timer_bar.max_value = 1.0
	_timer_bar.step = 0.0 # без округления: полоска течёт плавно, а не рывками
	_timer_bar.value = 1.0
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 14)
	_timer_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_timer_bar.custom_minimum_size.x = 520
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("f6c343")
	fill.set_corner_radius_all(7)
	_timer_bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.5)
	back.set_corner_radius_all(7)
	_timer_bar.add_theme_stylebox_override("background", back)
	_timer_bar.visible = false

	_message_label = _make_label(34)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message_label)
	column.add_child(_timer_bar)

	var hint := _make_label(16)
	hint.text = "Esc — выйти в лобби"
	hint.modulate.a = 0.6
	column.add_child(hint)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	return label


func _update_ui() -> void:
	_round_label.text = "Раунд %d / %d" % [MatchState.current_round, MatchState.rounds_total]
	for p in MatchState.turn_order():
		var s := MatchState.get_stats(p)
		var label := _score_labels[p.id] as Label
		label.text = "%d ₽" % s.coins # дефицит здесь не пишем — только баланс


func _highlight_score(current: PlayerData) -> void:
	for p in MatchState.turn_order():
		var panel := _score_panels[p.id] as PanelContainer
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		style.set_border_width_all(4 if p == current else 0)
