class_name KitchenRoom
extends Node3D
## Кухня советской квартиры: за диваном, вход из гостиной через проём в её передней стене
## (Apartment._front_with_kitchen_door). Комната X −3.9..−0.7, Z 3.7..6.3 (внутри).
## Стены: внизу белый кафель, выше — светлые обои; пол — линолеум в клетку с ромбиками.
## Сверху (общая камера смотрит спереди) не закрывает квартиру: передняя (дальняя) стена,
## стена с проёмом и потолок — только от первого лица; боковые стены — до 2.4 м видны всем.
## Внутри: холодильник, газовая плита с чайником, мойка под окном, навесной шкафчик, стол с
## клеёнкой и табуретки, радиоточка, отрывной календарь (сегодняшняя дата), абажур над столом
## с выключателем у двери. Модели — tools/blender/kitchen.py.

const DIR := "res://assets/models/kitchen/"
const APT := "res://assets/models/apartment/"
const DOOR_X0 := -2.0
const DOOR_X1 := -1.2
const DOOR_TOP := 2.1
const X0 := -3.9
const X1 := -0.7
const Z0 := 3.7
const Z1 := 6.3
const HEIGHT := 3.0
## До какой высоты кафель (выше — обои).
const TILE_H := 1.5
## Окно над мойкой в дальней стене: центр по X, низ и верх, ширина.
const WINDOW_X := -3.1
const WINDOW_Y0 := 1.15
const WINDOW_Y1 := 2.25
const WINDOW_W := 1.0
const LINOLEUM := preload("res://assets/textures/kitchen/linoleum.png")
const TILES := preload("res://assets/textures/kitchen/tiles.png")
const WINDOW_VIEW := preload("res://assets/textures/window_view.png")
const MONTHS: Array[String] = ["ЯНВАРЯ", "ФЕВРАЛЯ", "МАРТА", "АПРЕЛЯ", "МАЯ", "ИЮНЯ", "ИЮЛЯ",
	"АВГУСТА", "СЕНТЯБРЯ", "ОКТЯБРЯ", "НОЯБРЯ", "ДЕКАБРЯ"]
const WEEKDAYS: Array[String] = ["ВОСКРЕСЕНЬЕ", "ПОНЕДЕЛЬНИК", "ВТОРНИК", "СРЕДА", "ЧЕТВЕРГ",
	"ПЯТНИЦА", "СУББОТА"]

## Квартира (её выключатели, тени под мебелью, время суток за окном).
var apartment: Apartment

var _tile_mat: StandardMaterial3D
var _paper_mat: StandardMaterial3D
var _view_mat: StandardMaterial3D


func _ready() -> void:
	_tile_mat = _mat(Color.WHITE, 0.25)
	_tile_mat.albedo_texture = TILES
	_tile_mat.uv1_triplanar = true
	_tile_mat.uv1_world_triplanar = true
	_tile_mat.uv1_scale = Vector3.ONE / 0.6 # 4 плитки по 15 см на картинку
	_paper_mat = _mat(Color("e6dcb4"), 0.9)
	_build_floor()
	_build_walls()
	_build_window()
	_build_furniture()
	_build_lamp()
	_build_calendar()


func _process(_delta: float) -> void:
	# Вид за окном темнеет вечером вместе с двором за окном гостиной.
	if _view_mat and apartment and apartment.window_view:
		var day := apartment.window_view.daylight()
		_view_mat.albedo_color = Color(0.12, 0.13, 0.22).lerp(Color.WHITE, day)


# ---------------- Пол и стены ----------------

func _build_floor() -> void:
	var floor_mat := _mat(Color.WHITE, 0.6)
	floor_mat.albedo_texture = LINOLEUM
	floor_mat.uv1_triplanar = true
	floor_mat.uv1_world_triplanar = true
	# Пол — от передней стены гостиной (порог в проёме — тоже линолеум).
	_solid(Vector3(X1 - X0 + 0.4, 0.2, Z1 - 3.5 + 0.2),
		Vector3((X0 + X1) / 2.0, -0.1, (3.5 + Z1 + 0.2) / 2.0), floor_mat)


