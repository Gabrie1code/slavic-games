class_name RubgameTable
extends Node3D
## Стол рулетки в игровой комнате. Крутится сам по кругу, даже если у стола никого нет:
##   ставки (BET_TIME) → колесо крутится (SPIN_TIME) → результат (RESULT_TIME) → снова ставки.
## Весь круг — 20 секунд.
##
## Стол лежит вдоль локальной оси X: слева колесо, справа сукно с полем ставок.
## Игроки встают за дальний край стола (локальный −Z), камера стола смотрит с ближнего (+Z).
## Ставка — одна фишка; выигрыш платится фишками того же номинала (см. Roulette.payout).

signal phase_changed(phase: Phase)
## Колесо остановилось: выпало число result, выигрыши уже выплачены.
signal round_finished(result: int)

enum Phase { BETTING, SPINNING, RESULT }

const BET_TIME := 12.0
const SPIN_TIME := 5.0
const RESULT_TIME := 3.0

const DIR := "res://assets/models/rubgame/"
const FELT_TEXTURE := preload("res://assets/textures/rubgame/felt.png")
const WHEEL_TEXTURE := preload("res://assets/textures/rubgame/wheel.png")
## Сукно: центр и размер (локальные координаты стола).
const FELT_CENTER := Vector3(0.6, 0.918, 0.0)
const FELT_SIZE := Vector2(2.6, 1.06)
## Колесо: центр, высота диска, радиусы дорожки шарика.
const WHEEL_CENTER := Vector3(-1.33, 0.9, 0.0)
const WHEEL_DISC_Y := 0.125
const WHEEL_SIZE := 0.96
const BALL_TRACK_R := 0.46
const BALL_POCKET_R := 0.385
const BALL_RADIUS := 0.018
## Колесо всегда медленно вращается, при запуске — быстро.
const WHEEL_IDLE_SPEED := 0.6
const WHEEL_SPIN_SPEED := 3.0
## Сколько лишних оборотов делает шарик.
const BALL_TURNS := 6
const CHIP_SCALE := 0.4
const CHIP_HEIGHT := 0.025 * CHIP_SCALE
## Где встают игроки (за дальним краем стола) — по слоту игрока. Шаг 0.8 м: персонажи
## (радиус 0.4) стоят плечом к плечу и не залезают друг в друга.
const STAND_Z := -1.05
const STAND_X: Array[float] = [-1.2, -0.4, 0.4, 1.2]
## Толщина рамки «выбранная ставка» на сукне.
const FRAME_WIDTH := 0.018

var phase := Phase.BETTING
## Сколько секунд осталось до конца фазы.
var time_left := BET_TIME
## Последнее выпавшее число.
var result := 0
## Ставки этого круга: [{"player", "bet", "number", "value", "node"}].
var bets: Array[Dictionary] = []
## Итог круга по игрокам: PlayerData.id -> {"won": рублей выиграно, "lost": рублей проиграно}.
var last_round: Dictionary = {}

var _wheel: Node3D
var _wheel_angle := 0.0
var _ball: MeshInstance3D
var _ball_offset := 0.0 # «лишние» обороты шарика в начале запуска
var _chips_root: Node3D
var _board: Label3D
var _chip_scenes: Dictionary = {}
## Рамки выбранных ставок: PlayerData.id -> Node3D (4 планки цвета игрока).
var _selections: Dictionary = {}


func _ready() -> void:
	for value in PlayerManager.CHIP_VALUES:
		_chip_scenes[value] = load("res://assets/models/props/chip_%d.glb" % value)
	_build()
	result = Roulette.WHEEL.pick_random()
	_update_board()


func _process(delta: float) -> void:
	time_left -= delta
	var spin := 0.0 # 0..1 — насколько прошёл запуск
	if phase == Phase.SPINNING:
		spin = clampf(1.0 - time_left / SPIN_TIME, 0.0, 1.0)
	var speed := WHEEL_IDLE_SPEED
	if phase == Phase.SPINNING:
		speed += WHEEL_SPIN_SPEED * (1.0 - spin)
	_wheel_angle = wrapf(_wheel_angle + speed * delta, 0.0, TAU)
	_wheel.rotation.y = _wheel_angle
	_place_ball(spin)
	if time_left <= 0.0:
		_next_phase()
	_update_board()


