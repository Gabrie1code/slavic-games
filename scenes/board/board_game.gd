extends Node3D
## Игра на доске: ходы по очереди, кубик, развилки, клетки, ларёк «Дефицит».
##
## Порядок раунда: каждый игрок по очереди бросает кубик и ходит.
## Когда походили все — запускается мини-игра. После неё доска загружается снова
## и продолжает с того же места (всё состояние хранится в MatchState).

const CHARACTER_SCENE := preload("res://scenes/characters/test_character.tscn")
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
var _dice_label: Label3D

var _round_label: Label
var _message_label: Label
var _score_labels: Dictionary = {} # PlayerData.id -> Label

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

	_dice_label = Label3D.new()
	_dice_label.font_size = 160
	_dice_label.outline_size = 32
	_dice_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_dice_label.no_depth_test = true
	_dice_label.modulate = Color("f6c343")
	_dice_label.outline_modulate = Color("7a1410")
	_dice_label.visible = false
	add_child(_dice_label)

	_build_ui()
	_update_ui()
	_camera.look_at_from_position(CAMERA_OFFSET * 1.8, Vector3.ZERO)
	_run_round.call_deferred()


func _process(delta: float) -> void:
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

	# Кубик: числа крутятся, игрок жмёт — останавливается.
	_set_message("Ходит %s. Жми «%s», чтобы бросить кубик!" % [p.display_name, _confirm_hint(p)])
	_dice_label.visible = true
	var roll := 1
	var spin := 0.0
	_dice_label.global_position = pawn.global_position + Vector3.UP * 3.0
	await get_tree().process_frame
	# Проверяем нажатие каждый кадр, а число меняем раз в 0.06 сек.
	while not p.input.is_just_pressed("confirm"):
		spin += get_process_delta_time()
		if spin >= 0.06:
			spin = 0.0
			roll = roll % 6 + 1
			_dice_label.text = str(roll)
		await get_tree().process_frame
	roll = randi_range(1, 6)
	_dice_label.text = str(roll)
	_set_message("%s: выпало %d!" % [p.display_name, roll])
	await get_tree().create_timer(0.6).timeout

	var steps := roll
	while steps > 0:
		var current := _spaces[stats.space_index]
		var target := current.next[0]
		if current.next.size() > 1:
			target = await _choose_path(p, current)
		await _hop(pawn, target.stand_position(p.slot))
		stats.space_index = target.index
		steps -= 1
		_dice_label.text = str(steps) if steps > 0 else ""
		_dice_label.global_position = pawn.global_position + Vector3.UP * 3.0
		# Проходя мимо ларька, можно купить дефицит.
		if target.index == MatchState.deficit_space:
			await _offer_deficit(p)

	_dice_label.visible = false
	await _apply_space(p, _spaces[stats.space_index])
	_update_ui()


## Развилка: игрок листает варианты влево/вправо и подтверждает.
func _choose_path(p: PlayerData, from: BoardSpace) -> BoardSpace:
	var options := from.next
	var selected := 0
	_set_message("Развилка! Выбери путь: влево/вправо, «%s» — идти" % _confirm_hint(p))
	options[selected].set_highlight(true)
	await get_tree().process_frame
	while not p.input.is_just_pressed("confirm"):
		var dir := 0
		if p.input.is_just_pressed("move_left") or p.input.is_just_pressed("move_up"):
			dir = -1
		elif p.input.is_just_pressed("move_right") or p.input.is_just_pressed("move_down"):
			dir = 1
		if dir != 0:
			options[selected].set_highlight(false)
			selected = posmod(selected + dir, options.size())
			options[selected].set_highlight(true)
		await get_tree().process_frame
	options[selected].set_highlight(false)
	return options[selected]


func _offer_deficit(p: PlayerData) -> void:
	var stats := MatchState.get_stats(p)
	if stats.coins < MatchState.DEFICIT_PRICE:
		await _show_message("Ларёк «Дефицит»: нужно %d ₽, а у тебя %d. Не хватает!" % [
			MatchState.DEFICIT_PRICE, stats.coins], 1.6)
		return

	_set_message("Купить ДЕФИЦИТ за %d ₽?  «%s» — да,  «%s» — нет" % [
		MatchState.DEFICIT_PRICE, _confirm_hint(p), _cancel_hint(p)])
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


func _random_kiosk_space(exclude: int) -> int:
	var candidates: Array[int] = []
	for s in _spaces:
		if s.kiosk_allowed and s.type != BoardSpace.Type.START and s.index != exclude:
			candidates.append(s.index)
	return candidates.pick_random()


# ---------------- Интерфейс ----------------

func _confirm_hint(p: PlayerData) -> String:
	match p.device_kind:
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

	for p in MatchState.turn_order():
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(230, 0)
		var style := StyleBoxFlat.new()
		style.bg_color = p.color.darkened(0.35)
		style.set_corner_radius_all(10)
		style.set_content_margin_all(10)
		style.border_color = Color("f6c343")
		panel.add_theme_stylebox_override("panel", style)
		var label := _make_label(22)
		panel.add_child(label)
		top.add_child(panel)
		_score_labels[p.id] = label

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	_message_label = _make_label(34)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message_label)

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
		label.text = "%s\n%d ₽   ·   Дефицит: %d" % [p.display_name, s.coins, s.deficit]


func _highlight_score(current: PlayerData) -> void:
	for p in MatchState.turn_order():
		var panel := (_score_labels[p.id] as Label).get_parent() as PanelContainer
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		style.set_border_width_all(4 if p == current else 0)
