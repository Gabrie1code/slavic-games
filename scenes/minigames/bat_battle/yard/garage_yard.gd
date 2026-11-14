class_name GarageYard
extends Node3D
## Двор вокруг крыши гаражей (декорации «Битвы на битах»), собирается кодом из моделей
## assets/models/courtyard/:
##   сзади — хрущёвка с бельём, тарелками и антеннами; по бокам — деревья и фонари;
##   спереди — разбитый асфальт и лужи, чёрный «гелик» (без эмблем), «копейка» на кирпичах,
##   мусорные баки, бочки, ящики, лестница к крыше; на воротах — номера, замки и надписи.
## Баки стоят наискосок; правый приоткрыт и полон мусора, на его углу сидит «местный» голубь.
## Второй гараж («№18») приоткрыт — внутри картинка-заглушка (garage_inside.png) и лампочка.
## Асфальт: площадка перед гаражами, тротуар вдоль дома сзади (подъезды выходят прямо на него),
## тротуары у боковых домов и проезды по бокам от гаражей — всё одним цветом и на одной высоте.
## Голуби сидят по краям крыши и на мусорных баках и улетают (сами или если рядом боец);
## под гаражами бродит собака. У баков — чёрные мусорные мешки, на асфальте лужи и люки.
## За партию 1–2 раза случайная дверь подъезда хрущёвки сама открывается и закрывается.
## Если боец падает на гелик — у гелика мигают фары и поворотники (но падение всё равно выбивает).

const DIR := "res://assets/models/courtyard/"
## Земля во дворе (верх земли) и крыша гаражей.
const GROUND_Y := -3.4
const ROOF_HALF := Vector2(8.5, 4.5)
const DOOR_X: Array[float] = [-6.375, -2.125, 2.125, 6.375]
const DOOR_Z := 4.58
const GELIK_POS := Vector3(4.6, GROUND_Y, 6.35)
const PIGEON_COUNT := 6
## Мусорные баки: правый (открытый, с мусором) и левый (закрыт, на него садятся голуби).
## Стоят в ряд наискосок (поворот BIN_YAW).
const BINS: Array[Vector3] = [Vector3(-10.4, GROUND_Y, 6.4), Vector3(-11.98, GROUND_Y, 7.16)]
const BIN_YAW := 0.45
## Приоткрытый гараж (номер в DOOR_X) и на сколько открыта правая створка.
const OPEN_GARAGE := 1
const OPEN_LEAF_ANGLE := 0.6
## Лужи и люки на асфальте перед гаражами.
const PUDDLES: Array[Vector3] = [Vector3(-1.2, 0, 6.2), Vector3(0.9, 0, 7.6), Vector3(-8.2, 0, 9.4),
	Vector3(11.6, 0, 6.4), Vector3(7.8, 0, 9.0)]
