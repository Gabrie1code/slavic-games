extends Node3D
## Тестовое лобби: игроки подключаются со своих устройств и бегают по комнате.
##
## Вход:  Пробел/E — левая клавиатура, Enter — правая клавиатура, A — геймпад.
## Выход: Q, Backspace/Shift или B на геймпаде.
## Начать партию: все живые игроки подходят к телевизору и жмут кнопку действия («Готов»).
## Когда готовы все — спросим про ботов (если есть места), потом отсчёт 5 сек и старт.
## Рынок (справа): подойти и нажать кнопку подтверждения — откроется гардероб.

const CHARACTER_SCENE := preload("res://scenes/characters/test_character.tscn")
const SPAWN_RADIUS := 3.0
const ROUNDS := 5
const MARKET_POS := Vector3(7.0, 0.0, -1.6)
const MARKET_RADIUS := 2.0
const TV_ZONE_POS := Vector3(0.0, 0.0, -4.0)
const TV_ZONE_RADIUS := 1.8
const COUNTDOWN := 5.0

var _characters: Dictionary = {} # PlayerData.id -> персонаж
var _slot_panels: Array[PanelContainer] = []

## Окно «Добавить ботов?»
var _bot_dialog: PanelContainer
var _bot_count_label: Label
var _bot_count := 0

## Готовые к старту игроки: PlayerData.id -> надпись «ГОТОВ» над головой.
var _ready_marks: Dictionary = {}
## Отсчёт до старта (сек). Меньше нуля — отсчёта нет.
var _countdown := -1.0
var _countdown_label: Label

## Открытые примерочные: PlayerData.id -> DressingRoom
var _rooms: Dictionary = {}
var _rooms_root: Control

@onready var _players_root: Node3D = $Players
@onready var _camera: Camera3D = $Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _ui: CanvasLayer = $UI


func _ready() -> void:
	_camera.look_at_from_position(Vector3(0, 9.5, 10.5), Vector3(0, 0, 0.5))
	_sun.rotation_degrees = Vector3(-55, -35, 0)
	_build_ui()
	_build_market()
	_build_tv_zone()

	# Боты прошлой партии в лобби не нужны: при старте спросим заново.
	PlayerManager.remove_bots()
	PlayerManager.player_joined.connect(_on_player_joined)
	PlayerManager.player_left.connect(_on_player_left)
	# Игроки, которые уже вошли раньше (например, вернулись в лобби).
	for p in PlayerManager.players:
		_on_player_joined(p)
	_refresh_slots()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return

	if event is InputEventKey:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_ESCAPE:
			if _bot_dialog.visible:
				_close_bot_dialog()
			else:
				get_tree().quit()
			return
		if key.physical_keycode == KEY_F9:
			_test_add_money()
			return
		if _bot_dialog.visible:
			return
		var scheme := InputSetup.keyboard_join_scheme(key.physical_keycode)
		# Пока открыта примерочная, Enter — это «подтвердить» в меню, а не вход игрока.
		if scheme == PlayerData.DeviceKind.KEYBOARD_ARROWS and not _rooms.is_empty():
			return
		if scheme != -1:
			PlayerManager.add_local_player(scheme as PlayerData.DeviceKind)
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if _bot_dialog.visible:
			return
		if button.button_index == JOY_BUTTON_A:
			PlayerManager.add_local_player(PlayerData.DeviceKind.JOYPAD, button.device)


## Все живые игроки готовы: спросить про ботов (если есть места), иначе — сразу отсчёт.
func _all_ready() -> void:
	_close_all_wardrobes()
	if PlayerManager.free_slots() > 0:
		_open_bot_dialog()
	else:
		_start_countdown()


func _start_countdown() -> void:
	_countdown = COUNTDOWN
	_countdown_label.visible = true


func _cancel_countdown() -> void:
	if _countdown < 0.0:
		return
	_countdown = -1.0
	_countdown_label.visible = false
	PlayerManager.remove_bots() # ботов спросим заново, когда все снова будут готовы


func _launch() -> void:
	MatchState.start_new_match(ROUNDS)
	SceneManager.change_scene(MatchState.SCENE_BOARD)


