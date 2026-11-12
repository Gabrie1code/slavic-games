class_name StreetBackdrop
extends Node3D
## Улица вокруг ларька «Колбаса» (только декорации, без столкновений — игроки стоят в очереди):
## тротуар из плитки, бордюр, дорога с разметкой, газон с деревьями, хрущёвки на заднем плане,
## фонарь с объявлением, лавочка, мусорный бак, «копейка» у обочины и голуби.
## Ларёк стоит в (0, 0, −3), очередь — на линии z = 0.4, бордюр — z = 3.5.

const COURTYARD := "res://assets/models/courtyard/"
const PLAYGROUND := "res://assets/models/playground/"
const TEX := "res://assets/textures/street/"
const CURB_Z := 3.5
const ROAD_FAR_Z := 12.0
const LAWN_Z := -6.5


func _ready() -> void:
	_build_ground()
	_build_background()
	_build_street_props()


## Земля: плитка до бордюра, бордюр, дорога с прерывистой линией, газон за ларьком.
func _build_ground() -> void:
	var tiles := _textured(TEX + "sidewalk.png", 0.5)
	_box(Vector3(60, 0.1, CURB_Z - LAWN_Z), Vector3(0, -0.05, (CURB_Z + LAWN_Z) / 2.0), tiles)
	var asphalt := _textured(TEX + "asphalt.png", 0.25)
	_box(Vector3(60, 0.1, ROAD_FAR_Z - CURB_Z), Vector3(0, -0.12, (CURB_Z + ROAD_FAR_Z) / 2.0),
		asphalt)
	var curb := _plain(Color(0.78, 0.76, 0.71))
	_box(Vector3(60, 0.18, 0.3), Vector3(0, 0.0, CURB_Z), curb)
	var paint := _plain(Color(0.92, 0.92, 0.86))
	for i in 15:
		_box(Vector3(2.0, 0.02, 0.15), Vector3(-28.0 + i * 4.0, -0.06, 8.0), paint)
	var lawn := _plain(Color(0.33, 0.5, 0.22))
	_box(Vector3(60, 0.1, 9.0), Vector3(0, -0.08, LAWN_Z - 4.5), lawn)
	_box(Vector3(60, 0.1, 30.0), Vector3(0, -0.1, -26.0), lawn)


## Задний план: хрущёвки, тополя и берёзы вдоль газона.
func _build_background() -> void:
	_place(COURTYARD + "khrushchevka", Vector3(-3.0, 0, -20.0))
	_place(COURTYARD + "khrushchevka", Vector3(-27.0, 0, -9.0), PI / 2.5)
	_place(COURTYARD + "khrushchevka", Vector3(25.0, 0, -14.0), -PI / 3.0)
	var trees: Array[Vector3] = [
		Vector3(-9.0, 0, -8.0), Vector3(-5.5, 0, -9.5), Vector3(4.0, 0, -8.5),
		Vector3(7.5, 0, -10.0), Vector3(11.0, 0, -8.0), Vector3(-13.0, 0, -9.0),
	]
	for i in trees.size():
		var model := "tree_poplar" if i % 2 == 0 else "tree_birch"
		_place(COURTYARD + model, trees[i], randf() * TAU)
	_place(COURTYARD + "bush_wide", Vector3(-3.5, 0, -7.0))
	_place(COURTYARD + "bush_round", Vector3(2.8, 0, -7.2))


## Вещи на тротуаре и у дороги.
func _build_street_props() -> void:
	_place(PLAYGROUND + "bench", Vector3(3.8, 0, -2.6))
	_place(COURTYARD + "trash_bin", Vector3(-5.2, 0, -4.6), 0.3)
	_place(COURTYARD + "lamp_post", Vector3(-4.2, 0, 3.0), PI)
	# Объявление на фонарном столбе — лицом к очереди и камере.
	var notice := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.75)
	notice.mesh = quad
	var notice_mat := StandardMaterial3D.new()
	notice_mat.albedo_texture = load(TEX + "queue_notice.png")
	notice.material_override = notice_mat
	notice.position = Vector3(-4.2, 1.8, 3.12)
	notice.rotation.y = 0.5
	add_child(notice)
	# «Копейка» у обочины.
	_place(COURTYARD + "kopeyka", Vector3(-6.0, -0.07, 5.2), PI / 2)
	# Голуби ждут крошек от колбасы (клюют и крутят головой, как во дворе с гаражами).
	var pigeons: Array[Vector3] = [Vector3(2.7, 0, 2.0), Vector3(3.2, 0, 2.5), Vector3(-3.0, 0, 1.8)]
	for spot in pigeons:
		var pigeon := YardPigeon.new()
		pigeon.position = spot
		pigeon.rotation.y = randf() * TAU
		pigeon.scale = Vector3.ONE * 1.2
		add_child(pigeon)


func _textured(path: String, scale: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(path)
	mat.roughness = 0.95
	# Текстура привязана к миру: плитка не растягивается на длинных коробках.
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale
	return mat


func _plain(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


func _box(size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = pos
	add_child(mesh_instance)


func _place(path: String, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var node := (load(path + ".glb") as PackedScene).instantiate() as Node3D
	add_child(node)
	node.position = pos
	node.rotation.y = yaw
	return node
