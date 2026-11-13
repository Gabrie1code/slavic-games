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
const SEAT_RADIUS := 0.9
const COUNTDOWN := 5.0
## Вид от первого лица: чувствительность мыши и скорость обзора правым стиком.
const MOUSE_SENSITIVITY := 0.0025
const STICK_LOOK_SPEED := 2.8
const EYE_HEIGHT := 1.42
const PITCH_LIMIT := 1.2
## Бег на Shift в лобби: +15% к скорости.
const RUN_BONUS := 0.15
## На сколько опускается камера, когда персонаж присел.
const CROUCH_EYE_DROP := 0.45
## Удар рукой: дальность, перезарядка, сила толчка.
const PUNCH_REACH := 1.3
const PUNCH_COOLDOWN := 0.35
const PUNCH_PUSH := 3.0

var _characters: Dictionary = {} # PlayerData.id -> персонаж

## Окно «Добавить ботов?»
var _bot_dialog: PanelContainer
var _bot_count_label: Label
var _bot_count := 0

## Готовые к старту игроки: PlayerData.id -> надпись «ГОТОВ» над головой.
var _ready_marks: Dictionary = {}
## Отсчёт до старта (сек). Меньше нуля — отсчёта нет.
var _countdown := -1.0
var _countdown_label: Label
## Кадр, в котором нажали «Начать» в окне ботов (это нажатие больше никуда не идёт).
var _dialog_closed_frame := -1
## Отсчёт закончился, игра запускается — лобби больше ничего не открывает и не слушает.
var _launching := false

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
## Телефон и кот: подсказки, нажатия, игрок с трубкой.
var _gadgets: LobbyGadgets

@onready var _players_root: Node3D = $Players
@onready var _camera: Camera3D = $Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _ui: CanvasLayer = $UI
@onready var _apartment: Apartment = $Apartment


func _ready() -> void:
	# Сверху видно всю квартиру: игровую комнату, гостиную и спальню.
	_camera.look_at_from_position(Vector3(-1.2, 16.0, 15.0), Vector3(-1.2, 0, -0.5))
	# Сверху не показываем потолок и передние стены.
	_camera.cull_mask &= ~Apartment.FP_ONLY_LAYER & ~VIEWMODEL_LAYERS & ~Apartment.RUBGAME_LAMP_LAYER \
		& ~ToiletRoom.WALL_HIGH_LAYER
	var views_layer := CanvasLayer.new()
	views_layer.layer = 0
	add_child(views_layer)
	_views_root = Control.new()
	_views_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_views_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	views_layer.add_child(_views_root)
	_sun.rotation_degrees = Vector3(-55, -35, 0)
	_gadgets = LobbyGadgets.new(_apartment, _characters)
	_build_ui()
	_build_zone(Apartment.TV_ZONE, TV_ZONE_RADIUS, Color(0.56, 0.84, 0.58),
		"zone_play")
	_build_zone(Apartment.WARDROBE_ZONE, WARDROBE_RADIUS, Color(0.96, 0.76, 0.26),
		"zone_wardrobe")
	_build_zone(Apartment.RUBGAME_ZONE, RUBGAME_RADIUS, Color(1.0, 0.35, 0.75),
		"zone_rubgame")

	# Боты прошлой партии в лобби не нужны: при старте спросим заново.
	PlayerManager.remove_bots()
	PlayerManager.player_joined.connect(_on_player_joined)
	PlayerManager.player_left.connect(_on_player_left)
	# Игроки, которые уже вошли раньше (например, вернулись в лобби).
	for p in PlayerManager.players:
		_on_player_joined(p)
	_apply_view()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += (event as InputEventMouseMotion).relative


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed() or _launching:
		return # запускаемся — новых игроков и окон уже не нужно

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
	if _launching:
		return
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
	# Пока экран затемняется перед сменой сцены, лобби ещё живёт: без этого флага оно снова
	# видело «все готовы» и открывало окно ботов прямо перед стартом.
	_launching = true
	_bot_dialog.visible = false
	MatchState.start_new_match(ROUNDS)
	SceneManager.change_scene(MatchState.SCENE_BOARD)


