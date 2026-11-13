class_name FreezeYard
extends Node3D
## Двор 90-х для «Морожки»: разные дома вокруг на все 360° (хрущёвки, девятиэтажка, сталинка,
## башни, гаражи; вдали труба ТЭЦ, водокачка, краны), забор, лавочки, открытая песочница
## с «грибком», деревья, фонари и площадка — горка, качели, карусель (см. их скрипты).
## Площадка игры — X −15.75..15.75, Z −9.75..9.75 (в 1.5 раза больше прежней; забор-столкновения
## в сцене, здесь — модели). В песочнице — ведёрко, лопатка и формочка.

const COURTYARD := "res://assets/models/courtyard/"
const PLAYGROUND := "res://assets/models/playground/"
const FENCE_X := 17.0
const FENCE_Z := 11.0
## Во сколько раз двор больше первой версии (все расстановки умножаются на него).
const S := 1.5
const SANDBOX := Vector3(-5.0, 0, -2.5) * S

## Дома вокруг двора на все 360° (разные, tools/blender/city.py) и дальний горизонт: башни,
## труба ТЭЦ, водонапорная башня, краны. Только декорации (без столкновений, за забором).
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
	["tec_chimney", Vector3(140, 0, -120), 0.6],
	["water_tower", Vector3(-120, 0, -10), 0.0],
	["tower_crane", Vector3(-25, 0, 140), 1.0],
	["tower_crane", Vector3(120, 0, -30), 2.0],
]
const EXTRA_TREES: Array[Vector3] = [
	Vector3(-21, 0, 14), Vector3(8, 0, 17), Vector3(-12, 0, 18), Vector3(26, 0, -18),
	Vector3(-27, 0, -20), Vector3(-48, 0, 12), Vector3(47, 0, 18), Vector3(19, 0, -24),
	Vector3(-18, 0, -22), Vector3(30, 0, 13), Vector3(-30, 0, 24), Vector3(44, 0, -12),
]

## Лавочки, под которые можно спрятаться (их Transform: +Z — сторона, куда вылезают).
var benches: Array[Transform3D] = []
var slide: PlaygroundSlide
var swing: PlaygroundSwing
var carousel: PlaygroundCarousel


func _ready() -> void:
	_build_surroundings()
	_build_fence()
	_solid(PLAYGROUND + "sandbox", Vector3(3.0, 0.3, 3.0), SANDBOX)
	_build_sand_toys()
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


## Игрушки в песочнице: красное ведёрко, синяя лопатка, жёлтая формочка (только для красоты).
func _build_sand_toys() -> void:
	var sand_y := 0.27
	var bucket := MeshInstance3D.new()
	var bucket_mesh := CylinderMesh.new()
	bucket_mesh.top_radius = 0.13
	bucket_mesh.bottom_radius = 0.1
	bucket_mesh.height = 0.2
	bucket_mesh.radial_segments = 12
	bucket.mesh = bucket_mesh
	bucket.material_override = _toy_mat(Color("d93a2a"))
	bucket.position = SANDBOX + Vector3(0.6, sand_y + 0.1, 0.4)
	add_child(bucket)
	var handle := MeshInstance3D.new()
	var handle_mesh := TorusMesh.new()
	handle_mesh.inner_radius = 0.12
	handle_mesh.outer_radius = 0.135
	handle.mesh = handle_mesh
	handle.material_override = _toy_mat(Color("f6c343"))
	handle.rotation = Vector3(PI / 2, 0, 0.5)
	handle.position = Vector3(0, 0.1, 0)
	bucket.add_child(handle)
	# Лопатка лежит на песке: черенок и плоский совок.
	var shovel := Node3D.new()
	shovel.position = SANDBOX + Vector3(-0.4, sand_y + 0.02, 0.2)
	shovel.rotation = Vector3(0, 0.7, 0)
	add_child(shovel)
	var blue := _toy_mat(Color("3a6fd9"))
	_toy_box(shovel, Vector3(0.04, 0.03, 0.4), Vector3(0, 0, -0.1), blue)
	_toy_box(shovel, Vector3(0.16, 0.02, 0.18), Vector3(0, -0.005, 0.18), blue)
	# Формочка-«звёздочка» вверх дном и куличик рядом.
	var mold := MeshInstance3D.new()
	var mold_mesh := CylinderMesh.new()
	mold_mesh.top_radius = 0.07
	mold_mesh.bottom_radius = 0.1
	mold_mesh.height = 0.08
	mold_mesh.radial_segments = 5
	mold.mesh = mold_mesh
	mold.material_override = _toy_mat(Color("f2d23a"))
	mold.position = SANDBOX + Vector3(0.1, sand_y + 0.04, -0.6)
	add_child(mold)
	var cake := MeshInstance3D.new()
	cake.mesh = mold_mesh
	cake.material_override = _toy_mat(Color("d9c08a"))
	cake.position = SANDBOX + Vector3(0.35, sand_y + 0.04, -0.5)
	add_child(cake)


func _toy_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.4
	return mat


func _toy_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	parent.add_child(mesh_instance)


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
