extends Node3D
## Тестовое лобби: игроки подключаются со своих устройств и бегают по комнате.
##
## Вход:  Пробел/E — левая клавиатура, Enter — правая клавиатура, A — геймпад.
## Выход: Q, Backspace/Shift или B на геймпаде.
## Начать партию: все живые игроки подходят к телевизору и жмут кнопку действия («Готов»).
## Когда готовы все — спросим про ботов (если есть места), потом отсчёт 5 сек и старт.
## Лобби — советская квартира (см. Apartment): в гостиной всё можно ломать, на диване — сидеть.
## Шкаф в спальне: подойти и нажать кнопку подтверждения — откроется примерочная.
## Игровая комната (дверь в левой стене гостиной): у стола рулетки та же кнопка
## открывает стол крупным планом.
##
## Вид от первого лица (по умолчанию) или от третьего — F2 (пока идёт разработка).
## От первого лица у каждого живого игрока своя камера (экран делится):
## WASD + мышь, стрелки (влево/вправо — поворот), геймпад — левый стик + правый стик.

enum View { FIRST_PERSON, THIRD_PERSON }

## Слои «кулаков в кадре» всех игроков (биты 11–14).
const VIEWMODEL_LAYERS := 0b1111 << 10

const CHARACTER_SCENE := preload("res://scenes/characters/test_character.tscn")
const ROUNDS := 5
## Зоны в квартире (координаты — в Apartment).
const WARDROBE_RADIUS := 1.2
const TV_ZONE_RADIUS := 1.3
const RUBGAME_RADIUS := 1.3
const PHONE_RADIUS := 1.2
const CAT_RADIUS := 1.3
const SEAT_RADIUS := 0.9
const COUNTDOWN := 5.0
## Вид от первого лица: чувствительность мыши и скорость обзора правым стиком.
const MOUSE_SENSITIVITY := 0.0025
const STICK_LOOK_SPEED := 2.8
const EYE_HEIGHT := 1.42
const PITCH_LIMIT := 1.2
## Удар рукой: дальность, перезарядка, сила толчка.
const PUNCH_REACH := 1.4
const PUNCH_COOLDOWN := 0.35
const PUNCH_PUSH := 3.0

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

## Кто где сидит на диване: PlayerData.id -> номер места.
var _seated: Dictionary = {}

## Когда игрок сел (чтобы зажатая клавиша движения не подняла его сразу же).
var _sit_time: Dictionary = {}
## Когда игрок бил в последний раз (перезарядка удара).
var _punch_time: Dictionary = {}

## Вид от первого лица: PlayerData.id -> {"container", "camera", "prompt"}.
var _view := View.FIRST_PERSON
var _views: Dictionary = {}
var _views_root: Control
var _mouse_delta := Vector2.ZERO

## Открытые окна игроков (примерочная, стол игры на рубли): PlayerData.id -> LobbyRoom
var _rooms: Dictionary = {}
var _rooms_root: Control

@onready var _players_root: Node3D = $Players
@onready var _camera: Camera3D = $Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _ui: CanvasLayer = $UI
@onready var _apartment: Apartment = $Apartment


func _ready() -> void:
	# Сверху видно всю квартиру: игровую комнату, гостиную и спальню.
	_camera.look_at_from_position(Vector3(-1.2, 16.0, 15.0), Vector3(-1.2, 0, -0.5))
	# Сверху не показываем потолок и передние стены.
	_camera.cull_mask &= ~Apartment.FP_ONLY_LAYER & ~VIEWMODEL_LAYERS
	var views_layer := CanvasLayer.new()
	views_layer.layer = 0
	add_child(views_layer)
	_views_root = Control.new()
	_views_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_views_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	views_layer.add_child(_views_root)
	_sun.rotation_degrees = Vector3(-55, -35, 0)
	_build_ui()
	_build_zone(Apartment.TV_ZONE, TV_ZONE_RADIUS, Color(0.56, 0.84, 0.58),
		"ИГРАТЬ: встань в круг\nи нажми Пробел / Enter / A")
	_build_zone(Apartment.WARDROBE_ZONE, WARDROBE_RADIUS, Color(0.96, 0.76, 0.26),
		"ШКАФ: переодеться\nи купить одежду")
	_build_zone(Apartment.RUBGAME_ZONE, RUBGAME_RADIUS, Color(1.0, 0.35, 0.75),
		"ИГРА НА РУБЛИ\nкруг каждые 20 сек")

	# Боты прошлой партии в лобби не нужны: при старте спросим заново.
	PlayerManager.remove_bots()
	PlayerManager.player_joined.connect(_on_player_joined)
	PlayerManager.player_left.connect(_on_player_left)
	# Игроки, которые уже вошли раньше (например, вернулись в лобби).
	for p in PlayerManager.players:
		_on_player_joined(p)
	_refresh_slots()
	_apply_view()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += (event as InputEventMouseMotion).relative


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
		if _handle_dev_key(key.physical_keycode) or _bot_dialog.visible:
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