## Поставить одну фишку номинала value. false — ставки закрыты или нет такой фишки.
func place_bet(p: PlayerData, bet: int, number: int, value: int) -> bool:
	if phase != Phase.BETTING or int(PlayerManager.chips(p).get(value, 0)) < 1:
		return false
	PlayerManager.add_chips(p, value, -1)
	var chip := (_chip_scenes[value] as PackedScene).instantiate() as Node3D
	chip.scale = Vector3.ONE * CHIP_SCALE
	_chips_root.add_child(chip)
	chip.position = _chip_position(p, bet, number)
	chip.rotation.y = randf() * TAU
	# Фишка падает на сукно сверху.
	var target_y := chip.position.y
	chip.position.y += 0.25
	create_tween().tween_property(chip, "position:y", target_y, 0.25) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	bets.append({"player": p, "bet": bet, "number": number, "value": value, "node": chip})
	return true


## Ставки игрока на этот круг, сгруппированные: [{"title", "value", "count"}].
func bets_of(p: PlayerData) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for b in bets:
		if b["player"] != p:
			continue
		var title := Roulette.bet_title(b["bet"], b["number"])
		var found := false
		for g in groups:
			if g["title"] == title and g["value"] == b["value"]:
				g["count"] += 1
				found = true
		if not found:
			groups.append({"title": title, "value": b["value"], "count": 1})
	return groups


## Точка, где встаёт игрок у стола (в мировых координатах), и куда он смотрит (поворот Y).
func stand_point(slot: int) -> Vector3:
	return to_global(Vector3(STAND_X[clampi(slot, 0, 3)], 0.0, STAND_Z))


func stand_yaw() -> float:
	return global_rotation.y + PI # лицом к столу (к +Z стола)


## Обвести на сукне клетку, которую игрок сейчас выбрал (во время приёма ставок).
func set_selection(p: PlayerData, bet: int, number: int) -> void:
	var frame: Node3D = _selections.get(p.id)
	if frame == null:
		frame = _make_frame(p.color)
		_selections[p.id] = frame
	var rect := Roulette.layout_rect(bet, number)
	# Каждый игрок — чуть внутрь клетки, чтобы рамки нескольких игроков не сливались.
	var inset := 0.004 * (p.slot % 4)
	var x0 := FELT_CENTER.x + (rect.position.x - 0.5) * FELT_SIZE.x + inset
	var x1 := FELT_CENTER.x + (rect.end.x - 0.5) * FELT_SIZE.x - inset
	var z0 := FELT_CENTER.z + (rect.position.y - 0.5) * FELT_SIZE.y + inset
	var z1 := FELT_CENTER.z + (rect.end.y - 0.5) * FELT_SIZE.y - inset
	var bars := frame.get_children()
	_place_bar(bars[0] as Node3D, Vector3((x0 + x1) / 2, 0, z0), Vector3(x1 - x0, 0, 0))
	_place_bar(bars[1] as Node3D, Vector3((x0 + x1) / 2, 0, z1), Vector3(x1 - x0, 0, 0))
	_place_bar(bars[2] as Node3D, Vector3(x0, 0, (z0 + z1) / 2), Vector3(0, 0, z1 - z0))
	_place_bar(bars[3] as Node3D, Vector3(x1, 0, (z0 + z1) / 2), Vector3(0, 0, z1 - z0))
	frame.visible = phase == Phase.BETTING


func clear_selection(p: PlayerData) -> void:
	if _selections.has(p.id):
		(_selections[p.id] as Node3D).queue_free()
		_selections.erase(p.id)


## Камера над сукном: смотрит сверху на поле ставок (по клику на стол).
func felt_camera_transform() -> Transform3D:
	var eye := to_global(FELT_CENTER + Vector3(0, 1.9, 0.25))
	return Transform3D.IDENTITY.translated(eye).looking_at(to_global(FELT_CENTER), Vector3.UP)


## Камера крупного плана: стоит перед столом, видно колесо, сукно и игроков за столом.
func camera_transform() -> Transform3D:
	var eye := to_global(Vector3(0.15, 2.55, 2.75))
	var target := to_global(Vector3(0.1, 0.95, -0.25))
	return Transform3D.IDENTITY.translated(eye).looking_at(target, Vector3.UP)


