class_name HandHold
extends RefCounted
## Как держать вещь в руке (баллончик, губка, пульт) — одинаково для всех вещей.
## У персонажа: рука вынесена вперёд (set_arm_pose, 0.9 рад), вещь стоит в кулаке ровно
## вертикально (её +Y — вверх по миру, её −Z — вперёд). От первого лица: свой кулак цвета игрока
## справа внизу, вещь сжата в нём (раньше вещь висела у камеры огромной и без руки).

## Вверх и назад по миру — в осях вытянутой вперёд руки (поворот руки 0.9 рад).
const UP := Vector3(0.0, 0.62, -0.78)
const BACK := Vector3(0.0, 0.78, 0.62)
const HAND := Vector3(0.0, -0.44, 0.0)
## Кулак «в кадре» (в осях камеры от первого лица).
const VIEW_POS := Vector3(0.3, -0.33, -0.62)


## Поставить вещь в кулак персонажа (вещь уже прикреплена к руке ArmR).
## grip — где вещь сжата: столько метров от её точки (0,0,0) вверх по её оси.
static func place(item: Node3D, grip: float) -> void:
	item.basis = Basis(UP.cross(BACK), UP, BACK)
	item.position = HAND - UP * grip


## Вещь «в кадре»: кулак цвета игрока сжимает вещь. Возвращает корень (кулак + вещь);
## tilt — небольшой наклон вещи влево (рад), чтобы смотрелась живее.
## Каждый кадр, пока вещь в руке: держать её ровно по миру — вверх (с наклоном вперёд tilt рад)
## по повороту персонажа, в кулаке. Так поза не зависит от того, как сейчас повёрнута рука
## (раньше вещь в зеркале торчала вбок / лежала горизонтально).
## forward — вынести вещь вперёд из кулака на столько метров (губка: иначе прячется в кисти).
static func follow(item: Node3D, grip: float, tilt: float = 0.0, forward: float = 0.0) -> void:
	var arm := item.get_parent() as Node3D
	var character := _character_of(item)
	if arm == null or character == null:
		return
	var right := character.global_basis.x.normalized()
	var fwd := -character.global_basis.z.normalized()
	var up := (Vector3.UP * cos(tilt) + fwd * sin(tilt)).normalized()
	var back := right.cross(up).normalized()
	var hand := arm.to_global(HAND)
	item.global_transform = Transform3D(Basis(up.cross(back), up, back),
		hand - up * grip + fwd * forward)


static func _character_of(node: Node) -> PlayerCharacter:
	var current := node.get_parent()
	while current and not current is PlayerCharacter:
		current = current.get_parent()
	return current as PlayerCharacter


static func make_view(color: Color, item: Node3D, grip: float, layer: int,
		tilt: float = 0.15) -> Node3D:
	var root := Node3D.new()
	root.position = VIEW_POS
	var fist := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.11
	mesh.radial_segments = 8
	mesh.rings = 4
	fist.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	fist.material_override = mat
	root.add_child(fist)
	item.rotation = Vector3(0.0, 0.0, tilt)
	item.position = -item.basis.y * grip
	root.add_child(item)
	_set_layers(root, layer)
	return root


static func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_layers(child, layer)