func _build_walls() -> void:
	var outside := _mat(Color("c9b48a"), 0.9)
	var depth := Z1 - 3.5 + 0.2
	var mid_z := (3.5 + Z1 + 0.2) / 2.0
	# Боковые стены: до 2.4 м видны всем (как перегородки квартиры), выше — от первого лица.
	for x: float in [X0 - 0.1, X1 + 0.1]:
		_solid(Vector3(0.2, 2.4, depth), Vector3(x, 1.2, mid_z), outside)
		_fp_only(Vector3(0.2, HEIGHT - 2.4, depth), Vector3(x, 2.7, mid_z), outside)
		_collider(Vector3(0.2, HEIGHT - 2.4 + 0.3, depth), Vector3(x, 2.85, mid_z))
		var inner := x + (0.105 if x < X0 else -0.105)
		_faces_x(inner, Z0, Z1, true)
	# Дальняя стена — только от первого лица (сверху закрыла бы кухню), с проёмом окна.
	var far_z := Z1 + 0.1
	var wx0 := WINDOW_X - WINDOW_W / 2.0
	var wx1 := WINDOW_X + WINDOW_W / 2.0
	var width := X1 - X0
	_collider(Vector3(width + 0.4, HEIGHT, 0.2), Vector3((X0 + X1) / 2.0, HEIGHT / 2.0, far_z))
	for span: Vector2 in [Vector2(X0, wx0), Vector2(wx1, X1)]:
		_far_piece(span, 0.0, HEIGHT)
	_far_piece(Vector2(wx0, wx1), 0.0, WINDOW_Y0)
	_far_piece(Vector2(wx0, wx1), WINDOW_Y1, HEIGHT)
	# Стена с проёмом со стороны кухни (со стороны гостиной её строит квартира).
	for span: Vector2 in [Vector2(X0, DOOR_X0), Vector2(DOOR_X1, X1)]:
		_faces_z(span, Z0 + 0.005, 0.0, HEIGHT)
	_faces_z(Vector2(DOOR_X0, DOOR_X1), Z0 + 0.005, DOOR_TOP, HEIGHT)
	# Потолок: виден от первого лица, твёрдый для всех.
	_fp_only(Vector3(width + 0.4, 0.1, depth), Vector3((X0 + X1) / 2.0, HEIGHT + 0.05, mid_z),
		_mat(Color("e8e2d2"), 0.9))
	_collider(Vector3(width + 0.4, 0.3, depth), Vector3((X0 + X1) / 2.0, HEIGHT + 0.15, mid_z))


## Внутренняя отделка боковой стены (плоскость x): кафель до TILE_H, выше обои.
## low_visible — нижняя часть видна и сверху (боковые стены).
func _faces_x(x: float, z0: float, z1: float, low_visible: bool) -> void:
	var size_z := z1 - z0
	var mid := (z0 + z1) / 2.0
	var tiles := _box(Vector3(0.01, TILE_H, size_z), Vector3(x, TILE_H / 2.0, mid), _tile_mat)
	if not low_visible:
		_make_fp_only(tiles)
	var paper_h := 2.4 - TILE_H
	_box(Vector3(0.01, paper_h, size_z), Vector3(x, TILE_H + paper_h / 2.0, mid), _paper_mat)
	_fp_only(Vector3(0.01, HEIGHT - 2.4, size_z), Vector3(x, 2.7, mid), _paper_mat)
	_box(Vector3(0.014, 0.03, size_z), Vector3(x, TILE_H, mid), _mat(Color("8a6a48"), 0.5))


## Отделка поперечной стены (плоскость z) на отрезке span по X и высотах y0..y1 — от 1-го лица.
func _faces_z(span: Vector2, z: float, y0: float, y1: float) -> void:
	var w := span.y - span.x
	var cx := (span.x + span.y) / 2.0
	var tile_top := minf(y1, TILE_H)
	if tile_top > y0:
		_fp_only(Vector3(w, tile_top - y0, 0.01), Vector3(cx, (y0 + tile_top) / 2.0, z), _tile_mat)
	var paper_y0 := maxf(y0, TILE_H)
	if y1 > paper_y0:
		_fp_only(Vector3(w, y1 - paper_y0, 0.01), Vector3(cx, (paper_y0 + y1) / 2.0, z), _paper_mat)


## Кусок дальней стены (span по X, высоты y0..y1): сама стена и отделка внутри.
func _far_piece(span: Vector2, y0: float, y1: float) -> void:
	var w := span.y - span.x
	var cx := (span.x + span.y) / 2.0
	_fp_only(Vector3(w, y1 - y0, 0.2), Vector3(cx, (y0 + y1) / 2.0, Z1 + 0.1), _paper_mat)
	_faces_z(span, Z1 - 0.005, y0, y1)


# ---------------- Окно ----------------