## Камера над колесом: смотрит почти прямо вниз (пока колесо крутится и показывает итог).
func wheel_camera_transform() -> Transform3D:
	var center := WHEEL_CENTER + Vector3(0, WHEEL_DISC_Y, 0)
	var eye := to_global(center + Vector3(0, 1.45, 0.35))
	return Transform3D.IDENTITY.translated(eye).looking_at(to_global(center), Vector3.UP)


# ---------------- Круг игры ----------------

func _next_phase() -> void:
	match phase:
		Phase.BETTING:
			phase = Phase.SPINNING
			time_left = SPIN_TIME
			var old_pocket := Roulette.pocket_angle(result)
			result = Roulette.WHEEL.pick_random()
			# Шарик стартует с того кармана, где лежал, и делает BALL_TURNS лишних оборотов.
			_ball_offset = wrapf(Roulette.pocket_angle(result) - old_pocket, 0.0, TAU) \
				+ BALL_TURNS * TAU
		Phase.SPINNING:
			phase = Phase.RESULT
			time_left = RESULT_TIME
			_pay_out()
			round_finished.emit(result)
		Phase.RESULT:
			phase = Phase.BETTING
			time_left = BET_TIME
			_clear_chips(false)
			bets.clear()
	phase_changed.emit(phase)


func _pay_out() -> void:
	last_round.clear()
	for b in bets:
		var p: PlayerData = b["player"]
		var value: int = b["value"]
		var times := Roulette.payout(b["bet"], b["number"], result)
		var stats: Dictionary = last_round.get(p.id, {"won": 0, "lost": 0})
		if times > 0:
			PlayerManager.add_chips(p, value, times)
			stats["won"] = int(stats["won"]) + value * (times - 1)
		else:
			stats["lost"] = int(stats["lost"]) + value
			b["lost"] = true
		last_round[p.id] = stats
	_clear_chips(true)


## Убрать фишки со стола: only_lost — только проигравшие (крупье сгребает).
func _clear_chips(only_lost: bool) -> void:
	for b in bets:
		if only_lost and not b.get("lost", false):
			continue
		# Сначала проверка, потом типизированная переменная: проигравшую фишку уже убрали
		# (queue_free), и запись удалённого объекта в «Node3D» роняла игру после проигрыша.
		if not is_instance_valid(b["node"]):
			continue
		var chip: Node3D = b["node"]
		var tween := create_tween()
		tween.tween_property(chip, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_IN)
		tween.tween_callback(chip.queue_free)


## Шарик: лежит в кармане выпавшего числа и крутится вместе с колесом;
## при запуске бежит по дорожке в обратную сторону, замедляется и падает в карман.
func _place_ball(spin: float) -> void:
	# Угол кармана: на текстуре — по часовой стрелке сверху, поворот вокруг Y — против.
	var angle := _wheel_angle - Roulette.pocket_angle(result)
	var radius := BALL_POCKET_R
	var bounce := 0.0
	if phase == Phase.SPINNING:
		var left := 1.0 - spin
		angle += _ball_offset * left * left
		radius = lerpf(BALL_TRACK_R, BALL_POCKET_R, smoothstep(0.55, 0.85, spin))
		if spin > 0.55 and spin < 0.92:
			bounce = absf(sin(spin * 70.0)) * 0.025 * (0.92 - spin) / 0.37
	var local := Vector3(0, 0, -radius).rotated(Vector3.UP, angle)
	_ball.position = WHEEL_CENTER + Vector3(0, WHEEL_DISC_Y + BALL_RADIUS + bounce, 0) + local


func _chip_position(p: PlayerData, bet: int, number: int) -> Vector3:
	var uv := Roulette.layout_uv(bet, number)
	var pos := FELT_CENTER + Vector3((uv.x - 0.5) * FELT_SIZE.x, 0.0, (uv.y - 0.5) * FELT_SIZE.y)
	# У каждого игрока своё место в клетке, фишки одного игрока — стопкой.
	var corner := Vector3(-0.025 if p.slot % 2 == 0 else 0.025, 0, -0.03 if p.slot < 2 else 0.03)
	var stacked := 0
	for b in bets:
		if b["player"] == p and b["bet"] == bet and b["number"] == number:
			stacked += 1
	return pos + corner + Vector3.UP * (0.002 + stacked * CHIP_HEIGHT)


