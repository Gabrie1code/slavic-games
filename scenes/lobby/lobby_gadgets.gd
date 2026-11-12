class_name LobbyGadgets
extends RefCounted
## «Живые» вещи лобби, с которыми можно что-то сделать кнопками: дисковый телефон, кот Баггет,
## граммофон (три ноты) и торшер (включить/выключить). Повален — кнопки нет, пока не вернётся.
## Лобби каждый кадр спрашивает подсказку (hint), отдаёт нажатия (try_interact) и ведёт
## игрока с трубкой (process_holder).

const PHONE_RADIUS := 1.2
## С трубкой в руке диск можно крутить, только стоя у телефона.
const DIAL_RADIUS := 1.7
const CAT_RADIUS := 1.3
## Насколько точно надо смотреть на предмет, чтобы появилась кнопка (градусы от взгляда).
const LOOK_ANGLE := 50.0
const GRAMOPHONE_RADIUS := 1.4
const LAMP_RADIUS := 1.2
const ARCADE_RADIUS := 1.1
const TOILET_RADIUS := 1.2
const NIGHTSTAND_RADIUS := 1.1
const CAN_RADIUS := 1.0
## Через сколько граммофон можно завести снова (секунды).
const TUNE_TIME := 3.0
const NOTE := preload("res://assets/textures/fx/note_pixel.png")

var apartment: Apartment
## PlayerData.id -> PlayerCharacter (тот же словарь, что в лобби).
var characters: Dictionary
var _tune_until := 0.0
## Кто держит баллончик: PlayerData.id -> SprayCan.
var _held_cans: Dictionary = {}
var _player: AudioStreamPlayer3D


func _init(apt: Apartment, chars: Dictionary) -> void:
	apartment = apt
	characters = chars


## Одна строка подсказки: кнопка, действие, недоступно ли (серым).
static func entry(key: String, text: String, off: bool = false) -> Dictionary:
	return {"key": key, "text": text, "off": off}


## Смотрит ли персонаж на точку (по горизонтали, не дальше max_degrees от взгляда).
## Действие и подсказка появляются, только когда игрок рядом И смотрит на предмет.
static func facing(character: Node3D, point: Vector3, max_degrees: float = LOOK_ANGLE) -> bool:
	var to := point - character.global_position
	to.y = 0.0
	if to.length() < 0.3:
		return true # вплотную — считаем, что смотрит
	var forward := -character.global_basis.z
	forward.y = 0.0
	return forward.normalized().angle_to(to.normalized()) < deg_to_rad(max_degrees)


static func confirm_key(p: PlayerData) -> String:
	match p.device_kind:
		PlayerData.DeviceKind.KEYBOARD_WASD:
			return "Пробел"
		PlayerData.DeviceKind.KEYBOARD_ARROWS:
			return "Enter"
		_:
			return "A"


static func drop_key(p: PlayerData) -> String:
	match p.device_kind:
		PlayerData.DeviceKind.KEYBOARD_WASD:
			return "G"
		PlayerData.DeviceKind.KEYBOARD_ARROWS:
			return "."
		_:
			return "Y"


static func attack_key(p: PlayerData) -> String:
	match p.device_kind:
		PlayerData.DeviceKind.KEYBOARD_WASD:
			return "ЛКМ"
		PlayerData.DeviceKind.KEYBOARD_ARROWS:
			return "/"
		_:
			return "X"


# ---------------- Баллончики ----------------

func holds_can(p: PlayerData) -> bool:
	return _held_cans.has(p.id)


## Каждый кадр для держащего баллончик: «выбросить» (G) — бросить, удар — пшикнуть.
func process_can_holder(p: PlayerData) -> void:
	var can: SprayCan = _held_cans[p.id]
	var character: PlayerCharacter = characters[p.id]
	if p.input.is_just_pressed("drop"):
		release_can(p)
	elif p.input.is_just_pressed("attack"):
		can.spray(p.color, -character.global_basis.z)


