class_name CharacterRig
extends RefCounted
## Скелет персонажа с цельной гнущейся моделью (character_rigged.glb из BaseCharacter.blend с нашими
## глазами и ступнями, см. tools/blender/basechar_convert.py) и его готовые анимации.
##
## Два слоя движения:
## 1. Анимация модели (Idle, Walk, Run, Jump, Death…) — AnimationPlayer, его ведёт play() / hold().
## 2. Позы от кода — 6 невидимых «частей» (Torso, Head, ArmL, ArmR, LegL, LegR), которые игра
##    крутит, как раньше. Корпус и голова добавляются к анимации (наклон, взгляд), а руки и ноги
##    смешиваются с ней по весу weights (0 — только анимация, 1 — только код: предмет в руке,
##    сидя, присед).
## Одежда и предметы висят на «рамках» (frames) — они повторяют итоговую позу кости, поэтому
## шапка, куртка и трубка у уха двигаются вместе с анимацией.

## Кость скелета для каждой части.
const BONES := {
	"Torso": "Hips", "Head": "Head", "ArmL": "UpperArm.L", "ArmR": "UpperArm.R",
	"LegL": "UpperLeg.L", "LegR": "UpperLeg.R",
}
const ELBOWS := {"ArmL": "LowerArm.L", "ArmR": "LowerArm.R"}
const KNEES := {"LegL": "LowerLeg.L", "LegR": "LowerLeg.R"}
## Ступни — отдельные кости (в анимациях это «ручки» IK); от кода ставятся вслед за голенью.
const FEET := {"LegL": "Foot.L", "LegR": "Foot.R"}
const ORDER: Array[String] = ["Torso", "Head", "ArmR", "ArmL", "LegR", "LegL"]
## Повторяются по кругу.
const LOOPS: Array[String] = [
	"Idle", "Walk", "Run", "Walk_Carry", "Run_Carry", "Crouch", "CrouchWalk",
]
## Плавный переход между анимациями, сек.
const BLEND := 0.18
## Рука от кода «по умолчанию» отведена от тела на этот угол (рад); в модели руки — Т-поза.
const ARM_BIND := 0.15
## Подгонка одежды прежнего тела под новое (в координатах части): масштаб и сдвиг.
## Голова: центр был на 0.28 над суставом шеи, стал на 0.225; голова чуть меньше.
## Корпус уже и тоньше; руки тоньше и длиннее; ноги тоньше.
const FIT_SCALE := {
	"Torso": Vector3(0.62, 1.0, 0.6), "Head": Vector3(0.85, 0.96, 0.9),
	"ArmL": Vector3(0.8, 1.39, 0.8), "ArmR": Vector3(0.8, 1.39, 0.8),
	"LegL": Vector3(0.78, 0.94, 0.78), "LegR": Vector3(0.78, 0.94, 0.78),
}
const HEAD_CENTER_OLD := 0.28
const HEAD_CENTER_NEW := 0.225
## Гнёзда для предметов: голова — общий масштаб (трубка у уха, струя у рта), правая рука —
## кисть ниже (рука длиннее): прежняя точка «в руке» −0.42 → −0.58.
const HEAD_SOCKET_SCALE := 0.88
const HAND_DROP := 0.16
## «Точка в руке» в рамке кисти (как у прежней прямой руки: гнездо −HAND_DROP, кисть ещё −0.42).
const HAND_POINT := Vector3(0, -0.42 - 0.16, 0)
## Обычное расстояние плечо — кулак, когда рука держит предмет (м): локоть заметно согнут.
const DEFAULT_REACH := 0.4