## Клавиши для разработки: F2 — вид от 1-го/3-го лица, F9 — +500 ₽. true — клавиша обработана.
func _handle_dev_key(keycode: Key) -> bool:
	match keycode:
		KEY_F2:
			_view = View.THIRD_PERSON if _view == View.FIRST_PERSON else View.FIRST_PERSON
			_apply_view()
		KEY_F9:
			_test_add_money()
		_:
			return false
	return true


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
	if _view == View.FIRST_PERSON:
		_update_first_person(delta)
	if _bot_dialog.visible:
		_process_bot_dialog()
		return
	for p in PlayerManager.players.duplicate():
		if p.input == null or p.is_bot():
			continue
		if _rooms.has(p.id):
			continue # примерочная сама обрабатывает кнопки игрока
		var character: PlayerCharacter = _characters.get(p.id)
		if character and character.sitting:
			# Сидит на диване: встать — новым нажатием кнопки или движения.
			# (Раньше зажатая клавиша движения поднимала персонажа в тот же миг.)
			var since: float = Time.get_ticks_msec() / 1000.0 - float(_sit_time.get(p.id, 0.0))
			var pressed := p.input.is_just_pressed("confirm") or p.input.is_just_pressed("cancel")
			for move in ["move_up", "move_down", "move_left", "move_right"]:
				pressed = pressed or p.input.is_just_pressed(move)
			if since > 0.35 and pressed:
				_stand(p)
			continue
		if _apartment.phone.user == p:
			_process_phone(p)
			continue
		if p.input.is_just_pressed("attack"):
			_punch(p)
		if p.input.is_just_pressed("confirm") and _try_phone_or_cat(p):
			continue
		var at_tv := _is_near(p, Apartment.TV_ZONE, TV_ZONE_RADIUS)
		var seat := _free_seat_near(p)
		if p.input.is_just_pressed("confirm") and _is_near(p, Apartment.WARDROBE_ZONE, WARDROBE_RADIUS):
			_open_wardrobe(p)
		elif p.input.is_just_pressed("confirm") and _near_rubgame(p):
			_open_rubgame(p)
		elif p.input.is_just_pressed("confirm") and at_tv:
			_set_ready(p, not _ready_marks.has(p.id))
		elif p.input.is_just_pressed("confirm") and seat >= 0:
			_sit(p, seat)
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
		mark.layers = _player_layer(p) # над своей головой от первого лица не видно
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


# ---------------- Зоны, диван, примерочная ----------------

## Круг на полу с подписью: встань и нажми кнопку.
func _build_zone(pos: Vector3, radius: float, color: Color, text: String) -> void:
	var zone := MeshInstance3D.new()
	var zone_mesh := CylinderMesh.new()
	zone_mesh.top_radius = radius
	zone_mesh.bottom_radius = radius
	zone_mesh.height = 0.02
	zone_mesh.radial_segments = 24
	zone.mesh = zone_mesh
	var zone_mat := StandardMaterial3D.new()
	zone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone_mat.albedo_color = Color(color, 0.3)
	zone.material_override = zone_mat
	zone.position = pos + Vector3.UP * 0.04
	add_child(zone)
	var hint := Label3D.new()
	hint.text = text
	hint.font_size = 30
	hint.outline_size = 10
	hint.rotation_degrees.x = -90
	hint.position = pos + Vector3(0, 0.06, radius * 0.5)
	add_child(hint)


