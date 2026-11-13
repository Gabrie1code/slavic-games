class_name KitchenRoom
extends Node3D
## Кухня советской квартиры: за диваном, вход из гостиной через проём в её передней стене
## (Apartment._front_with_kitchen_door). Комната X −3.9..−0.7, Z 3.7..6.3 (внутри).
## Стены: внизу белый кафель, выше — светлые обои; пол — линолеум в клетку с ромбиками.
## Сверху (общая камера смотрит спереди) не закрывает квартиру: передняя (дальняя) стена,
## стена с проёмом и потолок — только от первого лица; боковые стены — до 2.4 м видны всем.
## Внутри: холодильник, газовая плита с чайником и духовкой (KitchenOven), мойка под окном
## (KitchenSink — моет руки и смывает краску, как рукомойник в туалете), навесной шкафчик
## (KitchenCabinet — правая дверца открывается, внутри стопки и батон), стол с клеёнкой,
## бутылкой и гранёными стаканами, табуретки, радиоточка, отрывной
## календарь (сегодняшняя дата), абажур над столом с выключателем у двери. За окном — тот же
## 3D-двор, что за окном гостиной (WindowView), стекло бьётся молотком (WindowGlass).
## Модели — tools/blender/kitchen.py.

const DIR := "res://assets/models/kitchen/"
const APT := "res://assets/models/apartment/"
const DOOR_X0 := -2.15 # проём 1.1 м: персонаж (капсула радиусом 0.4) в 0.8 м застревал
const DOOR_X1 := -1.05
const DOOR_TOP := 2.1
const X0 := -3.9
const X1 := -0.7
const Z0 := 3.7
const Z1 := 6.3
const HEIGHT := 3.0
## До какой высоты кафель (выше — обои).
const TILE_H := 1.5
const BOTTLE_BACK := 20.0
const BOTTLE_POS := Vector3(X1 - 0.41, 0.75, 5.12)
## Окно над мойкой в дальней стене: центр по X, низ и верх, ширина.
## Края проёма (x −3.6 и −2.55) — ровно по швам кафеля (плитка 15 см): иначе у откоса шов
## стены и шов откоса шли рядом и клетка «двоилась».
const WINDOW_X := -3.075
const WINDOW_Y0 := 1.15
const WINDOW_Y1 := 2.25
const WINDOW_W := 1.05
const LINOLEUM := preload("res://assets/textures/kitchen/linoleum.png")
const TILES := preload("res://assets/textures/kitchen/tiles.png")
const WEEKDAYS: Array[String] = ["ВОСКРЕСЕНЬЕ", "ПОНЕДЕЛЬНИК", "ВТОРНИК", "СРЕДА", "ЧЕТВЕРГ",
	"ПЯТНИЦА", "СУББОТА"]

## Квартира (её выключатели, тени под мебелью).
var apartment: Apartment
## Мойка, навесной шкафчик, стёкла окна (их ищет лобби: подсказки, удар молотком).
var sink: KitchenSink
var cabinet: KitchenCabinet
var oven: KitchenOven
## Бутылка на столе (null — забрали; новая появится через BOTTLE_BACK сек).
var bottle: KitchenBottle
var window_glass: WindowGlass

var _tile_mat: StandardMaterial3D
var _paper_mat: StandardMaterial3D


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
	# Откосы проёма со стороны кухни (половина толщины стены) и откосы окна — та же отделка:
	# кафель, коричневая полоса, обои (раньше там были голые обои и полоса обрывалась на углу).
	_reveal(DOOR_X0 + 0.005, 3.6, Z0 + 0.012, 0.0, DOOR_TOP)
	_reveal(DOOR_X1 - 0.005, 3.6, Z0 + 0.012, 0.0, DOOR_TOP)
	_reveal(wx0 + 0.005, Z1 - 0.012, Z1 + 0.06, WINDOW_Y0, WINDOW_Y1)
	_reveal(wx1 - 0.005, Z1 - 0.012, Z1 + 0.06, WINDOW_Y0, WINDOW_Y1)
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
	if y0 < TILE_H and y1 > TILE_H: # коричневая полоса по кромке кафеля — по всему периметру
		_fp_only(Vector3(w, 0.03, 0.014), Vector3(cx, TILE_H, z), _mat(Color("8a6a48"), 0.5))