## Управляющие узлы-части (их крутит код игры).
var parts: Dictionary = {}
## Узлы, повторяющие итоговую позу кости, — на них одежда и предметы.
var frames: Dictionary = {}
## Гнёзда для предметов (внутри рамок; у рук — в рамке предплечья, предмет идёт за кистью).
var sockets: Dictionary = {}
## Рамки кистей (ArmL / ArmR): в них гнёзда для предметов — предмет всегда в кулаке.
var hands: Dictionary = {}
## Насколько далеко от плеча кисть, когда рукой управляет код (м); короче руки — локоть согнут.
var arm_reach: Dictionary = {"ArmR": DEFAULT_REACH, "ArmL": DEFAULT_REACH}
## Точка, куда тянется кулак (в координатах модели персонажа), — вместо направления части;
## Vector3.INF — нет точки (телефон у уха, бутылка у рта).
var arm_target: Dictionary = {"ArmR": Vector3.INF, "ArmL": Vector3.INF}
## Вес позы от кода для рук и ног (0 — анимация, 1 — код).
var weights: Dictionary = {"ArmL": 0.0, "ArmR": 0.0, "LegL": 0.0, "LegR": 0.0}
## Гасить подъём тела из анимации (прыжок: высоту даёт физика).
var lock_root := false

var _skeleton: Skeleton3D
var _model_node: Node3D
var _anim: AnimationPlayer
var _to_model: Transform3D
var _root_bone := -1
var _root_rest_y := 0.0
var _root_shifted := false
## После прыжка подъём ещё гасится, пока идёт плавный переход из Jump (иначе тело подскакивает).
var _unlock_left := 0.0
var _current := ""
## Часть -> {"bone", "offset", "bind_local", "lower", "lower_rest", "foot", "foot_rest"}.
var _links: Dictionary = {}


## Построить части на месте суставов модели model (внутри неё есть Skeleton3D).
## Возвращает false, если скелета нет (старая модель из частей).
func setup(model: Node3D) -> bool:
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return false
	_skeleton = found[0] as Skeleton3D
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_anim = players[0] as AnimationPlayer
		# Анимацию двигаем сами в update(): сначала она, потом позы от кода поверх.
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for anim_name in LOOPS:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_model_node = model
	_to_model = model.global_transform.affine_inverse() * _skeleton.global_transform
	# Корень тела — родитель таза (кость «Body»; при импорте её могут переименовать в «Body_2»,
	# потому что так же называется сетка модели).
	_root_bone = _skeleton.get_bone_parent(_find_bone("Hips"))
	if _root_bone >= 0:
		_root_rest_y = _skeleton.get_bone_global_rest(_root_bone).origin.y
	var torso := _make_part(model, model, "Torso")
	for limb in ["Head", "ArmL", "ArmR"]:
		_make_part(model, torso, limb)
	for leg in ["LegL", "LegR"]:
		_make_part(model, model, leg)
	for part_name: String in frames:
		var socket := Node3D.new()
		socket.name = part_name + "Socket"
		(hands.get(part_name, frames[part_name]) as Node3D).add_child(socket)
		sockets[part_name] = socket
	var head_socket := sockets["Head"] as Node3D
	head_socket.scale = Vector3.ONE * HEAD_SOCKET_SCALE
	head_socket.position.y = HEAD_CENTER_NEW - HEAD_CENTER_OLD * HEAD_SOCKET_SCALE
	# Гнёзда кистей: «точка в руке» прежнего тела (−0.42 от гнезда) попадает в кулак.
	for arm in ["ArmR", "ArmL"]:
		(sockets[arm] as Node3D).position.y = -HAND_DROP
	if _anim:
		play("Idle", 1.0, 0.0)
	return true


## Есть ли у модели готовые анимации.
func animated() -> bool:
	return _anim != null


## Играть анимацию anim_name (если уже играет — только меняется скорость).
func play(anim_name: String, speed: float = 1.0, blend: float = BLEND) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	_anim.speed_scale = speed
	if _current != anim_name:
		if _current == "Jump":
			_unlock_left = blend
		_current = anim_name
		_anim.play(anim_name, blend)


## Разовое действие (удар): анимация с момента from_time, заново даже если уже играет.
## Возвращает, сколько секунд она будет идти (0 — такой анимации нет).
func play_action(anim_name: String, speed: float, from_time: float = 0.0) -> float:
	if _anim == null or not _anim.has_animation(anim_name):
		return 0.0
	_current = anim_name
	_anim.speed_scale = speed
	_anim.play(anim_name, 0.06)
	_anim.seek(from_time, false)
	return maxf(0.0, _anim.get_animation(anim_name).length - from_time) / speed


