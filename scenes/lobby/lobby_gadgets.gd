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
const SWITCH_RADIUS := 0.8
const RADIO_RADIUS := 1.4
const SIDEBOARD_RADIUS := 1.1
const SIDEBOARD_GLASS_RADIUS := 1.3
const ARCADE_RADIUS := 1.1
const TOILET_RADIUS := 1.2
const SINK_RADIUS := 1.0
## Удар по вещам: дальность и конус (градусы от взгляда) — бьётся одна вещь, самая «в прицеле».
const PUNCH_REACH_ITEMS := 1.3
const PUNCH_CONE := 22.0
const NIGHTSTAND_RADIUS := 1.1
const CAN_RADIUS := 1.0
## Как далеко долетает краска из баллончика и дотягивается губка.
const SPRAY_REACH := 3.5
const SPONGE_REACH := 1.6
## Через сколько граммофон можно завести снова (секунды).
const TUNE_TIME := 3.0
const NOTE := preload("res://assets/textures/fx/note_pixel.png")

var apartment: Apartment
## PlayerData.id -> PlayerCharacter (тот же словарь, что в лобби).
var characters: Dictionary
## Бутылка с кухни в руке (взять, выпить, бросить) — scenes/lobby/props/bottle_hand.gd.
var bottles: BottleHand
var _tune_until := 0.0
## Кто держит баллончик: PlayerData.id -> SprayCan.
var _held_cans: Dictionary = {}
## Губки в руках и «губки в кадре» у камер: PlayerData.id -> Sponge / Node3D.
var _held_sponges: Dictionary = {}
var _view_sponges: Dictionary = {}
## «Пульт в кадре» у камеры того, кто держит пульт (PlayerData.id -> Node3D).
var _view_remotes: Dictionary = {}
## Молотки в руках и «молотки в кадре»: PlayerData.id -> Hammer / Node3D.
var _held_hammers: Dictionary = {}
var _view_hammers: Dictionary = {}
var _player: AudioStreamPlayer3D


func _init(apt: Apartment, chars: Dictionary) -> void:
	apartment = apt
	characters = chars
	bottles = BottleHand.new(apt.kitchen_room, chars, apt)


## Одна строка подсказки: кнопка, действие, недоступно ли (серым).
## on_run — действие работает и на бегу (Shift): подсказка не сереет (удар молотком).
static func entry(key: String, text: String, off: bool = false, on_run: bool = false) -> Dictionary:
	return {"key": key, "text": text, "off": off, "on_run": on_run}


## Бежит (Shift и движется) — тогда кнопки действий не работают и подсказки серые: можно
## носиться и прыгать по квартире, ничего не задевая Пробелом случайно.
static func is_running(p: PlayerData, character: PlayerCharacter) -> bool:
	return p.input != null and p.input.is_pressed("sprint") \
		and Vector2(character.velocity.x, character.velocity.z).length() > 1.0