func _process(delta: float) -> void:
	if _view == View.FIRST_PERSON:
		_update_first_person(delta)
	if _launching:
		return
	if _bot_dialog.visible and _countdown >= 0.0:
		_bot_dialog.visible = false # на всякий случай: во время отсчёта окна нет
	if _bot_dialog.visible:
		_process_bot_dialog()
		return
	if Engine.get_process_frames() == _dialog_closed_frame:
		return # кадр, в котором закрыли окно ботов: это нажатие уже использовано
	# Копия списка (игрок может выйти посреди цикла) — обязательно в типизированную переменную,
	# иначе Godot не знает тип p и не загружает скрипт (см. «Уроки» в PROJECT_LOG).
	var players: Array[PlayerData] = PlayerManager.players.duplicate()
	for p in players:
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
			if _gadgets.hand_busy(p): # сидя тоже можно красить и оттирать
				var held_view: Dictionary = _views.get(p.id, {})
				_gadgets.process_hand(p, held_view.get("camera"), held_view.get("can"))
			continue
		if _gadgets.holds_phone(p):
			_gadgets.process_holder(p) # с трубкой ходят, но не дерутся и не садятся
			continue
		# Рядом с чем-то, что делается «подтверждением» (кот, телефон, диван, шкаф…), прыжка нет:
		# Пробел должен погладить кота, а не подбросить персонажа. На бегу (Shift) действий нет.
		if character == null:
			continue
		var running := LobbyGadgets.is_running(p, character)
		var has_action := not running and (not _prompt_for(p, character).is_empty()
			or _gadgets.hand_uses_confirm(p)) # «Положить губку» — тоже действие на Пробел
		character.can_jump = not has_action
		var act := p.input.is_just_pressed("confirm") and not running
		if act and has_action:
			_eat_jump(character) # Пробел ушёл на действие — не подпрыгивать
		if _gadgets.hand_busy(p):
			var view: Dictionary = _views.get(p.id, {})
			_gadgets.process_hand(p, view.get("camera"), view.get("can")) # баллончик / губка
			# Молоток бьёт и на бегу (Shift) — исключение из правила «на бегу действий нет».
			if p.input.is_just_pressed("attack") and _gadgets.holds_hammer(p):
				_punch(p, true) # молоток бьёт, как кулак (+ разбивает экран автомата)
		elif p.input.is_just_pressed("attack") and (running or not _gadgets.try_attack_use(p)):
			_punch(p) # у раковины удар берёт губку (try_attack_use), иначе — кулак
		elif p.input.is_just_pressed("secondary") and not running:
			_gadgets.try_secondary(p) # ПКМ у тумбочки — ночник
		if act and _gadgets.can_use_toilet(p):
			_eat_jump(character)
			_open_room(p, ToiletScreen.new().setup_for(p, character, _apartment.toilet_room.toilet))
			continue
		if act and _gadgets.try_interact(p):
			# Пробел ушёл на действие (положить губку, взять баллончик…) — даже если подсказка была
			# «рукой» (её нет в has_action), персонаж не подпрыгивает.
			_eat_jump(character)
			continue
		var at_tv := _is_near(p, Apartment.TV_ZONE, TV_ZONE_RADIUS)
		var seat := _free_seat_near(p)
		if act and _at_wardrobe(p):
			_open_wardrobe(p)
		elif act and _near_rubgame(p):
			_open_rubgame(p)
		elif act and at_tv and _looks_at(p, Apartment.TV_POS):
			_set_ready(p, not _ready_marks.has(p.id))
		elif act and seat >= 0:
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


## Смотрит ли игрок на точку (кнопка действия — только когда смотришь на предмет).
func _looks_at(p: PlayerData, point: Vector3) -> bool:
	return _characters.has(p.id) and LobbyGadgets.facing(_characters[p.id], point, 60.0)


func _at_wardrobe(p: PlayerData) -> bool:
	return _is_near(p, Apartment.WARDROBE_ZONE, WARDROBE_RADIUS) \
		and _looks_at(p, Apartment.WARDROBE_POS)


func _is_near(p: PlayerData, point: Vector3, radius: float) -> bool:
	if not _characters.has(p.id):
		return false
	var pos: Vector3 = (_characters[p.id] as Node3D).global_position
	return Vector2(pos.x - point.x, pos.z - point.z).length() < radius


# ---------------- Зоны, диван, примерочная ----------------