## Застыть на кадре анимации (время в секундах), например поза прыжка по скорости взлёта.
func hold(anim_name: String, time: float) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	# Скорость не ноль: иначе не идёт и плавный переход от прошлой анимации (поза «застревает»).
	# Кадр всё равно ставится каждый раз заново, сдвиг за кадр — доли миллисекунды.
	play(anim_name, 1.0)
	_anim.seek(time, false)


## Трансформ подгонки куска одежды прежнего тела в части part_name (layer — «слой» одежды).
static func fit(part_name: String, layer: Vector3) -> Transform3D:
	var s: Vector3 = FIT_SCALE.get(part_name, Vector3.ONE) * layer
	var origin := Vector3.ZERO
	if part_name == "Head":
		origin.y = HEAD_CENTER_NEW - HEAD_CENTER_OLD * s.y
	return Transform3D(Basis.from_scale(s), origin)


## Кадр: анимация, поверх неё позы частей, затем рамки одежды — по итоговым костям.
## knee_bend — сгиб коленей от кода (рад) по частям; руки от кода гнутся сами (IK, arm_reach).
func update(delta: float, knee_bend: Dictionary) -> void:
	if _anim:
		_anim.advance(delta)
	_unlock_left = maxf(0.0, _unlock_left - delta)
	_lock_root()
	var skel_inv := _skeleton.global_transform.affine_inverse()
	for part_name in ORDER:
		var link: Dictionary = _links[part_name]
		var bone := int(link["bone"])
		var offset: Transform3D = link["offset"]
		var part := parts[part_name] as Node3D
		var anim_xf := _skeleton.get_bone_global_pose(bone)
		var w := float(weights.get(part_name, -1.0))
		var final_xf: Transform3D
		var proc_xf := Transform3D()
		if w < 0.0:
			# Корпус и голова: поворот части (наклон, взгляд) добавляется к анимации.
			var turn: Transform3D = (link["bind_local"] as Transform3D).affine_inverse() * part.transform
			final_xf = anim_xf * (offset.affine_inverse() * turn * offset)
		else:
			proc_xf = skel_inv * part.global_transform * offset
			final_xf = anim_xf.interpolate_with(proc_xf, w) if w > 0.0 else anim_xf
			if hands.has(part_name):
				# Плечо остаётся там, где оно в анимации (присел, наклонился), — рука не отрывается.
				final_xf.origin = anim_xf.origin
		_skeleton.set_bone_global_pose(bone, final_xf)
		(frames[part_name] as Node3D).transform = _to_model * final_xf * offset.affine_inverse()
		var lower := int(link.get("lower", -1))
		if hands.has(part_name):
			if w > 0.0:
				_reach_arm(part_name, link, part, w, skel_inv)
			_place_hand(part_name, link, part, w)
		elif lower >= 0 and w > 0.0:
			_pose_lower(link, part, proc_xf, w, skel_inv, float(knee_bend.get(part_name, 0.0)))


## Колено (и ступня) от кода — смешиваются с анимацией по весу w.
func _pose_lower(link: Dictionary, part: Node3D, proc_xf: Transform3D, w: float,
		skel_inv: Transform3D, bend: float) -> void:
	var axis := (skel_inv.basis * part.global_basis * Vector3.RIGHT).normalized()
	var lower := int(link["lower"])
	var lower_xf: Transform3D = proc_xf * (link["lower_rest"] as Transform3D)
	lower_xf.basis = Basis(axis, bend) * lower_xf.basis
	_skeleton.set_bone_global_pose(lower,
		_skeleton.get_bone_global_pose(lower).interpolate_with(lower_xf, w))
	var foot := int(link.get("foot", -1))
	if foot >= 0:
		var foot_xf: Transform3D = lower_xf * (link["foot_rest"] as Transform3D)
		_skeleton.set_bone_global_pose(foot,
			_skeleton.get_bone_global_pose(foot).interpolate_with(foot_xf, w))