## Те же подсказки, но серые (на бегу).
static func greyed(entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for e in entries:
		result.append(e if e.get("on_run", false) else entry(e["key"], e["text"], true))
	return result


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


static func secondary_key(p: PlayerData) -> String:
	match p.device_kind:
		PlayerData.DeviceKind.KEYBOARD_WASD:
			return "ПКМ"
		PlayerData.DeviceKind.KEYBOARD_ARROWS:
			return ","
		_:
			return "RB"


static func attack_key(p: PlayerData) -> String:
	match p.device_kind:
		PlayerData.DeviceKind.KEYBOARD_WASD:
			return "ЛКМ"
		PlayerData.DeviceKind.KEYBOARD_ARROWS:
			return "/"
		_:
			return "X"


## Вещь под ударом: целая Breakable или Tippable в пределах PUNCH_REACH_ITEMS, ближе всего к лучу
## взгляда (от первого лица — с наклоном камеры), в узком конусе PUNCH_CONE. null — мимо.
func punch_target(character: PlayerCharacter, camera: Camera3D) -> Node3D:
	return PunchAim.target(character, camera, PUNCH_REACH_ITEMS, PUNCH_CONE)


# ---------------- Баллончики ----------------

func holds_can(p: PlayerData) -> bool:
	return _held_cans.has(p.id)


## Каждый кадр для держащего баллончик: «бросить» (G) — бросить; второе действие (ПКМ) — цвет;
## зажат удар — красить туда, куда смотрит прицел (camera — камера от первого лица, null — вид
## сверху: тогда «прицел» — прямо перед персонажем). view_can — баллончик «в кадре».
func _process_can_holder(p: PlayerData, camera: Camera3D, view_can: Node3D) -> void:
	var can: SprayCan = _held_cans[p.id]
	var character: PlayerCharacter = characters[p.id]
	if p.input.is_just_pressed("drop"):
		_release_can(p, look_dir(character, camera)) # бросить туда, куда смотрит
		return
	if p.input.is_just_pressed("secondary"):
		can.next_color()
	# Баллончик «в кадре» — того же цвета, что и в руке (перекрашиваем, только если сменился).
	if view_can and int(view_can.get_meta("tint", -1)) != can.color_index:
		SprayCan.tint_stripe(view_can, can.color())
		view_can.set_meta("tint", can.color_index)
	if not p.input.is_pressed("attack"):
		can.stop_spray()
		return
	var hit := _aim_hit(character, camera, SPRAY_REACH)
	if hit.is_empty():
		var far := _aim_end(character, camera, SPRAY_REACH)
		can.spray_at(far, Vector3.UP, false, apartment.get_process_delta_time(), null, view_can)
	else:
		can.spray_at(hit["position"], hit["normal"], true, apartment.get_process_delta_time(),
			hit["collider"], view_can)


## Куда смотрит прицел: от камеры (от первого лица) или от головы вперёд (вид сверху).
## Луч видит стены, мебель и игроков (слой 1) и посуду (Breakable.PAINT_LAYER).
func _aim_hit(character: PlayerCharacter, camera: Camera3D, reach: float) -> Dictionary:
	var from := camera.global_position if camera else character.global_position + Vector3.UP * 1.3
	var query := PhysicsRayQueryParameters3D.create(from, _aim_end(character, camera, reach),
		1 | Breakable.PAINT_LAYER, [character.get_rid()])
	return apartment.get_world_3d().direct_space_state.intersect_ray(query)


## Куда смотрит игрок: взгляд камеры от первого лица (или «вперёд» персонажа на виде сверху).
static func look_dir(character: PlayerCharacter, camera: Camera3D) -> Vector3:
	if camera:
		return -camera.global_basis.z
	return -character.global_basis.z


func _aim_end(character: PlayerCharacter, camera: Camera3D, reach: float) -> Vector3:
	if camera:
		return camera.global_position - camera.global_basis.z * reach
	return character.global_position + Vector3.UP * 1.3 - character.global_basis.z * reach


# ---------------- Рука: баллончик, губка или пульт ----------------

## В руке что-то есть (баллончик или губка) — второе не взять, кулаком не бьёт.
func hand_busy(p: PlayerData) -> bool:
	return holds_can(p) or _holds_sponge(p) or _holds_remote(p) or holds_hammer(p) \
		or bottles.holds(p)


func _holds_sponge(p: PlayerData) -> bool:
	return _held_sponges.has(p.id)


## Каждый кадр для того, у кого что-то в руке.
func process_hand(p: PlayerData, camera: Camera3D, view_can: Node3D) -> void:
	if holds_can(p):
		_process_can_holder(p, camera, view_can)
	elif _holds_sponge(p):
		_process_sponge(p, camera)
	elif _holds_remote(p):
		_process_remote(p, camera)
	elif holds_hammer(p):
		_process_hammer(p, camera)
	elif bottles.holds(p):
		bottles.process(p, camera)


## Бросить всё из руки (игрок ушёл из лобби).
func release_hand(p: PlayerData) -> void:
	_release_can(p)
	_release_sponge(p)
	_release_hammer(p)
	bottles.release(p)
	if _holds_remote(p):
		_hide_view_remote(p)
		apartment.tv_remote.go_home()


## Подсказки тому, у кого что-то в руке.
func hand_hint(p: PlayerData) -> Array[Dictionary]:
	if holds_can(p):
		return _can_holder_hint(p)
	if bottles.holds(p):
		return bottles.hint(p)
	if holds_hammer(p):
		var hammer_entries: Array[Dictionary] = [entry(attack_key(p), "Ударить молотком", false, true),
			entry(drop_key(p), "Бросить молоток")]
		return hammer_entries
	if _holds_remote(p):
		var remote_entries: Array[Dictionary] = [entry(attack_key(p), "Нажать кнопку"),
			entry(drop_key(p), "Бросить пульт")]
		return remote_entries
	if not _holds_sponge(p):
		return _no_hint()
	var result: Array[Dictionary] = [entry(attack_key(p), "Оттирать (зажать)"),
		entry(drop_key(p), "Бросить губку")]
	var sink := _near_sink(p)
	if sink and sink.accepts_sponge():
		result.append(entry(confirm_key(p), "Положить губку"))
	return result


## В подсказках руки есть действие на «подтвердить» («Положить губку») — Пробел не прыжок.
func hand_uses_confirm(p: PlayerData) -> bool:
	var key := confirm_key(p)
	for item in hand_hint(p):
		if item["key"] == key and not item["off"]:
			return true
	return false


## Удар у раковины, пульта, бутылки (рука свободна) — взять вещь вместо удара. true — взял.
func try_attack_use(p: PlayerData) -> bool:
	if _use_remote(p) or (not hand_busy(p) and bottles.try_take(p)):
		return true
	var sink := _near_sink(p)
	if hand_busy(p) or sink == null or sink.sponge == null:
		return false
	_hold_sponge(p, sink.take_sponge())
	return true


## Губка: G — бросить; зажат удар — оттирать то, что под прицелом (до 1.6 м).
func _process_sponge(p: PlayerData, camera: Camera3D) -> void:
	var sponge: Sponge = _held_sponges[p.id]
	var character: PlayerCharacter = characters[p.id]
	_show_view_sponge(p, camera)
	if p.input.is_just_pressed("drop"):
		_release_sponge(p, look_dir(character, camera))
		return
	if not p.input.is_pressed("attack"):
		sponge.stop_scrub()
		return
	var hit := _aim_hit(character, camera, SPONGE_REACH)
	if hit.is_empty():
		sponge.stop_scrub()
		return
	sponge.scrub_at(hit["position"], apartment.toilet_room.toilet)
	# Рука ходит туда-сюда, как будто трёт.
	character.arm_pose_x = 0.9 + sin(Time.get_ticks_msec() * 0.02) * 0.25


## Губка «в кадре» у камеры от первого лица (создаётся, когда взяли; убирается, когда бросили).
func _show_view_sponge(p: PlayerData, camera: Camera3D) -> void:
	if camera == null or _has_view(_view_sponges, p.id):
		return
	# Губка «в кадре» — одна губка, без руки (слой «в кадре» этого игрока).
	var model := HandHold.make_view(Sponge.make_model(), 1 << (p.slot + 10),
		Vector3(0.24, -0.26, -0.42), Vector3(0.4, 0.3, 0.0))
	camera.add_child(model)
	_view_sponges[p.id] = model


func _hold_sponge(p: PlayerData, sponge: Sponge) -> void:
	_held_sponges[p.id] = sponge
	sponge.hold(p, characters[p.id])


## Бросить губку (G или ушёл из лобби).
func _release_sponge(p: PlayerData, dir: Vector3 = Vector3.ZERO) -> void:
	if _has_view(_view_sponges, p.id):
		(_view_sponges[p.id] as Node).queue_free()
		_view_sponges.erase(p.id)
	if not _held_sponges.has(p.id):
		return
	var sponge: Sponge = _held_sponges[p.id]
	_held_sponges.erase(p.id)
	if is_instance_valid(sponge) and characters.has(p.id):
		sponge.drop(characters[p.id], apartment, dir)


## «Подтвердить»: у раковины с губкой в руке — положить её; рядом брошенная губка — подобрать.
func _use_sponge(p: PlayerData) -> bool:
	var sink := _near_sink(p)
	if _holds_sponge(p):
		if sink == null or not sink.accepts_sponge():
			return false
		var sponge: Sponge = _held_sponges[p.id]
		_release_sponge_quietly(p)
		sink.return_sponge(sponge)
		characters[p.id].set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2)
		return true
	if hand_busy(p):
		return false
	var loose := _near_loose_sponge(p)
	if loose:
		_hold_sponge(p, loose)
		return true
	return false