## Круг на полу с подписью: встань и нажми кнопку.
## Зона на полу (круг) и над ней — компактная «кнопка»-значок (assets/ui/prompts/<badge>.png),
## которая плавно покачивается. Какую клавишу жать — подсказка у прицела игрока (KeyPrompt).
func _build_zone(pos: Vector3, radius: float, color: Color, badge: String) -> void:
	# Мягкое свечение на полу, поменьше самой зоны (сплошной круг был слишком широким и ярким).
	var zone := GroundGlow.new().setup(color, radius * 0.75, 0.35)
	zone.position = pos + Vector3.UP * 0.03
	add_child(zone)
	var badge_node := ZoneBadge.new().setup(badge, 2.25)
	badge_node.position += pos
	add_child(badge_node)


## Удар рукой: от третьего лица — взмах вперёд, от первого — тычок кулаком в кадре.
## Разбивает вещи впереди, толкает стулья и гантели, отталкивает других игроков.
## Пробел ушёл на действие: отменить прыжок и не прыгать ещё чуть-чуть (см. jump_lock).
func _eat_jump(character: PlayerCharacter) -> void:
	character.jump_pending = false
	character.jump_lock = 0.25


func _punch(p: PlayerData, hammer: bool = false) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_punch_time.get(p.id, -10.0)) < PUNCH_COOLDOWN:
		return
	var character: PlayerCharacter = _characters[p.id]
	if hammer:
		if _gadgets.swing_hammer(p):
			_punch_time[p.id] = now
			return # разбил стекло серванта — посуда за ним цела до следующего удара
	elif not character.punch():
		return
	_punch_time[p.id] = now
	if _views.has(p.id) and not hammer:
		var fist: Node3D = _views[p.id]["fist"]
		var jab := create_tween()
		jab.tween_property(fist, "position:z", -0.85, 0.07).set_ease(Tween.EASE_OUT)
		jab.tween_property(fist, "position:z", -0.45, 0.16).set_ease(Tween.EASE_IN)

	var origin := character.global_position
	var forward := -character.global_basis.z
	# Удар задевает одну вещь — ту, что ближе всего к направлению взгляда (раньше бились
	# все вещи в широком конусе: целая полка хрусталя от одного удара).
	var target := _gadgets.punch_target(character, _views.get(p.id, {}).get("camera"))
	if target is Breakable:
		(target as Breakable).shatter(origin)
	elif target is Tippable:
		var body := target as Tippable
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
		if _is_near(p, _apartment.seats[i]["approach"], SEAT_RADIUS) \
				and _looks_at(p, _apartment.seats[i]["pos"]):
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
	room.color_changed.connect(func(changed: PlayerData) -> void:
		_update_fist_color(changed))
	_rooms_root.add_child(room)
	_rooms[p.id] = room
	_layout_rooms()


func _open_rubgame(p: PlayerData) -> void:
	var screen := RubgameScreen.new()
	screen.setup(p, _characters[p.id], _apartment.rubgame_table)
	_open_room(p, screen)


## Окно игрока поверх лобби (стол, туалет): персонаж замирает, лобби делит экран.
func _open_room(p: PlayerData, room: LobbyRoom) -> void:
	var character: PlayerCharacter = _characters[p.id]
	character.input_enabled = false
	character.velocity = Vector3.ZERO
	room.closed.connect(_on_room_closed)
	_rooms_root.add_child(room)
	_rooms[p.id] = room
	_layout_rooms()


## Рядом со столом рулетки: в круге перед столом или вплотную к столу с любой стороны.
func _near_rubgame(p: PlayerData) -> bool:
	var table := _apartment.rubgame_table
	if not _looks_at(p, table.global_position + table.global_basis.x * 0.6):
		return false # стол должен быть перед глазами
	if _is_near(p, Apartment.RUBGAME_ZONE, RUBGAME_RADIUS):
		return true
	if not _characters.has(p.id):
		return false
	var local := table.to_local((_characters[p.id] as Node3D).global_position)
	return absf(local.x) < 2.4 and absf(local.z) < 1.3


