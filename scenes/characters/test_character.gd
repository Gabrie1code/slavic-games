class_name PlayerCharacter
extends CharacterBody3D
## Персонаж игрока: единая модель из частей, окрашенная в цвет игрока, плюс одежда.
##
## Части модели (из tools/blender/character.py): Torso, Head, ArmL, ArmR, LegL, LegR.
## Анимация — кодом: ноги и руки качаются при ходьбе, правая рука поднимается
## и держит предметы, всё тело крутится при атаке.

const ACCELERATION := 40.0
## Прыжок: короткий и «тяжёлый» — гравитация персонажа сильнее стандартной.
const JUMP_VELOCITY := 7.0
const GRAVITY_SCALE := 2.2
## Сила, с которой персонаж толкает незакреплённые вещи (стулья, торшер).
const PUSH_FORCE := 0.5
## «Разгон»: копится, пока персонаж идёт быстрее RUN_UP_SPEED в одну сторону. Чтобы разбить
## или уронить вещь в лобби, нужен разгон (чем больше вещь, тем больше); подошёл аккуратно
## (с места, присев, медленно) — вещь цела. Бег (Shift) копит быстрее.
const RUN_UP_SPEED := 4.5
## Удар с разгоном по вещи, которую можно уронить: сила (на кг массы и м/с скорости).
const BUMP_FORCE := 0.35
## Поза сидя: насколько опустить модель и поднять ноги вперёд.
const SIT_DROP := 0.0
const SIT_LEGS := 1.45
## Вид от первого лица: скорость поворота стрелками/клавишами (рад/сек).
const FP_TURN_SPEED := 2.6
const TURN_SPEED := 12.0
const KNOCKBACK_DECAY := 18.0
## Приседание (как Shift в Minecraft): медленнее, ниже, корпус наклонён вперёд.
const CROUCH_SPEED := 0.4
## Присед: ноги выносятся вперёд на CROUCH_LEGS рад, и модель опускается ровно настолько,
## насколько при этом поднялись ступни (длина ноги LEG_LENGTH, пятка позади оси HEEL) —
## ступни остаются на полу (раньше модель опускалась на 0.2 м и ноги уходили в пол).
const CROUCH_LEGS := 0.75
const LEG_LENGTH := 0.54
const HEEL := 0.07
const CROUCH_LEAN := 0.45
## Прыжок «как в party-играх»: взлёт сразу, в момент толчка модель вытягивается, в полёте ноги
## поджаты и руки в стороны, на спуске ноги тянутся к земле, при приземлении — сжатие, пыль, звук.
const STRETCH := 0.2
const AIR_ARMS_RISE := 0.55
const AIR_ARMS_FALL := 0.95
## Максимальная скорость взлёта (прыжок 7, отбрасывание битой до ~7 — хватает с запасом).
const MAX_RISE_SPEED := 9.0
## Поворот правой руки: опущена / поднята вверх / вытянута в сторону.
## Во сколько раз шире по X/Z (и выше по Y) вещь этого слота — чтобы внешний слой был снаружи.
const LAYER_SCALE := {
	Cosmetics.Slot.HAT: Vector3(1.07, 1.04, 1.07),
	Cosmetics.Slot.JACKET: Vector3(1.035, 1.0, 1.035),
	Cosmetics.Slot.SHOES: Vector3(1.06, 1.0, 1.06),
}
## Слои надписей с именами (у каждого слота свой): своё имя не видно своей камере, а зеркало
## не показывает ни одно имя. Биты 7, 8, 9, 16 свободны в лобби.
const NAME_LAYERS: Array[int] = [1 << 7, 1 << 8, 1 << 9, 1 << 16]
const ARM_DOWN := 0.12
const ARM_UP := 2.75
const ARM_SIDE := 1.45
## Ходьба: частота шага и размах рук/ног.
const STEP_FREQUENCY := 2.4
const SWING := 0.65

var player: PlayerData
var spawn_position := Vector3.ZERO

