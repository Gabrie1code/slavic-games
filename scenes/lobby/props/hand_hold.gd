class_name HandHold
extends RefCounted
## Как держать вещь в руке (баллончик, губка, пульт) — одинаково для всех вещей.
## У персонажа: рука вынесена вперёд (set_arm_pose, 0.9 рад), вещь стоит в кулаке ровно
## вертикально (её +Y — вверх по миру, её −Z — вперёд). От первого лица: только сама вещь
## крупно справа внизу, без руки (так решил владелец проекта).

## Вверх и назад по миру — в осях вытянутой вперёд руки (поворот руки 0.9 рад).
const UP := Vector3(0.0, 0.62, -0.78)
const BACK := Vector3(0.0, 0.78, 0.62)
const HAND := Vector3(0.0, -0.44, 0.0)


## Поставить вещь в кулак персонажа (вещь уже прикреплена к руке ArmR).
## grip — где вещь сжата: столько метров от её точки (0,0,0) вверх по её оси.
static func place(item: Node3D, grip: float) -> void:
	item.basis = Basis(UP.cross(BACK), UP, BACK)
	item.position = HAND - UP * grip


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


## Вещь «в кадре» от первого лица — только сама вещь, без руки (как было раньше): крупно справа
## внизу. pos — где она у камеры, rot — её поворот (рад), size — во сколько раз крупнее.
## Возвращает корень (вещь внутри него).
static func make_view(item: Node3D, layer: int, pos: Vector3, rot: Vector3,
		size: float = 1.3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation = rot
	item.scale = Vector3.ONE * size
	root.add_child(item)
	_set_layers(root, layer)
	return root


static func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_layers(child, layer)


## «Рука поверх стен»: вещь в кадре (кулак, молоток, губка…) рисуется так, будто она у самых
## глаз, и не утопает в стене, когда подходишь вплотную. Для этого у каждого материала включается
## сжатие глубины к камере (z_clip_scale, есть в Godot 4.5+). Форма и размер на экране не
## меняются. Материалы копируются: у моделей из .glb они общие с вещами в мире.
## Подключено к camera.child_entered_tree — срабатывает для всего, что вешается на камеру.
static func on_top(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is MeshInstance3D:
		_on_top_mesh(node as MeshInstance3D)
	for child in node.get_children():
		on_top(child)


static func _on_top_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.material_override:
		mesh_instance.material_override = _on_top_material(mesh_instance.material_override)
		return
	if mesh_instance.mesh == null:
		return
	for i in mesh_instance.mesh.get_surface_count():
		var mat := mesh_instance.get_surface_override_material(i)
		if mat == null:
			mat = mesh_instance.mesh.surface_get_material(i)
		if mat:
			mesh_instance.set_surface_override_material(i, _on_top_material(mat))


static func _on_top_material(mat: Material) -> Material:
	if not mat is BaseMaterial3D:
		return mat
	var copy := mat.duplicate() as BaseMaterial3D
	if "use_z_clip_scale" in copy:
		copy.set("use_z_clip_scale", true)
		copy.set("z_clip_scale", 0.2) # в 5 раз ближе к глазам (стена ближе 0,3 м не бывает)
	else:
		# Запасной путь для старого Godot: рисовать без проверки глубины, поверх всего.
		copy.no_depth_test = true
		copy.render_priority = 10
	return copy
