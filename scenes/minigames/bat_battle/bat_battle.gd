extends Node3D
## Мини-игра «Битва на битах»: все против всех на крыше гаражей.
##
## У каждого 100 HP и бита. Атака — вращение вокруг себя: бьёт всех рядом
## и отбрасывает. Вылетел с крыши или кончились HP — выбыл.
## На крыше появляются бусты: улучшенная бита и энергетик «Ягуарр».
## Места: последний выживший — первый; дальше по порядку выбывания.
## Если время вышло — у кого больше HP, тот выше.

enum Boost { SUPER_BAT, DRINK }

const CHARACTER_SCENE := preload("res://scenes/characters/test_character.tscn")
const BAT_SCENE := preload("res://assets/models/props/bat.glb")
const SUPER_BAT_SCENE := preload("res://assets/models/props/bat_super.glb")
const CAN_SCENE := preload("res://assets/models/props/energy_can.glb")

## 250 HP: раунд не кончается слишком быстро (удар 20, супер-бита 34).
const MAX_HP := 250
const ROUND_TIME := 75.0
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(-5.5, 0.3, -2.5), Vector3(5.5, 0.3, -2.5), Vector3(-5.5, 0.3, 2.5), Vector3(5.5, 0.3, 2.5),
]
## Крыша: прямоугольник по X и Z. Ниже OUT_Y — значит упал с крыши.
const ROOF_HALF := Vector2(8.5, 4.5)
const OUT_Y := -1.5

## Атака-вращение.
const SPIN_TIME := 0.35
const SPIN_COOLDOWN := 0.9
const SPIN_SPEED_FACTOR := 0.6
## Как держать биту в покое: рука согнута перед грудью, бита лежит на плече.
const REST_ARM_Z := 0.42
const REST_ARM_X := 0.9 # рука согнута вперёд, кисть перед грудью
const REST_BAT_X := 2.76 # ≈158°: бита смотрит вверх и назад, за плечо
const HIT_RADIUS := 2.1
const HIT_DAMAGE := 20
const HIT_KNOCKBACK := 9.0
## С улучшенной битой.
const SUPER_RADIUS := 2.6
const SUPER_DAMAGE := 34
const SUPER_KNOCKBACK := 13.0
const SUPER_TIME := 15.0
## Энергетик «Ягуарр»: быстрее атака + немного лечения.
const DRINK_TIME := 8.0
const DRINK_COOLDOWN := 0.4
const DRINK_HEAL := 50

const BOOST_INTERVAL := 7.0
const MAX_BOOSTS := 2
const PICKUP_RADIUS := 1.1
## Боты: шанс ударить в каждом физическом кадре, когда враг рядом (~0.2 сек реакции).
const BOT_ATTACK_CHANCE := 0.08


## Состояние одного бойца.
class Fighter:
	var player: PlayerData
	var character: PlayerCharacter
	var hp_label: Label3D
	var hp := MAX_HP
	var alive := true
	var has_super_bat := false
	var cooldown := 0.0
	var super_left := 0.0
	var drink_left := 0.0
	var spinning := false
	var bat: Node3D


var _fighters: Array[Fighter] = []
## Выбывшие по порядку (первый выбывший — последнее место).
var _out_order: Array[PlayerData] = []
var _boosts: Array[Node3D] = []
var _time_left := ROUND_TIME
var _boost_timer := BOOST_INTERVAL / 2.0
var _fighting := false
var _finished := false

var _timer_label: Label
var _message_label: Label
## Полоски здоровья внизу: PlayerData.id -> {"main", "ghost", "text", "card"}.
var _hp_bars: Dictionary = {}

@onready var _camera: Camera3D = $Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _fighters_root: Node3D = $Fighters
@onready var _ui: CanvasLayer = $UI


func _ready() -> void:
	if not MatchState.in_progress:
		# Запуск сцены напрямую (F6) для теста.
		if PlayerManager.players.is_empty():
			PlayerManager.add_local_player(PlayerData.DeviceKind.KEYBOARD_WASD)
			PlayerManager.add_local_player(PlayerData.DeviceKind.KEYBOARD_ARROWS)
		MatchState.start_new_match(1)

	_sun.rotation_degrees = Vector3(-55, -30, 0)
	_camera.look_at_from_position(Vector3(0, 13.5, 12.5), Vector3(0, -0.5, 0.8))
	_spawn_fighters()
	# Двор вокруг крыши: дома, машины, голуби, собака.
	var yard := GarageYard.new()
	for f in _fighters:
		yard.watchers.append(f.character)
	add_child(yard)
	_build_ui()
	_run_intro.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			MatchState.abort_to_lobby()


