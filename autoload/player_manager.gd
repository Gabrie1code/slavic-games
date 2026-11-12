extends Node
## Глобальный список игроков (автозагрузка PlayerManager).
##
## Отвечает за вход и выход игроков, выдачу слотов, цветов и управления.

signal player_joined(player: PlayerData)
signal player_left(player: PlayerData)

## Партия и мини-игры рассчитаны на 1–4 игроков (пустые места позже займут боты).
const MAX_PLAYERS := 4
## Профили игроков (в папке сохранений пользователя): наряд, кошелёк, купленные вещи.
## Профиль привязан к устройству: левая/правая клавиатура, конкретный геймпад.
const PROFILE_PATH := "user://profile.cfg"

## Палитра цветов персонажа. Один цвет — у одного игрока.
const COLORS: Array[Color] = [
	Color("d93a2b"), Color("2f6fd6"), Color("f2c230"), Color("3aa655"), Color("f08a24"),
	Color("8e44ad"), Color("1fb5b5"), Color("e86aa8"), Color("e8e4da"), Color("8b5a2b"),
]
const COLOR_NAMES: Array[String] = [
	"Красный", "Синий", "Жёлтый", "Зелёный", "Оранжевый",
	"Фиолетовый", "Бирюзовый", "Розовый", "Белый", "Коричневый",
]

## Имена ботов.
const BOT_NAMES: Array[String] = ["Колян", "Серёга", "Вовчик", "Лёха"]

var players: Array[PlayerData] = []
var _next_id := 1


func _ready() -> void:
	InputSetup.ensure_menu_arrows()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func can_join() -> bool:
	return players.size() < MAX_PLAYERS


## Добавляет локального игрока. Возвращает null, если мест нет или устройство уже занято.
func add_local_player(kind: PlayerData.DeviceKind, joypad_id: int = -1) -> PlayerData:
	if not can_join() or is_device_taken(kind, joypad_id):
		return null

	var p := PlayerData.new()
	p.id = _next_id
	_next_id += 1
	p.slot = _free_slot()
	p.display_name = "Игрок %d" % (p.slot + 1)
	p.device_kind = kind
	p.joypad_id = joypad_id if kind == PlayerData.DeviceKind.JOYPAD else -1
	# Любимый цвет из профиля, если он свободен; иначе — первый свободный.
	var preferred: int = _profile_get(p.device_key(), "color", p.slot)
	_apply_color(p, preferred if color_owner(preferred) == null else first_free_color())

	InputSetup.register_player(p)
	p.input = PlayerInput.new(p.slot)
	p.input.wasd_keyboard = kind == PlayerData.DeviceKind.KEYBOARD_WASD
	p.outfit = load_outfit(p.device_key())

	players.append(p)
	player_joined.emit(p)
	return p


## Добавляет бота в свободный слот. Возвращает null, если мест нет.
func add_bot() -> PlayerData:
	if not can_join():
		return null
	var p := PlayerData.new()
	p.id = _next_id
	_next_id += 1
	p.slot = _free_slot()
	_apply_color(p, p.slot if color_owner(p.slot) == null else first_free_color())
	p.device_kind = PlayerData.DeviceKind.BOT
	p.input = BotInput.new()
	p.outfit = Cosmetics.random_outfit()
	var taken: Array[String] = []
	for other in players:
		taken.append(other.display_name)
	for bot_name in BOT_NAMES:
		if not taken.has(bot_name):
			p.display_name = bot_name
			break
	players.append(p)
	player_joined.emit(p)
	return p


# ---------------- Профиль: наряд, кошелёк, покупки ----------------

## Сохранить наряд игрока.
func save_outfit(p: PlayerData) -> void:
	_profile_set(p, "outfits", p.outfit)


## Загрузить наряд по ключу устройства. Ненайденные и некупленные вещи пропускаем.
func load_outfit(key: String) -> Dictionary:
	var outfit: Dictionary = _profile_get(key, "outfits", {})
	var owned: Array = _profile_get(key, "owned", [])
	for slot: int in outfit.keys():
		var id: String = outfit[slot]
		if not Cosmetics.ITEMS.has(id) or not (Cosmetics.is_free(id) or owned.has(id)):
			outfit.erase(slot)
	return outfit