## Удар рукой: от третьего лица — взмах вперёд, от первого — тычок кулаком в кадре.
## Разбивает вещи впереди, толкает стулья и гантели, отталкивает других игроков.
func _punch(p: PlayerData) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_punch_time.get(p.id, -10.0)) < PUNCH_COOLDOWN:
		return
	var character: PlayerCharacter = _characters[p.id]
	if not character.punch():
		return
	_punch_time[p.id] = now
	if _views.has(p.id):
		var fist: Node3D = _views[p.id]["fist"]
		var jab := create_tween()
		jab.tween_property(fist, "position:z", -0.85, 0.07).set_ease(Tween.EASE_OUT)
		jab.tween_property(fist, "position:z", -0.45, 0.16).set_ease(Tween.EASE_IN)

	var origin := character.global_position
	var forward := -character.global_basis.z
	for node in get_tree().get_nodes_in_group("breakable"):
		var item := node as Breakable
		if item and not item.is_broken() and _in_front(origin, forward, item.global_position, 2.2):
			item.shatter(origin)
	for node in get_tree().get_nodes_in_group("tippable"):
		var body := node as Tippable
		if body and _in_front(origin, forward, body.global_position, 1.5):
			body.apply_impulse((forward + Vector3.UP * 0.3) * PUNCH_PUSH * body.mass * 0.4,
				Vector3.UP * 0.4)
	for other_id: int in _characters:
		var other: PlayerCharacter = _characters[other_id]
		if other != character and not other.sitting \
				and _in_front(origin, forward, other.global_position, 1.0):
			other.apply_knockback(forward * 7.0 + Vector3.UP * 3.0)


## Цель перед персонажем: ближе PUNCH_REACH по полу, в конусе ~60° и не выше max_height.
func _in_front(origin: Vector3, forward: Vector3, target: Vector3, max_height: float) -> bool:
	var offset := target - origin
	if offset.y > max_height or offset.y < -0.5:
		return false
	offset.y = 0.0
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	if offset.length() > PUNCH_REACH:
		return false
	return offset.length() < 0.3 or offset.normalized().dot(flat_forward) > 0.5


## Свободное место на диване рядом с игроком (-1 — нет).
func _free_seat_near(p: PlayerData) -> int:
	for i in _apartment.seats.size():
		if _seated.values().has(i):
			continue
		if _is_near(p, _apartment.seats[i]["approach"], SEAT_RADIUS):
			return i
	return -1


func _sit(p: PlayerData, seat: int) -> void:
	_seated[p.id] = seat
	_sit_time[p.id] = Time.get_ticks_msec() / 1000.0
	var info: Dictionary = _apartment.seats[seat]
	var character: PlayerCharacter = _characters[p.id]
	character.sit_at(info["pos"], info["yaw"])
	character.fp_pitch = 0.0


func _stand(p: PlayerData) -> void:
	_seated.erase(p.id)
	if _characters.has(p.id):
		(_characters[p.id] as PlayerCharacter).stand_up()

## ДЛЯ ТЕСТОВ (убрать перед релизом): F9 — всем живым игрокам +500 ₽.
func _test_add_money() -> void:
	for p in PlayerManager.players:
		PlayerManager.add_to_wallet(p, 500)
		if _rooms.has(p.id):
			(_rooms[p.id] as LobbyRoom).refresh()


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


# ---------------- Телефон и кот ----------------

## С трубкой у уха: удар (ЛКМ/F) — крутить диск, подтвердить/отмена — положить трубку.
func _process_phone(p: PlayerData) -> void:
	(_characters[p.id] as PlayerCharacter).input_enabled = false # говорит — стоит на месте
	if p.input.is_just_pressed("attack"):
		_apartment.phone.dial()
	elif p.input.is_just_pressed("confirm") or p.input.is_just_pressed("cancel"):
		_apartment.phone.hang_up()
		(_characters[p.id] as PlayerCharacter).input_enabled = true


