class_name Breakable
extends Node3D
## Ломающаяся вещь в квартире (хрусталь, банки, горшки, книги, лампы).
##
## Игрок задевает вещь — она разлетается на осколки, через RESPAWN_TIME секунд
## появляется снова. Зона задевания — цилиндр от пола до вещи, чтобы можно было
## разбить и то, что стоит на полке: достаточно подойти вплотную.

## Разбили / появилась снова (радио по ним выключает и включает музыку).
signal broken
signal restored

const RESPAWN_TIME := 12.0
## Слой «мишени для краски»: невидимое тело по размеру вещи — его видит луч баллончика,
## а игроки сквозь него проходят (их маска — только слой 1).
const PAINT_LAYER := 1 << 3
const SHARD_LIFETIME := 3.0
const SHARD_COUNT := 9
const TOUCH_GAP := 0.6

## Задевая вещи телом, игрок разбивает не больше одной за TOUCH_GAP сек
## (иначе, проходя вдоль серванта, бил всю полку разом): id тела -> время последнего раза.
static var _last_touch: Dictionary = {}

## Через сколько секунд вещь появляется снова (у радио — быстрее).
var respawn_time := RESPAWN_TIME
## Защита (например, сервиз за целым стеклом серванта): вернёт false — вещь сейчас не бьётся.
var guard: Callable

var _model: Node3D
var _colors: Array[Color] = []
var _shard_size := 0.07
var _broken := false
## Разгон, нужный чтобы разбить вещь телом (PlayerCharacter.run_up): маленькую — с небольшого
## разбега, большую — с длинного; подошёл аккуратно — цела. Кулаком бьётся всегда.
var _run_up_needed := 0.3


## scene — модель вещи, colors — цвета осколков, reach — радиус зоны задевания.
func setup(scene: PackedScene, colors: Array[Color], reach: float = 0.45,
		shard_size: float = 0.07) -> void:
	setup_model(scene.instantiate() as Node3D, colors, reach, shard_size)


## То же, но модель уже собрана кодом (отрывной календарь на кухне).
func setup_model(model: Node3D, colors: Array[Color], reach: float = 0.45,
		shard_size: float = 0.07) -> void:
	_model = model
	add_child(_model)
	add_to_group("breakable")
	_colors = colors
	_shard_size = shard_size

	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = reach
	cylinder.height = maxf(position.y, 0.0) + 0.6
	shape.shape = cylinder
	# Цилиндр от пола до вещи (вещь может стоять на полке).
	shape.position.y = -cylinder.height / 2.0 + 0.6
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	add_child(area)
	_add_paint_target()


## Узел, к которому цепляются следы краски (пропадают вместе с вещью, когда она разбита).
func paint_root() -> Node3D:
	return _model


func _add_paint_target() -> void:
	var box := AABB()
	var first := true
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var local := _model.global_transform.affine_inverse() * mesh_instance.global_transform
		var part := local * mesh_instance.get_aabb()
		box = part if first else box.merge(part)
		first = false
	if first:
		return
	_run_up_needed = clampf(0.1 + maxf(box.size.x, maxf(box.size.y, box.size.z)) * 1.2, 0.25, 1.3)
	var body := StaticBody3D.new()
	body.collision_layer = PAINT_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size
	shape.shape = box_shape
	shape.position = box.get_center()
	body.add_child(shape)
	add_child(body)


func is_broken() -> bool:
	return _broken


## Можно ли сейчас разбить (цела и ничем не защищена).
func can_break() -> bool:
	return not _broken and (not guard.is_valid() or bool(guard.call()))


func _on_body_entered(body: Node3D) -> void:
	if not can_break() or not body is PlayerCharacter:
		return
	if (body as PlayerCharacter).run_up < _run_up_needed:
		return # подошёл аккуратно, без разгона
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_touch.get(body.get_instance_id(), -10.0)) < TOUCH_GAP:
		return
	_last_touch[body.get_instance_id()] = now
	shatter(body.global_position)


## Разбить: спрятать вещь, разбросать осколки, через время вернуть.
func shatter(from: Vector3) -> void:
	_broken = true
	_model.visible = false
	SprayCan.clear_paint(_model) # разбили — краска на ней пропала
	var away := global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.05 else Vector3.BACK
	for i in SHARD_COUNT:
		_spawn_shard(away)
	broken.emit()
	await get_tree().create_timer(respawn_time).timeout
	if not is_inside_tree():
		return
	_model.visible = true
	_model.scale = Vector3.ONE * 0.01
	create_tween().tween_property(_model, "scale", Vector3.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_broken = false
	restored.emit()


func _spawn_shard(away: Vector3) -> void:
	var shard := RigidBody3D.new()
	# Осколки сталкиваются с полом и мебелью (слой 1), но не мешают игрокам.
	shard.collision_layer = 2
	shard.collision_mask = 1
	shard.mass = 0.1
	var size := Vector3(randf_range(0.6, 1.3), randf_range(0.4, 1.0), randf_range(0.6, 1.3))
	size *= _shard_size
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = _colors.pick_random() if not _colors.is_empty() else Color.WHITE
	if material.albedo_color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material
	shard.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shard.add_child(shape)
	get_parent().add_child(shard)
	var jitter := Vector3(randf_range(-0.1, 0.1), randf_range(0.05, 0.25), randf_range(-0.1, 0.1))
	shard.global_position = global_position + jitter
	shard.linear_velocity = (away + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))) \
		* randf_range(1.5, 3.5) + Vector3.UP * randf_range(2.0, 4.0)
	shard.angular_velocity = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
	_fade_shard(shard)


func _fade_shard(shard: RigidBody3D) -> void:
	await get_tree().create_timer(SHARD_LIFETIME).timeout
	if not is_instance_valid(shard):
		return
	var tween := shard.create_tween()
	tween.tween_property(shard, "scale", Vector3.ONE * 0.01, 0.4)
	tween.tween_callback(shard.queue_free)