## Брошенная губка рядом, на которую игрок смотрит (null — нет).
func _near_loose_sponge(p: PlayerData) -> Sponge:
	for node in apartment.get_tree().get_nodes_in_group("sponge"):
		var sponge := node as Sponge
		if sponge and sponge.state == Sponge.State.LOOSE \
				and _near(p, sponge.global_position, CAN_RADIUS):
			return sponge
	return null


## Убрать губку из руки без броска (её кладут на раковину).
func _release_sponge_quietly(p: PlayerData) -> void:
	if _has_view(_view_sponges, p.id):
		(_view_sponges[p.id] as Node).queue_free()
		_view_sponges.erase(p.id)
	_held_sponges.erase(p.id)


# ---------------- Пульт от телевизора ----------------

func _holds_remote(p: PlayerData) -> bool:
	var remote := apartment.tv_remote
	return remote != null and remote.state == TvRemote.State.HELD and remote.holder == p


## Пульт рядом (на диване или брошенный), который можно взять (null — нет или уже в руке).
func _near_remote(p: PlayerData) -> TvRemote:
	var remote := apartment.tv_remote
	if remote == null or remote.state == TvRemote.State.HELD or remote.returning or hand_busy(p):
		return null
	return remote if _near(p, remote.global_position, CAN_RADIUS) else null