## Рука от кода — через кисть (IK из двух костей): часть задаёт направление, кисть ставится на
## расстоянии reach от плеча по этому направлению, а плечо и предплечье сгибаются в локте, чтобы
## до неё дотянуться. Локоть смотрит вниз-наружу-назад, как у человека.
func _reach_arm(part_name: String, link: Dictionary, part: Node3D, w: float,
		skel_inv: Transform3D) -> void:
	var bone := int(link["bone"])
	var lower := int(link["lower"])
	var side := 1.0 if part_name == "ArmR" else -1.0
	var reach := float(arm_reach.get(part_name, DEFAULT_REACH))
	var aim: Vector3 = arm_target.get(part_name, Vector3.INF)
	# Цель кулака — от настоящего плеча (в анимации тело могло присесть и наклониться), а не от
	# плеча стоящего персонажа: сдвиг «плечо → цель» тот же, что у стоящего.
	var rest_shoulder := skel_inv * part.global_position
	var goal := skel_inv * (part.global_transform * Vector3(0, -reach, 0))
	if aim.is_finite():
		goal = skel_inv * (_model_node.global_transform * aim)
	var pole := skel_inv.basis * (_model_basis() * Vector3(side, -0.7, 0.45))
	var upper_xf := _skeleton.get_bone_global_pose(bone)
	var shoulder := upper_xf.origin
	var target := shoulder + (goal - rest_shoulder)
	var a := float(link["upper_skel"])
	var b := float(link["fore_skel"])
	var to_t := target - shoulder
	var d := clampf(to_t.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir := to_t.normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var bend_dir := (pole - dir * pole.dot(dir)).normalized()
	var elbow := shoulder + (dir * cos_a + bend_dir * sqrt(1.0 - cos_a * cos_a)) * a
	var hand := shoulder + dir * d
	# Кости поворачиваем так, чтобы их ось (Y) смотрела на локоть / на кисть; крутка — как у части.
	var proc_xf := skel_inv * part.global_transform * (link["offset"] as Transform3D)
	var up_basis := _aim(proc_xf.basis, elbow - shoulder)
	var ik_upper := Transform3D(up_basis, shoulder)
	_skeleton.set_bone_global_pose(bone, upper_xf.interpolate_with(ik_upper, w))
	(frames[part_name] as Node3D).transform = _to_model * _skeleton.get_bone_global_pose(bone) \
		* (link["offset"] as Transform3D).affine_inverse()
	var fore := ik_upper * (link["lower_rest"] as Transform3D)
	fore = Transform3D(_aim(fore.basis, hand - elbow), elbow)
	_skeleton.set_bone_global_pose(lower,
		_skeleton.get_bone_global_pose(lower).interpolate_with(fore, w))


## Рамка кисти: ориентация — как у части (предметы стоят в кулаке так же, как раньше), а точка
## «в руке» — там, где сейчас кулак (от кода — цель IK, в анимации — кулак анимации).
func _place_hand(part_name: String, link: Dictionary, part: Node3D, w: float) -> void:
	var fist := int(link["fist"])
	var fist_xf := _skeleton.get_bone_global_pose(fist)
	var fist_model := _to_model * (fist_xf.origin + fist_xf.basis.y * float(link["fist_half"]))
	var model_inv := _model_node.global_transform.affine_inverse()
	var arm_basis := (frames[part_name] as Node3D).transform.basis
	var part_basis := (model_inv * part.global_transform).basis
	var basis := part_basis if w > 0.5 else arm_basis
	var hand := hands[part_name] as Node3D
	var b := basis.orthonormalized()
	hand.transform = Transform3D(b, fist_model - b * HAND_POINT)


func _model_basis() -> Basis:
	return _model_node.global_basis.orthonormalized()


## Повернуть basis так, чтобы его ось Y смотрела вдоль along (кратчайшим поворотом).
static func _aim(basis: Basis, along: Vector3) -> Basis:
	var y := basis.y.normalized()
	var to := along.normalized()
	if y.dot(to) > 0.99999:
		return basis
	return Basis(Quaternion(y, to)) * basis


## Прыжок делает физика: подъём корня тела из анимации убираем (вместе со ступнями) — сдвигом
## самой верхней кости; без прыжка она возвращается на место.
func _lock_root() -> void:
	if _root_bone < 0:
		return
	var top := _skeleton.get_bone_parent(_root_bone)
	if top < 0:
		return
	var top_rest := _skeleton.get_bone_rest(top).origin
	if not lock_root and _unlock_left <= 0.0:
		if _root_shifted:
			_skeleton.set_bone_pose_position(top, top_rest)
			_root_shifted = false
		return
	_skeleton.set_bone_pose_position(top, top_rest)
	var rise := _skeleton.get_bone_global_pose(_root_bone).origin.y - _root_rest_y
	_skeleton.set_bone_pose_position(top, top_rest - Vector3(0, rise, 0))
	_root_shifted = true


func _make_part(model: Node3D, parent: Node3D, part_name: String) -> Node3D:
	var bone := _find_bone(String(BONES[part_name]))
	var rest := _skeleton.get_bone_global_rest(bone)
	var joint_model := _to_model * rest.origin
	var part := Node3D.new()
	part.name = part_name
	parent.add_child(part)
	# Голова и руки — внутри корпуса (наклоняются вместе с ним): их место — от сустава корпуса.
	part.position = joint_model - parent.position if parent != model else joint_model
	# «Нулевая» поза части: руки опущены вдоль тела (чуть отведены), остальное — как в модели.
	var bind_rot := 0.0
	if part_name == "ArmR":
		bind_rot = ARM_BIND
	elif part_name == "ArmL":
		bind_rot = -ARM_BIND
	var bind_model := Transform3D(Basis(Vector3.BACK, bind_rot), joint_model)
	var rest_model := _to_model * rest
	var posed_model := rest_model
	if part_name.begins_with("Arm"):
		# В модели руки разведены (Т-поза): поворачиваем кость вокруг плеча вниз, к позе части.
		var along := (rest_model.basis * Vector3.UP).normalized()
		var down := Basis(Vector3.BACK, bind_rot) * Vector3.DOWN
		var turn := Basis(Quaternion(along, down))
		posed_model = Transform3D(turn, joint_model - turn * joint_model) * rest_model
	var bind_skel := _to_model.affine_inverse() * bind_model
	var posed_skel := _to_model.affine_inverse() * posed_model
	var link := {
		"bone": bone, "offset": bind_skel.affine_inverse() * posed_skel, "bind_local": part.transform,
	}
	var lower_name := String(ELBOWS.get(part_name, KNEES.get(part_name, "")))
	if lower_name != "":
		var lower := _find_bone(lower_name)
		var lower_rest := _skeleton.get_bone_global_rest(lower)
		link["lower"] = lower
		link["lower_rest"] = rest.affine_inverse() * lower_rest
		if part_name.begins_with("Arm"):
			# Длины для IK (в единицах скелета): плечо и предплечье до середины кулака.
			var fist := _find_bone("Fist." + part_name.substr(3))
			var fist_rest := _skeleton.get_bone_global_rest(fist)
			var fist_len := 0.15 / _to_model.basis.get_scale().x
			link["fist"] = fist
			link["fist_half"] = fist_len * 0.5
			link["upper_skel"] = (lower_rest.origin - rest.origin).length()
			link["fore_skel"] = (fist_rest.origin - lower_rest.origin).length() + fist_len * 0.5
			var hand := Node3D.new()
			hand.name = part_name + "Hand"
			model.add_child(hand)
			hand.transform = bind_model
			hands[part_name] = hand
		var foot := _find_bone(String(FEET.get(part_name, "")))
		if foot >= 0:
			link["foot"] = foot
			link["foot_rest"] = lower_rest.affine_inverse() * _skeleton.get_bone_global_rest(foot)
	_links[part_name] = link
	parts[part_name] = part
	# Рамка для одежды и предметов: в модели, позу задаёт update().
	var frame := Node3D.new()
	frame.name = part_name + "Frame"
	model.add_child(frame)
	frame.transform = bind_model
	frames[part_name] = frame
	return part


## Кость по имени (импорт мог заменить точку в имени на «_»).
func _find_bone(bone_name: String) -> int:
	if bone_name == "":
		return -1
	var idx := _skeleton.find_bone(bone_name)
	if idx < 0:
		idx = _skeleton.find_bone(bone_name.replace(".", "_"))
	return idx