## Откос (боковая грань проёма) в плоскости x на глубину z0..z1, высоты y0..y1 — от 1-го лица.
func _reveal(x: float, z0: float, z1: float, y0: float, y1: float) -> void:
	var depth := z1 - z0
	var mid := (z0 + z1) / 2.0
	var tile_top := minf(y1, TILE_H)
	if tile_top > y0:
		_fp_only(Vector3(0.01, tile_top - y0, depth), Vector3(x, (y0 + tile_top) / 2.0, mid), _tile_mat)
	var paper_y0 := maxf(y0, TILE_H)
	if y1 > paper_y0:
		_fp_only(Vector3(0.01, y1 - paper_y0, depth), Vector3(x, (paper_y0 + y1) / 2.0, mid),
			_paper_mat)
	if y0 < TILE_H and y1 > TILE_H:
		_fp_only(Vector3(0.014, 0.03, depth + 0.004), Vector3(x, TILE_H, mid),
			_mat(Color("8a6a48"), 0.5))


## Кусок дальней стены (span по X, высоты y0..y1): сама стена и отделка внутри.
func _far_piece(span: Vector2, y0: float, y1: float) -> void:
	var w := span.y - span.x
	var cx := (span.x + span.y) / 2.0
	_fp_only(Vector3(w, y1 - y0, 0.2), Vector3(cx, (y0 + y1) / 2.0, Z1 + 0.1), _paper_mat)
	_faces_z(span, Z1 - 0.005, y0, y1)


# ---------------- Окно ----------------

## Окно над мойкой — как в гостиной: рама с подоконником (kitchen_window), за ней настоящий
## 3D-двор (WindowView: хрущёвки, деревья, голуби, небо по времени суток, свет в окнах ночью),
## 4 стекла бьются молотком (WindowGlass) и через 20 сек проявляются снова.
## Всё — от первого лица (сверху дальней стены нет).
func _build_window() -> void:
	var frame := _model("kitchen_window")
	frame.position = Vector3(WINDOW_X, WINDOW_Y0, Z1 + 0.1)
	frame.scale.x = WINDOW_W # модель рамы — под проём 1.0 м
	frame.rotation.y = PI # подоконник — в кухню
	_make_fp_only(frame)
	add_child(frame)
	# Подоконник (узкий) твёрдый: на него можно запрыгнуть.
	_collider(Vector3(WINDOW_W + 0.2, 0.04, 0.15), Vector3(WINDOW_X, WINDOW_Y0, Z1 + 0.005))
	# Низ проёма между подоконником и рамой — белый (раньше там была непокрашенная полоса).
	_fp_only(Vector3(WINDOW_W, 0.01, 0.2), Vector3(WINDOW_X, WINDOW_Y0 + 0.015, Z1 + 0.1),
		_mat(Color("f2f0ea"), 0.5))
	window_glass = WindowGlass.new()
	window_glass.panes = [
		Vector4(-0.2625, WINDOW_Y0 + 0.4175, 0.462, 0.715),
		Vector4(0.2625, WINDOW_Y0 + 0.4175, 0.462, 0.715),
		Vector4(-0.2625, WINDOW_Y0 + 0.9325, 0.462, 0.215),
		Vector4(0.2625, WINDOW_Y0 + 0.9325, 0.462, 0.215),
	]
	window_glass.position = Vector3(WINDOW_X, 0, Z1 + 0.1)
	window_glass.rotation.y = PI # осколки летят в кухню
	add_child(window_glass)
	var outside := WindowView.new()
	outside.position = Vector3(WINDOW_X, 0, Z1 + 0.2)
	outside.rotation.y = PI # двор — за дальней стеной кухни
	add_child(outside)


# ---------------- Мебель ----------------