## Рубли в кошельке игрока (копятся между партиями).
func wallet(p: PlayerData) -> int:
	return _profile_get(p.device_key(), "wallet", 0)


func add_to_wallet(p: PlayerData, amount: int) -> void:
	if p.is_bot() or p.device_key() == "":
		return
	_profile_set(p, "wallet", maxi(0, wallet(p) + amount))


## Есть ли у игрока вещь (бесплатные есть у всех, боты носят что угодно).
func owns(p: PlayerData, id: String) -> bool:
	if p.is_bot() or Cosmetics.is_free(id):
		return true
	var owned: Array = _profile_get(p.device_key(), "owned", [])
	return owned.has(id)


## Купить вещь. Возвращает true, если получилось.
func buy(p: PlayerData, id: String) -> bool:
	if owns(p, id):
		return true
	var cost := Cosmetics.price(id)
	if wallet(p) < cost or p.device_key() == "":
		return false
	var owned: Array = _profile_get(p.device_key(), "owned", [])
	owned.append(id)
	_profile_set(p, "owned", owned)
	_profile_set(p, "wallet", wallet(p) - cost)
	return true


func _profile_get(key: String, section: String, default: Variant) -> Variant:
	var config := ConfigFile.new()
	if key == "" or config.load(PROFILE_PATH) != OK:
		return default
	return config.get_value(section, key, default)


func _profile_set(p: PlayerData, section: String, value: Variant) -> void:
	if p.device_key() == "":
		return
	var config := ConfigFile.new()
	config.load(PROFILE_PATH) # если файла нет — начнём с пустого
	config.set_value(section, p.device_key(), value)
	config.save(PROFILE_PATH)


# ---------------- Цвета ----------------

## Кто из игроков носит этот цвет (null — свободен).
func color_owner(index: int, except: PlayerData = null) -> PlayerData:
	for p in players:
		if p != except and p.color_index == index:
			return p
	return null


func first_free_color() -> int:
	for i in COLORS.size():
		if color_owner(i) == null:
			return i
	return 0


## Сменить цвет игрока. Возвращает false, если цвет занят другим.
func set_color(p: PlayerData, index: int) -> bool:
	if color_owner(index, p) != null:
		return false
	_apply_color(p, index)
	if not p.is_bot():
		_profile_set(p, "color", index)
	return true


func _apply_color(p: PlayerData, index: int) -> void:
	p.color_index = clampi(index, 0, COLORS.size() - 1)
	p.color = COLORS[p.color_index]


func free_slots() -> int:
	return MAX_PLAYERS - players.size()


func remove_bots() -> void:
	for p in players.duplicate():
		if p.is_bot():
			remove_player(p)


func remove_player(p: PlayerData) -> void:
	if not players.has(p):
		return
	players.erase(p)
	if p.is_local() and not p.is_bot():
		InputSetup.unregister_slot(p.slot)
	player_left.emit(p)


func clear() -> void:
	for p in players.duplicate():
		remove_player(p)


func is_device_taken(kind: PlayerData.DeviceKind, joypad_id: int = -1) -> bool:
	for p in players:
		if p.device_kind != kind:
			continue
		if kind != PlayerData.DeviceKind.JOYPAD or p.joypad_id == joypad_id:
			return true
	return false


func get_by_slot(slot: int) -> PlayerData:
	for p in players:
		if p.slot == slot:
			return p
	return null


func _free_slot() -> int:
	for i in MAX_PLAYERS:
		if get_by_slot(i) == null:
			return i
	return -1


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return
	# Пока просто убираем игрока с отключённым геймпадом.
	# Позже: пауза и предложение переподключить.
	for p in players.duplicate():
		if p.device_kind == PlayerData.DeviceKind.JOYPAD and p.joypad_id == device:
			remove_player(p)