## Окно над мойкой: белая рама с переплётом и форточкой, подоконник, за стеклом — двор
## (картинка, вечером темнеет). Всё — от первого лица (сверху дальней стены нет).
func _build_window() -> void:
	var frame := _mat(Color("f2efe6"), 0.6)
	var cy := (WINDOW_Y0 + WINDOW_Y1) / 2.0
	var h := WINDOW_Y1 - WINDOW_Y0
	var z := Z1 + 0.06
	for x: float in [WINDOW_X - WINDOW_W / 2.0 + 0.03, WINDOW_X, WINDOW_X + WINDOW_W / 2.0 - 0.03]:
		_fp_only(Vector3(0.06, h, 0.08), Vector3(x, cy, z), frame)
	for y: float in [WINDOW_Y0 + 0.03, WINDOW_Y1 - 0.03, WINDOW_Y1 - 0.32]:
		_fp_only(Vector3(WINDOW_W, 0.06, 0.08), Vector3(WINDOW_X, y, z), frame)
	_fp_only(Vector3(WINDOW_W + 0.2, 0.04, 0.22), Vector3(WINDOW_X, WINDOW_Y0 - 0.02, Z1 - 0.06),
		frame) # подоконник
	var glass := _mat(Color(0.82, 0.92, 0.96, WindowGlass.ALPHA), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fp_only(Vector3(WINDOW_W, h, 0.006), Vector3(WINDOW_X, cy, z), glass)
	_view_mat = StandardMaterial3D.new()
	_view_mat.albedo_texture = WINDOW_VIEW
	_view_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var view := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(WINDOW_W + 0.4, h + 0.4)
	view.mesh = quad
	view.material_override = _view_mat
	view.position = Vector3(WINDOW_X, cy, Z1 + 0.25)
	view.rotation.y = PI # лицом в кухню
	_make_fp_only(view)
	add_child(view)
	# Кактус на подоконнике.
	_breakable(APT + "cactus_pot.glb", Vector3(WINDOW_X + 0.35, WINDOW_Y0, Z1 - 0.08),
		[Color("2f7a2f"), Color("a0522d")], 0.35)


# ---------------- Мебель ----------------

func _build_furniture() -> void:
	# Вдоль левой стены (лицом в кухню, +X): холодильник у двери, плита.
	_furniture("kitchen_fridge", Vector3(X0 + 0.32, 0, 4.15), PI / 2, Vector3(0.62, 1.5, 0.6))
	var stove := _furniture("kitchen_stove", Vector3(X0 + 0.3, 0, 5.0), PI / 2,
		Vector3(0.58, 0.88, 0.5))
	# Под окном — мойка (лицом от окна, −Z), правее — навесной шкафчик.
	_furniture("kitchen_sink", Vector3(WINDOW_X, 0, Z1 - 0.31), PI, Vector3(1.0, 0.87, 0.62))
	var cabinet := _model("kitchen_cabinet")
	cabinet.position = Vector3(-1.9, 1.5, Z1 - 0.16)
	cabinet.rotation.y = PI
	add_child(cabinet)
	# У правой стены — стол с клеёнкой (длинной стороной вдоль стены) и три табуретки.
	var table_pos := Vector3(X1 - 0.36, 0, 5.3)
	_furniture("kitchen_table", table_pos, PI / 2, Vector3(1.0, 0.75, 0.7))
	for z: float in [4.95, 5.65]:
		_tippable(APT + "stool.glb", Vector3(X1 - 0.95, 0, z), Vector3(0.36, 0.47, 0.36), 0.24)
	_tippable(APT + "stool.glb", Vector3(X1 - 0.36, 0, 4.45), Vector3(0.36, 0.47, 0.36), 0.24)
	# Чайник на передней левой конфорке, на столе — чай в подстаканниках и заварочный чайник.
	_breakable(DIR + "kitchen_kettle.glb", stove.to_global(Vector3(-0.12, 0.878, 0.12)),
		[Color("b81a14"), Color("f2f2ea"), Color("111111")], 0.4)
	for offset: Vector3 in [Vector3(0.05, 0.75, 5.1), Vector3(0.15, 0.75, 5.5)]:
		_breakable(DIR + "kitchen_glass.glb", Vector3(table_pos.x + offset.x - 0.1, offset.y,
			offset.z), [Color("caa060"), Color("d8ecf2"), Color("5a2a0a")], 0.3, 0.04)
	_breakable(APT + "china_teapot.glb", Vector3(table_pos.x + 0.1, 0.75, 5.3),
		[Color(0.95, 0.95, 0.93), Color(0.1, 0.2, 0.6)], 0.35, 0.05) # заварочный чайник
	# Радиоточка на правой стене над столом.
	var radio := _model("kitchen_radio")
	radio.position = Vector3(X1 - 0.012, 1.45, 4.85)
	radio.rotation.y = -PI / 2 # лицом в кухню (−X)
	add_child(radio)


## Мебель на полу: модель, коробка столкновений по размеру (size — ширина, высота, глубина в
## осях модели) и тень-пятно под ней.
func _furniture(model_name: String, pos: Vector3, yaw: float, size: Vector3) -> Node3D:
	var body := StaticBody3D.new()
	var model := _model(model_name)
	body.add_child(model)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y / 2.0
	body.add_child(shape)
	body.position = pos
	body.rotation.y = yaw
	add_child(body)
	if apartment:
		body.add_child(apartment.contact_shadow(Vector2(size.x, size.z)))
	return body


func _breakable(path: String, pos: Vector3, colors: Array, reach: float,
		shard: float = 0.06) -> Breakable:
	var item := Breakable.new()
	add_child(item)
	item.global_position = pos
	var typed: Array[Color] = []
	typed.assign(colors)
	item.setup(load(path) as PackedScene, typed, reach, shard)
	return item


## Поворот и место — до добавления в сцену: Tippable запоминает «дом» при появлении.
func _tippable(path: String, pos: Vector3, size: Vector3, center_y: float) -> void:
	var body := Tippable.new()
	body.setup(load(path) as PackedScene, size, center_y, 2.0)
	body.position = pos
	add_child(body)


# ---------------- Свет и календарь ----------------

## Абажур над столом (только от первого лица — сверху закрыл бы стол) и выключатель у двери.
func _build_lamp() -> void:
	var at := Vector3(X1 - 0.36, 0, 5.3)
	var lamp := _model("kitchen_lamp")
	lamp.position = at
	_make_fp_only(lamp)
	add_child(lamp)
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for node in lamp.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.mesh.get_surface_count():
			var surface := mesh_instance.mesh.surface_get_material(i)
			if surface and surface.resource_name.begins_with("KitchenBulb"):
				mesh_instance.set_surface_override_material(i, bulb_mat)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = 1.3
	light.omni_range = 4.5
	light.position = at + Vector3(0, 2.2, 0)
	add_child(light)
	if apartment:
		# Выключатель — на стене у двери, со стороны кухни (клавиша смотрит в кухню, +Z).
		apartment.add_switch(LobbyLamp.new(light, bulb_mat),
			Vector3(DOOR_X0 - 0.25, 1.25, Z0 + 0.01), 0.0, false)


## Отрывной календарь на правой стене: картонка, листок с сегодняшним числом.
func _build_calendar() -> void:
	var board := Node3D.new()
	board.position = Vector3(X1 - 0.02, 1.55, 5.95)
	board.rotation.y = -PI / 2 # лицом в кухню
	add_child(board)
	var back := _box(Vector3(0.2, 0.3, 0.01), Vector3.ZERO, _mat(Color("b8322a"), 0.6))
	back.reparent(board, false)
	var sheet := _box(Vector3(0.16, 0.18, 0.012), Vector3(0, -0.04, 0.006), _mat(Color("f6f1e4"), 0.8))
	sheet.reparent(board, false)
	var date := Time.get_date_dict_from_system()
	var day := Label3D.new()
	day.text = str(date["day"])
	day.font_size = 96
	day.pixel_size = 0.0008
	day.modulate = Color("b8322a")
	day.outline_size = 0
	day.position = Vector3(0, -0.035, 0.014)
	board.add_child(day)
	var month := Label3D.new()
	month.text = "%s\n%s" % [MONTHS[int(date["month"]) - 1], WEEKDAYS[int(date["weekday"])]]
	month.font_size = 28
	month.pixel_size = 0.0006
	month.modulate = Color("222222")
	month.outline_size = 0
	month.position = Vector3(0, 0.07, 0.014)
	board.add_child(month)


# ---------------- Помощники ----------------

func _model(model_name: String) -> Node3D:
	return (load(DIR + model_name + ".glb") as PackedScene).instantiate() as Node3D


func _box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = pos
	add_child(mesh_instance)
	return mesh_instance


func _fp_only(size: Vector3, pos: Vector3, material: Material) -> void:
	_make_fp_only(_box(size, pos, material))


func _make_fp_only(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.layers = Apartment.FP_ONLY_LAYER
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_make_fp_only(child)


func _solid(size: Vector3, pos: Vector3, material: Material) -> void:
	_box(size, pos, material)
	_collider(size, pos)


func _collider(size: Vector3, pos: Vector3) -> void:
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