const MANHOLES: Array[Vector3] = [Vector3(2.6, 0, 10.2), Vector3(-6.8, 0, 13.4)]
## Хрущёвка сзади и её подъезды (x дверей — как в tools/blender/courtyard.py).
const HOUSE_POS := Vector3(0, GROUND_Y, -13.5)
const ENTRANCE_X: Array[float] = [-8.145, 1.164, 10.473]
const ENTRANCE_Z := 5.57
const GARAGE_NUMBERS: Array[int] = [17, 18, 21, 23]
## Граффити на воротах (имена картинок в assets/textures/garage/).
const GRAFFITI: Array[String] = [
	"graffiti_tsoi", "", "graffiti_vasya", "graffiti_kino",
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
	_build_trash_bags()
	_build_open_garage()
	_schedule_doors()


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


## Случайная точка на краю крыши (только по краям, не посередине) или на мусорном баке.
func _edge_spot() -> Vector3:
	var inset := 0.18
	if randf() < 0.2: # на закрытый бак (открытый занят «местным» голубем)
		var offset := Vector3(randf_range(-0.55, 0.55), 1.22, randf_range(-0.3, 0.3))
		return BINS[1] + offset.rotated(Vector3.UP, BIN_YAW)
	if randf() < 0.5:
		var x := randf_range(-ROOF_HALF.x + 0.5, ROOF_HALF.x - 0.5)
		var z := (ROOF_HALF.y - inset) * (1.0 if randf() < 0.5 else -1.0)
		return Vector3(x, 0.0, z)
	var z2 := randf_range(-ROOF_HALF.y + 0.5, ROOF_HALF.y - 0.5)
	var x2 := (ROOF_HALF.x - inset) * (1.0 if randf() < 0.5 else -1.0)
	return Vector3(x2, 0.0, z2)


# ---------------- Двери подъездов и мешки ----------------

## 1–2 раза за партию случайная дверь подъезда открывается (кто-то вышел) и закрывается.
func _schedule_doors() -> void:
	var doors: Array[Node3D] = []
	var door_mat := _mat(Color(0.35, 0.2, 0.1), 0.7)
	var dark := _mat(Color(0.04, 0.035, 0.03), 1.0)
	for x in ENTRANCE_X:
		var base := HOUSE_POS + Vector3(x, 0, ENTRANCE_Z)
		_box(Vector3(1.2, 2.1, 0.02), base + Vector3(0, 1.05, 0.01), dark) # темнота за дверью
		# Створка поворачивается на петле у левого края.
		var hinge := Node3D.new()
		hinge.position = base + Vector3(-0.65, 0, 0.05)
		add_child(hinge)
		var leaf := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.3, 2.2, 0.06)
		leaf.mesh = mesh
		leaf.material_override = door_mat
		leaf.position = Vector3(0.65, 1.1, 0)
		hinge.add_child(leaf)
		var handle := MeshInstance3D.new()
		var handle_mesh := BoxMesh.new()
		handle_mesh.size = Vector3(0.04, 0.2, 0.05)
		handle.mesh = handle_mesh
		handle.material_override = _mat(Color(0.75, 0.75, 0.7), 0.4)
		handle.position = Vector3(1.15, 1.0, 0.05)
		hinge.add_child(handle)
		doors.append(hinge)
	for i in randi_range(1, 2):
		var door: Node3D = doors.pick_random()
		var tween := create_tween()
		tween.tween_interval(randf_range(4.0, 40.0) + i * 10.0)
		tween.tween_property(door, "rotation:y", -1.7, 0.7).set_trans(Tween.TRANS_SINE)
		tween.tween_interval(randf_range(1.5, 3.0))
		tween.tween_property(door, "rotation:y", 0.0, 0.5).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_IN)


## Чёрные мусорные мешки у баков: модели trash_bag / trash_bag_fat (tools/blender/courtyard.py) —
## осевшее дно, складки, завязанные «ушки», матовый полиэтилен (раньше — блестящие шары).
func _build_trash_bags() -> void:
	var front := Vector3(sin(BIN_YAW), 0, cos(BIN_YAW)) # «лицо» баков
	var along := Vector3(cos(BIN_YAW), 0, -sin(BIN_YAW)) # вдоль ряда баков (вправо)
	var spots: Array[Vector3] = [
		BINS[0] + front * 0.95 - along * 0.35, BINS[0] + front * 0.85 + along * 0.5,
		BINS[0] + along * 1.2 + front * 0.15, BINS[1] + front * 0.95 + along * 0.1,
		BINS[1] - along * 1.15 + front * 0.25,
	]
	for i in spots.size():
		var bag := _place("trash_bag_fat" if i % 2 else "trash_bag", spots[i], i * 1.3)
		bag.rotation.z = (i % 3 - 1) * 0.08 # чуть завалился набок
		bag.scale = Vector3.ONE * (0.95 + (i % 3) * 0.08)
	# «Местный» голубь на переднем правом углу открытого бака: машет крыльями, не улетает.
	var pigeon := YardPigeon.new()
	pigeon.resident = true
	add_child(pigeon)
	pigeon.global_position = BINS[0] + Vector3(0.66, 1.1, 0.44).rotated(Vector3.UP, BIN_YAW)
	pigeon.rotation.y = BIN_YAW + 0.4


## Гараж OPEN_GARAGE приоткрыт: левая створка закрыта, правая открыта наружу; за ней —
## картинка внутренности (свет лампочки, полки, шины, велосипед) и тёплый свет.
func _build_open_garage() -> void:
	var x := DOOR_X[OPEN_GARAGE]
	var inside := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.24, 2.26)
	inside.mesh = quad
	var inside_mat := StandardMaterial3D.new()
	inside_mat.albedo_texture = load("res://assets/textures/garage/garage_inside.png")
	inside_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # полумрак уже нарисован
	inside.material_override = inside_mat
	inside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inside.position = Vector3(x, -2.25, 4.505)
	add_child(inside)
	var leaf_mat := _mat(Color(0.5, 0.23, 0.12), 0.8)
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(x + side * 1.65, -2.25, 4.53)
		hinge.rotation.y = OPEN_LEAF_ANGLE if side > 0.0 else 0.0
		add_child(hinge)
		var leaf := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.64, 2.3, 0.06)
		leaf.mesh = mesh
		leaf.material_override = leaf_mat
		leaf.position = Vector3(-side * 0.82, 0, 0)
		hinge.add_child(leaf)
		if side > 0.0: # номер — на открытой створке
			_decal("plate_%d" % GARAGE_NUMBERS[OPEN_GARAGE], Vector2(0.56, 0.28),
				Vector3(-0.45, 0.83, 0.035), hinge)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 0.8
	lamp.omni_range = 3.0
	lamp.position = Vector3(x, -1.4, 4.9)
	add_child(lamp)