func _spawn_fighters() -> void:
	var order := MatchState.turn_order()
	for i in order.size():
		var f := Fighter.new()
		f.player = order[i]
		f.character = CHARACTER_SCENE.instantiate()
		f.character.setup(f.player, SPAWN_POINTS[i % SPAWN_POINTS.size()])
		f.character.can_jump = false # кнопка подтверждения = атака
		f.character.respawn_on_fall = false
		f.character.input_enabled = false # включим после отсчёта
		_fighters_root.add_child(f.character)
		# Повернуть лицом к центру крыши.
		var to_center := -f.character.position
		f.character.rotation.y = atan2(-to_center.x, -to_center.z)
		_give_bat(f, BAT_SCENE)

		f.hp_label = Label3D.new()
		f.hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		f.hp_label.no_depth_test = true
		f.hp_label.font_size = 40
		f.hp_label.outline_size = 10
		f.hp_label.position.y = 2.45
		f.character.add_child(f.hp_label)
		_fighters.append(f)
		_update_hp(f)


func _run_intro() -> void:
	for text in ["3", "2", "1"]:
		_message_label.text = text
		await get_tree().create_timer(0.7).timeout
	_message_label.text = "БЕЙ!"
	_fighting = true
	for f in _fighters:
		f.character.input_enabled = true
	await get_tree().create_timer(0.8).timeout
	if not _finished:
		_message_label.text = ""


func _physics_process(delta: float) -> void:
	if not _fighting:
		return

	_time_left -= delta
	_timer_label.text = "%d" % ceili(maxf(_time_left, 0.0))

	for f in _fighters:
		if not f.alive:
			continue
		f.cooldown = maxf(0.0, f.cooldown - delta)
		f.super_left = maxf(0.0, f.super_left - delta)
		f.drink_left = maxf(0.0, f.drink_left - delta)
		if f.has_super_bat and f.super_left == 0.0:
			f.has_super_bat = false
			_give_bat(f, BAT_SCENE)

		if f.player.is_bot():
			_bot_think(f)
		# Кнопку можно не только нажимать, но и держать: удары идут сами по перезарядке.
		# Зажал Пробел (или кнопку удара — ЛКМ/F, «/», X) — бьёт сам раз в перезарядку, без «спама».
		var held := f.player.input != null \
			and (f.player.input.is_pressed("confirm") or f.player.input.is_pressed("attack"))
		if held and f.cooldown == 0.0 and not f.spinning:
			_spin(f)

		if _fell_off(f.character.global_position):
			_eliminate(f, "вылетел с крыши")

	_update_boosts(delta)
	_check_end()


## Слетел с крыши: ниже OUT_Y или за краем крыши и ниже её уровня (например, упал на гелик —
## его крыша выше OUT_Y, но это всё равно падение).
func _fell_off(pos: Vector3) -> bool:
	var outside := absf(pos.x) > ROOF_HALF.x or absf(pos.z) > ROOF_HALF.y
	return pos.y < OUT_Y or (outside and pos.y < -0.6)


## Дать бойцу биту (обычную или супер) и поставить в позу «бита на плече».
func _give_bat(f: Fighter, scene: PackedScene) -> void:
	f.bat = f.character.hold_item(scene.instantiate())
	_rest_pose(f, 0.01)


## Поза покоя: рука согнута перед грудью, бита лежит на плече.
func _rest_pose(f: Fighter, time: float) -> void:
	if not is_instance_valid(f.bat):
		return
	f.character.set_arm_pose(REST_ARM_Z, REST_ARM_X, time)
	create_tween().tween_property(f.bat, "rotation:x", REST_BAT_X, time)