func _on_room_closed(p: PlayerData) -> void:
	if not _rooms.has(p.id):
		return
	(_rooms[p.id] as Node).queue_free()
	_rooms.erase(p.id)
	if _characters.has(p.id):
		# Чуть позже: тем же Пробелом, которым отошли от стола, персонаж не должен подпрыгнуть.
		var character: PlayerCharacter = _characters[p.id]
		get_tree().create_timer(0.15).timeout.connect(func() -> void:
			if is_instance_valid(character) and not _rooms.has(p.id):
				character.input_enabled = true)
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
	camera.add_to_group(Mirror.VIEWER_GROUP) # зеркала отражают то, что видят эти глаза
	camera.cull_mask = (0xFFFFF & ~_player_layer(p) & ~VIEWMODEL_LAYERS
		& ~Apartment.OVERVIEW_ONLY_LAYER & ~PlayerCharacter.name_layer(p.slot)) | _viewmodel_layer(p)
	viewport.add_child(camera)
	camera.current = true
	# Всё «в кадре» (кулак, вещи в руке) рисуется поверх стен — не пропадает вплотную к ним.
	camera.child_entered_tree.connect(HandHold.on_top)
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
	# Трубка телефона «в кадре» — видна, пока игрок говорит по телефону (вместо кулака).
	var handset := (load("res://assets/models/apartment/phone_handset.glb") as PackedScene) \
		.instantiate() as Node3D
	handset.position = Vector3(0.24, -0.16, -0.36)
	handset.rotation = Vector3(0.3, -0.5, 1.2)
	handset.scale = Vector3.ONE * 1.3
	handset.visible = false
	_set_layers(handset, _viewmodel_layer(p))
	camera.add_child(handset)
	# Баллончик «в кадре», пока игрок его держит (вместо кулака).
	# Баллончик в кулаке (HandHold): сопло сверху; видимость — у кулака с баллончиком.
	var view_can := (load("res://assets/models/apartment/spray_can.glb") as PackedScene) \
		.instantiate() as Node3D
	var can_hand := HandHold.make_view(p.color, view_can, 0.09, _viewmodel_layer(p))
	can_hand.visible = false
	camera.add_child(can_hand)

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
	# Подсказка «кнопка + действие» — чуть правее и ниже прицела, как в шутерах.
	var prompt := KeyPrompt.new()
	prompt.set_anchors_preset(Control.PRESET_CENTER)
	prompt.offset_left = 36
	prompt.offset_top = 20
	container.add_child(prompt)
	_views_root.add_child(container)
	_views[p.id] = {"container": container, "camera": camera, "prompt": prompt, "fist": fist,
		"handset": handset, "can": view_can}
	_layout_views()


func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_layers(child, layer)


## Кулак «в кадре» — цвета игрока: после смены цвета в шкафу перекрасить сразу.
func _update_fist_color(p: PlayerData) -> void:
	if _views.has(p.id):
		var fist: MeshInstance3D = _views[p.id]["fist"]
		(fist.material_override as StandardMaterial3D).albedo_color = p.color


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
		var eye_height := EYE_HEIGHT - (0.1 if character.sitting else 0.0) \
			- CROUCH_EYE_DROP * character.crouch_amount # присел — камера ниже
		var eye := character.global_position + Vector3.UP * eye_height
		eye.y = minf(eye.y, Apartment.WALL_HEIGHT - 0.15) # камера не заглядывает за потолок
		camera.global_transform = Transform3D(
			Basis.from_euler(Vector3(character.fp_pitch, character.rotation.y, 0.0)), eye)
		var entries := _prompt_for(p, character)
		entries.append_array(_gadgets.hand_hint(p))
		if LobbyGadgets.is_running(p, character):
			entries = LobbyGadgets.greyed(entries) # на бегу кнопки действий серые
		var prompt: KeyPrompt = _views[id]["prompt"]
		prompt.set_entries(entries)
		# Во время отсчёта кнопка «Отменить «Готов»» — по центру под надписью «Начинаем через…».
		var under_timer := _countdown >= 0.0 and _ready_marks.has(p.id)
		var shift := Vector2(-prompt.size.x / 2.0, 64.0) if under_timer else Vector2(36.0, 20.0)
		if not under_timer and _gadgets.hand_busy(p):
			shift.x = -prompt.size.x - 36.0 # вещь в руке справа — подсказки слева от прицела
		prompt.position = prompt.get_parent_control().size / 2.0 + shift # размер не меняется
		var on_phone := _gadgets.holds_phone(p)
		var holds_can := _gadgets.holds_can(p)
		(_views[id]["fist"] as Node3D).visible = not on_phone and not _gadgets.hand_busy(p)
		(_views[id]["can"] as Node3D).get_parent().visible = holds_can # кулак с баллончиком
		(_views[id]["handset"] as Node3D).visible = on_phone
		if on_phone: # провод «в кадре» — к своей трубке у камеры
			_apartment.phone.set_view_handset(_views[id]["handset"], _viewmodel_layer(p),
				_player_layer(p))
	# Мышь ловим, только если есть игрок на WASD и не открыто окно/примерочная.
	var want_capture := _view == View.FIRST_PERSON and _rooms.is_empty() and not _bot_dialog.visible \
		and PlayerManager.is_device_taken(PlayerData.DeviceKind.KEYBOARD_WASD)
	var mode := Input.MOUSE_MODE_CAPTURED if want_capture else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode


## Подсказка внизу экрана игрока: что можно сделать здесь.
func _prompt_for(p: PlayerData, character: PlayerCharacter) -> Array[Dictionary]:
	var key := LobbyGadgets.confirm_key(p)
	var hint := _gadgets.hint(p)
	if not hint.is_empty():
		return hint
	var action := ""
	if character.sitting:
		action = "Встать"
	elif _at_wardrobe(p):
		action = "Шкаф: переодеться"
	elif _near_rubgame(p):
		action = "Игра на рубли"
	elif _is_near(p, Apartment.TV_ZONE, TV_ZONE_RADIUS) and _looks_at(p, Apartment.TV_POS):
		action = "Отменить «Готов» (ждём остальных)" if _ready_marks.has(p.id) else "Готов к игре"
	elif _free_seat_near(p) >= 0:
		action = _apartment.seats[_free_seat_near(p)]["name"]
	var result: Array[Dictionary] = []
	if action != "":
		result.append(LobbyGadgets.entry(key, action))
	result.append_array(_gadgets.remote_hint(p)) # пульт на ЛКМ — вместе с «Сесть на диван»
	return result


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
	if _countdown >= 0.0:
		return # отсчёт уже идёт — окно не нужно
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
	if not _bot_dialog.visible:
		return
	_bot_dialog.visible = false
	# Нажатие «Начать» не должно в этом же кадре снять «Готов» у телевизора.
	_dialog_closed_frame = Engine.get_process_frames()
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
	if _countdown >= 0.0 or not _bot_dialog.visible:
		return # после «Начать» ботов уже не меняем
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
	character.run_bonus = RUN_BONUS # Shift — бег
	_characters[p.id] = character
	character.set_render_layer(_player_layer(p))
	if _view == View.FIRST_PERSON and not p.is_bot():
		character.first_person = true
		character.rotation.y = 0.0 # лицом к телевизору
		_create_view(p)
	if not p.is_bot():
		_cancel_countdown() # новый игрок пришёл — пусть тоже подтвердит готовность
	else:
		_place_bot(p, character as PlayerCharacter)


## Бот перед игрой садится на свободное место — диван, потом кресло (каждый на своё —
## не застревают друг в друге). Мест нет — стоит за диваном лицом к телевизору.
func _place_bot(p: PlayerData, character: PlayerCharacter) -> void:
	for i in _apartment.seats.size():
		if not _seated.values().has(i):
			_sit(p, i)
			return
	var behind_x: Array[float] = [-0.8, 0.0, 0.8]
	character.global_position = Apartment.SOFA_POS + Vector3(behind_x[p.slot % 3], 0.05, 0.85)
	character.rotation.y = 0.0


func _on_player_left(p: PlayerData) -> void:
	_seated.erase(p.id)
	_gadgets.release_hand(p)
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
		+ "ШКАФ в спальне · диван · ТЕЛЕВИЗОР — старт · Удар: F/ЛКМ, /, X · F2 — вид\n"
		+ "Tab (Back на геймпаде) — список игроков")
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

	# Слоты игроков — в меню по Tab (раньше полоска внизу экрана).
	var players_menu := PlayersMenu.new()
	players_menu.is_ready = func(p: PlayerData) -> bool: return _ready_marks.has(p.id)
	_ui.add_child(players_menu)


func _build_bot_dialog() -> void:
	var dialog := BotDialog.new()
	dialog.step_pressed.connect(_change_bot_count)
	dialog.back_pressed.connect(_close_bot_dialog)
	dialog.start_pressed.connect(_confirm_bots)
	_ui.add_child(dialog)
	_bot_dialog = dialog
	_bot_count_label = dialog.count_label
