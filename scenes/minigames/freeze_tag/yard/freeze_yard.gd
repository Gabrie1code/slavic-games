class_name FreezeYard
extends Node3D
## Двор 90-х для «Морожки»: разные дома вокруг на все 360° (хрущёвки, девятиэтажка, сталинка,
## башни, гаражи; вдали труба ТЭЦ с дымом, водокачка, краны), забор, лавочки, открытая песочница
## с «грибком», деревья, фонари и площадка — горка, качели, карусель (см. их скрипты),
## у краёв — шведская стенка, «глобус» и дуга-лесенка (препятствия); облака разных видов;
## тропинки и тротуары вокруг (YardPaths); вдали — деревья до горизонта.
## Площадка игры — X −15.75..15.75, Z −9.75..9.75 (в 1.5 раза больше прежней; забор-столкновения
## в сцене, здесь — модели). Игрушки в песочнице — в её модели (playground.py).

const COURTYARD := "res://assets/models/courtyard/"
const PLAYGROUND := "res://assets/models/playground/"
const FENCE_X := 17.0
const FENCE_Z := 11.0
## Во сколько раз двор больше первой версии (все расстановки умножаются на него).
const S := 1.5
const SANDBOX := Vector3(-5.0, 0, -2.5) * S

## Дома вокруг двора на все 360° (разные, tools/blender/city.py) и дальний горизонт: башни,
## труба ТЭЦ (с дымом — ChimneySmoke), водонапорная башня, башенные краны.
## Только декорации (без столкновений, за забором).
const SURROUNDINGS: Array = [
	# Близкий круг: лицом к площадке.
	["khrushchevka", Vector3(0, 0, -26.25), 0.0],
	["khrushchevka", Vector3(-36, 0, -4.5), PI / 2],
	["brick_khrushchevka", Vector3(35, 0, -4.5), -PI / 2],
	["panel_ninestory", Vector3(-6, 0, 31), PI],
	["garage_row", Vector3(22, 0, 20), PI],
	["transformer_box", Vector3(-24, 0, 17), PI],
	["stalinka", Vector3(32, 0, -34), -0.7],
	["tower_block", Vector3(-33, 0, -33), 0.7],
	["brick_khrushchevka", Vector3(-38, 0, 33), PI * 0.75],
	["stalinka", Vector3(38, 0, 36), -PI * 0.75],
	# Дальний горизонт.
	["tower_block", Vector3(-95, 0, -60), 0.5],
	["tower_block", Vector3(85, 0, 75), PI + 0.4],
	["tower_block", Vector3(-40, 0, 110), PI],
	["panel_ninestory", Vector3(10, 0, -85), 0.0],
	["panel_ninestory", Vector3(-85, 0, 35), PI / 2],
	["panel_ninestory", Vector3(95, 0, 5), -PI / 2],
	["stalinka", Vector3(60, 0, -75), -0.4],
	["khrushchevka", Vector3(-55, 0, -80), 0.3],
	# Труба ТЭЦ и краны — в просветах между ближними домами (иначе их закрывают дома).
	["tec_chimney", Vector3(-111, 0, 100), 0.6],
	["tower_crane", Vector3(105, 0, 34), 2.4],
	["tower_crane", Vector3(-104, 0, 62), -0.9],
	["water_tower", Vector3(-120, 0, -10), 0.0],
]
const EXTRA_TREES: Array[Vector3] = [
	Vector3(-21, 0, 14), Vector3(8, 0, 17), Vector3(-12, 0, 18), Vector3(26, 0, -18),
	Vector3(-27, 0, -20), Vector3(-48, 0, 12), Vector3(47, 0, 18), Vector3(19, 0, -24),
	Vector3(-18, 0, -22), Vector3(30, 0, 13), Vector3(-30, 0, 24), Vector3(44, 0, -12),
]

const YARD_BUSHES: Array[Vector3] = [
	Vector3(-21.5, 0, 6), Vector3(-21.5, 0, -9), Vector3(21.5, 0, 7), Vector3(21.5, 0, -10),
	Vector3(-9, 0, -15.2), Vector3(10, 0, -15.2), Vector3(-13, 0, 15.2), Vector3(3, 0, 15.2),
]
## Облака вокруг на 360° (tools/textures/sky_clouds.py): вид — [картинка, высота над горизонтом
## от и до (градусы)]; перистые выше всех, слоистые ниже. Ниже ~20° облака закрыты домами.
const SKY := "res://assets/textures/sky/"
const CLOUD_KINDS: Array = [
	["cloud_cumulus_a", 24.0, 40.0], ["cloud_cumulus_b", 20.0, 34.0], ["cloud_cumulus_a", 34.0, 52.0],
	["cloud_cirrus", 45.0, 65.0], ["cloud_stratus", 18.0, 26.0], ["cloud_cumulus_a", 26.0, 36.0],
	["cloud_cumulus_b", 40.0, 58.0],
]
const CLOUD_COUNT := 44
## Облака медленно плывут по кругу (рад/сек).
const CLOUD_DRIFT := 0.004

