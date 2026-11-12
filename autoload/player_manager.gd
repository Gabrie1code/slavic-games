extends Node
## Глобальный список игроков (автозагрузка PlayerManager).
##
## Отвечает за вход и выход игроков, выдачу слотов, цветов и управления.

signal player_joined(player: PlayerData)
signal player_left(player: PlayerData)

const MAX_PLAYERS := 8

## Цвета игроков по слотам.
const SLOT_COLORS: Array[Color] = [
	Color("d93a2b"), # красный
	Color("2f6fd6"), # синий
	Color("f2c230"), # жёлтый
	Color("3aa655"), # зелёный
	Color("f08a24"), # оранжевый
	Color("8e44ad"), # фиолетовый
	Color("1fb5b5"), # бирюзовый
	Color("e86aa8"), # розовый
]

var players: Array[PlayerData] = []
var _next_id := 1


func _ready() -> void:
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
	p.color = SLOT_COLORS[p.slot]
	p.device_kind = kind
	p.joypad_id = joypad_id if kind == PlayerData.DeviceKind.JOYPAD else -1

	InputSetup.register_player(p)
	p.input = PlayerInput.new(p.slot)

	players.append(p)
	player_joined.emit(p)
	return p


func remove_player(p: PlayerData) -> void:
	if not players.has(p):
		return
	players.erase(p)
	if p.is_local():
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