## Подсказка «Взять пульт» (на ЛКМ: Пробел у дивана — «сесть»). Пусто — пульта рядом нет.
func remote_hint(p: PlayerData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _near_remote(p):
		result.append(entry(attack_key(p), "Взять пульт"))
	elif not hand_busy(p):
		result.append_array(bottles.take_hint(p))
	return result


## Удар у пульта — взять его в руку. true — взял.
func _use_remote(p: PlayerData) -> bool:
	var remote := _near_remote(p)
	if remote == null:
		return false
	remote.hold(p, characters[p.id])
	return true


## Пульт в руке: G — бросить туда, куда смотришь.
func _process_remote(p: PlayerData, camera: Camera3D) -> void:
	var character: PlayerCharacter = characters[p.id]
	if camera and not _has_view(_view_remotes, p.id):
		var model := HandHold.make_view(TvRemote.make_model(), 1 << (p.slot + 10),
			Vector3(0.22, -0.24, -0.4), Vector3(0.5, 0.25, 0.0)) # один пульт, без руки
		camera.add_child(model)
		_view_remotes[p.id] = model
	if p.input.is_just_pressed("attack"): # ЛКМ — нажать красную кнопку (просто щёлкает)
		apartment.tv_remote.press()
		if _has_view(_view_remotes, p.id):
			TvRemote.press_button(_view_remotes[p.id]) # ищет кнопку внутри модели
	if not p.input.is_just_pressed("drop"):
		return
	_hide_view_remote(p)
	apartment.tv_remote.throw(character, look_dir(character, camera))


func _hide_view_remote(p: PlayerData) -> void:
	if _has_view(_view_remotes, p.id):
		(_view_remotes[p.id] as Node).queue_free()
		_view_remotes.erase(p.id)


# ---------------- Сервант и молоток ----------------

func holds_hammer(p: PlayerData) -> bool:
	return _held_hammers.has(p.id)


## Взмах молотком (удар — как кулаком, это делает лобби); автомат перед игроком —
## разбивается стекло экрана. Молоток «в кадре» резко клюёт вперёд.
## true — удар пришёлся по стеклу серванта (тогда больше ничего не бьётся).
func swing_hammer(p: PlayerData, camera: Camera3D = null) -> bool:
	var hammer: Hammer = _held_hammers[p.id]
	hammer.swing(characters[p.id])
	if _has_view(_view_hammers, p.id):
		var view: Node3D = _view_hammers[p.id]
		var hit := view.create_tween()
		# Замах назад-вверх, потом резкий удар вперёд-вниз и возврат.
		hit.tween_property(view, "rotation:x", 0.55, 0.09).set_ease(Tween.EASE_OUT)
		hit.tween_property(view, "rotation:x", -1.1, 0.07).set_ease(Tween.EASE_IN)
		hit.tween_property(view, "rotation:x", 0.0, 0.2).set_ease(Tween.EASE_OUT)
	# Какое стекло под ударом — то, куда смотрит игрок (точка взгляда на плоскости стёкол).
	var character: PlayerCharacter = characters[p.id]
	var eye := camera.global_position if camera else character.global_position + Vector3.UP * 1.2
	var pane := apartment.sideboard.pane_hit(eye, look_dir(character, camera),
		SIDEBOARD_GLASS_RADIUS)
	if pane >= 0 and not apartment.sideboard.pane_broken(pane):
		return apartment.sideboard.break_pane(pane)
	# Окно гостиной: 4 створки, с наклоном головы (верхние — если смотреть вверх).
	for glass: WindowGlass in [apartment.window_glass, apartment.kitchen_room.window_glass]:
		var window := glass.pane_hit(eye, look_dir(character, camera), SIDEBOARD_GLASS_RADIUS)
		if window >= 0:
			return glass.break_pane(window)
	var arcade := _near_arcade(p)
	if arcade:
		arcade.smash()
	return false


## Молоток в руке: G — бросить туда, куда смотришь.
func _process_hammer(p: PlayerData, camera: Camera3D) -> void:
	if camera and not _has_view(_view_hammers, p.id):
		camera.add_child(_make_view_hammer(p))
	if p.input.is_just_pressed("drop"):
		_release_hammer(p, look_dir(characters[p.id], camera))


## Молоток «в кадре» — только молоток, без руки: рукоятка внизу, боёк вверху. Взмах —
## поворот всего молотка вокруг низа рукоятки.
func _make_view_hammer(p: PlayerData) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.36, -0.42, -0.62) # кулак справа внизу (подсказки — слева от прицела)
	var model := Hammer.make_model() # только молоток, без руки
	# Ручка снизу вверх, чуть влево и от камеры; ударная часть смотрит вперёд (от игрока),
	# гвоздодёр — назад, к игроку (базис задаём осями: так не ошибиться с порядком поворотов).
	var up := Vector3(-0.25, 1.0, -0.35).normalized()
	var claw := Vector3(0.15, 0.0, 1.0)
	claw = (claw - up * claw.dot(up)).normalized()
	model.basis = Basis(up.cross(claw), up, claw)
	model.position.y = -0.02
	root.add_child(model)
	_set_layers(root, 1 << (p.slot + 10)) # слой «в кадре» этого игрока
	_view_hammers[p.id] = root
	return root