func _process(delta: float) -> void:
	if _bot_dialog.visible:
		_process_bot_dialog()
		return
	for p in PlayerManager.players.duplicate():
		if p.input == null or p.is_bot():
			continue
		if _rooms.has(p.id):
			continue # примерочная сама обрабатывает кнопки игрока
		var at_tv := _is_near(p, TV_ZONE_POS, TV_ZONE_RADIUS)
		if p.input.is_just_pressed("confirm") and _is_at_market(p):
			_open_wardrobe(p)
		elif p.input.is_just_pressed("confirm") and at_tv:
			_set_ready(p, not _ready_marks.has(p.id))
		elif p.input.is_just_pressed("cancel"):
			PlayerManager.remove_player(p)
			continue
		if not at_tv and _ready_marks.has(p.id):
			_set_ready(p, false) # отошёл от телевизора — уже не готов

	if _countdown >= 0.0:
		_countdown -= delta
		_countdown_label.text = "Начинаем через %d..." % ceili(_countdown)
		if _countdown <= 0.0:
			_countdown = -1.0
			_launch()
		return
	var humans := PlayerManager.players.filter(func(p: PlayerData) -> bool: return not p.is_bot())
	var all_ready := humans.all(func(p: PlayerData) -> bool: return _ready_marks.has(p.id))
	if not humans.is_empty() and all_ready:
		_all_ready()


## Отметить игрока готовым (надпись «ГОТОВ» над головой) или снять отметку.
func _set_ready(p: PlayerData, on: bool) -> void:
	if on == _ready_marks.has(p.id):
		return
	if on:
		var mark := Label3D.new()
		mark.text = "ГОТОВ!"
		mark.font_size = 56
		mark.outline_size = 14
		mark.modulate = Color("8fd694")
		mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mark.no_depth_test = true
		mark.position.y = 2.5
		(_characters[p.id] as Node3D).add_child(mark)
		_ready_marks[p.id] = mark
	else:
		var mark: Node = _ready_marks[p.id]
		if is_instance_valid(mark):
			mark.queue_free()
		_ready_marks.erase(p.id)
		_cancel_countdown()


func _is_near(p: PlayerData, point: Vector3, radius: float) -> bool:
	if not _characters.has(p.id):
		return false
	var pos: Vector3 = (_characters[p.id] as Node3D).global_position
	return Vector2(pos.x - point.x, pos.z - point.z).length() < radius


# ---------------- Рынок и гардероб ----------------

## ДЛЯ ТЕСТОВ (убрать перед релизом): F9 — всем живым игрокам +500 ₽.
func _test_add_money() -> void:
	for p in PlayerManager.players:
		PlayerManager.add_to_wallet(p, 500)
		if _rooms.has(p.id):
			(_rooms[p.id] as DressingRoom).refresh()


func _is_at_market(p: PlayerData) -> bool:
	if not _characters.has(p.id):
		return false
	var pos: Vector3 = (_characters[p.id] as Node3D).global_position
	return Vector2(pos.x - MARKET_POS.x, pos.z - MARKET_POS.z).length() < MARKET_RADIUS


func _open_wardrobe(p: PlayerData) -> void:
	var character: PlayerCharacter = _characters[p.id]
	character.input_enabled = false
	character.velocity = Vector3.ZERO
	var room := DressingRoom.new()
	room.setup(p, character)
	room.closed.connect(_on_room_closed)
	room.color_changed.connect(func(_p: PlayerData) -> void: _refresh_slots())
	_rooms_root.add_child(room)
	_rooms[p.id] = room
	_layout_rooms()


func _on_room_closed(p: PlayerData) -> void:
	if not _rooms.has(p.id):
		return
	(_rooms[p.id] as Node).queue_free()
	_rooms.erase(p.id)
	if _characters.has(p.id):
		(_characters[p.id] as PlayerCharacter).input_enabled = true
	_layout_rooms()


func _close_all_wardrobes() -> void:
	for room: DressingRoom in _rooms.values():
		room.close()


## Одна примерочная — на весь экран, две — пополам, три-четыре — по четвертям.
func _layout_rooms() -> void:
	var screen := get_viewport().get_visible_rect().size
	var rooms: Array[DressingRoom] = []
	for room: DressingRoom in _rooms.values():
		rooms.append(room)
	rooms.sort_custom(func(a: DressingRoom, b: DressingRoom) -> bool:
		return a.player.slot < b.player.slot)
	var n := rooms.size()
	for i in n:
		var rect := Rect2(Vector2.ZERO, screen)
		if n == 2:
			rect = Rect2(Vector2(screen.x / 2.0 * i, 0), Vector2(screen.x / 2.0, screen.y))
		elif n > 2:
			var half := screen / 2.0
			rect = Rect2(Vector2(half.x * (i % 2), half.y * (i / 2)), half)
		rooms[i].position = rect.position
		rooms[i].size = rect.size