## Атака: вращение с битой, урон и отбрасывание всем, кто рядом.
func _spin(f: Fighter) -> void:
	var is_super := f.has_super_bat
	f.cooldown = DRINK_COOLDOWN if f.drink_left > 0.0 else SPIN_COOLDOWN
	f.spinning = true
	f.character.speed = 6.0 * SPIN_SPEED_FACTOR

	# Замах: рука с битой выносится в сторону, бита — продолжение руки; затем оборот.
	f.character.set_arm_pose(PlayerCharacter.ARM_SIDE, 0.0, 0.06)
	if f.bat:
		create_tween().tween_property(f.bat, "rotation:x", 0.0, 0.06)
	_spawn_swoosh(f, SUPER_RADIUS if is_super else HIT_RADIUS)
	var tween := create_tween()
	f.character.visual.rotation.y = 0.0
	tween.tween_interval(0.05)
	tween.tween_property(f.character.visual, "rotation:y", -TAU, SPIN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		f.character.visual.rotation.y = 0.0
		f.character.speed = 6.0
		f.spinning = false
		_rest_pose(f, 0.2))

	var radius := SUPER_RADIUS if is_super else HIT_RADIUS
	var damage := SUPER_DAMAGE if is_super else HIT_DAMAGE
	var force := SUPER_KNOCKBACK if is_super else HIT_KNOCKBACK
	var origin := f.character.global_position
	for other in _fighters:
		if other == f or not other.alive:
			continue
		var offset := other.character.global_position - origin
		offset.y = 0.0
		if offset.length() > radius:
			continue
		var dir := offset.normalized() if offset.length() > 0.01 else Vector3.FORWARD
		other.character.apply_knockback(dir * force + Vector3.UP * 4.0)
		var dealt := mini(other.hp, damage)
		other.hp -= dealt
		_update_hp(other)
		_flash(other.character)
		_damage_number(other.character, dealt, is_super)
		if other.hp == 0:
			_eliminate(other, "выбит")


## Мозги бота: идти к ближайшему врагу (или к бусту, если он ближе),
## не подходить к краю крыши и крутиться, когда враг в зоне удара.
func _bot_think(f: Fighter) -> void:
	var bot := f.player.bot_input()
	var pos := f.character.global_position
	var target := Vector3.ZERO
	var enemy_dist := INF
	for other in _fighters:
		if other == f or not other.alive:
			continue
		var d := pos.distance_to(other.character.global_position)
		if d < enemy_dist:
			enemy_dist = d
			target = other.character.global_position
	var chasing_enemy := enemy_dist < INF
	var boost_dist := INF
	for boost in _boosts:
		var d := pos.distance_to(boost.global_position)
		if d < enemy_dist * 0.8 and d < boost_dist:
			boost_dist = d
			target = boost.global_position
			chasing_enemy = false

	var to_target := Vector2(target.x - pos.x, target.z - pos.z)
	var move := to_target.normalized() if to_target.length() > 0.2 else Vector2.ZERO
	# Вплотную к врагу не лезем: стоим на дистанции удара.
	if chasing_enemy and enemy_dist < HIT_RADIUS * 0.6:
		move *= 0.2
	# Близко к краю — тянем к центру крыши.
	var edge := Vector2(pos.x / ROOF_HALF.x, pos.z / ROOF_HALF.y)
	if absf(edge.x) > 0.75 or absf(edge.y) > 0.75:
		move += Vector2(-pos.x, -pos.z).normalized() * 1.2
	bot.move = move.limit_length(1.0)

	var reach := SUPER_RADIUS if f.has_super_bat else HIT_RADIUS
	if enemy_dist < reach * 0.9 and f.cooldown == 0.0 and randf() < BOT_ATTACK_CHANCE:
		bot.press("confirm")


func _eliminate(f: Fighter, reason: String) -> void:
	if not f.alive:
		return
	if f.hp > 0:
		_damage_number(f.character, f.hp, true) # слетел с крыши — минус все оставшиеся HP
	f.alive = false
	f.hp = 0
	_update_hp(f)
	_out_order.append(f.player)
	f.character.input_enabled = false
	if f.player.is_bot():
		f.player.bot_input().move = Vector2.ZERO
	f.hp_label.text = "ВЫБЫЛ"
	_message_label.text = "%s %s!" % [f.player.display_name, reason]
	# Выбитого (не упавшего) уносит с крыши.
	if f.character.global_position.y > OUT_Y:
		var away := f.character.global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else Vector3.BACK
		f.character.apply_knockback(away * 16.0 + Vector3.UP * 7.0)
	# Краснеет, падает, крестики на глазах, плавно исчезает.
	f.character.play_death()


func _check_end() -> void:
	if _finished:
		return
	var alive := _fighters.filter(func(f: Fighter) -> bool: return f.alive)
	var solo := _fighters.size() == 1
	if _time_left <= 0.0 or (not solo and alive.size() <= 1) or alive.is_empty():
		_finish(alive)


