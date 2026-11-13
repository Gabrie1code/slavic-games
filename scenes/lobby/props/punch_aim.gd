class_name PunchAim
extends RefCounted
## Какую вещь задевает удар (кулак, молоток): одна вещь, ближе всего к лучу взгляда
## (от первого лица — с наклоном камеры), в узком конусе cone градусов, не дальше reach.
## Вынесено из LobbyGadgets.


static func target(character: PlayerCharacter, camera: Camera3D, reach: float,
		cone: float) -> Node3D:
	var eye := character.global_position + Vector3.UP * 1.2
	var aim := -character.global_basis.z
	if camera:
		eye = camera.global_position
		aim = -camera.global_basis.z
	var best: Node3D = null
	var best_angle := deg_to_rad(cone)
	var candidates: Array[Node] = character.get_tree().get_nodes_in_group("breakable")
	candidates.append_array(character.get_tree().get_nodes_in_group("tippable"))
	for node in candidates:
		var item := node as Node3D
		if item is Breakable and not (item as Breakable).can_break():
			continue # разбита или за целым стеклом серванта
		# Точка вещи ближе всего к прицелу: у Tippable — по всей высоте (торшер бьётся и по
		# стойке, и по абажуру, и лёжа), у Breakable — чуть выше основания.
		var to := _aim_point(item, eye, aim) - eye
		var flat := Vector2(to.x, to.z).length()
		if flat > reach or to.length() < 0.05:
			continue
		var angle := aim.angle_to(to)
		if camera == null: # общий вид сверху: наклона камеры нет — только по полу
			angle = Vector2(aim.x, aim.z).angle_to(Vector2(to.x, to.z))
			angle = absf(angle) * 0.75
		if flat < 0.45:
			angle *= 0.5 # вплотную — попасть легче
		if angle < best_angle:
			best_angle = angle
			best = item
	return best



static func _aim_point(item: Node3D, eye: Vector3, aim: Vector3) -> Vector3:
	var base := item.global_position
	if not item is Tippable:
		return base + Vector3.UP * 0.15
	var up := item.global_basis.y.normalized() * (item as Tippable).height
	var best := base
	var best_angle := INF
	for k in 6:
		var p := base + up * (0.1 + 0.8 * k / 5.0)
		var a := aim.angle_to(p - eye)
		if a < best_angle:
			best_angle = a
			best = p
	return best