## Круг перед телевизором: встань и нажми кнопку — «Готов».
func _build_tv_zone() -> void:
	var zone := MeshInstance3D.new()
	var zone_mesh := CylinderMesh.new()
	zone_mesh.top_radius = TV_ZONE_RADIUS
	zone_mesh.bottom_radius = TV_ZONE_RADIUS
	zone_mesh.height = 0.02
	zone_mesh.radial_segments = 24
	zone.mesh = zone_mesh
	var zone_mat := StandardMaterial3D.new()
	zone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone_mat.albedo_color = Color(0.56, 0.84, 0.58, 0.3)
	zone.material_override = zone_mat
	zone.position = TV_ZONE_POS + Vector3.UP * 0.05
	add_child(zone)
	var hint := Label3D.new()
	hint.text = "ИГРАТЬ: встань в круг\nи нажми Пробел / Enter / A"
	hint.font_size = 34
	hint.outline_size = 10
	hint.rotation_degrees.x = -90
	hint.position = TV_ZONE_POS + Vector3(0, 0.07, 0.9)
	add_child(hint)


func _build_market() -> void:
	var market := Node3D.new()
	market.name = "Market"
	market.position = MARKET_POS
	add_child(market)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("7a4a2a")
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("c0392b")
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("eeeeee")
	# Прилавок, стойки и полосатый навес.
	_add_box(market, Vector3(3.2, 0.9, 0.9), Vector3(0, 0.45, -1.9), wood, true)
	for x in [-1.5, 1.5]:
		_add_box(market, Vector3(0.12, 2.6, 0.12), Vector3(x, 1.3, -2.3), wood, true)
	for i in 6:
		_add_box(market, Vector3(0.55, 0.08, 1.4), Vector3(-1.38 + i * 0.55, 2.62, -2.0),
			red if i % 2 == 0 else white, false)
	# На прилавке выложен товар.
	for item_info in [["hat_kepka", -0.8], ["hat_ushanka", 0.0], ["hat_fedora", 0.8]]:
		var item := Cosmetics.load_item(item_info[0]).instantiate() as Node3D
		item.position = Vector3(item_info[1], -0.45, -1.9)
		market.add_child(item)

	var sign := Label3D.new()
	sign.text = "РЫНОК"
	sign.font_size = 96
	sign.outline_size = 18
	sign.modulate = Color("f6c343")
	sign.position = Vector3(0, 3.1, -2.0)
	market.add_child(sign)

	# Круг «встань сюда».
	var zone := MeshInstance3D.new()
	var zone_mesh := CylinderMesh.new()
	zone_mesh.top_radius = MARKET_RADIUS
	zone_mesh.bottom_radius = MARKET_RADIUS
	zone_mesh.height = 0.02
	zone_mesh.radial_segments = 24
	zone.mesh = zone_mesh
	var zone_mat := StandardMaterial3D.new()
	zone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone_mat.albedo_color = Color(0.96, 0.76, 0.26, 0.3)
	zone.material_override = zone_mat
	zone.position.y = 0.04
	market.add_child(zone)

	var hint := Label3D.new()
	hint.text = "Встань в круг и нажми\nПробел / Enter / A"
	hint.font_size = 36
	hint.outline_size = 10
	hint.rotation_degrees.x = -90
	hint.position = Vector3(0, 0.06, 0.6)
	market.add_child(hint)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, solid: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = pos
	if not solid:
		parent.add_child(mesh_instance)
		return
	var body := StaticBody3D.new()
	body.position = pos
	mesh_instance.position = Vector3.ZERO
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	parent.add_child(body)


# ---------------- Окно ботов ----------------

func _open_bot_dialog() -> void:
	_close_all_wardrobes()
	_bot_count = PlayerManager.free_slots()
	_update_bot_dialog()
	_bot_dialog.visible = true
	_set_characters_input(false)


func _close_bot_dialog() -> void:
	_bot_dialog.visible = false
	_set_characters_input(true)
	# «Назад» — снимаем готовность со всех, иначе окно тут же откроется снова.
	for p in PlayerManager.players:
		_set_ready(p, false)


func _confirm_bots() -> void:
	_bot_dialog.visible = false
	_set_characters_input(true)
	for i in _bot_count:
		PlayerManager.add_bot()
	_start_countdown()


## Управлять окном может любой живой игрок своими кнопками.
func _process_bot_dialog() -> void:
	for p in PlayerManager.players:
		if p.input == null or p.is_bot():
			continue
		if p.input.menu_just_pressed("move_left") or p.input.menu_just_pressed("move_down"):
			_change_bot_count(-1)
		elif p.input.menu_just_pressed("move_right") or p.input.menu_just_pressed("move_up"):
			_change_bot_count(1)
		elif p.input.menu_just_pressed("confirm"):
			_confirm_bots()
			return
		elif p.input.is_just_pressed("cancel"):
			_close_bot_dialog()
			return


## Листать число ботов по кругу: ... 2 → 3 → «Без ботов» → 1 → 2 ...
func _change_bot_count(step: int) -> void:
	_bot_count = posmod(_bot_count + step, PlayerManager.free_slots() + 1)
	_update_bot_dialog()


