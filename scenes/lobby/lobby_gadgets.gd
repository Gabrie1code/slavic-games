class_name LobbyGadgets
extends RefCounted
## «Живые» вещи лобби, с которыми можно что-то сделать кнопками: дисковый телефон и кот Баггет.
## Лобби каждый кадр спрашивает подсказку (hint), отдаёт нажатия (try_interact) и ведёт
## игрока с трубкой (process_holder).

const PHONE_RADIUS := 1.2
## С трубкой в руке диск можно крутить, только стоя у телефона.
const DIAL_RADIUS := 1.7
const CAT_RADIUS := 1.3

var apartment: Apartment
## PlayerData.id -> PlayerCharacter (тот же словарь, что в лобби).
var characters: Dictionary


func _init(apt: Apartment, chars: Dictionary) -> void:
	apartment = apt
	characters = chars


## Одна строка подсказки: кнопка, действие, недоступно ли (серым).
static func entry(key: String, text: String, off: bool = false) -> Dictionary:
	return {"key": key, "text": text, "off": off}


static func confirm_key(p: PlayerData) -> String:
	match p.device_kind:
		PlayerData.DeviceKind.KEYBOARD_WASD:
			return "Пробел"
		PlayerData.DeviceKind.KEYBOARD_ARROWS:
			return "Enter"
		_:
			return "A"


static func attack_key(p: PlayerData) -> String:
	match p.device_kind:
		PlayerData.DeviceKind.KEYBOARD_WASD:
			return "ЛКМ"
		PlayerData.DeviceKind.KEYBOARD_ARROWS:
			return "/"
		_:
			return "X"


func holds_phone(p: PlayerData) -> bool:
	return apartment.phone.user == p


## Игрок с трубкой ходит как обычно; у телефона удар крутит диск, «подтвердить» у телефона —
## положить трубку, «отмена» — положить откуда угодно (а не выйти из игры).
func process_holder(p: PlayerData) -> void:
	var phone := apartment.phone
	if p.input.is_just_pressed("attack") and _near(p, Apartment.PHONE_TABLE_POS, DIAL_RADIUS):
		phone.dial()
	elif p.input.is_just_pressed("cancel") \
			or (p.input.is_just_pressed("confirm") and _near(p, Apartment.PHONE_TABLE_POS, PHONE_RADIUS)):
		phone.hang_up()


## «Подтвердить» рядом с телефоном или котом. true — нажатие использовано.
func try_interact(p: PlayerData) -> bool:
	var character: PlayerCharacter = characters[p.id]
	if _near(p, Apartment.PHONE_TABLE_POS, PHONE_RADIUS) and apartment.phone.can_use(p):
		apartment.phone.pick_up(p, character)
		return true
	if _near_cat(p) and apartment.cat.pet():
		# Персонаж тянет руку к коту.
		character.set_arm_pose(0.25, 0.9, 0.15)
		character.get_tree().create_timer(0.7).timeout.connect(func() -> void:
			if is_instance_valid(character) and apartment.phone.user != p:
				character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2))
		return true
	return false


## Подсказка у телефона и кота (пусто — рядом ничего нет).
func hint(p: PlayerData) -> Array[Dictionary]:
	var phone := apartment.phone
	if phone.user == p:
		var near := _near(p, Apartment.PHONE_TABLE_POS, DIAL_RADIUS)
		return [entry(attack_key(p), "Крутить диск", not near),
			entry(confirm_key(p), "Положить трубку", not near)]
	if _near(p, Apartment.PHONE_TABLE_POS, PHONE_RADIUS):
		if phone.dropped:
			return [entry(confirm_key(p), "Трубку вырвали — подожди", true)]
		if phone.can_use(p):
			return [entry(confirm_key(p), "Снять трубку")]
		return [entry(confirm_key(p), "Телефон занят: %s" % phone.user.display_name, true)]
	if _near_cat(p):
		return _cat_hint(p)
	return []


func _cat_hint(p: PlayerData) -> Array[Dictionary]:
	var cat := apartment.cat
	var cat_name := LobbyCat.CAT_NAME
	if cat.is_sleepy():
		return [entry(confirm_key(p), "%s спит — не будить" % cat_name, true)]
	if not cat.can_pet():
		return [entry(confirm_key(p), "Погладить %sа (%d с)" % [cat_name, ceili(cat.cooldown_left())],
			true)]
	return [entry(confirm_key(p), "Погладить %sа" % cat_name)]


func _near_cat(p: PlayerData) -> bool:
	return _near(p, apartment.cat.position, CAT_RADIUS)


func _near(p: PlayerData, point: Vector3, radius: float) -> bool:
	if not characters.has(p.id):
		return false
	var pos: Vector3 = (characters[p.id] as Node3D).global_position
	return Vector2(pos.x - point.x, pos.z - point.z).length() < radius