# ---------------- Земля ----------------

func _build_ground() -> void:
	# Весь асфальт — один материал и одна высота: куски стыкуются встык или совпадают,
	# ничего не лежит «слоями» (раньше заплатки разных оттенков наползали друг на друга).
	var asphalt := _mat(Color(0.27, 0.27, 0.28), 0.95)
	_box(Vector3(34, 0.04, 14), Vector3(0, GROUND_Y + 0.02, 11.5), asphalt) # перед гаражами
	# Тротуар вдоль дома сзади: ступеньки всех трёх подъездов стоят прямо на нём.
	_box(Vector3(45.6, 0.04, 2.0), Vector3(0, GROUND_Y + 0.02, -7.0), asphalt)
	# Проезды по бокам от гаражей: соединяют тротуар у дома с площадкой спереди.
	for side: float in [-1.0, 1.0]:
		_box(Vector3(2.0, 0.04, 10.5), Vector3(side * 16.0, GROUND_Y + 0.02, -0.75), asphalt)
		# Тротуар вдоль лицевой стороны бокового дома (дом повёрнут на 45°): подъезды на нём,
		# конец тротуара у дома сзади сходится с ним по средней линии.
		var house := Vector3(side * 31.0, GROUND_Y, -8.0)
		var yaw := -side * PI / 4.0
		var walk := _box(Vector3(28.0, 0.04, 2.0), Vector3.ZERO, asphalt)
		walk.rotation.y = yaw
		walk.position = house + Vector3(0, 0, 6.5).rotated(Vector3.UP, yaw) + Vector3(0, 0.02, 0)
	# Разбитый асфальт: несколько заплаток на площадке перед гаражами, не касаются друг
	# друга, луж и люков.
	var rng := RandomNumberGenerator.new()
	rng.seed = 90
	var taken: Array[Vector3] = [] # x, z — центр, y — радиус
	for spot: Vector3 in PUDDLES + MANHOLES:
		taken.append(Vector3(spot.x, 1.4, spot.z))
	var patch := _mat(Color(0.22, 0.22, 0.23), 1.0)
	for i in 40:
		if taken.size() >= PUDDLES.size() + MANHOLES.size() + 10:
			break
		var size := Vector3(rng.randf_range(0.7, 1.8), 0.02, rng.randf_range(0.5, 1.2))
		var pos := Vector3(rng.randf_range(-15, 15), GROUND_Y + 0.045, rng.randf_range(5.5, 17.5))
		var radius := Vector2(size.x, size.z).length() / 2.0
		var free := true
		for t in taken:
			if Vector2(pos.x - t.x, pos.z - t.z).length() < radius + t.y + 0.3:
				free = false
				break
		if free:
			taken.append(Vector3(pos.x, radius, pos.z))
			_box(size, pos, patch).rotation.y = rng.randf_range(0, PI)
	# Лужи — только на асфальте: неровное пятно из 2–3 сплюснутых кругов, мокрый тёмный асфальт
	# с бликом неба. Не «металл»: металл в игре без отражений становится чёрным (были «чёрные
	# дыры»), и раньше одна лужа лежала на траве.
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.15, 0.16, 0.18)
	water.metallic = 0.0
	water.roughness = 0.06
	for spot: Vector3 in PUDDLES:
		for k in rng.randi_range(2, 3):
			var puddle := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = rng.randf_range(0.35, 0.8)
			mesh.bottom_radius = mesh.top_radius
			mesh.height = 0.01
			mesh.radial_segments = 16
			mesh.rings = 1
			puddle.mesh = mesh
			puddle.material_override = water
			puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var offset := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.3, 0.3))
			puddle.position = spot + offset + Vector3(0, GROUND_Y + 0.06, 0)
			puddle.scale = Vector3(1.0, 1.0, rng.randf_range(0.5, 0.85))
			puddle.rotation.y = rng.randf() * TAU
			add_child(puddle)
	# Канализационные люки (чугунная крышка с узором, вокруг — заплатка асфальта).
	for spot: Vector3 in MANHOLES:
		_place("manhole", spot + Vector3(0, GROUND_Y + 0.05, 0), rng.randf() * TAU)