## Бросить баллончик (G или игрок ушёл из лобби).
func release_can(p: PlayerData) -> void:
	if not _held_cans.has(p.id):
		return
	var can: SprayCan = _held_cans[p.id]
	_held_cans.erase(p.id)
	if is_instance_valid(can) and characters.has(p.id):
		can.drop(characters[p.id], apartment)


## Подсказка держащему баллончик (добавляется к остальным).
func can_holder_hint(p: PlayerData) -> Array[Dictionary]:
	if not holds_can(p):
		return []
	return [entry(drop_key(p), "Бросить баллончик"), entry(attack_key(p), "Пшикнуть")]


## Тумбочка и брошенные баллончики: открыть ящик, взять баллончик.
func _use_cans(p: PlayerData, character: PlayerCharacter) -> bool:
	if holds_can(p):
		return false # одна рука — один баллончик
	var loose := _near_loose_can(p)
	var stand := apartment.nightstand
	var near_stand := _near(p, stand.front_point(), NIGHTSTAND_RADIUS)
	var can: SprayCan = null
	if loose:
		can = loose
	elif near_stand and stand.can_take():
		can = stand.take_can()
	elif near_stand and stand.can_open():
		stand.open()
		return true
	if can == null:
		return false
	_held_cans[p.id] = can
	can.hold(p, character)
	return true


func _can_hint(p: PlayerData) -> Array[Dictionary]:
	if holds_can(p):
		return []
	if _near_loose_can(p):
		return [entry(confirm_key(p), "Подобрать баллончик")]
	var stand := apartment.nightstand
	if not _near(p, stand.front_point(), NIGHTSTAND_RADIUS):
		return []
	if stand.can_take():
		return [entry(confirm_key(p), "Взять баллончик")]
	if stand.can_open():
		return [entry(confirm_key(p), "Открыть ящик")]
	return [] # ящик «сломан» (открыт) — кнопки нет


## Брошенный баллончик рядом, на который игрок смотрит (null — нет).
func _near_loose_can(p: PlayerData) -> SprayCan:
	for node in apartment.get_tree().get_nodes_in_group("spray_can"):
		var can := node as SprayCan
		if can and can.state == SprayCan.State.LOOSE \
				and _near(p, can.global_position, CAN_RADIUS):
			return can
	return null


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
	if _near_tippable(p, apartment.gramophone, GRAMOPHONE_RADIUS) and _gramophone_ready():
		_play_gramophone()
		return true
	if _use_switch(p) or _use_cans(p, character):
		return true
	if _near_cat(p) and apartment.cat.pet():
		# Персонаж тянет руку к коту.
		character.set_arm_pose(0.25, 0.9, 0.15)
		character.get_tree().create_timer(0.7).timeout.connect(func() -> void:
			if is_instance_valid(character) and apartment.phone.user != p:
				character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2))
		return true
	return false


## Торшер, ночник, игровые автоматы — «щёлкнуть выключателем». true — нажатие использовано.
func _use_switch(p: PlayerData) -> bool:
	var arcade := _near_arcade(p)
	var toilet := _near_toilet(p)
	if _near_tippable(p, apartment.floor_lamp, LAMP_RADIUS) and apartment.lamp_lit():
		apartment.turn_off_lamp()
	elif toilet and toilet.can_flush():
		toilet.flush()
	elif toilet and toilet.can_open():
		toilet.open_lid()
	elif arcade and arcade.is_working():
		arcade.break_down()
	else:
		return false
	return true


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
	return _furniture_hint(p)


## Граммофон, торшер, тумбочка, баллончики, туалет и автоматы.
## Кнопка есть, только пока вещь стоит на месте (поваленную трогать нельзя).
func _furniture_hint(p: PlayerData) -> Array[Dictionary]:
	if _near_tippable(p, apartment.gramophone, GRAMOPHONE_RADIUS):
		return [entry(confirm_key(p), "Завести граммофон", not _gramophone_ready())]
	# Выключенный торшер «чинится» сам — кнопки нет, пока снова не загорится.
	if _near_tippable(p, apartment.floor_lamp, LAMP_RADIUS) and apartment.lamp_lit():
		return [entry(confirm_key(p), "Выключить торшер")]
	var can_entries := _can_hint(p)
	if not can_entries.is_empty():
		return can_entries
	if _near_toilet(p):
		return _toilet_hint(p)
	return _arcade_hint(p)


