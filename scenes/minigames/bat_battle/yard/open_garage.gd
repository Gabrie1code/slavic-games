class_name OpenGarage
extends Node3D
## Приоткрытый гараж в «Битве на битах» — объёмный, потому что камера смотрит сверху:
## коробка гаража собрана из стен с настоящим проёмом ворот, внутри комната (пол, стены,
## потолок) и вещи из простых фигур: верстак с тисками и ящиком, щит с инструментами, полка
## с банками и красной канистрой, стопка шин (модель roof_tire), велосипед, лампочка с тёплым
## светом. Правая створка закрыта (номер на ней), левая открыта наружу: камера стоит правее
## гаража, и открытая правая створка закрыла бы проём.
## Начало координат — центр гаража на уровне земли (низ ворот), гараж смотрит в +Z.

const SIZE := Vector3(4.25, 3.0, 9.0)
const DOOR := Vector2(3.3, 2.3)
## Глубина «комнаты» за воротами (дальше — глухая стена, её не видно).
const ROOM_DEPTH := 4.2
const LEAF_ANGLE := 1.0
const WALL_COLOR := Color(0.55, 0.5, 0.45)
const LEAF_COLOR := Color(0.5, 0.23, 0.12)
const TIRE := preload("res://assets/models/courtyard/roof_tire.glb")

var plate_texture: Texture2D


func _ready() -> void:
	_build_shell()
	_build_room()
	_build_props()
	_build_leaves()


## Внешняя коробка: передняя стена с проёмом (над воротами и по бокам), бока, зад.
func _build_shell() -> void:
	var wall := _mat(WALL_COLOR, 0.9)
	var front := SIZE.z / 2.0
	var side_w := (SIZE.x - DOOR.x) / 2.0
	_box(Vector3(SIZE.x, SIZE.y - DOOR.y, 0.2),
		Vector3(0, DOOR.y + (SIZE.y - DOOR.y) / 2.0, front - 0.1), wall)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(side_w, DOOR.y, 0.2),
			Vector3(s * (DOOR.x + side_w) / 2.0, DOOR.y / 2.0, front - 0.1), wall)
		_box(Vector3(0.2, SIZE.y, SIZE.z), Vector3(s * (SIZE.x / 2.0 - 0.1), SIZE.y / 2.0, 0), wall)
	_box(Vector3(SIZE.x, SIZE.y, 0.2), Vector3(0, SIZE.y / 2.0, -front + 0.1), wall)
	_box(Vector3(SIZE.x, 0.2, SIZE.z), Vector3(0, SIZE.y - 0.1, 0), wall) # потолок (под крышей)


## Комната за воротами: бетонный пол с пятном, стены темнее снаружи (полумрак).
func _build_room() -> void:
	var front := SIZE.z / 2.0 - 0.2
	var back := front - ROOM_DEPTH
	var inner := SIZE.x - 0.4
	# Пол до самого порога: под проёмом ворот (толщина стены) иначе виднелась трава.
	_box(Vector3(inner, 0.04, ROOM_DEPTH + 0.2),
		Vector3(0, 0.02, (front + back) / 2.0 + 0.1), _mat(Color(0.46, 0.45, 0.42), 0.95))
	_box(Vector3(1.2, 0.01, 0.7),
		Vector3(-0.1, 0.045, front - 2.4), _mat(Color(0.2, 0.2, 0.2), 0.4)) # масло
	_box(Vector3(inner, SIZE.y - 0.2, 0.1),
		Vector3(0, (SIZE.y - 0.2) / 2.0, back), _mat(Color(0.33, 0.29, 0.25), 0.95))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 2.2
	lamp.omni_range = 5.0
	lamp.position = Vector3(-0.3, SIZE.y - 0.75, front - 1.0)
	add_child(lamp)
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	bulb.mesh = sphere
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.9, 0.6)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.85, 0.55)
	glow.emission_energy_multiplier = 3.0
	bulb.material_override = glow
	bulb.position = lamp.position
	add_child(bulb)
	_box(Vector3(0.01, 0.5, 0.01),
		lamp.position + Vector3(0, 0.3, 0), _mat(Color(0.1, 0.1, 0.1), 0.8))


