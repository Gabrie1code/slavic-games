class_name ToiletRoom
extends Node3D
## Туалет квартиры: маленькая комната правее гостиной, перед спальней
## (X 3.1..5.4, Z 1.7..3.5), дверной проём — из гостиной в стене x = 3.1.
## Стены внизу покрашены масляной краской (видно и сверху), выше — побелка только для вида
## от первого лица (как потолок и передние стены квартиры). Правая стена — на своём слое
## WALL_LAYER / WALL_HIGH_LAYER: камера «вид сбоку» на унитаз её не рисует и смотрит сквозь неё.
## Внутри: унитаз (Toilet), лампочка на проводе, рулон бумаги, газета на гвозде.

const WALL_LAYER := 1 << 14
## Верх правой стены: видят только камеры от первого лица (общая камера лобби его не рисует —
## как FP_ONLY_LAYER), и тоже не видит «вид сбоку».
const WALL_HIGH_LAYER := 1 << 5
const X0 := 3.1 # стена с дверью (общая с гостиной)
const X1 := 5.4
const Z0 := 1.74 # перед стеной спальни (её передняя стенка видна от первого лица)
const Z1 := 3.5
const DOOR_FROM_Z := 2.45
const DOOR_TO_Z := 3.3
const DOOR_TOP := 2.1
const PAINT_HEIGHT := 1.2
const HEIGHT := 3.0
const TILES := preload("res://assets/textures/toilet/floor_tiles.png")

var toilet: Toilet

var _paint: StandardMaterial3D
var _whitewash: StandardMaterial3D


func _ready() -> void:
	_paint = _mat(Color("6f9fa8"))
	_whitewash = _mat(Color("ece8dc"))
	_build_floor()
	_build_door_wall()
	_build_walls()
	toilet = Toilet.new()
	toilet.position = Vector3((X0 + X1) / 2.0 + 0.1, 0, Z0)
	add_child(toilet)
	_build_details()


func _build_floor() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = TILES
	floor_mat.roughness = 0.35
	floor_mat.uv1_triplanar = true
	floor_mat.uv1_world_triplanar = true
	floor_mat.uv1_scale = Vector3.ONE # текстура на 1 м: плитка 12.5 см
	# От края пола спальни (z = 1.5) до передней стены.
	_solid(Vector3(X1 - X0, 0.2, Z1 - 1.5), Vector3((X0 + X1) / 2.0, -0.1, (1.5 + Z1) / 2.0),
		floor_mat)


## Стена с дверью: со стороны гостиной обои, внутри — краска и побелка.
func _build_door_wall() -> void:
	var wallpaper := _mat(Color("c9b48a"))
	for span: Vector2 in [Vector2(Z0 - 0.24, DOOR_FROM_Z), Vector2(DOOR_TO_Z, Z1)]:
		var length := span.y - span.x
		var mid := (span.x + span.y) / 2.0
		# Низ до 2.4 м виден всегда (как перегородка между комнатами), выше — только от 1-го лица.
		_solid(Vector3(0.12, 2.4, length), Vector3(X0, 1.2, mid), wallpaper)
		_fp_only(Vector3(0.12, HEIGHT - 2.4, length), Vector3(X0, 2.4 + (HEIGHT - 2.4) / 2.0, mid),
			wallpaper)
		_inner_faces(Vector3(0.02, 0, length), Vector3(X0 + 0.07, 0, mid))
	var door_len := DOOR_TO_Z - DOOR_FROM_Z
	var door_mid := (DOOR_FROM_Z + DOOR_TO_Z) / 2.0
	_box(Vector3(0.12, 2.4 - DOOR_TOP, door_len), Vector3(X0, (2.4 + DOOR_TOP) / 2.0, door_mid),
		wallpaper)
	_fp_only(Vector3(0.12, HEIGHT - 2.4, door_len),
		Vector3(X0, 2.4 + (HEIGHT - 2.4) / 2.0, door_mid), wallpaper)
	# Табличка над дверью со стороны гостиной.
	var plate := _box(Vector3(0.02, 0.16, 0.36), Vector3(X0 - 0.07, DOOR_TOP + 0.15, door_mid),
		_mat(Color("f2efe6")))
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sign_text := Label3D.new()
	sign_text.text = "ТУАЛЕТ"
	sign_text.font_size = 40
	sign_text.outline_size = 0
	sign_text.modulate = Color("2a5a8a")
	sign_text.position = Vector3(X0 - 0.085, DOOR_TOP + 0.15, door_mid)
	sign_text.rotation.y = -PI / 2.0
	add_child(sign_text)


