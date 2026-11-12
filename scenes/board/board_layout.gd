class_name BoardLayout
extends RefCounted
## Строит тестовую доску кодом: кольцо из 26 клеток и короткая срезка через центр.
##
## Настоящие доски потом будем расставлять в редакторе Godot.
##
## Ход идёт по часовой стрелке от СТАРТА (левый нижний угол).
## На клетке 4 (низ, середина) развилка: дальше по кольцу или вверх через центр
## по срезке из 4 клеток прямо к клетке 17 (верх, середина).

const STEP := 2.4
const COLUMNS := 9
const ROWS := 6
## Клетка кольца, где начинается срезка, и клетка, где она заканчивается.
const FORK_FROM := 4
const FORK_TO := 17


static func build(parent: Node3D) -> Array[BoardSpace]:
	var points: Array[Vector2i] = []
	# Низ: слева направо
	for x in COLUMNS:
		points.append(Vector2i(x, ROWS - 1))
	# Правая сторона: снизу вверх
	for z in range(ROWS - 2, -1, -1):
		points.append(Vector2i(COLUMNS - 1, z))
	# Верх: справа налево
	for x in range(COLUMNS - 2, -1, -1):
		points.append(Vector2i(x, 0))
	# Левая сторона: сверху вниз
	for z in range(1, ROWS - 1):
		points.append(Vector2i(0, z))

	var spaces: Array[BoardSpace] = []
	for i in points.size():
		var type := BoardSpace.Type.BLUE
		if i == 0:
			type = BoardSpace.Type.START
		elif i % 5 == 3:
			type = BoardSpace.Type.RED
		elif i % 4 == 2:
			type = BoardSpace.Type.EVENT
		spaces.append(_make_space(parent, spaces.size(), points[i], type))
	for i in spaces.size():
		spaces[i].next.append(spaces[(i + 1) % spaces.size()])

	# Срезка: короче, но опаснее (красные клетки и события).
	var fork_x := points[FORK_FROM].x
	var shortcut_types := [
		BoardSpace.Type.RED, BoardSpace.Type.EVENT, BoardSpace.Type.RED, BoardSpace.Type.EVENT,
	]
	var prev: BoardSpace = spaces[FORK_FROM]
	var first_shortcut: BoardSpace = null
	for k in ROWS - 2:
		var s := _make_space(parent, spaces.size(), Vector2i(fork_x, ROWS - 2 - k), shortcut_types[k])
		s.kiosk_allowed = false
		if first_shortcut == null:
			first_shortcut = s
		else:
			prev.next.append(s)
		prev = s
		spaces.append(s)
	prev.next.append(spaces[FORK_TO])
	# У развилки два пути: дальше по кольцу или в срезку.
	spaces[FORK_FROM].next.append(first_shortcut)

	for s in spaces:
		for n in s.next:
			_make_path(parent, s.position, n.position)
	return spaces


static func _make_space(
		parent: Node3D, idx: int, grid: Vector2i, type: BoardSpace.Type) -> BoardSpace:
	var s := BoardSpace.new()
	s.name = "Space%d" % idx
	s.index = idx
	s.type = type
	s.position = Vector3(
		(grid.x - (COLUMNS - 1) / 2.0) * STEP, 0.0, (grid.y - (ROWS - 1) / 2.0) * STEP)
	parent.add_child(s)
	return s


## Дорожка между клетками.
static func _make_path(parent: Node3D, from: Vector3, to: Vector3) -> void:
	var dir := to - from
	var length := dir.length() - BoardSpace.RADIUS * 2.0
	if length <= 0.0:
		return
	var path := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.35, 0.06, length)
	path.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("c9b98f")
	path.material_override = mat
	parent.add_child(path)
	path.position = (from + to) / 2.0 + Vector3.UP * 0.03
	path.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