func _build_furniture() -> void:
	# Вдоль левой стены (лицом в кухню, +X): холодильник у двери, плита.
	var fridge := _furniture("kitchen_fridge", Vector3(X0 + 0.32, 0, 4.15), PI / 2,
		Vector3(0.6, 1.5, 0.62))
	var model_name := Label3D.new() # «MODEL №192» на плашке холодильника
	model_name.text = "MODEL №192"
	model_name.font_size = 44
	model_name.pixel_size = 0.0004
	model_name.modulate = Color("2a2520") # тёмные цифры на светлой плашке
	model_name.outline_size = 0
	model_name.position = Vector3(0, 1.36, 0.32)
	fridge.add_child(model_name)
	var stove := _furniture("kitchen_stove", Vector3(X0 + 0.3, 0, 5.0), PI / 2,
		Vector3(0.5, 0.88, 0.58))
	# На холодильнике — красная мухобойка.
	var swatter := _model("kitchen_swatter")
	swatter.position = Vector3(X0 + 0.32, 1.5, 4.12)
	swatter.rotation.y = 0.5
	add_child(swatter)
	oven = KitchenOven.new() # дверца духовки откидывается, внутри — курица
	stove.add_child(oven)
	# Над плитой — плакат «Береги рабочее время!» (часы и рабочий с молотом).
	if apartment:
		apartment.poster("kitchen_time", Vector2(0.5, 0.7), Vector3(X0 + 0.012, 1.95, 5.0), PI / 2)
	# Под окном — мойка (лицом от окна, −Z), правее — навесной шкафчик.
	sink = KitchenSink.new()
	sink.position = Vector3(WINDOW_X, 0, Z1 - 0.31)
	sink.rotation.y = PI
	add_child(sink)
	if apartment:
		sink.add_child(apartment.contact_shadow(Vector2(1.0, 0.62)))
	cabinet = KitchenCabinet.new()
	cabinet.position = Vector3(-1.9, 1.5, Z1 - 0.16)
	cabinet.rotation.y = PI
	add_child(cabinet)
	# У правой стены — стол с клеёнкой (длинной стороной вдоль стены) и три табуретки.
	var table_pos := Vector3(X1 - 0.36, 0, 5.3)
	_furniture("kitchen_table", table_pos, PI / 2, Vector3(1.0, 0.75, 0.7))
	for z: float in [4.95, 5.65]:
		_tippable(APT + "stool.glb", Vector3(X1 - 0.95, 0, z), Vector3(0.36, 0.47, 0.36), 0.24)
	# Третья — у дальнего торца стола (у ближнего загораживала проход от двери).
	_tippable(APT + "stool.glb", Vector3(X1 - 0.36, 0, 6.05), Vector3(0.36, 0.47, 0.36), 0.24)
	# Чайник — на дальней левой конфорке (если смотреть на плиту).
	_breakable(DIR + "kitchen_kettle.glb", stove.to_global(Vector3(-0.12, 0.878, -0.14)),
		[Color("d9561a"), Color("1c1c1c"), Color("cfcfcf")], 0.4)
	# На столе — бутылка и два гранёных стакана: пустой и с тёмно-бордовым (бьются).
	_restock_bottle()
	_breakable(DIR + "kitchen_tumbler.glb", Vector3(table_pos.x + 0.1, 0.75, 5.42),
		[Color(0.85, 0.92, 0.95, 0.6)], 0.3, 0.03)
	_breakable(DIR + "kitchen_tumbler_wine.glb", Vector3(table_pos.x - 0.08, 0.75, 5.55),
		[Color(0.85, 0.92, 0.95, 0.6), Color("4a0812")], 0.3, 0.03)
	# Радиоточка стоит на маленькой полочке на правой стене над столом; бьётся, через 7 сек
	# появляется снова.
	var shelf_mat := _mat(Color("8a5a32"), 0.6)
	_box(Vector3(0.14, 0.02, 0.32), Vector3(X1 - 0.07, 1.4, 4.85), shelf_mat)
	for z: float in [4.74, 4.96]:
		_box(Vector3(0.02, 0.08, 0.02), Vector3(X1 - 0.01, 1.35, z), shelf_mat) # кронштейны
	var radio := _breakable(DIR + "kitchen_radio.glb", Vector3(X1 - 0.07, 1.418, 4.85),
		[Color("e6d9b8"), Color("5a3320")], 0.35, 0.04)
	radio.rotation.y = -PI / 2 # лицом в кухню (−X)
	radio.respawn_time = 7.0
	# Пачка соды на столешнице справа от мойки.
	var soda := _breakable(DIR + "kitchen_soda.glb", sink.to_global(Vector3(0.3, 0.86, -0.16)),
		[Color("c81e16"), Color("ffe628"), Color("fafaf5")], 0.3, 0.035)
	soda.rotation.y = PI - 0.25 # этикеткой к тому, кто стоит перед мойкой


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