## Лавочки, под которые можно спрятаться (их Transform: +Z — сторона, куда вылезают).
var benches: Array[Transform3D] = []
var slide: PlaygroundSlide
var swing: PlaygroundSwing
var carousel: PlaygroundCarousel
## Дым из трубы ТЭЦ (в дождь RainWeather делает его темнее).
var smoke: ChimneySmoke
var _clouds: Node3D


func _ready() -> void:
	_build_surroundings()
	_build_far_trees()
	_build_clouds()
	smoke = ChimneySmoke.new()
	smoke.position = Vector3(-111, 61, 100) # верх трубы ТЭЦ (см. SURROUNDINGS)
	add_child(smoke)
	var paths := YardPaths.new()
	add_child(paths)
	paths.build(SURROUNDINGS)
	_build_fence()
	_solid(PLAYGROUND + "sandbox", Vector3(3.0, 0.3, 3.0), SANDBOX)
	_bench(Vector3(1.5, 0, -6.6) * S, 0.0)
	_bench(Vector3(10.2, 0, -2.0) * S, -PI / 2)
	_bench(Vector3(-10.2, 0, -1.0) * S, PI / 2)
	_tree("tree_poplar", Vector3(-9.2, 0, -5.4) * S)
	_tree("tree_birch", Vector3(9.3, 0, 5.4) * S)
	slide = PlaygroundSlide.new()
	slide.position = Vector3(4.6, 0, 2.2) * S
	add_child(slide)
	swing = PlaygroundSwing.new()
	swing.position = Vector3(-1.0, 0, 4.4) * S
	add_child(swing)
	carousel = PlaygroundCarousel.new()
	carousel.position = Vector3(-7.0, 0, 3.2) * S
	add_child(carousel)
	# Металлические снаряды у краёв площадки — просто препятствия, вокруг них можно бегать
	# и «водить за нос» водящего (tools/blender/playground.py). Залезть на них нельзя.
	_solid(PLAYGROUND + "wall_bars", Vector3(1.1, 2.6, 0.2), Vector3(9.0, 0, -8.6))
	_solid(PLAYGROUND + "climbing_globe", Vector3(2.0, 2.6, 2.0), Vector3(12.5, 0, -6.0))
	_solid(PLAYGROUND + "arch_ladder", Vector3(2.3, 1.2, 0.8), Vector3(-7.5, 0, 8.4))


func _build_surroundings() -> void:
	_build_far_ground()
	for item: Array in SURROUNDINGS:
		var spot: Vector3 = item[1]
		_place(COURTYARD + String(item[0]), spot, float(item[2]))
	for spot: Vector3 in [Vector3(-14, 0, 8.5), Vector3(13.5, 0, -9.5), Vector3(-13.5, 0, -10),
			Vector3(14.5, 0, 6.0)]:
		var model := "tree_birch" if spot.z > 0 else "tree_poplar"
		_place(COURTYARD + model, spot * S, randf() * TAU)
	for i in EXTRA_TREES.size():
		_place(COURTYARD + ("tree_birch" if i % 3 == 0 else "tree_poplar"), EXTRA_TREES[i],
			i * 1.7)
	for x in [-12.5, 12.5]:
		_place(COURTYARD + "lamp_post", Vector3(x, 0, 8.4) * S, PI)
	# Немного кустов вокруг площадки (за асфальтовым кольцом, не на дорожках).
	for i in YARD_BUSHES.size():
		var bush := _place(COURTYARD + ("bush_round" if i % 2 == 0 else "bush_wide"), YARD_BUSHES[i],
			i * 1.3)
		bush.scale = Vector3.ONE * (0.8 + 0.1 * (i % 3))
	# У гаражей: «жигуль» носом к гаражу (ворота четвёртого гаража приоткрыты — в модели).
	_place(COURTYARD + "zhiguli", Vector3(27.1, 0, 16.8), -PI / 2)


## Земля до горизонта: основной газон сцены — 90 × 90 м, дальше — большая плоскость чуть ниже
## (под газоном её не видно), иначе за дальними домами был бы обрыв в небо.
func _build_far_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.37, 0.52, 0.28)
	mat.roughness = 0.95
	ground.material_override = mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.position.y = -0.03
	add_child(ground)


func _process(delta: float) -> void:
	if _clouds:
		_clouds.rotation.y += CLOUD_DRIFT * delta


