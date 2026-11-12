class_name GarageYard
extends Node3D
## Двор вокруг крыши гаражей (декорации «Битвы на битах»), собирается кодом из моделей
## assets/models/courtyard/:
##   сзади — хрущёвка с бельём, тарелками и антеннами; по бокам — деревья и фонари;
##   спереди — разбитый асфальт и лужи, чёрный «гелик» (без эмблем), «копейка» на кирпичах,
##   мусорные баки, бочки, ящики, лестница к крыше; на воротах — номера, замки и надписи.
## Голуби сидят только по краям крыши и улетают (сами или если рядом боец);
## под гаражами бродит собака.
## Если боец падает на гелик — у гелика мигают фары и поворотники (но падение всё равно выбивает).

const DIR := "res://assets/models/courtyard/"
## Земля во дворе (верх земли) и крыша гаражей.
const GROUND_Y := -3.4
const ROOF_HALF := Vector2(8.5, 4.5)
const DOOR_X: Array[float] = [-6.375, -2.125, 2.125, 6.375]
const DOOR_Z := 4.58
const GELIK_POS := Vector3(4.6, GROUND_Y, 6.35)
const PIGEON_COUNT := 6
const GRAFFITI: Array[String] = ["ЦОЙ ЖИВ", "СПАРТАК —\nЧЕМПИОН", "Здесь был\nВася", "КИНО"]
const GRAFFITI_COLORS: Array[Color] = [
	Color(0.95, 0.95, 0.9), Color(0.9, 0.2, 0.2), Color(0.3, 0.6, 1.0), Color(0.95, 0.8, 0.2),
]

## Бойцы: голуби улетают, если кто-то из них рядом.
var watchers: Array[Node3D] = []

var _pigeons: Array[YardPigeon] = []
var _gelik_lights: Node3D
var _gelik_light: OmniLight3D
var _blink_tween: Tween


func _ready() -> void:
	_build_ground()
	_build_buildings()
	_build_front()
	_build_garage_details()
	var dog := YardDog.new()
	dog.position = Vector3(0, GROUND_Y, 4.95)
	add_child(dog)
	for i in PIGEON_COUNT:
		_spawn_pigeon(false)


func _process(delta: float) -> void:
	for pigeon in _pigeons:
		if pigeon.flying:
			continue
		for body in watchers:
			if is_instance_valid(body) and body.visible \
					and body.global_position.distance_to(pigeon.global_position) < YardPigeon.SCARE_DISTANCE:
				pigeon.fly_away(body.global_position)
				break
		# Иногда голубь улетает сам по себе.
		if not pigeon.flying and randf() < delta * 0.02:
			pigeon.fly_away(pigeon.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))


## Мигнуть фарами гелика (на него кто-то упал).
func blink_gelik() -> void:
	if _blink_tween:
		_blink_tween.kill()
	_blink_tween = create_tween()
	for i in 6:
		_blink_tween.tween_callback(_set_gelik_lights.bind(true))
		_blink_tween.tween_interval(0.18)
		_blink_tween.tween_callback(_set_gelik_lights.bind(false))
		_blink_tween.tween_interval(0.14)


# ---------------- Голуби ----------------

func _spawn_pigeon(fly_in: bool) -> void:
	var pigeon := YardPigeon.new()
	add_child(pigeon)
	var spot := _edge_spot()
	pigeon.flown.connect(_on_pigeon_flown)
	_pigeons.append(pigeon)
	if fly_in:
		pigeon.land_at(spot)
	else:
		pigeon.global_position = spot
		pigeon.rotation.y = randf() * TAU


func _on_pigeon_flown(pigeon: YardPigeon) -> void:
	_pigeons.erase(pigeon)
	# Через какое-то время прилетит другой голубь.
	get_tree().create_timer(randf_range(6.0, 14.0)).timeout.connect(_spawn_pigeon.bind(true))