## Вещи внутри (всё у стен, середина свободна — видно пол).
func _build_props() -> void:
	var front := SIZE.z / 2.0 - 0.2
	var back := front - ROOM_DEPTH
	var wood := _mat(Color(0.45, 0.3, 0.16), 0.8)
	# Сверху видно ~2 м пола у ворот и левую часть (правую закрывает створка) — всё
	# заметное стоит там.
	var xw := -SIZE.x / 2.0 + 0.2 # левая внутренняя стена
	# Верстак у левой стены: столешница, ножки, тиски, красный ящик.
	_box(Vector3(0.7, 0.06, 2.0), Vector3(xw + 0.35, 0.9, front - 2.2), wood)
	for z: float in [front - 1.3, front - 3.1]:
		_box(Vector3(0.06, 0.9, 0.06), Vector3(xw + 0.62, 0.45, z), wood)
	_box(Vector3(0.22, 0.16, 0.26),
		Vector3(xw + 0.4, 1.01, front - 1.5), _mat(Color(0.3, 0.38, 0.45), 0.5))
	_box(Vector3(0.3, 0.2, 0.45),
		Vector3(xw + 0.35, 1.03, front - 2.7), _mat(Color(0.65, 0.18, 0.12), 0.6))
	# Щит с инструментами на левой стене над верстаком.
	_box(Vector3(0.03, 0.8, 1.6),
		Vector3(xw + 0.02, 1.6, front - 2.2), _mat(Color(0.55, 0.42, 0.26), 0.9))
	var steel := _mat(Color(0.6, 0.6, 0.62), 0.4)
	for k in 4:
		_box(Vector3(0.04, 0.45 - k * 0.05, 0.05),
			Vector3(xw + 0.05, 1.6, front - 2.75 + k * 0.36), steel)
	# Полка у задней стены: банки и канистра.
	_box(Vector3(1.6, 0.05, 0.35), Vector3(0.4, 1.3, back + 0.25), wood)
	var colors: Array[Color] = [Color(0.6, 0.25, 0.2), Color(0.25, 0.4, 0.6), Color(0.75, 0.62, 0.25),
		Color(0.35, 0.5, 0.3)]
	for k in 5:
		_box(Vector3(0.14, 0.2, 0.14),
			Vector3(-0.2 + k * 0.24, 1.43, back + 0.25), _mat(colors[k % 4], 0.6))
	_box(Vector3(0.35, 0.45, 0.2),
		Vector3(-0.1, 0.23, front - 1.0), _mat(Color(0.7, 0.18, 0.12), 0.5)) # канистра у ворот
	# Стопка шин посередине, поглубже.
	for k in 4:
		var tire := TIRE.instantiate() as Node3D
		tire.position = Vector3(-0.1, 0.04 + k * 0.28, front - 2.0)
		tire.rotation.y = k * 0.7
		add_child(tire)
	_bicycle(Vector3(-0.85, 0, front - 0.6))


## Велосипед у ворот, боком к камере (вдоль X): два колеса, рама, руль, седло.
func _bicycle(at: Vector3) -> void:
	var bike := Node3D.new()
	bike.position = at
	bike.rotation.y = PI / 2.0 # рама вдоль Z модели → вдоль X мира
	add_child(bike)
	var frame := _mat(Color(0.65, 0.15, 0.15), 0.5)
	var dark := _mat(Color(0.08, 0.08, 0.08), 0.7)
	for dz: float in [-0.5, 0.5]:
		var wheel := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.27
		torus.outer_radius = 0.345
		torus.rings = 20
		torus.ring_segments = 6
		wheel.mesh = torus
		wheel.material_override = dark
		wheel.position = Vector3(0, 0.33, dz)
		wheel.rotation.z = PI / 2.0 # колесо стоит вертикально в плоскости YZ
		bike.add_child(wheel)
	var tubes: Array[Vector3] = [
		Vector3(0, 0.33, -0.5), Vector3(0, 0.36, 0.0), # нижняя
		Vector3(0, 0.36, 0.0), Vector3(0, 0.75, -0.15), # подседельная
		Vector3(0, 0.75, -0.15), Vector3(0, 0.75, 0.38), # верхняя
		Vector3(0, 0.36, 0.0), Vector3(0, 0.75, 0.38), # наклонная
		Vector3(0, 0.75, 0.38), Vector3(0, 0.33, 0.5), # вилка
		Vector3(0, 0.33, -0.5), Vector3(0, 0.75, -0.15), # задние перья
	]
	for k in range(0, tubes.size(), 2):
		_bar(tubes[k], tubes[k + 1], frame, bike)
	_bar(Vector3(0, 0.75, 0.38), Vector3(0, 0.92, 0.36), dark, bike) # вынос руля
	_box(Vector3(0.5, 0.03, 0.03), Vector3(0, 0.92, 0.36), dark, bike) # руль
	_box(Vector3(0.12, 0.05, 0.24), Vector3(0, 0.84, -0.17), dark, bike) # седло


## Обе створки: правая закрыта (на ней номер), левая открыта наружу.
func _build_leaves() -> void:
	var leaf_mat := _mat(LEAF_COLOR, 0.8)
	for s: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(s * DOOR.x / 2.0, DOOR.y / 2.0, SIZE.z / 2.0 + 0.03)
		hinge.rotation.y = -LEAF_ANGLE if s < 0.0 else 0.0
		add_child(hinge)
		_box(Vector3(DOOR.x / 2.0 - 0.01, DOOR.y, 0.06),
			Vector3(-s * DOOR.x / 4.0, 0, 0), leaf_mat, hinge)
		if s > 0.0 and plate_texture:
			var plate := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(0.56, 0.28)
			plate.mesh = quad
			var plate_mat := StandardMaterial3D.new()
			plate_mat.albedo_texture = plate_texture
			plate_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			plate_mat.roughness = 0.9
			plate.material_override = plate_mat
			plate.position = Vector3(-0.45, 0.83, 0.035)
			hinge.add_child(plate)


func _bar(a: Vector3, b: Vector3, material: Material, parent: Node3D) -> void:
	var piece := _box(Vector3(0.05, 0.05, a.distance_to(b)), (a + b) / 2.0, material, parent)
	var up := Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT
	piece.basis = Basis.looking_at(b - a, up) # длинная сторона (Z) — от a к b


func _box(size: Vector3, pos: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = pos
	(parent if parent else self as Node3D).add_child(mesh_instance)
	return mesh_instance


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m