## Бросить молоток (dir — взгляд; Vector3.ZERO — уронить под себя, игрок ушёл из лобби).
func _release_hammer(p: PlayerData, dir: Vector3 = Vector3.ZERO) -> void:
	if _has_view(_view_hammers, p.id):
		(_view_hammers[p.id] as Node).queue_free()
		_view_hammers.erase(p.id)
	if not _held_hammers.has(p.id):
		return
	var hammer: Hammer = _held_hammers[p.id]
	_held_hammers.erase(p.id)
	if is_instance_valid(hammer) and characters.has(p.id):
		hammer.drop(characters[p.id], apartment, dir)


## «Подтвердить» у тумбы серванта: открыть дверцу / взять молоток; рядом брошенный — подобрать.
func _use_sideboard(p: PlayerData) -> bool:
	if hand_busy(p):
		return false
	var hammer := _near_loose_hammer(p)
	var cabinet := apartment.sideboard
	var near := _near(p, cabinet.front_point(), SIDEBOARD_RADIUS)
	if hammer == null and near and cabinet.can_take():
		hammer = cabinet.take_hammer()
	if hammer:
		_held_hammers[p.id] = hammer
		hammer.hold(p, characters[p.id])
		return true
	if near and cabinet.can_open():
		cabinet.open()
		return true
	if near and cabinet.can_close():
		cabinet.close()
		return true
	return _use_kitchen_cabinet(p)