func _update_bot_dialog() -> void:
	_bot_count_label.text = "Без ботов" if _bot_count == 0 else str(_bot_count)


func _set_characters_input(enabled: bool) -> void:
	for character: PlayerCharacter in _characters.values():
		character.input_enabled = enabled


func _on_player_joined(p: PlayerData) -> void:
	var character := CHARACTER_SCENE.instantiate()
	var angle := TAU * p.slot / PlayerManager.MAX_PLAYERS
	var spawn := Vector3(sin(angle), 0.0, cos(angle)) * SPAWN_RADIUS + Vector3.UP * 0.5
	character.setup(p, spawn)
	_players_root.add_child(character)
	_characters[p.id] = character
	if not p.is_bot():
		_cancel_countdown() # новый игрок пришёл — пусть тоже подтвердит готовность
	_refresh_slots()


func _on_player_left(p: PlayerData) -> void:
	_ready_marks.erase(p.id)
	if not p.is_bot():
		_cancel_countdown()
	if _rooms.has(p.id):
		(_rooms[p.id] as Node).queue_free()
		_rooms.erase(p.id)
		_layout_rooms()
	if _characters.has(p.id):
		_characters[p.id].queue_free()
		_characters.erase(p.id)
	_refresh_slots()


# ---------------- Интерфейс ----------------

func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 32)
	_ui.add_child(root)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	var title := Label.new()
	title.text = "SLAVIC GAMES"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("f6c343"))
	title.add_theme_color_override("font_outline_color", Color("7a1410"))
	title.add_theme_constant_override("outline_size", 16)
	column.add_child(title)

	var hint := Label.new()
	hint.text = ("Вход: Пробел (WASD) · Enter (стрелки) · A (геймпад)\n"
		+ "Прыжок: та же кнопка · Выйти: Q / Backspace / B · Закрыть игру: Esc\n"
		+ "Переодеться: РЫНОК справа · НАЧАТЬ: все подходят к ТЕЛЕВИЗОРУ и жмут кнопку")
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 8)
	column.add_child(hint)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	_build_bot_dialog()

	_countdown_label = Label.new()
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	_countdown_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_countdown_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 72)
	_countdown_label.add_theme_color_override("font_color", Color("f6c343"))
	_countdown_label.add_theme_color_override("font_outline_color", Color("7a1410"))
	_countdown_label.add_theme_constant_override("outline_size", 18)
	_countdown_label.visible = false
	_ui.add_child(_countdown_label)

	var rooms_layer := CanvasLayer.new()
	rooms_layer.layer = 10
	add_child(rooms_layer)
	_rooms_root = Control.new()
	_rooms_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rooms_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rooms_layer.add_child(_rooms_root)

	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 12)
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(slots)
	for i in PlayerManager.MAX_PLAYERS:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(280, 90)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		panel.add_child(label)
		slots.add_child(panel)
		_slot_panels.append(panel)


func _refresh_slots() -> void:
	for i in _slot_panels.size():
		var panel := _slot_panels[i]
		var label := panel.get_child(0) as Label
		var p := PlayerManager.get_by_slot(i)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		if p:
			style.bg_color = p.color.darkened(0.25)
			label.text = "%s\n%s" % [p.display_name, p.device_label()]
			label.add_theme_color_override("font_color", Color.WHITE)
		else:
			style.bg_color = Color(0, 0, 0, 0.45)
			label.text = "Свободно"
			label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		panel.add_theme_stylebox_override("panel", style)


func _build_bot_dialog() -> void:
	_bot_dialog = PanelContainer.new()
	_bot_dialog.visible = false
	_bot_dialog.set_anchors_preset(Control.PRESET_CENTER)
	_bot_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bot_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.07, 0.95)
	style.border_color = Color("f6c343")
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(32)
	_bot_dialog.add_theme_stylebox_override("panel", style)
	_ui.add_child(_bot_dialog)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_bot_dialog.add_child(column)
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
	left.pressed.connect(_change_bot_count.bind(-1))
	picker.add_child(left)
	_bot_count_label = Label.new()
	_bot_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bot_count_label.custom_minimum_size.x = 260
	_bot_count_label.add_theme_font_size_override("font_size", 64)
	picker.add_child(_bot_count_label)
	var right := _dialog_button("▶", 48)
	right.pressed.connect(_change_bot_count.bind(1))
	picker.add_child(right)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	var start := _dialog_button("Начать", 30)
	start.pressed.connect(_confirm_bots)
	buttons.add_child(start)
	var back := _dialog_button("Назад", 30)
	back.pressed.connect(_close_bot_dialog)
	buttons.add_child(back)

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