func _arcade_hint(p: PlayerData) -> Array[Dictionary]:
	var arcade := _near_arcade(p)
	if arcade == null:
		return []
	if arcade.is_working():
		return [entry(confirm_key(p), "Сломать автомат")]
	return [entry(confirm_key(p), "Автомат чинится…", true)]


## Унитаз: поднять крышку → сходить → (перезарядка 60 сек) смыть.
func _toilet_hint(p: PlayerData) -> Array[Dictionary]:
	var toilet := apartment.toilet_room.toilet
	var key := confirm_key(p)
	var text := "Поднять крышку"
	var disabled := false
	if toilet.in_use:
		text = "Занято"
		disabled = true
	elif toilet.is_flushing():
		text = "Смывается…"
		disabled = true
	elif toilet.can_flush():
		text = "Смыть (снова — через %d с)" % ceili(toilet.cooldown_left())
	elif toilet.can_use():
		text = "Сходить в туалет"
	return [entry(key, text, disabled)]


## Можно сходить в туалет (лобби открывает вид сбоку — ToiletScreen).
func can_use_toilet(p: PlayerData) -> bool:
	var toilet := _near_toilet(p)
	return toilet != null and toilet.can_use()


## Унитаз, к которому игрок подошёл лицом (null — далеко).
func _near_toilet(p: PlayerData) -> Toilet:
	var toilet := apartment.toilet_room.toilet
	return toilet if _near(p, toilet.bowl_position(), TOILET_RADIUS) else null


## Игровой автомат, к экрану которого игрок стоит лицом (null — рядом нет).
func _near_arcade(p: PlayerData) -> ArcadeScreen:
	for screen in apartment.arcade_screens:
		if _near(p, screen.global_position, ARCADE_RADIUS):
			return screen
	return null


## Рядом с вещью, которая стоит на месте (поваленную трогать нельзя — кнопки нет).
func _near_tippable(p: PlayerData, item: Tippable, radius: float) -> bool:
	return item.is_at_home() and _near(p, item.global_position, radius)


func _gramophone_ready() -> bool:
	return Time.get_ticks_msec() / 1000.0 > _tune_until


## Три ноты: звук (мелодия собирается в Tune) и три пиксельные нотки над раструбом.
func _play_gramophone() -> void:
	var gramophone := apartment.gramophone
	_tune_until = Time.get_ticks_msec() / 1000.0 + TUNE_TIME
	if _player == null or not is_instance_valid(_player):
		_player = AudioStreamPlayer3D.new()
		_player.unit_size = 4.0
		_player.position = Vector3(0, 0.6, 0)
		gramophone.add_child(_player)
	_player.stream = Tune.random_melody()
	_player.play()
	for i in 3:
		_spawn_note(gramophone, i * 0.32)


func _spawn_note(gramophone: Node3D, delay: float) -> void:
	var note := Sprite3D.new()
	note.texture = NOTE
	note.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # пиксели чёткие
	note.pixel_size = 0.016
	note.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	note.shaded = false
	note.modulate.a = 0.0
	note.position = Vector3(randf_range(-0.12, 0.12), 0.75, randf_range(-0.12, 0.12))
	gramophone.add_child(note)
	var tween := note.create_tween().set_parallel(true)
	tween.tween_property(note, "modulate:a", 1.0, 0.1).set_delay(delay)
	tween.tween_property(note, "position:y", 1.35, 1.1).set_delay(delay)
	tween.tween_property(note, "position:x", note.position.x + randf_range(-0.15, 0.15), 1.1) \
		.set_delay(delay).set_trans(Tween.TRANS_SINE)
	tween.tween_property(note, "modulate:a", 0.0, 0.3).set_delay(delay + 0.8)
	tween.chain().tween_callback(note.queue_free)


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
	var character := characters[p.id] as Node3D
	var pos := character.global_position
	return Vector2(pos.x - point.x, pos.z - point.z).length() < radius and facing(character, point)