## Случайная точка на краю крыши (только по краям, не посередине).
func _edge_spot() -> Vector3:
	var inset := 0.18
	if randf() < 0.5:
		var x := randf_range(-ROOF_HALF.x + 0.5, ROOF_HALF.x - 0.5)
		var z := (ROOF_HALF.y - inset) * (1.0 if randf() < 0.5 else -1.0)
		return Vector3(x, 0.0, z)
	var z2 := randf_range(-ROOF_HALF.y + 0.5, ROOF_HALF.y - 0.5)
	var x2 := (ROOF_HALF.x - inset) * (1.0 if randf() < 0.5 else -1.0)
	return Vector3(x2, 0.0, z2)


# ---------------- Земля ----------------

func _build_ground() -> void:
	var asphalt := _mat(Color(0.27, 0.27, 0.28), 0.95)
	_box(Vector3(34, 0.04, 14), Vector3(0, GROUND_Y + 0.02, 11.5), asphalt)
	_box(Vector3(34, 0.04, 4), Vector3(0, GROUND_Y + 0.02, -6.5), asphalt) # проезд сзади
	# Разбитый асфальт: заплатки и ямы разных оттенков.
	var rng := RandomNumberGenerator.new()
	rng.seed = 90
	for i in 26:
		var shade := rng.randf_range(0.18, 0.36)
		var patch := _mat(Color(shade, shade, shade * 1.03), 1.0)
		var size := Vector3(rng.randf_range(0.6, 2.4), 0.02, rng.randf_range(0.4, 1.6))
		var pos := Vector3(rng.randf_range(-15, 15), GROUND_Y + 0.045, rng.randf_range(5.0, 17.0))
		_box(size, pos, patch).rotation.y = rng.randf_range(0, PI)
	# Лужи: тёмные и блестящие.
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.18, 0.22, 0.27)
	water.metallic = 0.6
	water.roughness = 0.05
	for spot: Vector3 in [Vector3(-1.2, 0, 6.2), Vector3(0.9, 0, 7.3), Vector3(-9.5, 0, 8.0),
			Vector3(11.0, 0, 5.8), Vector3(-12.5, 0, 3.0), Vector3(7.8, 0, 8.5)]:
		var puddle := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = rng.randf_range(0.6, 1.3)
		mesh.bottom_radius = mesh.top_radius
		mesh.height = 0.02
		mesh.radial_segments = 14
		puddle.mesh = mesh
		puddle.material_override = water
		puddle.position = spot + Vector3(0, GROUND_Y + 0.06, 0)
		puddle.scale = Vector3(1.0, 1.0, rng.randf_range(0.5, 0.9))
		add_child(puddle)


# ---------------- Дома, деревья, фонари ----------------

func _build_buildings() -> void:
	_place("khrushchevka", Vector3(0, GROUND_Y, -13.5))
	_place("khrushchevka", Vector3(-31, GROUND_Y, -8.0), PI / 4)
	_place("khrushchevka", Vector3(31, GROUND_Y, -8.0), -PI / 4)
	for spot: Vector3 in [Vector3(-12.5, 0, -2.0), Vector3(13.0, 0, 1.0), Vector3(-11.0, 0, -6.5),
			Vector3(10.5, 0, -6.8)]:
		var model := "tree_poplar" if int(spot.x) % 2 == 0 else "tree_birch"
		_place(model, spot + Vector3(0, GROUND_Y, 0), randf() * TAU)
	_place("tree_birch", Vector3(-14.5, GROUND_Y, 9.0))
	for x in [-10.5, 10.5]:
		_place("lamp_post", Vector3(x, GROUND_Y, 9.5), PI) # плафон смотрит к гаражам


# ---------------- Перед гаражами ----------------