# ---------------- Дома, деревья, фонари ----------------

func _build_buildings() -> void:
	_place("khrushchevka", Vector3(0, GROUND_Y, -13.5))
	_place("khrushchevka", Vector3(-31, GROUND_Y, -8.0), PI / 4)
	_place("khrushchevka", Vector3(31, GROUND_Y, -8.0), -PI / 4)
	for spot: Vector3 in [Vector3(-12.5, 0, -2.0), Vector3(13.0, 0, 1.0), Vector3(-11.0, 0, -5.0),
			Vector3(10.5, 0, -5.0)]:
		var model := "tree_poplar" if int(spot.x) % 2 == 0 else "tree_birch"
		_place(model, spot + Vector3(0, GROUND_Y, 0), randf() * TAU)
	_place("tree_birch", Vector3(-18.6, GROUND_Y, 9.0)) # на траве за краем асфальта
	# Кусты на траве вокруг гаражей и у деревьев.
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	# (не на асфальте: проезды по бокам — x ±15..17, тротуар у дома — z −8..−6)
	for spot: Vector3 in [Vector3(-10.2, 0, 0.8), Vector3(-11.6, 0, 3.4), Vector3(-13.6, 0, 0.3),
			Vector3(-13.5, 0, -3.6), Vector3(-9.8, 0, -3.8), Vector3(-13.3, 0, 2.4),
			Vector3(11.3, 0, -1.2), Vector3(12.1, 0, 3.6), Vector3(13.8, 0, -3.1),
			Vector3(13.9, 0, 2.6), Vector3(11.8, 0, -4.4), Vector3(-12.8, 0, -5.2)]:
		var bush := _place("bush_round" if rng.randf() < 0.5 else "bush_wide",
			spot + Vector3(0, GROUND_Y, 0), rng.randf() * TAU)
		bush.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
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
	_solid("trash_bin_open", Vector3(1.5, 1.2, 1.0), BINS[0], BIN_YAW)
	_solid("trash_bin", Vector3(1.5, 1.2, 1.0), BINS[1], BIN_YAW)
	_solid("barrel", Vector3(0.65, 0.9, 0.65), Vector3(9.4, GROUND_Y, 3.3))
	_solid("barrel", Vector3(0.65, 0.9, 0.65), Vector3(9.9, GROUND_Y, 2.5))
	_solid("crate", Vector3(0.6, 0.55, 0.6), Vector3(9.4, GROUND_Y, 1.4), 0.3)
	_solid("crate", Vector3(0.6, 0.55, 0.6), Vector3(9.5, GROUND_Y + 0.55, 1.45), 0.8)
	_solid("crate", Vector3(0.6, 0.55, 0.6), Vector3(-9.3, GROUND_Y, -1.5), 0.5)
	_place("barrel", Vector3(-9.4, GROUND_Y, -2.6))
	# Лестница прислонена к боковой стене гаражей (верх — у края крыши).
	var ladder := _place("ladder", Vector3(ROOF_HALF.x + 1.18, GROUND_Y, -2.4))
	ladder.rotation = Vector3(-0.335, PI / 2, 0)


## Номера-таблички, замки и граффити на воротах гаражей (картинки из
## tools/textures/garage_decals.py — чёткие, с прозрачностью; раньше были мыльные Label3D).
func _build_garage_details() -> void:
	for i in DOOR_X.size():
		if i == OPEN_GARAGE:
			continue # приоткрытый гараж — свои створки (_build_open_garage)
		var x := DOOR_X[i]
		var plate_pos := Vector3(x + 1.2, -1.42, DOOR_Z + 0.012)
		_decal("plate_%d" % GARAGE_NUMBERS[i], Vector2(0.56, 0.28), plate_pos)
		var lock := _place("padlock", Vector3(x + 0.12, -2.65, DOOR_Z + 0.03))
		lock.scale = Vector3.ONE * 1.4
		_decal(GRAFFITI[i], Vector2(2.3, 1.15), Vector3(x - 0.15, -1.95, DOOR_Z + 0.01))


## Картинка-наклейка на стене (смотрит вперёд, +Z): освещается как стена, края мягкие.
func _decal(texture_name: String, size: Vector2, pos: Vector3, parent: Node3D = null) -> void:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	quad.mesh = mesh
	var decal_mat := StandardMaterial3D.new()
	decal_mat.albedo_texture = load("res://assets/textures/garage/%s.png" % texture_name)
	decal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	decal_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	decal_mat.roughness = 0.9
	quad.material_override = decal_mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position = pos
	(parent if parent else self as Node3D).add_child(quad)


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