func _make_frame(color: Color) -> Node3D:
	var frame := Node3D.new()
	frame.position.y = FELT_CENTER.y + 0.004
	var frame_mat := StandardMaterial3D.new()
	frame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	frame_mat.albedo_color = color.lightened(0.25)
	for i in 4:
		var bar := MeshInstance3D.new()
		bar.mesh = BoxMesh.new()
		bar.material_override = frame_mat
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		frame.add_child(bar)
	add_child(frame)
	# Рамка «дышит», чтобы её было видно на пёстром сукне.
	var pulse := frame.create_tween().set_loops()
	pulse.tween_property(frame_mat, "albedo_color:a", 0.45, 0.5)
	pulse.tween_property(frame_mat, "albedo_color:a", 1.0, 0.5)
	frame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return frame


func _place_bar(bar: Node3D, center: Vector3, length: Vector3) -> void:
	bar.position = center
	var box := (bar as MeshInstance3D).mesh as BoxMesh
	box.size = Vector3(maxf(absf(length.x), FRAME_WIDTH), 0.006, maxf(absf(length.z), FRAME_WIDTH))


func _update_board() -> void:
	match phase:
		Phase.BETTING:
			_board.text = "СТАВКИ: %d" % ceili(time_left)
			_board.modulate = Color("8fd694")
		Phase.SPINNING:
			_board.text = "КРУТИМ!"
			_board.modulate = Color("f6c343")
		Phase.RESULT:
			_board.text = "%d — %s" % [result, Roulette.color_name(result).to_upper()]
			_board.modulate = Color("ff6b5a") if Roulette.is_red(result) \
				else (Color("8fd694") if result == 0 else Color.WHITE)


# ---------------- Построение ----------------

func _build() -> void:
	var body := StaticBody3D.new()
	body.add_child(_model("roulette_table"))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.9, 1.0, 1.25)
	shape.shape = box
	shape.position.y = 0.5
	body.add_child(shape)
	add_child(body)

	var felt := MeshInstance3D.new()
	var felt_mesh := PlaneMesh.new()
	felt_mesh.size = FELT_SIZE
	felt.mesh = felt_mesh
	var felt_mat := StandardMaterial3D.new()
	felt_mat.albedo_texture = FELT_TEXTURE
	felt_mat.roughness = 1.0
	felt.material_override = felt_mat
	felt.position = FELT_CENTER
	add_child(felt)

	var bowl := _model("wheel_bowl")
	bowl.position = WHEEL_CENTER
	add_child(bowl)
	_wheel = Node3D.new()
	_wheel.position = WHEEL_CENTER + Vector3(0, WHEEL_DISC_Y, 0)
	add_child(_wheel)
	var disc := MeshInstance3D.new()
	var disc_mesh := PlaneMesh.new()
	disc_mesh.size = Vector2.ONE * WHEEL_SIZE
	disc.mesh = disc_mesh
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_texture = WHEEL_TEXTURE
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	disc_mat.roughness = 0.4
	disc.material_override = disc_mat
	_wheel.add_child(disc)
	_wheel.add_child(_model("wheel_turret"))

	_ball = MeshInstance3D.new()
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = BALL_RADIUS
	ball_mesh.height = BALL_RADIUS * 2.0
	_ball.mesh = ball_mesh
	var ball_mat := StandardMaterial3D.new()
	ball_mat.albedo_color = Color(0.97, 0.96, 0.92)
	ball_mat.roughness = 0.2
	_ball.material_override = ball_mat
	add_child(_ball)

	_chips_root = Node3D.new()
	add_child(_chips_root)

	# Табло над колесом: время до запуска / «КРУТИМ!» / выпавшее число.
	_board = Label3D.new()
	_board.font_size = 72
	_board.outline_size = 16
	_board.pixel_size = 0.004
	_board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_board.position = WHEEL_CENTER + Vector3(0, 1.0, 0)
	_board.layers = ZoneBadge.OVERHEAD_LAYER # у стола крупным планом табло не нужно
	add_child(_board)


func _model(model_name: String) -> Node3D:
	return (load(DIR + model_name + ".glb") as PackedScene).instantiate() as Node3D