func _finish(alive: Array) -> void:
	_finished = true
	_fighting = false
	for f in _fighters:
		f.character.input_enabled = false
	# Выжившие — по HP, затем выбывшие с конца.
	alive.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.hp > b.hp)
	var places: Array[PlayerData] = []
	for f in alive:
		places.append(f.player)
	for i in range(_out_order.size() - 1, -1, -1):
		places.append(_out_order[i])

	var lines: PackedStringArray = []
	for i in places.size():
		var reward: int = MatchState.MINIGAME_REWARDS[i] if i < MatchState.MINIGAME_REWARDS.size() else 0
		lines.append("%d. %s  +%d ₽" % [i + 1, places[i].display_name, reward])
	var header := "Время вышло!" if _time_left <= 0.0 else "Победитель: %s!" % places[0].display_name
	_message_label.text = header + "\n" + "\n".join(lines)
	await get_tree().create_timer(3.5).timeout
	MatchState.finish_minigame(places)


# ---------------- Бусты ----------------

func _update_boosts(delta: float) -> void:
	_boost_timer -= delta
	if _boost_timer <= 0.0:
		_boost_timer = BOOST_INTERVAL
		if _boosts.size() < MAX_BOOSTS:
			_spawn_boost(Boost.values().pick_random())

	# Копия списка с явным типом: в цикле бусты могут удаляться.
	var boosts: Array[Node3D] = _boosts.duplicate()
	for boost in boosts:
		boost.rotate_y(2.0 * delta)
		for f in _fighters:
			if not f.alive:
				continue
			var d := f.character.global_position - boost.global_position
			d.y = 0.0
			if d.length() < PICKUP_RADIUS:
				_apply_boost(f, boost.get_meta("type"))
				_boosts.erase(boost)
				boost.queue_free()
				break


func _spawn_boost(type: Boost) -> void:
	var root := Node3D.new()
	root.set_meta("type", type)
	var model: Node3D
	var label := Label3D.new()
	if type == Boost.SUPER_BAT:
		model = SUPER_BAT_SCENE.instantiate()
		model.rotation_degrees.z = 90.0
		model.position = Vector3(0.4, 0.7, 0)
		label.text = "СУПЕР-БИТА"
		label.modulate = Color("ff6b5a")
	else:
		model = CAN_SCENE.instantiate()
		model.scale = Vector3.ONE * 4.0
		model.position.y = 0.25
		label.text = "«ЯГУАРР»"
		label.modulate = Color("ffb52e")
	root.add_child(model)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.outline_size = 10
	label.position.y = 1.6
	root.add_child(label)
	root.position = Vector3(
		randf_range(-ROOF_HALF.x + 1.5, ROOF_HALF.x - 1.5), 0.0,
		randf_range(-ROOF_HALF.y + 1.0, ROOF_HALF.y - 1.0))
	add_child(root)
	_boosts.append(root)


func _apply_boost(f: Fighter, type: Boost) -> void:
	if type == Boost.SUPER_BAT:
		f.super_left = SUPER_TIME
		f.has_super_bat = true
		_give_bat(f, SUPER_BAT_SCENE)
		_message_label.text = "%s взял СУПЕР-БИТУ!" % f.player.display_name
	else:
		f.drink_left = DRINK_TIME
		# +50 HP всегда, даже при полном здоровье (тогда сверх максимума, до MAX_HP + 50).
		f.hp = mini(MAX_HP + DRINK_HEAL, f.hp + DRINK_HEAL)
		_update_hp(f)
		_message_label.text = "%s выпил «Ягуарр»! +%d HP и крутится быстрее!" \
			% [f.player.display_name, DRINK_HEAL]
	_clear_message_later()


func _clear_message_later() -> void:
	var text := _message_label.text
	await get_tree().create_timer(1.5).timeout
	if not _finished and _message_label.text == text:
		_message_label.text = ""


# ---------------- Отображение ----------------

func _update_hp(f: Fighter) -> void:
	f.hp_label.text = "%d HP" % f.hp
	f.hp_label.modulate = Color("a8f0a0").lerp(Color("ff6b5a"),
		clampf(1.0 - float(f.hp) / MAX_HP, 0.0, 1.0))
	if _hp_bars.has(f.player.id):
		_set_hp_bar(_hp_bars[f.player.id], f.hp, f.alive)