## Настройки, которые меняют мини-игры.
var speed := 6.0
var input_enabled := true
var can_jump := true
## Прыжок нажат и ждёт следующего кадра физики. Лобби ставит false, если в этом кадре
## Пробел ушёл на действие (подобрать, включить, сесть…) — тогда персонаж не подпрыгнет.
var jump_pending := false
## Сколько ещё секунд прыжок запрещён: Пробел только что ушёл на действие. Нужно при высоком FPS:
## кадр физики может прийти уже после того, как подсказка пропала, — и «Пробел» стал бы прыжком.
var jump_lock := 0.0
var respawn_on_fall := true
var fall_limit := -10.0
## Наклон правой руки вперёд (>0) / назад (<0), когда рука занята (держит предмет).
var arm_pose_x := 0.0
## Сидит ли персонаж (на диване в лобби).
var sitting := false
## Вид от первого лица: движение относительно взгляда.
var first_person := false
## Насколько персонаж присел: 0 — стоит, 1 — сидит на корточках (плавно).
var crouch_amount := 0.0
var crouching := false
## Бег на Shift, пока кнопка зажата: +доля к скорости (в лобби 0.15). 0 — бега нет
## (в мини-играх свои правила, например спринт-способность в «Морожке»).
var run_bonus := 0.0
## От первого лица: true — A/D шагают вбок (поворот мышью/стиком), false — A/D поворачивают.
var fp_strafe := false
## Разгон в секундах (как будто шёл обычным шагом столько секунд): см. RUN_UP_SPEED.
var run_up := 0.0
## Наклон взгляда вверх/вниз (для камеры от первого лица).
var fp_pitch := 0.0
## Поворот головы влево/вправо относительно тела (свободный взгляд на Alt, FreeLook).
var head_yaw := 0.0
## Голова запрокинута (>0, пьёт из бутылки) и корпус наклонён вперёд (>0, тошнит) — доп. к позе.
var head_tilt := 0.0
var lean := 0.0
## Опьянение 0..1 (плавно): шатает модель и камеру, ведёт в сторону при ходьбе.
var drunk := 0.0
## Сколько ещё секунд пьян (потом плавно трезвеет); 0 — протрезветь (после рвоты).
var drunk_left := 0.0
## Сильно пьян: картинка расплывается и двоится (0..1, плавно) и сколько ещё секунд.
var blur := 0.0
var blur_left := 0.0

var _knockback := Vector3.ZERO
## Направление и скорость бега до столкновения (для разгона и толчка вещей).
var _run_dir := Vector2.ZERO
var _impact_speed := 0.0
## Когда последний раз толкнули вещь с разгоном: id вещи -> время (не толкать каждый кадр).
var _bumped: Dictionary = {}
## Прыжок: насколько персонаж в «позе полёта» (0..1), сколько уже в воздухе, сжатие/растяжение
## модели (>0 — вытянут, <0 — сплющен), стоял ли на земле в прошлом кадре.
var _air := 0.0
## Наклон головы вверх/вниз за взглядом (плавно догоняет fp_pitch).
var _head_pitch := 0.0
var _air_time := 0.0
var _squash := 0.0
var _was_on_floor := true
var _air_pose_on := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _arm_tween: Tween
var _right_arm_busy := false
var _walk_phase := 0.0
var _idle_time := 0.0
var _primary_material: StandardMaterial3D
## Слот одежды -> надетые куски (чтобы снять при смене).
var _worn: Dictionary = {}
## Слот -> id надетой вещи (для правила «платье занимает и штаны»).
var _worn_ids: Dictionary = {}
## Слой видимости модели (свою модель камера от первого лица не показывает).
var _render_layer := 1

@onready var visual: Node3D = $Visual
@onready var right_hand: Node3D = Node3D.new()
@onready var _model: Node3D = $Visual/Model
@onready var _name_label: Label3D = $NameLabel
@onready var _parts := {
	"Torso": $Visual/Model/Torso,
	"Head": $Visual/Model/Head,
	"ArmL": $Visual/Model/ArmL,
	"ArmR": $Visual/Model/ArmR,
	"LegL": $Visual/Model/LegL,
	"LegR": $Visual/Model/LegR,
}


## Вызывается сразу после создания персонажа, до добавления в сцену.
func setup(p: PlayerData, spawn: Vector3) -> void:
	player = p
	spawn_position = spawn
	position = spawn
	name = "Player%d" % p.slot


