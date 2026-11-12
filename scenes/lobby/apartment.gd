class_name Apartment
extends Node3D
## Лобби — советская квартира: гостиная и спальня.
##
## Гостиная: телевизор (старт игры), диван (можно сесть), ковёр, сервант с хрусталём,
## стол со стульями, окно с горшками, банки, книги, торшер. Почти всё ломается или падает.
## Спальня: шкаф с зеркалом (примерочная и покупки), кровать, тумбочка с лампой.
##
## Стены есть только сзади и по бокам — спереди «срез», чтобы камера видела комнаты.
## Координаты: X вправо, Z к камере. Гостиная X −6..3.1, спальня X 3.1..9.

const DIR := "res://assets/models/apartment/"
const TV_SCENE := preload("res://assets/models/props/soviet_tv.glb")

const WALL_HEIGHT := 3.0
const BACK_Z := -4.0
const LIVING_FRONT_Z := 3.5
const BEDROOM_FRONT_Z := 1.5
const LEFT_X := -6.0
const PARTITION_X := 3.1
const RIGHT_X := 9.0
## Дверной проём между комнатами (по Z).
const DOOR_FROM_Z := -1.8
const DOOR_TO_Z := -0.2

## Важные точки (лобби вешает на них зоны).
const TV_POS := Vector3(-2.4, 0, -3.45)
const TV_ZONE := Vector3(-2.4, 0, -2.1)
const WARDROBE_POS := Vector3(5.2, 0, -3.62)
const WARDROBE_ZONE := Vector3(5.2, 0, -2.4)
const SOFA_POS := Vector3(-0.3, 0, -3.42)
## Места на диване: точка под сиденьем (персонаж садится лицом к камере).
const SEATS: Array[Vector3] = [Vector3(-0.85, 0.04, -3.32), Vector3(0.25, 0.04, -3.32)]
const SPAWNS: Array[Vector3] = [
	Vector3(-3.5, 0.3, 2.2), Vector3(-1.8, 0.3, 2.6), Vector3(0.4, 0.3, 2.6), Vector3(2.0, 0.3, 2.2),
]

const CRYSTAL := Color(0.75, 0.9, 1.0, 0.6)
const CLAY := Color(0.65, 0.3, 0.15)
const PLANT := Color(0.15, 0.45, 0.15)
const GLASS := Color(0.8, 0.95, 0.9, 0.6)


func _ready() -> void:
	_build_rooms()
	_build_living_room()
	_build_bedroom()


# ---------------- Стены и пол ----------------