## Подтвердить рядом с телефоном или котом. true — нажатие использовано.
func _try_phone_or_cat(p: PlayerData) -> bool:
	var character: PlayerCharacter = _characters[p.id]
	if _near_phone(p) and _apartment.phone.can_use(p):
		character.input_enabled = false
		character.velocity = Vector3.ZERO
		_apartment.phone.pick_up(p, character)
		return true
	if _near_cat(p) and _apartment.cat.pet():
		# Персонаж тянет руку к коту.
		character.set_arm_pose(0.25, 0.9, 0.15)
		get_tree().create_timer(0.7).timeout.connect(func() -> void:
			if is_instance_valid(character) and _apartment.phone.user != p:
				character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2))
		return true
	return false


func _near_phone(p: PlayerData) -> bool:
	return _is_near(p, Apartment.PHONE_TABLE_POS, PHONE_RADIUS)


func _near_cat(p: PlayerData) -> bool:
	return _is_near(p, _apartment.cat.position, CAT_RADIUS)


## Подсказка у телефона и кота. «~» в начале — действие сейчас недоступно (серым).
func _phone_cat_hint(p: PlayerData) -> String:
	var phone := _apartment.phone
	if phone.user == p:
		return "%s — крутить диск   %s — положить трубку" % [_attack_key(p), _confirm_key(p)]
	if _near_phone(p):
		if phone.can_use(p):
			return "%s — снять трубку" % _confirm_key(p)
		return "~%s — снять трубку (телефон занят: %s)" % [_confirm_key(p), phone.user.display_name]
	return _cat_hint(p) if _near_cat(p) else ""


func _cat_hint(p: PlayerData) -> String:
	var cat := _apartment.cat
	if cat.is_sleepy():
		return "~%s спит — не будить" % LobbyCat.CAT_NAME
	if not cat.can_pet():
		return "~Баггета только что погладили (%d с)" % ceili(cat.cooldown_left())
	return "%s — погладить Баггета" % _confirm_key(p)


func _attack_key(p: PlayerData) -> String:
	match p.device_kind:
		PlayerData.DeviceKind.KEYBOARD_WASD:
			return "ЛКМ / F"
		PlayerData.DeviceKind.KEYBOARD_ARROWS:
			return "/"
		_:
			return "X"


func _open_rubgame(p: PlayerData) -> void:
	var character: PlayerCharacter = _characters[p.id]
	character.input_enabled = false
	character.velocity = Vector3.ZERO
	var screen := RubgameScreen.new()
	screen.setup(p, character, _apartment.rubgame_table)
	screen.closed.connect(_on_room_closed)
	_rooms_root.add_child(screen)
	_rooms[p.id] = screen
	_layout_rooms()


## Рядом со столом рулетки: в круге перед столом или вплотную к столу с любой стороны.
func _near_rubgame(p: PlayerData) -> bool:
	if _is_near(p, Apartment.RUBGAME_ZONE, RUBGAME_RADIUS):
		return true
	if not _characters.has(p.id):
		return false
	var table := _apartment.rubgame_table
	var local := table.to_local((_characters[p.id] as Node3D).global_position)
	return absf(local.x) < 2.4 and absf(local.z) < 1.3


func _on_room_closed(p: PlayerData) -> void:
	if not _rooms.has(p.id):
		return
	(_rooms[p.id] as Node).queue_free()
	_rooms.erase(p.id)
	if _characters.has(p.id):
		(_characters[p.id] as PlayerCharacter).input_enabled = true
	_layout_rooms()


func _close_all_wardrobes() -> void:
	for room: LobbyRoom in _rooms.values():
		room.close()