func _ready() -> void:
	# Разлетающиеся осколки и опрокинутые вещи — не «движущаяся платформа»: их скорость
	# персонажу не передаётся (карусель в «Морожке» по-прежнему везёт, пока на ней стоишь).
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	_primary_material = StandardMaterial3D.new()
	_primary_material.albedo_color = player.color
	_primary_material.roughness = 0.6
	_recolor(_model)

	# Точка «в руке» — на конце правой руки.
	right_hand.name = "Hand"
	right_hand.position = Vector3(0, -0.42, 0)
	_part("ArmR").add_child(right_hand)
	_part("ArmL").rotation.z = -ARM_DOWN
	_part("ArmR").rotation.z = ARM_DOWN
	# Голова и руки — внутри туловища: при наклоне (приседание) они наклоняются вместе с ним.
	for limb in ["Head", "ArmL", "ArmR"]:
		_part(limb).reparent(_part("Torso"), true)

	apply_outfit(player.outfit)
	_name_label.text = player.display_name
	_name_label.modulate = player.color.lightened(0.3)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * GRAVITY_SCALE * delta

	var move := Vector2.ZERO
	crouching = input_enabled and player.input != null and player.input.is_pressed("crouch") \
		and not sitting
	if input_enabled and player.input:
		move = player.input.get_move()
		if crouching:
			move *= CROUCH_SPEED # крадётся
		elif run_bonus > 0.0 and player.input.is_pressed("sprint"):
			move *= 1.0 + run_bonus # бежит
		# Прыжок отдельно от бега: на бегу (Shift) тоже можно прыгать. Присев — нельзя.
		# Прыжок — на следующем кадре физики: если в этом кадре Пробел ушёл на действие (подобрать,
		# включить, сесть…), лобби отменит прыжок (jump_pending = false), и персонаж не подпрыгнет.
		if jump_pending and is_on_floor():
			velocity.y = JUMP_VELOCITY
			_squash = 1.0 # толчок: вытянулся вверх (звук прыжка выключен по просьбе владельца)
		jump_lock = maxf(0.0, jump_lock - delta)
		jump_pending = not crouching and can_jump and jump_lock <= 0.0 \
			and player.input.is_just_pressed("confirm") \
			and is_on_floor()

	# Камера смотрит спереди, поэтому «вверх» на экране — это -Z в мире.
	var dir := Vector3(move.x, 0.0, move.y)
	if drunk > 0.01:
		dir = _drunk_steer(dir)
	if first_person:
		# От первого лица — относительно взгляда: basis.z смотрит назад, basis.x — вправо.
		if fp_strafe:
			dir = transform.basis.x * move.x + transform.basis.z * move.y
		else:
			rotation.y -= move.x * FP_TURN_SPEED * delta
			dir = transform.basis.z * move.y
	var target := dir * speed
	velocity.x = move_toward(velocity.x - _knockback.x, target.x, ACCELERATION * delta) + _knockback.x
	velocity.z = move_toward(velocity.z - _knockback.z, target.z, ACCELERATION * delta) + _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)

	if dir.length() > 0.1 and not first_person:
		var yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, yaw, TURN_SPEED * delta)

	_update_run_up(delta)
	var fall_speed := -velocity.y
	move_and_slide()
	_check_landing(delta, fall_speed)
	# Защита от «катапульты»: персонаж не взлетает быстрее MAX_RISE_SPEED, что бы его ни подбросило
	# (раньше удар по полке с хрусталём мог запустить персонажа под потолок и выше).
	velocity.y = minf(velocity.y, MAX_RISE_SPEED)
	_push_bodies()

	if respawn_on_fall and global_position.y < fall_limit:
		global_position = spawn_position
		velocity = Vector3.ZERO
		_knockback = Vector3.ZERO


