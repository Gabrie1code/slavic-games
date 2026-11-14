class_name CharacterRig
extends RefCounted
## Связка «части тела» ↔ «скелет» для персонажа с цельной гнущейся моделью (character_rigged.glb,
## из BaseCharacter.blend, см. tools/blender/basechar_convert.py).
##
## Весь код игры по-прежнему двигает 6 частей тела — Torso, Head, ArmL, ArmR, LegL, LegR
## (это невидимые узлы-«части» на месте суставов). Каждый кадр drive() ставит кости скелета так,
## чтобы модель повторяла эти части; локти и колени гнутся сами (по взмаху руки или ноги).
## Одежда и предметы крепятся к частям, как раньше: одежда сделана под прежнее тело и
## подгоняется трансформом FIT, предметы — через «гнёзда» (socket) с поправкой на размеры.

## Кость скелета для каждой части.
const BONES := {
	"Torso": "Hips", "Head": "Head", "ArmL": "UpperArm.L", "ArmR": "UpperArm.R",
	"LegL": "UpperLeg.L", "LegR": "UpperLeg.R",
}
const ELBOWS := {"ArmL": "LowerArm.L", "ArmR": "LowerArm.R"}
const KNEES := {"LegL": "LowerLeg.L", "LegR": "LowerLeg.R"}
## Руки в модели отведены от тела на этот угол (рад) — это «нулевая» поза кости.
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

var parts: Dictionary = {}
var sockets: Dictionary = {}

var _skeleton: Skeleton3D
## Часть -> {"bone", "offset" (Transform3D: из части в кость), "lower", "lower_rest"}.
var _links: Dictionary = {}


## Построить части на месте суставов модели model (внутри неё есть Skeleton3D).
## Возвращает false, если скелета нет (старая модель из частей).
func setup(model: Node3D) -> bool:
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return false
	_skeleton = found[0] as Skeleton3D
	var to_model := model.global_transform.affine_inverse() * _skeleton.global_transform
	var torso := _make_part(model, "Torso", to_model)
	for limb in ["Head", "ArmL", "ArmR"]:
		_make_part(torso, limb, to_model)
	for leg in ["LegL", "LegR"]:
		_make_part(model, leg, to_model)
	for part_name: String in parts:
		var socket := Node3D.new()
		socket.name = part_name + "Socket"
		(parts[part_name] as Node3D).add_child(socket)
		sockets[part_name] = socket
	var head_socket := sockets["Head"] as Node3D
	head_socket.scale = Vector3.ONE * HEAD_SOCKET_SCALE
	head_socket.position.y = HEAD_CENTER_NEW - HEAD_CENTER_OLD * HEAD_SOCKET_SCALE
	(sockets["ArmR"] as Node3D).position.y = -HAND_DROP
	(sockets["ArmL"] as Node3D).position.y = -HAND_DROP
	return true


## Трансформ подгонки куска одежды прежнего тела в части part_name (layer — «слой» одежды).
static func fit(part_name: String, layer: Vector3) -> Transform3D:
	var s: Vector3 = FIT_SCALE.get(part_name, Vector3.ONE) * layer
	var origin := Vector3.ZERO
	if part_name == "Head":
		origin.y = HEAD_CENTER_NEW - HEAD_CENTER_OLD * s.y
	return Transform3D(Basis.from_scale(s), origin)


## Поставить кости по частям. elbow_bend / knee_bend — сгиб локтей и коленей (рад) по частям.
func drive(elbow_bend: Dictionary, knee_bend: Dictionary) -> void:
	var skel_inv := _skeleton.global_transform.affine_inverse()
	for part_name in ["Torso", "Head", "ArmR", "ArmL", "LegR", "LegL"]:
		var link: Dictionary = _links[part_name]
		var part_xf := skel_inv * (parts[part_name] as Node3D).global_transform
		var bone_xf: Transform3D = part_xf * (link["offset"] as Transform3D)
		_skeleton.set_bone_global_pose(int(link["bone"]), bone_xf)
		var lower := int(link.get("lower", -1))
		if lower < 0:
			continue
		var bend := float(elbow_bend.get(part_name, knee_bend.get(part_name, 0.0)))
		var lower_xf: Transform3D = bone_xf * (link["lower_rest"] as Transform3D)
		var axis := part_xf.basis.x.normalized()
		lower_xf.basis = Basis(axis, bend) * lower_xf.basis
		_skeleton.set_bone_global_pose(lower, lower_xf)


func _make_part(parent: Node3D, part_name: String, to_model: Transform3D) -> Node3D:
	var bone := _find_bone(String(BONES[part_name]))
	var rest := _skeleton.get_bone_global_rest(bone)
	var joint_model := to_model * rest.origin
	var part := Node3D.new()
	part.name = part_name
	parent.add_child(part)
	# Голова и руки — внутри корпуса (наклоняются вместе с ним): их место — от сустава корпуса.
	part.position = joint_model - parent.position if parent.name == "Torso" else joint_model
	# «Нулевая» поза части там, где стоит кость в модели (руки чуть отведены).
	var bind_rot := 0.0
	if part_name == "ArmR":
		bind_rot = ARM_BIND
	elif part_name == "ArmL":
		bind_rot = -ARM_BIND
	var bind_model := Transform3D(Basis(Vector3.BACK, bind_rot), joint_model)
	var bind_skel := to_model.affine_inverse() * bind_model
	var link := {"bone": bone, "offset": bind_skel.affine_inverse() * rest}
	var lower_name := String(ELBOWS.get(part_name, KNEES.get(part_name, "")))
	if lower_name != "":
		var lower := _find_bone(lower_name)
		link["lower"] = lower
		link["lower_rest"] = rest.affine_inverse() * _skeleton.get_bone_global_rest(lower)
	_links[part_name] = link
	parts[part_name] = part
	return part


## Кость по имени (импорт мог заменить точку в имени на «_»).
func _find_bone(bone_name: String) -> int:
	var idx := _skeleton.find_bone(bone_name)
	if idx < 0:
		idx = _skeleton.find_bone(bone_name.replace(".", "_"))
	return idx