## Одно окно (примерочная или стол) — на весь экран, две — пополам, три-четыре — по четвертям.
func _layout_rooms() -> void:
	var screen := get_viewport().get_visible_rect().size
	var rooms: Array[LobbyRoom] = []
	for room: LobbyRoom in _rooms.values():
		rooms.append(room)
	rooms.sort_custom(func(a: LobbyRoom, b: LobbyRoom) -> bool:
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


# ---------------- Вид от первого лица ----------------

## Слой модели игрока: его собственная камера от первого лица этот слой не рисует.
func _player_layer(p: PlayerData) -> int:
	return 1 << (p.slot + 1)


## Слой «кулака в кадре»: его видит только камера этого игрока.
func _viewmodel_layer(p: PlayerData) -> int:
	return 1 << (p.slot + 10)


func _apply_view() -> void:
	var first := _view == View.FIRST_PERSON
	for p in PlayerManager.players:
		if p.is_bot() or not _characters.has(p.id):
			continue
		var character: PlayerCharacter = _characters[p.id]
		character.first_person = first
		if first:
			_create_view(p)
		else:
			_remove_view(p)
	if not first:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layout_views()


func _create_view(p: PlayerData) -> void:
	if _views.has(p.id):
		return
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport) # мир общий с лобби — своя только камера
	var camera := Camera3D.new()
	camera.fov = 75.0
	# Своё тело не рисуем, чужие «кулаки в кадре» — тоже; свой кулак — рисуем.
	camera.cull_mask = (0xFFFFF & ~_player_layer(p) & ~VIEWMODEL_LAYERS) | _viewmodel_layer(p)
	viewport.add_child(camera)
	camera.current = true
	var fist := MeshInstance3D.new()
	var fist_mesh := SphereMesh.new()
	fist_mesh.radius = 0.09
	fist_mesh.height = 0.16
	fist_mesh.radial_segments = 8
	fist_mesh.rings = 4
	fist.mesh = fist_mesh
	var fist_mat := StandardMaterial3D.new()
	fist_mat.albedo_color = p.color
	fist.material_override = fist_mat
	fist.layers = _viewmodel_layer(p)
	fist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fist.position = Vector3(0.26, -0.24, -0.45)
	camera.add_child(fist)

	var frame := ReferenceRect.new()
	frame.border_color = p.color
	frame.border_width = 3
	frame.editor_only = false
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(frame)
	var dot := _overlay_label("•", 28)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	container.add_child(dot)
	var prompt := _overlay_label("", 24)
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_top = -120
	prompt.offset_bottom = -80
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.add_child(prompt)
	_views_root.add_child(container)
	_views[p.id] = {"container": container, "camera": camera, "prompt": prompt, "fist": fist}
	_layout_views()


func _remove_view(p: PlayerData) -> void:
	if not _views.has(p.id):
		return
	(_views[p.id]["container"] as Node).queue_free()
	_views.erase(p.id)
	_layout_views()


## Одна камера — весь экран, две — пополам, три-четыре — по четвертям.
func _layout_views() -> void:
	var screen := get_viewport().get_visible_rect().size
	var ids: Array = _views.keys()
	ids.sort_custom(func(a: int, b: int) -> bool:
		return _player_by_id(a).slot < _player_by_id(b).slot)
	var n := ids.size()
	for i in n:
		var rect := Rect2(Vector2.ZERO, screen)
		if n == 2:
			rect = Rect2(Vector2(screen.x / 2.0 * i, 0), Vector2(screen.x / 2.0, screen.y))
		elif n > 2:
			var half := screen / 2.0
			rect = Rect2(Vector2(half.x * (i % 2), half.y * (i / 2)), half)
		var container: SubViewportContainer = _views[ids[i]]["container"]
		container.position = rect.position
		container.size = rect.size


func _player_by_id(id: int) -> PlayerData:
	for p in PlayerManager.players:
		if p.id == id:
			return p
	return null