## Анимация ходьбы и дыхания (только визуал, работает и без физики).
func _process(delta: float) -> void:
	_idle_time += delta
	var walk_speed := Vector2(velocity.x, velocity.z).length() if is_physics_processing() else 0.0
	var amount := clampf(walk_speed / 6.0, 0.0, 1.0)
	_walk_phase += delta * STEP_FREQUENCY * TAU * amount
	var swing := sin(_walk_phase) * SWING * amount
	# Приседание: плавно опускаемся, корпус наклоняется вперёд, голова смотрит прямо.
	crouch_amount = move_toward(crouch_amount, 1.0 if crouching else 0.0, delta * 6.0)
	# Ноги и руки качаются навстречу друг другу; в стойке — плавно возвращаются.
	var legs_back := 1.0 - minf(1.0, delta * 10.0)
	if sitting:
		_part("LegL").rotation.x = SIT_LEGS
		_part("LegR").rotation.x = SIT_LEGS
	else:
		# Присев, ноги чуть вынесены вперёд (crouch_legs); в стойке плавно возвращаются к нему.
		var crouch_legs := CROUCH_LEGS * crouch_amount
		swing *= 1.0 - 0.6 * crouch_amount # гуськом шаги меньше
		var settle := 1.0 - legs_back
		_part("LegL").rotation.x = swing + crouch_legs if amount > 0.05 \
			else lerpf(_part("LegL").rotation.x, crouch_legs, settle)
		_part("LegR").rotation.x = -swing + crouch_legs if amount > 0.05 \
			else lerpf(_part("LegR").rotation.x, crouch_legs, settle)
	_part("ArmL").rotation.x = -swing * 0.8
	if not _right_arm_busy:
		_part("ArmR").rotation.x = swing * 0.8
	else:
		_part("ArmR").rotation.x = arm_pose_x
	_part("Torso").rotation.x = -CROUCH_LEAN * crouch_amount - lean
	_update_drunk(delta)
	# Подпрыгивание при шаге и лёгкое «дыхание» в стойке.
	_model.position.y = SIT_DROP if sitting else absf(sin(_walk_phase)) * 0.06 * amount
	if crouch_amount > 0.0 and not sitting:
		var legs := minf(absf(_part("LegL").rotation.x), absf(_part("LegR").rotation.x))
		var rise := LEG_LENGTH * (1.0 - cos(legs)) - HEEL * sin(legs)
		_model.position.y -= maxf(0.0, rise) * crouch_amount
	# Голова смотрит туда же, куда игрок от первого лица (вверх/вниз) — видно другим и в зеркале.
	# Не до конца (70% наклона взгляда), иначе голова «ломается» на шее.
	_head_pitch = lerpf(_head_pitch, clampf(fp_pitch, -0.9, 0.9) * 0.7, minf(1.0, delta * 12.0))
	_part("Head").rotation.x = sin(_idle_time * 2.0) * 0.04 + CROUCH_LEAN * crouch_amount * 0.8 \
		+ _head_pitch + head_tilt
	# Свободный взгляд: голова поворачивается за камерой (не до конца — шея не ломается).
	_part("Head").rotation.y = clampf(head_yaw, -1.3, 1.3)
	_animate_jump(delta)


## Пьяный: всё тело покачивается из стороны в сторону, медленно «плывёт».
func _update_drunk(delta: float) -> void:
	drunk_left = maxf(0.0, drunk_left - delta)
	blur_left = maxf(0.0, blur_left - delta)
	blur = move_toward(blur, 1.0 if blur_left > 0.0 else 0.0, delta / 2.0)
	var sober := drunk_left <= 0.0 # трезвеет медленнее, чем пьянеет
	drunk = move_toward(drunk, 0.0 if sober else 1.0, delta / (4.0 if sober else 1.5))
	_model.rotation.z = sin(_idle_time * 1.3) * 0.13 * drunk
	_model.rotation.x = sin(_idle_time * 0.9 + 1.0) * 0.06 * drunk


## Пьяная походка: направление «гуляет», и даже стоя его слегка водит в сторону.
func _drunk_steer(dir: Vector3) -> Vector3:
	var wobble := sin(_idle_time * 1.7) * 0.6 + sin(_idle_time * 0.63) * 0.35
	var steered := dir.rotated(Vector3.UP, wobble * drunk)
	return steered + Vector3(sin(_idle_time * 0.8), 0.0, cos(_idle_time * 1.1)) * 0.18 * drunk


## Сесть: персонаж ставится в точку (под сиденьем) и поворачивается на yaw.
func sit_at(point: Vector3, yaw: float) -> void:
	sitting = true
	set_physics_process(false)
	velocity = Vector3.ZERO
	global_position = point
	rotation.y = yaw


## Встать с дивана: шаг вперёд и снова обычная физика.
func stand_up() -> void:
	if not sitting:
		return
	sitting = false
	global_position += -global_basis.z * 0.7 + Vector3.UP * 0.1
	set_physics_process(true)