## Дверцы на кухне (навесной шкафчик, духовка): открыть / закрыть. true — нажатие использовано.
func _use_kitchen_cabinet(p: PlayerData) -> bool:
	var prop := _near_hinged(p)
	if prop == null:
		return false
	if prop.can_open():
		prop.open()
		return true
	if prop.can_close():
		prop.close()
		return true
	return false


## Шкафчик или духовка на кухне, к которым подошли лицом (null — далеко). Если рядом и мойка,
## а смотрят скорее на неё, — null (мойка и духовка стоят бок о бок: раньше у мойки всегда
## предлагало «Открыть духовку»).
func _near_hinged(p: PlayerData) -> HingedProp:
	var prop := _hinged_in_reach(p)
	var sink := _sink_in_reach(p)
	if prop and sink and _view_angle(p, sink.front_point()) < _view_angle(p, prop.front_point()):
		return null
	return prop


func _hinged_in_reach(p: PlayerData) -> HingedProp:
	return apartment.kitchen_room.hinged_near(characters[p.id], 0.9) \
		if characters.has(p.id) else null


func _view_angle(p: PlayerData, point: Vector3) -> float:
	return KitchenRoom.view_angle(characters[p.id], point)


func _sideboard_hint(p: PlayerData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if hand_busy(p):
		return result
	var cabinet := apartment.sideboard
	if _near_loose_hammer(p):
		result.append(entry(confirm_key(p), "Подобрать молоток"))
	elif _near(p, cabinet.front_point(), SIDEBOARD_RADIUS):
		if cabinet.can_take():
			result.append(entry(confirm_key(p), "Взять молоток"))
		elif cabinet.can_open():
			result.append(entry(confirm_key(p), "Открыть тумбу"))
		elif cabinet.can_close():
			result.append(entry(confirm_key(p), "Закрыть тумбу"))
	elif _near_hinged(p):
		var prop := _near_hinged(p)
		if prop.can_open():
			result.append(entry(confirm_key(p), prop.open_text))
		elif prop.can_close():
			result.append(entry(confirm_key(p), prop.close_text))
	return result


func _near_loose_hammer(p: PlayerData) -> Hammer:
	for node in apartment.get_tree().get_nodes_in_group("hammer"):
		var hammer := node as Hammer
		if hammer and hammer.state == Hammer.State.LOOSE \
				and _near(p, hammer.global_position, CAN_RADIUS):
			return hammer
	return null


## Есть ли вещь «в кадре» (камера удаляется на F2 — запись устарела: убираем, иначе падало).
func _has_view(views: Dictionary, id: int) -> bool:
	if views.has(id) and not is_instance_valid(views[id]):
		views.erase(id)
	return views.has(id)


func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_layers(child, layer)


## Бросить баллончик (G); dir = Vector3.ZERO — уронить под себя (игрок ушёл из лобби).
func _release_can(p: PlayerData, dir: Vector3 = Vector3.ZERO) -> void:
	if not _held_cans.has(p.id):
		return
	var can: SprayCan = _held_cans[p.id]
	_held_cans.erase(p.id)
	if is_instance_valid(can) and characters.has(p.id):
		can.drop(characters[p.id], apartment, dir)


## Подсказка держащему баллончик (добавляется к остальным).
func _can_holder_hint(p: PlayerData) -> Array[Dictionary]:
	if not holds_can(p):
		return _no_hint()
	return [entry(attack_key(p), "Красить (зажать)"), entry(secondary_key(p), "Сменить цвет"),
		entry(drop_key(p), "Бросить баллончик")]


## Тумбочка и брошенные баллончики: открыть ящик, взять баллончик.
func _use_cans(p: PlayerData, character: PlayerCharacter) -> bool:
	if hand_busy(p):
		return false # одна рука — одна вещь
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
	if hand_busy(p):
		return _no_hint()
	if _near_loose_can(p):
		return [entry(confirm_key(p), "Подобрать баллончик")]
	if _near_loose_sponge(p):
		return [entry(confirm_key(p), "Подобрать губку")]
	var stand := apartment.nightstand
	if not _near(p, stand.front_point(), NIGHTSTAND_RADIUS):
		return _no_hint()
	var text := "" # ящик «сломан» (открыт) и пуст — кнопки нет
	var disabled := false
	if stand.can_take():
		text = "Взять баллончик"
	elif stand.shows_joke():
		text = "Хм… это не баллончик"
		disabled = true
	elif stand.can_open():
		text = "Открыть ящик"
	var result: Array[Dictionary] = []
	if text != "":
		result.append(entry(confirm_key(p), text, disabled))
	if not apartment.night_lamp.is_broken(): # ночник на тумбочке — на вторую кнопку
		var lit := apartment.night_lamp_light.is_on()
		result.append(entry(secondary_key(p), "Выключить ночник" if lit else "Включить ночник"))
	return result


## Вторая кнопка (ПКМ) с пустой рукой: у тумбочки — ночник. true — нажатие использовано.
func try_secondary(p: PlayerData) -> bool:
	if hand_busy(p) or apartment.night_lamp.is_broken():
		return false
	if not _near(p, apartment.nightstand.front_point(), NIGHTSTAND_RADIUS):
		return false
	apartment.night_lamp_light.toggle()
	return true


## Торшер, выключатели люстр и радио (свет — на время, см. LobbyLamp).
func _light_hint(p: PlayerData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _near_tippable(p, apartment.floor_lamp, LAMP_RADIUS):
		var lamp_on := apartment.floor_lamp_light.is_on()
		result.append(entry(confirm_key(p), "Выключить торшер" if lamp_on else "Включить торшер"))
		return result
	var chandelier := _near_switch(p)
	if chandelier:
		var lit := chandelier.is_on()
		result.append(entry(confirm_key(p), "Выключить свет" if lit else "Включить свет"))
	elif _near_radio(p):
		var music := apartment.radio_music.switched_on
		result.append(entry(confirm_key(p), "Выключить радио" if music else "Включить радио"))
	return result


## Целое радио на полке, на которое смотрит игрок.
func _near_radio(p: PlayerData) -> bool:
	var radio := apartment.radio_music.radio
	return not radio.is_broken() and _near(p, radio.global_position, RADIO_RADIUS)


## Выключатель люстры, к которому подошли лицом (null — нет рядом).
func _near_switch(p: PlayerData) -> LobbyLamp:
	var character: PlayerCharacter = characters[p.id]
	for chandelier in apartment.chandeliers:
		var to_player: Vector3 = character.global_position - chandelier["switch"]
		var in_front: bool = to_player.dot(chandelier["normal"]) > 0.0 # не через стену
		if in_front and Vector2(to_player.x, to_player.z).length() < SWITCH_RADIUS \
				and facing(character, chandelier["switch"], 30.0): # уже конус: только лицом
			return chandelier["lamp"]
	return null


## Пустая подсказка (типизированный массив: `return []` даёт обычный Array — падает).
func _no_hint() -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	return none


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
	if _gramophone_near(p) and _gramophone_ready():
		_play_gramophone()
		return true
	# Губка первой: с губкой в руке у раковины «подтвердить» — положить её, а не мыть руки.
	if _use_sponge(p) or _use_switch(p) or _use_cans(p, character) or _use_sideboard(p):
		return true
	if _near_cat(p) and apartment.cat.pet():
		# Персонаж тянет руку к коту.
		character.set_arm_pose(0.25, 0.9, 0.15)
		character.get_tree().create_timer(0.7).timeout.connect(func() -> void:
			if is_instance_valid(character) and apartment.phone.user != p:
				character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2))
		return true
	return false


## Торшер, люстры, раковина, туалет, автоматы — «щёлкнуть». true — нажатие использовано.
func _use_switch(p: PlayerData) -> bool:
	var arcade := _near_arcade(p)
	var toilet := _near_toilet(p)
	var sink := _near_sink(p)
	var chandelier := _near_switch(p)
	if _near_tippable(p, apartment.floor_lamp, LAMP_RADIUS):
		apartment.floor_lamp_light.toggle()
	elif chandelier:
		chandelier.toggle()
	elif _near_radio(p):
		apartment.radio_music.toggle()
	elif sink and sink.can_use(p):
		sink.use(p, characters[p.id])
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


## Граммофон, торшер, тумбочка, баллончики, туалет, автоматы (поваленную вещь не трогают).
func _furniture_hint(p: PlayerData) -> Array[Dictionary]:
	if _gramophone_near(p):
		return [entry(confirm_key(p), "Завести граммофон", not _gramophone_ready())]
	var light_entries := _light_hint(p)
	if not light_entries.is_empty():
		return light_entries
	var can_entries := _can_hint(p)
	if can_entries.is_empty():
		can_entries = _sideboard_hint(p)
	if not can_entries.is_empty():
		return can_entries
	if _near_sink(p) and not _holds_sponge(p): # с губкой в руке — подсказки руки («Положить»)
		return _sink_hint(p)
	if _near_toilet(p):
		return _toilet_hint(p)
	return _arcade_hint(p)


## Рукомойник: помыть руки (смывает краску) — каждому раз в 15 сек.
func _sink_hint(p: PlayerData) -> Array[Dictionary]:
	var sink := _near_sink(p)
	var wash := entry(confirm_key(p), "Помыть руки")
	if sink.busy:
		wash = entry(confirm_key(p), "Вода течёт…", true)
	elif not sink.can_use(p):
		wash = entry(confirm_key(p), "Помыть руки (через %d с)" % ceili(sink.cooldown_left(p)), true)
	var result: Array[Dictionary] = [wash]
	if sink.sponge != null and not hand_busy(p):
		result.append(entry(attack_key(p), "Взять губку"))
	return result


## Рукомойник в туалете или мойка на кухне, к кранам которых игрок подошёл лицом
## (null — далеко, или рядом духовка/шкафчик и смотрят скорее на них).
func _near_sink(p: PlayerData) -> Sink:
	var sink := _sink_in_reach(p)
	var prop := _hinged_in_reach(p)
	if sink and prop and _view_angle(p, prop.front_point()) < _view_angle(p, sink.front_point()):
		return null
	return sink


func _sink_in_reach(p: PlayerData) -> Sink:
	for sink: Sink in [apartment.toilet_room.sink, apartment.kitchen_room.sink]:
		if sink and _near(p, sink.front_point(), SINK_RADIUS):
			return sink
	return null


func _arcade_hint(p: PlayerData) -> Array[Dictionary]:
	var arcade := _near_arcade(p)
	if arcade == null:
		return _no_hint()
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
		text = "Смыть"
	elif toilet.can_use():
		text = "Сходить в туалет"
	elif toilet.lid_open: # крышка поднята, но перезарядка ещё идёт
		text = "Сходить — через %d с" % ceili(toilet.cooldown_left())
		disabled = true
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


## Граммофон рядом — но если выключатель тоже рядом (стол стоит под ним), граммофон уступает.
func _gramophone_near(p: PlayerData) -> bool:
	return _near_tippable(p, apartment.gramophone, GRAMOPHONE_RADIUS) and _near_switch(p) == null


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