## Каждый кадр: обзор мышью/стиком, камеры на уровне глаз, подсказки.
func _update_first_person(delta: float) -> void:
	var mouse := _mouse_delta
	_mouse_delta = Vector2.ZERO
	for id: int in _views:
		var p := _player_by_id(id)
		if p == null or not _characters.has(id):
			continue
		var character: PlayerCharacter = _characters[id]
		var look := Vector2.ZERO
		match p.device_kind:
			PlayerData.DeviceKind.KEYBOARD_WASD:
				look = mouse * MOUSE_SENSITIVITY
				character.fp_strafe = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			PlayerData.DeviceKind.JOYPAD:
				var stick := Vector2(Input.get_joy_axis(p.joypad_id, JOY_AXIS_RIGHT_X),
					Input.get_joy_axis(p.joypad_id, JOY_AXIS_RIGHT_Y))
				if stick.length() > 0.2:
					look = stick * STICK_LOOK_SPEED * delta
				character.fp_strafe = true
			_:
				character.fp_strafe = false # стрелки: влево/вправо — поворот
		if not _rooms.has(id):
			character.rotation.y -= look.x
			character.fp_pitch = clampf(character.fp_pitch - look.y, -PITCH_LIMIT, PITCH_LIMIT)
		var camera: Camera3D = _views[id]["camera"]
		var eye_height := EYE_HEIGHT - (0.1 if character.sitting else 0.0)
		var eye := character.global_position + Vector3.UP * eye_height
		camera.global_transform = Transform3D(
			Basis.from_euler(Vector3(character.fp_pitch, character.rotation.y, 0.0)), eye)
		# «~» в начале подсказки — действие сейчас недоступно: показываем серым.
		var prompt_text := _prompt_for(p, character)
		var prompt: Label = _views[id]["prompt"]
		prompt.modulate = Color(0.6, 0.6, 0.6, 0.8) if prompt_text.begins_with("~") else Color.WHITE
		prompt.text = prompt_text.trim_prefix("~")
	# Мышь ловим, только если есть игрок на WASD и не открыто окно/примерочная.
	var want_capture := _view == View.FIRST_PERSON and _rooms.is_empty() and not _bot_dialog.visible \
		and PlayerManager.is_device_taken(PlayerData.DeviceKind.KEYBOARD_WASD)
	var mode := Input.MOUSE_MODE_CAPTURED if want_capture else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode


## Подсказка внизу экрана игрока: что можно сделать здесь.
func _prompt_for(p: PlayerData, character: PlayerCharacter) -> String:
	var key := _confirm_key(p)
	var hint := _phone_cat_hint(p)
	if hint != "":
		return hint
	var action := ""
	if character.sitting:
		action = "встать"
	elif _is_near(p, Apartment.WARDROBE_ZONE, WARDROBE_RADIUS):
		action = "открыть шкаф (переодеться)"
	elif _near_rubgame(p):
		action = "сыграть в рулетку"
	elif _is_near(p, Apartment.TV_ZONE, TV_ZONE_RADIUS):
		if _ready_marks.has(p.id):
			return "Ты ГОТОВ! Ждём остальных  (%s — отменить)" % key
		action = "ГОТОВ к игре"
	elif _free_seat_near(p) >= 0:
		action = "сесть на диван"
	return "" if action == "" else "%s — %s" % [key, action]


func _confirm_key(p: PlayerData) -> String:
	match p.device_kind:
		PlayerData.DeviceKind.KEYBOARD_WASD:
			return "Пробел"
		PlayerData.DeviceKind.KEYBOARD_ARROWS:
			return "Enter"
		_:
			return "A"


func _overlay_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	return label


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
	var spawn := Apartment.SPAWNS[p.slot % Apartment.SPAWNS.size()]
	character.setup(p, spawn)
	_players_root.add_child(character)
	character.add_to_group("lobby_character") # часы с кукушкой чувствуют, кто рядом
	_characters[p.id] = character
	character.set_render_layer(_player_layer(p))
	if _view == View.FIRST_PERSON and not p.is_bot():
		character.first_person = true
		character.rotation.y = 0.0 # лицом к телевизору
		_create_view(p)
	if not p.is_bot():
		_cancel_countdown() # новый игрок пришёл — пусть тоже подтвердит готовность
	_refresh_slots()


func _on_player_left(p: PlayerData) -> void:
	_seated.erase(p.id)
	if _apartment.phone.user == p:
		_apartment.phone.hang_up()
	_remove_view(p)
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
		+ "ШКАФ в спальне · диван · ТЕЛЕВИЗОР — старт · Удар: F/ЛКМ, /, X · F2 — вид")
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
	# Слева «Назад», справа «Начать» (как привычно: «вперёд» — справа).
	var back := _dialog_button("Назад", 30)
	back.pressed.connect(_close_bot_dialog)
	buttons.add_child(back)
	var start := _dialog_button("Начать", 30)
	start.pressed.connect(_confirm_bots)
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