## Приземлился после полёта: сплющиться (тем сильнее, чем быстрее падал), пыль и «тук».
func _check_landing(delta: float, fall_speed: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and _air_time > 0.12:
		var strength := clampf(fall_speed / 12.0, 0.2, 1.0)
		_squash = -(0.45 + 0.55 * strength)
		if fall_speed > 3.5 and _idle_time > 0.5: # не «тукать» всем сразу при появлении
			JumpFx.dust(self, strength) # звук приземления пока выключен (по просьбе владельца)
	_air_time = 0.0 if on_floor else _air_time + delta
	_was_on_floor = on_floor


## Поза прыжка поверх ходьбы: в воздухе ноги поджаты (на взлёте) или тянутся вниз (на спуске),
## руки разведены; модель вытягивается при толчке и сплющивается при приземлении.
func _animate_jump(delta: float) -> void:
	var airborne := is_physics_processing() and not sitting and not is_on_floor() \
		and _air_time > 0.06
	_air = move_toward(_air, 1.0 if airborne else 0.0, delta * (8.0 if airborne else 12.0))
	_squash = move_toward(_squash, 0.0, delta * 6.0)
	_model.scale = Vector3(1.0 - STRETCH * 0.5 * _squash, 1.0 + STRETCH * _squash,
		1.0 - STRETCH * 0.5 * _squash)
	if _air <= 0.0:
		if _air_pose_on: # поза закончилась — руки на место (один раз, чтобы не мешать другим позам)
			_air_pose_on = false
			_part("ArmL").rotation.z = -ARM_DOWN
			if not _right_arm_busy:
				_part("ArmR").rotation.z = ARM_DOWN
		return
	_air_pose_on = true
	# 1 — летит вверх, 0 — падает.
	var rise := clampf(0.5 + 0.5 * velocity.y / JUMP_VELOCITY, 0.0, 1.0)
	var leg_l := lerpf(-0.12, 0.85, rise)
	var leg_r := lerpf(0.12, 0.4, rise)
	_part("LegL").rotation.x = lerpf(_part("LegL").rotation.x, leg_l, _air)
	_part("LegR").rotation.x = lerpf(_part("LegR").rotation.x, leg_r, _air)
	var spread := lerpf(AIR_ARMS_FALL, AIR_ARMS_RISE, rise) * _air
	_part("ArmL").rotation.z = -(ARM_DOWN + spread)
	_part("ArmL").rotation.x = lerpf(_part("ArmL").rotation.x, -0.3, _air)
	if not _right_arm_busy:
		_part("ArmR").rotation.z = ARM_DOWN + spread
		_part("ArmR").rotation.x = lerpf(_part("ArmR").rotation.x, -0.3, _air)
	_model.position.y *= 1.0 - _air # в воздухе без «подпрыгивания» шага


## Разгон: идёт быстро и не сворачивает резко — копится; медленно — быстро пропадает.
func _update_run_up(delta: float) -> void:
	var flat := Vector2(velocity.x, velocity.z)
	_impact_speed = flat.length()
	if _impact_speed < RUN_UP_SPEED:
		run_up = maxf(0.0, run_up - delta * 4.0)
		return
	var dir := flat / _impact_speed
	if _run_dir.dot(dir) < 0.9: # резко свернул — разгон заново
		run_up = 0.0
	_run_dir = dir
	run_up += delta * pow(_impact_speed / 6.0, 2.0) # бегом (Shift) копится быстрее


## Толкнуть незакреплённые вещи, в которые упёрся персонаж. Мебель (Tippable) падает только
## от удара с разгоном (Tippable.run_up_needed), иначе персонаж просто упирается в неё.
func _push_bodies() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider() as RigidBody3D
		if body == null or body.freeze:
			continue
		var push := -hit.get_normal()
		push.y = 0.0
		var offset := hit.get_position() - body.global_position
		var tippable := body as Tippable
		if tippable == null:
			body.apply_impulse(push * PUSH_FORCE, offset)
		elif run_up >= tippable.run_up_needed \
				and now - float(_bumped.get(body.get_instance_id(), -10.0)) > 0.5:
			_bumped[body.get_instance_id()] = now
			body.apply_impulse(push * body.mass * _impact_speed * BUMP_FORCE, offset)


## Удар рукой: правая рука резко выбрасывается вперёд и возвращается.
## Возвращает false, если рука занята (держит предмет).
func punch() -> bool:
	if _right_arm_busy:
		return false
	set_arm_pose(0.15, 1.65, 0.07)
	_finish_punch()
	return true


func _finish_punch() -> void:
	await get_tree().create_timer(0.16).timeout
	if is_inside_tree():
		set_arm_angle(ARM_DOWN, 0.18)


## Отбросить персонажа (например, от удара битой).
func apply_knockback(impulse: Vector3) -> void:
	_knockback += Vector3(impulse.x, 0.0, impulse.z)
	velocity.y = maxf(velocity.y, impulse.y)


## Поднять или опустить правую руку.
func raise_hand(up: bool, time: float = 0.15) -> void:
	set_arm_angle(ARM_UP if up else ARM_DOWN, time)


## Повернуть правую руку на угол (радианы, ARM_DOWN = опущена).
func set_arm_angle(angle: float, time: float = 0.15) -> void:
	_right_arm_busy = absf(angle - ARM_DOWN) > 0.01
	arm_pose_x = 0.0
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween()
	_arm_tween.tween_property(_part("ArmR"), "rotation:z", angle, time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Поза правой руки: angle_z — в сторону (ARM_DOWN = опущена), angle_x — вперёд (>0) / назад.
func set_arm_pose(angle_z: float, angle_x: float, time: float = 0.15) -> void:
	_right_arm_busy = true
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween().set_parallel(true)
	_arm_tween.tween_property(_part("ArmR"), "rotation:z", angle_z, time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_arm_tween.tween_property(self, "arm_pose_x", angle_x, time)


## Взять предмет в правую руку (старый предмет удаляется). Возвращает сам предмет.
func hold_item(item: Node3D) -> Node3D:
	for child in right_hand.get_children():
		child.queue_free()
	if item:
		right_hand.add_child(item)
		_right_arm_busy = true
	return item


## Показать или спрятать имя над головой (в примерочной не нужно).
func show_name(visible_name: bool) -> void:
	_name_label.visible = visible_name


## Слой видимости надписи с именем (например, чтобы её не видел водящий в тумане).
func set_name_layer(layer: int) -> void:
	_name_label.layers = layer


## Перекрасить «основной» цвет (например, белый халат продавщицы).
func set_body_color(color: Color) -> void:
	_primary_material.albedo_color = color


## Перекрасить персонажа в новый цвет игрока (тело, «фирменная» одежда, имя).
func set_player_color(color: Color) -> void:
	_primary_material.albedo_color = color
	_name_label.modulate = color.lightened(0.3)


## Надеть наряд: словарь {Cosmetics.Slot: id вещи}. Пустые слоты — ничего.
func apply_outfit(outfit: Dictionary) -> void:
	for slot: int in Cosmetics.SLOT_NAMES:
		wear(slot, outfit.get(slot, ""))


## Надеть вещь в слот (пустой id — снять). Платье снимает штаны и наоборот (Cosmetics.covers).
func wear(slot: int, item_id: String) -> void:
	_take_off(slot)
	if item_id == "":
		item_id = Cosmetics.default_item(slot) # рот снять нельзя — надевается обычный
	if item_id == "" or not Cosmetics.ITEMS.has(item_id):
		return
	for covered: int in Cosmetics.covers(item_id):
		_take_off(covered)
	var worn_slots: Array = _worn_ids.keys()
	for other: int in worn_slots:
		if Cosmetics.covers(_worn_ids[other]).has(slot):
			_take_off(other)
	var item := Cosmetics.load_item(item_id).instantiate()
	var pieces: Array[Node] = []
	# Каждый кусок вещи переезжает внутрь своей части тела.
	for piece: Node in item.get_children():
		if not piece is Node3D or not _parts.has(String(piece.name)):
			continue
		var piece_3d := piece as Node3D
		item.remove_child(piece_3d)
		_part(String(piece.name)).add_child(piece_3d)
		piece_3d.transform = Transform3D.IDENTITY
		# Слои одежды: шапка шире головы (голова не торчит на бегу), верх поверх штанов,
		# обувь поверх штанин — внешний слой чуть шире по X/Z вокруг оси части тела.
		piece_3d.scale = LAYER_SCALE.get(slot, Vector3.ONE)
		_recolor(piece_3d)
		_apply_layer(piece_3d)
		pieces.append(piece_3d)
	item.queue_free()
	if Cosmetics.ITEMS[item_id].get("number", false):
		pieces.append(_shirt_number())
	_worn[slot] = pieces
	_worn_ids[slot] = item_id


func _take_off(slot: int) -> void:
	for piece: Node in _worn.get(slot, []):
		piece.queue_free()
	_worn.erase(slot)
	_worn_ids.erase(slot)


## Номер на спине футболки — номер игрока (1–4).
func _shirt_number() -> Label3D:
	var number := Label3D.new()
	number.text = str(player.slot + 1)
	number.font_size = 120
	number.outline_size = 16
	number.modulate = Color.WHITE
	number.outline_modulate = Color(0.1, 0.1, 0.12)
	number.pixel_size = 0.0022
	# Спина туловища: в координатах части Torso (сустав — таз).
	number.position = Vector3(0, 0.3, 0.215)
	_part("Torso").add_child(number)
	_apply_layer(number)
	return number


## Слой видимости всей модели персонажа (и надетой одежды).
func set_render_layer(layer: int) -> void:
	_render_layer = layer
	_apply_layer(self)
	_name_label.layers = name_layer(player.slot) # имя — на своём слое (см. NAME_LAYERS)


## Слой надписи с именем игрока в слоте slot.
static func name_layer(slot: int) -> int:
	return NAME_LAYERS[slot % NAME_LAYERS.size()]


## Все слои имён (зеркало их не рисует).
static func all_name_layers() -> int:
	var mask := 0
	for layer in NAME_LAYERS:
		mask |= layer
	return mask


## Смерть: персонаж краснеет, падает навзничь, на глазах крестики, потом плавно исчезает
## (прозрачность растёт) и прячется. Физика не выключается сразу — тело ещё может лететь.
func play_death(fade_delay: float = 0.9, fade_time: float = 1.0) -> void:
	input_enabled = false
	var meshes: Array[GeometryInstance3D] = []
	_collect_geometry(visual, meshes)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1.0, 0.1, 0.05, 0.55)
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mesh in meshes:
		mesh.material_overlay = red
	# Крестики вместо глаз: по две чёрные планки на каждый глаз.
	var cross_mat := StandardMaterial3D.new()
	cross_mat.albedo_color = Color(0.05, 0.02, 0.02)
	cross_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cross_mesh := BoxMesh.new()
	cross_mesh.size = Vector3(0.12, 0.028, 0.012)
	for x in [-0.11, 0.11]:
		for angle in [PI / 4, -PI / 4]:
			var bar := MeshInstance3D.new()
			bar.mesh = cross_mesh
			bar.material_override = cross_mat
			bar.position = Vector3(x, 0.32, -0.322)
			bar.rotation.z = angle
			attach_to_part("Head", bar)
			meshes.append(bar)
	create_tween().tween_property(visual, "rotation:x", PI / 2, 0.45) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# Исчезновение — все части сразу, после падения и паузы.
	var fade := create_tween().set_parallel(true)
	var start := 0.45 + fade_delay
	for mesh in meshes:
		fade.tween_property(mesh, "transparency", 1.0, fade_time).set_delay(start)
	fade.tween_property(_name_label, "modulate:a", 0.0, fade_time).set_delay(start)
	fade.chain().tween_callback(func() -> void:
		visible = false
		set_physics_process(false))


## Подкрасить всего персонажа поверх его цветов (например, синим во льду).
## Прозрачный цвет (alpha = 0) — убрать подкраску.
func set_tint(color: Color) -> void:
	var meshes: Array[GeometryInstance3D] = []
	_collect_geometry(visual, meshes)
	var overlay: StandardMaterial3D = null
	if color.a > 0.0:
		overlay = StandardMaterial3D.new()
		overlay.albedo_color = color
		overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mesh in meshes:
		mesh.material_overlay = overlay


func _collect_geometry(node: Node, out: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D:
		out.append(node as GeometryInstance3D)
	for child in node.get_children():
		_collect_geometry(child, out)


## Прикрепить предмет к части тела (Torso/Head/ArmL/ArmR/LegL/LegR), например трубку к уху.
## Предмет получает слой видимости персонажа (от первого лица своя трубка не мешает обзору).
func attach_to_part(part_name: String, node: Node3D) -> void:
	_part(part_name).add_child(node)
	_apply_layer(node)


func _apply_layer(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = _render_layer
	for child in node.get_children():
		_apply_layer(child)


## Часть тела по имени (Torso/Head/ArmL/ArmR/LegL/LegR) — для поз вне игры (пьедестал итогов).
func part(part_name: String) -> Node3D:
	return _part(part_name)


func _part(part_name: String) -> Node3D:
	return _parts[part_name] as Node3D


## Материал "Primary" на всех мешах внутри node заменяется цветом игрока.
func _recolor(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.mesh.get_surface_count():
			var surface_material := mesh_instance.mesh.surface_get_material(i)
			if surface_material and surface_material.resource_name.begins_with("Primary"):
				mesh_instance.set_surface_override_material(i, _primary_material)
	for child in node.get_children():
		_recolor(child)