## Отрывной календарь на правой стене (как настоящий): толстый блок листков, сверху золотистая
## планка со скрепкой и рваные остатки оторванных листков. На листке — «КАЛЕНДАРЬ», большое
## число и день недели по часам компьютера; в субботу и воскресенье — красные, иначе чёрные.
func _build_calendar() -> void:
	# Календарь бьётся (кулаком, молотком) и через 6 сек появляется снова: модель — внутри
	# Breakable, точка вещи — на 15 см ниже середины (прицел удара берёт +0.15).
	var item := Breakable.new()
	item.position = Vector3(X1 - 0.011, 1.47, 5.95)
	item.rotation.y = -PI / 2 # лицом в кухню
	add_child(item)
	var pad := Node3D.new()
	pad.position = Vector3(0, 0.15, 0)
	add_child(pad)
	var paper := _mat(Color("f3f0e8"), 0.9)
	var stack := _box(Vector3(0.15, 0.2, 0.03), Vector3(0, 0, 0.015), _mat(Color("dcd6c8"), 0.95))
	stack.reparent(pad, false)
	var sheet := _box(Vector3(0.146, 0.196, 0.002), Vector3(0, -0.002, 0.031), paper)
	sheet.reparent(pad, false)
	var torn := _box(Vector3(0.152, 0.012, 0.033), Vector3(0, 0.104, 0.0165),
		_mat(Color("e9e4d6"), 1.0))
	torn.reparent(pad, false) # рваные остатки листков под планкой
	var gold := _mat(Color("c9a43c"), 0.25)
	gold.metallic = 0.8
	var bar := _box(Vector3(0.16, 0.035, 0.038), Vector3(0, 0.125, 0.019), gold)
	bar.reparent(pad, false)
	var blue := _mat(Color("2a4f9a"), 0.4)
	for x: float in [-0.022, 0.022]:
		var dot := _box(Vector3(0.012, 0.012, 0.002), Vector3(x, 0.125, 0.0385), blue)
		dot.reparent(pad, false)
	var staple := _box(Vector3(0.044, 0.002, 0.002), Vector3(0, 0.125, 0.0395),
		_mat(Color("b0b0b0"), 0.3))
	staple.reparent(pad, false)
	var date := Time.get_date_dict_from_system()
	var weekday := int(date["weekday"]) # 0 — воскресенье, 6 — суббота
	var ink := Color("c4172c") if weekday == 0 or weekday == 6 else Color("1c1c1c")
	var title := _calendar_label(pad, "КАЛЕНДАРЬ", 26, Color("1c1c1c"), 0.075)
	title.outline_size = 5 # обводка тем же цветом — буквы жирнее
	title.outline_modulate = Color("1c1c1c")
	_calendar_label(pad, str(date["day"]), 150, ink, -0.005)
	_calendar_label(pad, WEEKDAYS[weekday], 28, ink, -0.08)
	remove_child(pad) # setup_model сам кладёт модель внутрь вещи
	var shards: Array[Color] = [Color("f3f0e8"), Color("c9a43c"), Color("c4172c")]
	item.setup_model(pad, shards, 0.25, 0.035)
	item.respawn_time = 6.0


func _calendar_label(pad: Node3D, text: String, size: int, color: Color, y: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.0005
	label.modulate = color
	label.outline_size = 0
	label.position = Vector3(0, y, 0.0325)
	pad.add_child(label)
	return label


# ---------------- Для лобби: что перед игроком ----------------

## Взять бутылку со стола (через BOTTLE_BACK сек на её месте появится новая).
func take_bottle() -> KitchenBottle:
	var taken := bottle
	bottle = null
	get_tree().create_timer(BOTTLE_BACK).timeout.connect(_restock_bottle)
	return taken


func _restock_bottle() -> void:
	if bottle != null:
		return
	bottle = KitchenBottle.new()
	bottle.position = BOTTLE_POS
	add_child(bottle)

## Шкафчик или духовка ближе radius и в поле взгляда (если оба — тот, что ближе к центру
## взгляда); null — нет.
func hinged_near(character: Node3D, radius: float) -> HingedProp:
	var best: HingedProp = null
	for prop: HingedProp in [cabinet, oven]:
		if prop == null:
			continue
		var point := prop.front_point()
		var flat := Vector2(point.x - character.global_position.x,
			point.z - character.global_position.z)
		if flat.length() >= radius or not LobbyGadgets.facing(character, point, 35.0):
			continue
		if best == null or view_angle(character, point) < view_angle(character, best.front_point()):
			best = prop
	return best


## На сколько градусов точка в стороне от взгляда персонажа (по горизонтали).
static func view_angle(character: Node3D, point: Vector3) -> float:
	var to := point - character.global_position
	to.y = 0.0
	var forward := -character.global_basis.z
	forward.y = 0.0
	if to.length() < 0.01 or forward.length() < 0.01:
		return 0.0
	return rad_to_deg(forward.angle_to(to))


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