## Задняя, правая и передняя стены.
func _build_walls() -> void:
	var width := X1 - X0
	var depth := Z1 - Z0
	# Задняя (у бачка): краска внизу видна всегда, побелка — от первого лица.
	_inner_faces(Vector3(width, 0, 0.02), Vector3((X0 + X1) / 2.0, 0, Z0 + 0.01))
	# Правая: на своём слое — «вид сбоку» смотрит сквозь неё.
	var right_low := _box(Vector3(0.12, PAINT_HEIGHT, depth),
		Vector3(X1 + 0.06, PAINT_HEIGHT / 2.0, (Z0 + Z1) / 2.0), _paint)
	right_low.layers = WALL_LAYER
	var right_high := _box(Vector3(0.12, HEIGHT - PAINT_HEIGHT, depth),
		Vector3(X1 + 0.06, PAINT_HEIGHT + (HEIGHT - PAINT_HEIGHT) / 2.0, (Z0 + Z1) / 2.0), _whitewash)
	right_high.layers = WALL_HIGH_LAYER
	right_high.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_collider(Vector3(0.2, HEIGHT, depth + 0.4), Vector3(X1 + 0.1, HEIGHT / 2.0, (Z0 + Z1) / 2.0))
	# Передняя — как у всей квартиры: невидимая стенка и стена только от первого лица.
	_collider(Vector3(width + 0.2, HEIGHT, 0.4), Vector3((X0 + X1) / 2.0, HEIGHT / 2.0, Z1 + 0.2))
	_fp_only(Vector3(width, HEIGHT, 0.2), Vector3((X0 + X1) / 2.0, HEIGHT / 2.0, Z1 + 0.1),
		_whitewash)


## Внутренняя отделка стены: краска до PAINT_HEIGHT (+ тёмная полоска по краю), выше побелка.
## size.y не используется: высоты берутся из констант.
func _inner_faces(size: Vector3, pos: Vector3) -> void:
	_box(Vector3(size.x, PAINT_HEIGHT, size.z), Vector3(pos.x, PAINT_HEIGHT / 2.0, pos.z), _paint)
	var stripe := Vector3(size.x + 0.004, 0.03, size.z + 0.004)
	_box(stripe, Vector3(pos.x, PAINT_HEIGHT, pos.z), _mat(Color("3d6670")))
	_fp_only(Vector3(size.x, HEIGHT - PAINT_HEIGHT, size.z),
		Vector3(pos.x, PAINT_HEIGHT + (HEIGHT - PAINT_HEIGHT) / 2.0, pos.z), _whitewash)


## Лампочка на проводе, рулон бумаги, газета на гвозде.
func _build_details() -> void:
	var center_x := (X0 + X1) / 2.0
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.6)
	light.light_energy = 0.9
	light.omni_range = 3.0
	light.position = Vector3(center_x, 2.45, (Z0 + Z1) / 2.0)
	add_child(light)
	var bulb_mat := _mat(Color(1.0, 0.95, 0.8))
	bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bulb := _sphere(0.05, light.position, bulb_mat)
	bulb.layers = Apartment.FP_ONLY_LAYER
	var wire := _box(Vector3(0.01, 0.5, 0.01), light.position + Vector3(0, 0.3, 0), _mat(Color.BLACK))
	wire.layers = Apartment.FP_ONLY_LAYER
	# Рулон на правой стене (держатель — палочка).
	var roll := MeshInstance3D.new()
	var roll_mesh := CylinderMesh.new()
	roll_mesh.top_radius = 0.055
	roll_mesh.bottom_radius = 0.055
	roll_mesh.height = 0.1
	roll.mesh = roll_mesh
	roll.material_override = _mat(Color("f4f1ea"))
	roll.rotation.x = PI / 2.0 # ось вдоль стены
	roll.position = Vector3(X1 - 0.08, 0.72, Z0 + 0.75)
	add_child(roll)
	# Газета «Правда» на гвозде — на стене с дверью.
	var paper := _box(Vector3(0.01, 0.32, 0.24), Vector3(X0 + 0.09, 0.95, Z0 + 0.35),
		_mat(Color("d9d4c4")))
	paper.rotation.x = 0.06
	var title := Label3D.new()
	title.text = "ПРАВДА"
	title.font_size = 18
	title.outline_size = 0
	title.modulate = Color("1a1a1a")
	title.position = Vector3(X0 + 0.1, 1.06, Z0 + 0.35)
	title.rotation.y = PI / 2.0
	add_child(title)


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat


func _box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = pos
	add_child(mesh_instance)
	return mesh_instance


func _sphere(radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = pos
	add_child(mesh_instance)
	return mesh_instance


func _fp_only(size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh_instance := _box(size, pos, material)
	mesh_instance.layers = Apartment.FP_ONLY_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