## Всплывающая цифра урона над головой: «-20», летит вверх и тает.
func _damage_number(character: PlayerCharacter, amount: int, big: bool) -> void:
	var label := Label3D.new()
	label.text = "-%d" % amount
	label.font_size = 96 if big else 72
	label.outline_size = 18
	label.modulate = Color("ffd23f") if big else Color("ff5a4a")
	label.outline_modulate = Color(0.25, 0.02, 0.02)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	label.global_position = character.global_position + Vector3(randf_range(-0.3, 0.3), 2.3, 0)
	label.scale = Vector3.ONE * 0.4
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector3.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y + 1.3, 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tween.chain().tween_callback(label.queue_free)


## След биты в воздухе: полупрозрачная дуга, крутится вместе с персонажем и тает.
func _spawn_swoosh(f: Fighter, radius: float) -> void:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var steps := 24
	for i in steps + 1:
		var t := float(i) / steps
		var a := t * TAU * 0.8 # дуга на 290°
		var dir := Vector3(cos(a), 0.0, -sin(a))
		var alpha := t * t * 0.7 # хвост прозрачный, голова — плотнее
		verts.append(dir * 0.45)
		verts.append(dir * radius)
		colors.append(Color(1, 1, 1, 0.0))
		colors.append(Color(1, 1, 1, alpha))
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	var swoosh := MeshInstance3D.new()
	swoosh.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	swoosh.material_override = material
	swoosh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	swoosh.position.y = 1.0
	f.character.visual.add_child(swoosh)
	var tween := create_tween()
	tween.tween_property(swoosh, "transparency", 1.0, SPIN_TIME + 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(swoosh.queue_free)


## Краткая вспышка при получении удара.
func _flash(character: PlayerCharacter) -> void:
	var tween := create_tween()
	tween.tween_property(character.visual, "scale", Vector3(1.25, 0.8, 1.25), 0.06)
	tween.tween_property(character.visual, "scale", Vector3.ONE, 0.12)


func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 24)
	_ui.add_child(root)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	var top := HBoxContainer.new()
	column.add_child(top)
	var title := _label("Битва на битах", 44, Color("f6c343"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_timer_label = _label("%d" % int(ROUND_TIME), 52, Color.WHITE)
	top.add_child(_timer_label)

	var rules := "Атака (вращение): Пробел / Enter / A.  Скинь всех с крыши!"
	column.add_child(_label(rules, 20, Color.WHITE))

	_message_label = _label("", 54, Color.WHITE)
	_message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_message_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	for f in _fighters:
		var bar := _make_hp_card(f)
		row.add_child(bar["card"])
		_hp_bars[f.player.id] = bar


## Карточка здоровья: имя и «230 / 250» сверху, под ними полоска цвета игрока. За ней —
## «след урона» (светлая полоска, которая догоняет с задержкой, как в файтингах).
func _make_hp_card(f: Fighter) -> Dictionary:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.05, 0.85)
	style.border_color = f.player.color
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size.x = 270
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var name_label := _label(f.player.display_name, 22, f.player.color.lightened(0.3))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(name_label)
	var text := _label("%d / %d" % [f.hp, MAX_HP], 22, Color.WHITE)
	header.add_child(text)
	var holder := Control.new()
	holder.custom_minimum_size.y = 20
	column.add_child(holder)
	# «Хвост» урона — красный: видно, сколько только что сняли.
	var ghost := _hp_progress(Color(0.9, 0.15, 0.12), Color(0.15, 0.12, 0.1))
	holder.add_child(ghost)
	var main := _hp_progress(f.player.color.lightened(0.1), Color(0, 0, 0, 0))
	holder.add_child(main)
	return {"main": main, "ghost": ghost, "text": text, "card": card}


func _hp_progress(fill_color: Color, back_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.max_value = MAX_HP
	bar.value = MAX_HP
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(7)
	fill.border_color = fill_color.lightened(0.35) # светлый блик сверху
	fill.border_width_top = 3
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = back_color
	back.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", back)
	return bar


func _set_hp_bar(bar: Dictionary, hp: int, alive: bool) -> void:
	var main: ProgressBar = bar["main"]
	var ghost: ProgressBar = bar["ghost"]
	(bar["text"] as Label).text = ("%d / %d" % [hp, MAX_HP]) if alive else "ВЫБЫЛ"
	create_tween().tween_property(main, "value", float(hp), 0.15)
	if hp < ghost.value:
		create_tween().tween_property(ghost, "value", float(hp), 0.5).set_delay(0.4)
	else:
		ghost.value = hp
	if not alive:
		(bar["card"] as Control).modulate = Color(0.55, 0.55, 0.55)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	return label