func _build_rooms() -> void:
	var parquet := _mat(Color("6b4423"), 0.6)
	var bedroom_floor := _mat(Color("7a5a3a"), 0.7)
	var wallpaper := _mat(Color("c9b48a"), 0.9)
	var wallpaper_bed := _mat(Color("a9b896"), 0.9)
	var skirting := _mat(Color("4a2a12"), 0.6)
	var living_w := PARTITION_X - LEFT_X
	var bed_w := RIGHT_X - PARTITION_X
	_solid_box(Vector3(living_w, 0.2, LIVING_FRONT_Z - BACK_Z),
		Vector3((LEFT_X + PARTITION_X) / 2, -0.1, (BACK_Z + LIVING_FRONT_Z) / 2), parquet)
	_solid_box(Vector3(bed_w, 0.2, BEDROOM_FRONT_Z - BACK_Z),
		Vector3((PARTITION_X + RIGHT_X) / 2, -0.1, (BACK_Z + BEDROOM_FRONT_Z) / 2), bedroom_floor)
	# Задняя стена (гостиная и спальня разного цвета) и плинтус.
	_solid_box(Vector3(living_w, WALL_HEIGHT, 0.2),
		Vector3((LEFT_X + PARTITION_X) / 2, WALL_HEIGHT / 2, BACK_Z - 0.1), wallpaper)
	_solid_box(Vector3(bed_w, WALL_HEIGHT, 0.2),
		Vector3((PARTITION_X + RIGHT_X) / 2, WALL_HEIGHT / 2, BACK_Z - 0.1), wallpaper_bed)
	_box(Vector3(RIGHT_X - LEFT_X, 0.12, 0.04),
		Vector3((LEFT_X + RIGHT_X) / 2, 0.06, BACK_Z + 0.02), skirting)
	# Боковые стены.
	_solid_box(Vector3(0.2, WALL_HEIGHT, LIVING_FRONT_Z - BACK_Z),
		Vector3(LEFT_X - 0.1, WALL_HEIGHT / 2, (BACK_Z + LIVING_FRONT_Z) / 2), wallpaper)
	_solid_box(Vector3(0.2, WALL_HEIGHT, BEDROOM_FRONT_Z - BACK_Z),
		Vector3(RIGHT_X + 0.1, WALL_HEIGHT / 2, (BACK_Z + BEDROOM_FRONT_Z) / 2), wallpaper_bed)
	# Перегородка с дверным проёмом.
	var partition_h := 2.4
	_solid_box(Vector3(0.16, partition_h, DOOR_FROM_Z - BACK_Z),
		Vector3(PARTITION_X, partition_h / 2, (BACK_Z + DOOR_FROM_Z) / 2), wallpaper)
	_solid_box(Vector3(0.16, partition_h, BEDROOM_FRONT_Z - DOOR_TO_Z),
		Vector3(PARTITION_X, partition_h / 2, (DOOR_TO_Z + BEDROOM_FRONT_Z) / 2), wallpaper)
	# Невидимые стенки спереди, чтобы не уйти из квартиры.
	_invisible_wall(Vector3(living_w, 3, 0.4),
		Vector3((LEFT_X + PARTITION_X) / 2, 1.5, LIVING_FRONT_Z + 0.2))
	_invisible_wall(Vector3(bed_w, 3, 0.4),
		Vector3((PARTITION_X + RIGHT_X) / 2, 1.5, BEDROOM_FRONT_Z + 0.2))
	_invisible_wall(Vector3(0.4, 3, LIVING_FRONT_Z - BEDROOM_FRONT_Z),
		Vector3(PARTITION_X + 0.2, 1.5, (BEDROOM_FRONT_Z + LIVING_FRONT_Z) / 2))
	# Половик в спальне и дорожка в гостиной.
	_box(Vector3(2.4, 0.02, 1.6), Vector3(6.6, 0.01, -1.0), _mat(Color("8a2a2a"), 0.95))
	_box(Vector3(3.6, 0.02, 2.2), Vector3(-1.0, 0.01, 0.8), _mat(Color("6a1c1c"), 0.95))
	_box(Vector3(3.3, 0.022, 1.9), Vector3(-1.0, 0.011, 0.8), _mat(Color("b8862e"), 0.95))
	_box(Vector3(3.1, 0.024, 1.7), Vector3(-1.0, 0.012, 0.8), _mat(Color("6a1c1c"), 0.95))


# ---------------- Гостиная ----------------

