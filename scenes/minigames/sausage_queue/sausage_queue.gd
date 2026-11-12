extends Node3D
## Мини-игра «Очередь за колбасой» (реакция).
##
## Игроки стоят перед ларьком. Продавщица тётя Валя держит колбасу.
## Когда она кричит «КОЛБАСА!» и поднимает её — жми свою кнопку быстрее всех:
## у нажавшего поднимается рука. Нажал раньше — фальстарт, последнее место.
## Победитель забирает колбасу.

enum Phase { INTRO, WAIT, GO, DONE }

const CHARACTER_SCENE := preload("res://scenes/characters/test_character.tscn")
const SAUSAGE_SCENE := preload("res://assets/models/props/sausage.glb")
const GO_TIMEOUT := 2.5
const PLAYER_SPACING := 1.5
const PLAYERS_Z := 0.4
## Боты: время реакции (сек) и шанс фальстарта.
const BOT_REACTION := Vector2(0.28, 0.65)
const BOT_FALSE_START_CHANCE := 0.12

var _phase := Phase.INTRO
var _go_time_ms := 0
var _pressed: Array[PlayerData] = []
var _false_starts: Array[PlayerData] = []
var _characters: Dictionary = {} # PlayerData.id -> PlayerCharacter
var _cards: Dictionary = {} # PlayerData.id -> Label

var _seller: PlayerCharacter
var _sausage: Node3D
var _speech: Label3D

@onready var _camera: Camera3D = $Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _characters_root: Node3D = $Characters
@onready var _ui: CanvasLayer = $UI


func _ready() -> void:
	if not MatchState.in_progress:
		# Запуск сцены напрямую (F6) для теста.
		if PlayerManager.players.is_empty():
			PlayerManager.add_local_player(PlayerData.DeviceKind.KEYBOARD_WASD)
			PlayerManager.add_local_player(PlayerData.DeviceKind.KEYBOARD_ARROWS)
		MatchState.start_new_match(1)

	_sun.rotation_degrees = Vector3(-50, 30, 0)
	_camera.look_at_from_position(Vector3(5.0, 3.6, 6.2), Vector3(0, 1.3, -1.2))
	_spawn_seller()
	_spawn_players()
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
		var character: PlayerCharacter = _characters[p.id]
		character.raise_hand(true)
		if _phase == Phase.WAIT:
			_false_starts.append(p)
			_set_card(p, "ФАЛЬСТАРТ!", Color("ff6b5a"))
			_lower_hand_later(character)
		else:
			_pressed.append(p)
			var ms := Time.get_ticks_msec() - _go_time_ms
			_set_card(p, "%d-й в очереди\n%.2f сек" % [_pressed.size(), ms / 1000.0], Color("a8f0a0"))


func _run() -> void:
	_say("Подходим, не толпимся!")
	await get_tree().create_timer(2.5).timeout

	_phase = Phase.WAIT
	_say("Ждём завоза...")
	var wait := randf_range(1.5, 4.0)
	for p in MatchState.turn_order():
		if p.is_bot() and randf() < BOT_FALSE_START_CHANCE:
			_bot_press_later(p, randf_range(0.3, wait - 0.1))
	await get_tree().create_timer(wait).timeout

	_phase = Phase.GO
	_go_time_ms = Time.get_ticks_msec()
	_say("КОЛБАСА!", Color("ffe14d"), 200)
	_seller.raise_hand(true, 0.1)
	for p in MatchState.turn_order():
		if p.is_bot():
			_bot_press_later(p, randf_range(BOT_REACTION.x, BOT_REACTION.y))

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

	for i in places.size():
		var reward: int = MatchState.MINIGAME_REWARDS[i] if i < MatchState.MINIGAME_REWARDS.size() else 0
		var card := _cards[places[i].id] as Label
		card.text += "\n%d место: +%d ₽" % [i + 1, reward]

	# Колбаса достаётся первому в очереди.
	if not _pressed.is_empty():
		var winner: PlayerCharacter = _characters[_pressed[0].id]
		_sausage.reparent(winner.right_hand, false)
		_seller.raise_hand(false)
		_say("Держи, %s! Следующий!" % _pressed[0].display_name)
	else:
		_say("Колбасы хватило не всем!")

	await get_tree().create_timer(3.0).timeout
	MatchState.finish_minigame(places)


## Бот нажимает кнопку через delay секунд (если ещё не нажимал).
func _bot_press_later(p: PlayerData, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if _phase in [Phase.WAIT, Phase.GO] and not _pressed.has(p) and not _false_starts.has(p):
		p.bot_input().press("confirm")


func _lower_hand_later(character: PlayerCharacter) -> void:
	await get_tree().create_timer(0.6).timeout
	character.raise_hand(false)


func _spawn_seller() -> void:
	var seller_data := PlayerData.new()
	seller_data.display_name = "Тётя Валя"
	seller_data.color = Color("f2efe6") # белый халат
	seller_data.slot = 0
	_seller = CHARACTER_SCENE.instantiate()
	_seller.setup(seller_data, Vector3(0, 0, -3.1))
	_seller.name = "Seller"
	_seller.rotation.y = PI # лицом к покупателям
	_seller.scale = Vector3.ONE * 1.1
	_characters_root.add_child(_seller)
	_seller.set_physics_process(false)

	# Белый колпак продавщицы.
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.3
	cap_mesh.bottom_radius = 0.34
	cap_mesh.height = 0.26
	cap_mesh.radial_segments = 10
	cap.mesh = cap_mesh
	cap.position.y = 1.62
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color.WHITE
	cap.material_override = cap_mat
	_seller.visual.add_child(cap)

	_sausage = SAUSAGE_SCENE.instantiate()
	_sausage.scale = Vector3.ONE * 1.4
	_seller.hold_item(_sausage)

	_speech = Label3D.new()
	_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_speech.no_depth_test = true
	_speech.outline_size = 24
	_speech.position = Vector3(0, 3.6, -2.6)
	add_child(_speech)


func _spawn_players() -> void:
	var order := MatchState.turn_order()
	for i in order.size():
		var p := order[i]
		var character: PlayerCharacter = CHARACTER_SCENE.instantiate()
		var x := (i - (order.size() - 1) / 2.0) * PLAYER_SPACING
		character.setup(p, Vector3(x, 0, PLAYERS_Z))
		_characters_root.add_child(character)
		character.set_physics_process(false) # стоят в очереди, не ходят
		_characters[p.id] = character


func _say(text: String, color: Color = Color.WHITE, font_size: int = 110) -> void:
	_speech.text = text
	_speech.modulate = color
	_speech.font_size = font_size


func _set_card(p: PlayerData, text: String, color: Color) -> void:
	var card := _cards[p.id] as Label
	card.text = "%s\n%s" % [p.display_name, text]
	card.add_theme_color_override("font_color", color)


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
	column.add_child(_label("Очередь за колбасой", 52, Color("f6c343")))
	column.add_child(_label("Жми «Пробел» / «Enter» / «A», когда тётя Валя крикнет «КОЛБАСА!»\n"
		+ "Нажмёшь раньше — фальстарт и в конец очереди.", 22, Color.WHITE))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	for p in MatchState.turn_order():
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(250, 120)
		var style := StyleBoxFlat.new()
		style.bg_color = p.color.darkened(0.3)
		style.set_corner_radius_all(12)
		style.set_content_margin_all(10)
		panel.add_theme_stylebox_override("panel", style)
		var card := _label("%s\nЖдёт..." % p.display_name, 24, Color.WHITE)
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