func _build_front() -> void:
	# Гелик: твёрдый (на него можно упасть), сверху датчик падения.
	var gelik := _solid("gelik", Vector3(4.7, 2.3, 1.95), GELIK_POS)
	_gelik_lights = _model("gelik_lights")
	gelik.add_child(_gelik_lights)
	_gelik_lights.visible = false
	_gelik_light = OmniLight3D.new()
	_gelik_light.light_color = Color(1.0, 0.7, 0.3)
	_gelik_light.light_energy = 3.0
	_gelik_light.omni_range = 5.0
	_gelik_light.position = Vector3(0, 1.4, 0)
	_gelik_light.visible = false
	gelik.add_child(_gelik_light)
	var sensor := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.8, 1.2, 2.1)
	shape.shape = box
	shape.position.y = 2.6
	sensor.add_child(shape)
	sensor.body_entered.connect(func(body: Node3D) -> void:
		if body is CharacterBody3D:
			blink_gelik())
	gelik.add_child(sensor)

	_solid("kopeyka", Vector3(4.1, 1.7, 1.65), Vector3(-4.4, GROUND_Y, 6.6), PI)
	_solid("trash_bin", Vector3(1.5, 1.2, 1.0), Vector3(-10.4, GROUND_Y, 6.4))
	_solid("trash_bin", Vector3(1.5, 1.2, 1.0), Vector3(-12.1, GROUND_Y, 6.3), 0.1)
	_solid("barrel", Vector3(0.65, 0.9, 0.65), Vector3(9.4, GROUND_Y, 3.3))
	_solid("barrel", Vector3(0.65, 0.9, 0.65), Vector3(9.9, GROUND_Y, 2.5))
	_solid("crate", Vector3(0.6, 0.55, 0.6), Vector3(9.4, GROUND_Y, 1.4), 0.3)
	_solid("crate", Vector3(0.6, 0.55, 0.6), Vector3(9.5, GROUND_Y + 0.55, 1.45), 0.8)
	_solid("crate", Vector3(0.6, 0.55, 0.6), Vector3(-9.3, GROUND_Y, -1.5), 0.5)
	_place("barrel", Vector3(-9.4, GROUND_Y, -2.6))
	# Лестница прислонена к боковой стене гаражей (верх — у края крыши).
	var ladder := _place("ladder", Vector3(ROOF_HALF.x + 1.18, GROUND_Y, -2.4))
	ladder.rotation = Vector3(-0.335, PI / 2, 0)


## Номера, замки и надписи на воротах гаражей.
func _build_garage_details() -> void:
	for i in DOOR_X.size():
		var x := DOOR_X[i]
		var number := Label3D.new()
		number.text = "№ %d" % [17, 18, 21, 23][i]
		number.font_size = 64
		number.outline_size = 0
		number.modulate = Color(0.95, 0.92, 0.85)
		number.pixel_size = 0.006
		number.position = Vector3(x + 1.2, -0.9, DOOR_Z)
		add_child(number)
		var lock := _place("padlock", Vector3(x + 0.12, -2.65, DOOR_Z + 0.03))
		lock.scale = Vector3.ONE * 1.4
		var graffiti := Label3D.new()
		graffiti.text = GRAFFITI[i]
		graffiti.font_size = 96
		graffiti.outline_size = 0
		graffiti.modulate = GRAFFITI_COLORS[i]
		graffiti.pixel_size = 0.006
		graffiti.position = Vector3(x - 0.5, -1.9, DOOR_Z + 0.01)
		graffiti.rotation.z = randf_range(-0.12, 0.12)
		add_child(graffiti)


func _set_gelik_lights(on: bool) -> void:
	_gelik_lights.visible = on
	_gelik_light.visible = on


# ---------------- Помощники ----------------

func _model(model_name: String) -> Node3D:
	return (load(DIR + model_name + ".glb") as PackedScene).instantiate() as Node3D


func _place(model_name: String, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var node := _model(model_name)
	add_child(node)
	node.position = pos
	node.rotation.y = yaw
	return node


## Неподвижная вещь с коробкой столкновений (размер size, низ коробки — на земле).
## Модели машин в Blender лежат вдоль X — коробка тоже.
func _solid(model_name: String, size: Vector3, pos: Vector3, yaw: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.add_child(_model(model_name))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y / 2.0
	body.add_child(shape)
	add_child(body)
	body.position = pos
	body.rotation.y = yaw
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


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m