func _build_living_room() -> void:
	# Телевизор — старт игры.
	var tv := TV_SCENE.instantiate() as Node3D
	tv.scale = Vector3.ONE * 1.3
	_solid(tv, Vector3(1.3, 1.5, 1.0), 0.75, TV_POS)

	# Диван (можно сесть) и ковёр над ним.
	_solid(_model("sofa"), Vector3(2.4, 0.6, 0.9), 0.3, SOFA_POS)
	_place(_model("wall_carpet"), SOFA_POS + Vector3(0, 0.9, -0.48))
	_tippable("floor_lamp", Vector3(0.5, 1.75, 0.5), 0.88, Vector3(1.3, 0, -3.5), 6.0)

	# Сервант с хрусталём и рюмками на полках.
	var sideboard_pos := Vector3(-4.6, 0, -3.7)
	_solid(_model("sideboard"), Vector3(2.0, 2.2, 0.5), 1.1, sideboard_pos)
	var shelf_heights := [0.97, 1.365, 1.765]
	for row in shelf_heights.size():
		for i in 4:
			var x := sideboard_pos.x - 0.72 + i * 0.48
			var item := "crystal_vase" if (i + row) % 2 == 0 else "wine_glass"
			# Зона пошире: сервант не даёт подойти вплотную к полке.
			_breakable(item, Vector3(x, shelf_heights[row], sideboard_pos.z - 0.05), [CRYSTAL], 0.6, 0.05)

	# Окно с горшками на подоконнике.
	var window_pos := Vector3(1.9, 0, BACK_Z + 0.08)
	_place(_model("window"), window_pos)
	for i in 3:
		var pot := "cactus_pot" if i != 1 else "aloe_pot"
		_breakable(pot, Vector3(window_pos.x - 0.5 + i * 0.5, 0.885, window_pos.z + 0.14),
			[CLAY, PLANT], 0.35)

	# Стол со стульями, на столе — варенье, ваза, книги.
	var table_pos := Vector3(-1.0, 0, 0.8)
	_solid(_model("table"), Vector3(1.4, 0.8, 0.85), 0.4, table_pos)
	var chairs := [[Vector3(-0.95, 0, 0), 90.0], [Vector3(0.95, 0, 0), -90.0],
		[Vector3(0, 0, -0.75), 0.0], [Vector3(0, 0, 0.75), 180.0]]
	for chair_info in chairs:
		_tippable("chair", Vector3(0.45, 0.95, 0.45), 0.47, table_pos + chair_info[0], 3.0, chair_info[1])
	_breakable("jar_jam", table_pos + Vector3(-0.35, 0.78, 0.1), [Color("801010"), GLASS], 0.4)
	_breakable("crystal_vase", table_pos + Vector3(0.1, 0.78, -0.1), [CRYSTAL], 0.4, 0.05)
	_breakable("book_stack", table_pos + Vector3(0.45, 0.78, 0.15),
		[Color("992018"), Color("1a4080"), Color("cc9918")], 0.4)

	# Банки и книги на полу у серванта.
	for i in 3:
		var jar := "jar_pickles" if i % 2 == 0 else "jar_jam"
		var color := Color("5a7a2a") if i % 2 == 0 else Color("801010")
		_breakable(jar, Vector3(-5.5 + i * 0.32, 0, -2.6), [color, GLASS], 0.35)
	var books_a := [Color("992018"), Color("1a4080"), Color("2a6a2a")]
	var books_b := [Color("cc9918"), Color("6a2a6a"), Color("1a4080")]
	_breakable("book_stack", Vector3(-5.4, 0, -0.8), books_a, 0.4)
	_breakable("book_stack", Vector3(-5.4, 0, -0.2), books_b, 0.4)


# ---------------- Спальня ----------------

func _build_bedroom() -> void:
	_solid(_model("wardrobe"), Vector3(1.5, 2.2, 0.6), 1.1, WARDROBE_POS)
	_solid(_model("bed"), Vector3(1.1, 0.7, 2.05), 0.35, Vector3(7.9, 0, -2.85))
	var stand_pos := Vector3(6.8, 0, -3.6)
	_solid(_model("nightstand"), Vector3(0.45, 0.6, 0.4), 0.3, stand_pos)
	_breakable("table_lamp", stand_pos + Vector3(0, 0.6, 0), [Color("2a7040"), Color("c0a050")], 0.4)
	for i in 2:
		_breakable("book_stack", Vector3(8.6, 0, 0.2 + i * 0.5), [Color("992018"), Color("cc9918")], 0.4)


# ---------------- Помощники ----------------

func _model(model_name: String) -> Node3D:
	return (load(DIR + model_name + ".glb") as PackedScene).instantiate() as Node3D


func _place(node: Node3D, pos: Vector3) -> Node3D:
	add_child(node)
	node.position = pos
	return node


## Неподвижная мебель: модель + коробка столкновений.
func _solid(model: Node3D, size: Vector3, center_y: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.add_child(model)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = center_y
	body.add_child(shape)
	add_child(body)
	body.position = pos
	return body


func _breakable(model_name: String, pos: Vector3, colors: Array, reach: float,
		shard_size: float = 0.07) -> Breakable:
	var item := Breakable.new()
	item.position = pos
	add_child(item)
	var typed_colors: Array[Color] = []
	typed_colors.assign(colors)
	item.setup(load(DIR + model_name + ".glb") as PackedScene, typed_colors, reach, shard_size)
	return item


## Поворот задаём до добавления в сцену: Tippable запоминает «дом» при появлении.
func _tippable(model_name: String, size: Vector3, center_y: float, pos: Vector3,
		body_mass: float, yaw_degrees: float = 0.0) -> Tippable:
	var body := Tippable.new()
	body.setup(load(DIR + model_name + ".glb") as PackedScene, size, center_y, body_mass)
	body.position = pos
	body.rotation_degrees.y = yaw_degrees
	add_child(body)
	return body


func _box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = pos
	add_child(mesh_instance)
	return mesh_instance


func _solid_box(size: Vector3, pos: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	add_child(body)


func _invisible_wall(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	add_child(body)


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m