## Деревья вдали (50–115 м) — закрывают пустые просветы до горизонта между домами. Крупнее
## обычных (вдали их не разглядеть), не ставятся вплотную к дальним домам. Seed постоянный.
func _build_far_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var placed := 0
	var tries := 0
	while placed < 130 and tries < 900:
		tries += 1
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(50.0, 115.0)
		var spot := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var free := true
		for item: Array in SURROUNDINGS:
			var house: Vector3 = item[1]
			if house.length() > 50.0 and house.distance_to(spot) < 24.0:
				free = false
				break
		if not free:
			continue
		var tree := _place(COURTYARD + ("tree_birch" if rng.randf() < 0.4 else "tree_poplar"), spot,
			rng.randf() * TAU)
		tree.scale = Vector3.ONE * rng.randf_range(2.6, 4.0)
		placed += 1
	# Роща в просвете на востоке (между кирпичной хрущёвкой и сталинкой виден горизонт).
	for spot: Vector3 in [Vector3(58, 0, 22), Vector3(64, 0, 28), Vector3(70, 0, 21),
			Vector3(62, 0, 16), Vector3(76, 0, 30), Vector3(68, 0, 35)]:
		var grove := _place(COURTYARD + "tree_poplar", spot, rng.randf() * TAU)
		grove.scale = Vector3.ONE * rng.randf_range(2.8, 3.8)


## Перекрасить облака (в дождь — серые тучи, RainWeather).
func tint_clouds(color: Color) -> void:
	for cloud in _clouds.get_children():
		(cloud as Sprite3D).modulate = color


## Облака разных видов по кругу (seed постоянный — каждый раз одинаково): плоские картинки,
## повёрнутые к центру двора, в 260–420 м, на разной высоте над горизонтом.
func _build_clouds() -> void:
	_clouds = Node3D.new()
	add_child(_clouds)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1990
	for i in CLOUD_COUNT:
		var kind: Array = CLOUD_KINDS[rng.randi() % CLOUD_KINDS.size()]
		var angle := TAU * i / CLOUD_COUNT + rng.randf_range(-0.08, 0.08)
		var dist := rng.randf_range(260.0, 420.0)
		var elevation := deg_to_rad(rng.randf_range(float(kind[1]), float(kind[2])))
		var cloud := Sprite3D.new()
		cloud.texture = load(SKY + String(kind[0]) + ".png") as Texture2D
		cloud.shaded = false
		cloud.pixel_size = dist * rng.randf_range(0.0008, 0.0014)
		cloud.flip_h = rng.randf() < 0.5
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.position = Vector3(cos(angle) * dist, tan(elevation) * dist, sin(angle) * dist)
		# Повёрнуто к центру двора один раз (не «billboard»): billboard поворачивался вслед за
		# камерой вокруг своей середины, и широкие облака заметно ездили по небу при повороте мыши.
		cloud.rotation.y = atan2(cloud.position.x, cloud.position.z) + PI
		_clouds.add_child(cloud)


## Низкий зелёный забор по периметру (секции по 2 м).
func _build_fence() -> void:
	var x := -FENCE_X + 1.0
	while x < FENCE_X:
		for z in [-FENCE_Z, FENCE_Z]:
			_place(PLAYGROUND + "fence", Vector3(x, 0, z))
		x += 2.0
	var z2 := -FENCE_Z + 1.0
	while z2 < FENCE_Z:
		for side in [-FENCE_X, FENCE_X]:
			_place(PLAYGROUND + "fence", Vector3(side, 0, z2), PI / 2)
		z2 += 2.0


func _bench(pos: Vector3, yaw: float) -> void:
	_solid(PLAYGROUND + "bench", Vector3(1.8, 0.9, 0.5), pos, yaw)
	benches.append(Transform3D(Basis(Vector3.UP, yaw), pos))
	# Значок-подсказка «ЛАВОЧКА», как у горки и качелей (водящему не виден — см. freeze_tag.gd).
	var badge := ZoneBadge.new().setup("zone_bench", 1.9)
	badge.position += pos
	add_child(badge)


## Лавочка рядом с точкой (-1 — нет): подойти можно спереди или сзади.
func bench_near(point: Vector3, radius: float) -> int:
	for i in benches.size():
		var local := benches[i].affine_inverse() * point
		if absf(local.x) < 1.0 and absf(local.z) < radius:
			return i
	return -1


func _tree(model: String, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.add_child((load(COURTYARD + model + ".glb") as PackedScene).instantiate())
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.3
	cylinder.height = 3.0
	shape.shape = cylinder
	shape.position.y = 1.5
	body.add_child(shape)
	add_child(body)
	body.position = pos


func _place(path: String, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var node := (load(path + ".glb") as PackedScene).instantiate() as Node3D
	add_child(node)
	node.position = pos
	node.rotation.y = yaw
	return node


func _solid(path: String, size: Vector3, pos: Vector3, yaw: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.add_child((load(path + ".glb") as PackedScene).instantiate())
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y / 2.0
	body.add_child(shape)
	add_child(body)
	body.position = pos
	body.rotation.y = yaw
