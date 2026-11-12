class_name FreezeYard
extends Node3D
## Двор 90-х для «Морожки»: хрущёвки вокруг, забор, лавочки, открытая песочница с «грибком»,
## деревья, фонари и площадка — горка, качели, карусель (см. их скрипты).
## Площадка игры — X −10.5..10.5, Z −6.5..6.5 (забор-столкновения в сцене, здесь — модели).

const COURTYARD := "res://assets/models/courtyard/"
const PLAYGROUND := "res://assets/models/playground/"
const FENCE_X := 11.2
const FENCE_Z := 7.2

## Лавочки, под которые можно спрятаться (их Transform: +Z — сторона, куда вылезают).
var benches: Array[Transform3D] = []
var slide: PlaygroundSlide
var swing: PlaygroundSwing
var carousel: PlaygroundCarousel


func _ready() -> void:
	_build_surroundings()
	_build_fence()
	_solid(PLAYGROUND + "sandbox", Vector3(3.0, 0.3, 3.0), Vector3(-5.0, 0, -2.5))
	_bench(Vector3(1.5, 0, -6.4), 0.0)
	_bench(Vector3(10.0, 0, -2.0), -PI / 2)
	_bench(Vector3(-10.0, 0, -1.0), PI / 2)
	_tree("tree_poplar", Vector3(-9.2, 0, -5.4))
	_tree("tree_birch", Vector3(9.3, 0, 5.4))
	slide = PlaygroundSlide.new()
	slide.position = Vector3(4.6, 0, 2.2)
	add_child(slide)
	swing = PlaygroundSwing.new()
	swing.position = Vector3(-1.0, 0, 4.4)
	add_child(swing)
	carousel = PlaygroundCarousel.new()
	carousel.position = Vector3(-7.0, 0, 3.2)
	add_child(carousel)


func _build_surroundings() -> void:
	_place(COURTYARD + "khrushchevka", Vector3(0, 0, -17.5))
	_place(COURTYARD + "khrushchevka", Vector3(-27, 0, -3.0), PI / 2)
	_place(COURTYARD + "khrushchevka", Vector3(27, 0, -3.0), -PI / 2)
	for spot: Vector3 in [Vector3(-14, 0, 8.5), Vector3(13.5, 0, -9.5), Vector3(-13.5, 0, -10),
			Vector3(14.5, 0, 6.0)]:
		var model := "tree_birch" if spot.z > 0 else "tree_poplar"
		_place(COURTYARD + model, spot, randf() * TAU)
	for x in [-12.5, 12.5]:
		_place(COURTYARD + "lamp_post", Vector3(x, 0, 8.4), PI)


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
