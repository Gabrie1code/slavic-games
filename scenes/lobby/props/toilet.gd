class_name Toilet
extends StaticBody3D
## Унитаз в туалете квартиры.
##
## «Подтвердить» рядом — поднять крышку (сама закрывается через LID_CLOSE_AFTER сек).
## В открытый унитаз «подтвердить» — вид от глаз на унитаз (ToiletScreen) и жёлтая струя: она
## летит туда, куда показывает курсор мыши; вода в чаше от попадания желтеет,
## промах — лужица на полу (высыхает).
## После этого действие недоступно COOLDOWN сек, зато работает кнопка смыва на бачке:
## кнопка нажимается, вода плавно становится снова голубой.
## Модель — tools/blender/toilet.py (части ToiletBody, Lid, Water, FlushButton).

const MODEL := preload("res://assets/models/apartment/toilet.glb")
const LID_OPEN_ANGLE := -1.6 # ≈ −92°: крышка опирается на бачок
const LID_CLOSE_AFTER := 20.0
const COOLDOWN := 60.0
const FLUSH_TIME := 2.6
const BLUE := Color(0.45, 0.75, 0.95)
const YELLOW := Color(0.95, 0.8, 0.2)
## Чаша (в координатах унитаза): центр воды, радиус «попадания», высота ободка.
const BOWL := Vector3(0, 0.3, 0.41)
const BOWL_RADIUS := 0.13
const RIM_RADIUS := 0.24
const RIM_Y := 0.43
## Где стоит пользующийся (перед унитазом) — в координатах унитаза.
const STAND := Vector3(0, 0, 1.0)
const STREAM_DROPS := 26
const PUDDLE_LIFE := 20.0

var lid_open := false
var in_use := false

var _lid: Node3D
var _water: Node3D
var _water_mat: StandardMaterial3D
var _button: Node3D
var _button_y := 0.0
var _time := 0.0
var _close_at := 0.0
var _cooldown_until := 0.0
var _flush_left := 0.0
var _yellow := 0.0
var _drops: Array[MeshInstance3D] = []
var _splash: CPUParticles3D
var _stream_mat: StandardMaterial3D
## Лужица текущего похода (растёт, пока льётся мимо) и все лужицы: [MeshInstance3D, время].
var _puddle: MeshInstance3D
var _puddles: Array[Array] = []


func _ready() -> void:
	var model := MODEL.instantiate() as Node3D
	add_child(model)
	_lid = model.find_child("Lid", true, false) as Node3D
	_water = model.find_child("Water", true, false) as Node3D
	_button = model.find_child("FlushButton", true, false) as Node3D
	_button_y = _button.position.y
	_water_mat = StandardMaterial3D.new()
	_water_mat.albedo_color = BLUE
	_water_mat.roughness = 0.05
	_water_mat.metallic_specular = 0.9
	(_water as MeshInstance3D).material_override = _water_mat
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.84, 0.66)
	shape.shape = box
	shape.position = Vector3(0, 0.42, 0.33)
	add_child(shape)
	_build_stream()


func _process(delta: float) -> void:
	_time += delta
	if lid_open and not in_use and _time >= _close_at:
		lid_open = false # сама закрылась
	var target := LID_OPEN_ANGLE if lid_open else 0.0
	_lid.rotation.x = move_toward(_lid.rotation.x, target, delta * 4.0)
	_process_flush(delta)
	_water_mat.albedo_color = BLUE.lerp(YELLOW, _yellow)
	_dry_puddles()


## Поднять крышку можно, если она закрыта и не идёт смыв.
func can_open() -> bool:
	return not lid_open and _flush_left <= 0.0


func open_lid() -> void:
	lid_open = true
	_close_at = _time + LID_CLOSE_AFTER


## Сходить можно в открытый, свободный унитаз и не на перезарядке.
func can_use() -> bool:
	return lid_open and not in_use and not on_cooldown()


func on_cooldown() -> bool:
	return _time < _cooldown_until


func cooldown_left() -> float:
	return maxf(0.0, _cooldown_until - _time)


## Смыв работает, пока идёт перезарядка (и сейчас не смывается).
func can_flush() -> bool:
	return on_cooldown() and not in_use and _flush_left <= 0.0


func is_flushing() -> bool:
	return _flush_left > 0.0


func flush() -> void:
	if can_flush():
		_flush_left = FLUSH_TIME


func start_use() -> void:
	in_use = true
	_puddle = null


## Закончил: струя пропадает, начинается перезарядка, крышка закроется через 20 сек.
func stop_use() -> void:
	in_use = false
	_cooldown_until = _time + COOLDOWN
	_close_at = _time + LID_CLOSE_AFTER
	for drop in _drops:
		drop.visible = false
	_splash.emitting = false


## Точка, где встаёт пользующийся, и его поворот (лицом к унитазу).
func stand_point() -> Vector3:
	return to_global(STAND)


func stand_yaw() -> float:
	return global_rotation.y


func bowl_position() -> Vector3:
	return to_global(BOWL)


## Струя из точки origin до точки land (по горизонтали — куда целятся). Попала в чашу — вода
## желтеет; по ободку — брызги; мимо — лужица на полу.
func pour(origin: Vector3, land: Vector3, delta: float) -> void:
	var bowl := bowl_position()
	var off := Vector2(land.x - bowl.x, land.z - bowl.z).length()
	var end_y := global_position.y + 0.01
	if off < BOWL_RADIUS:
		end_y = bowl.y
		_yellow = minf(1.0, _yellow + delta * 0.22)
	elif off < RIM_RADIUS:
		end_y = global_position.y + RIM_Y # по ободку — брызги, но без лужи
	else:
		_grow_puddle(Vector3(land.x, global_position.y + 0.005, land.z), delta)
	var end := Vector3(land.x, end_y, land.z)
	var distance := Vector2(end.x - origin.x, end.z - origin.z).length()
	var rise := 0.08 + distance * 0.2
	var drop_y := origin.y - end_y
	for i in _drops.size():
		var t := float(i) / (_drops.size() - 1)
		var point := origin.lerp(end, t)
		point.y = origin.y + rise * t - (rise + drop_y) * t * t
		point.x += sin(_time * 31.0 + i * 1.7) * 0.004
		_drops[i].global_position = point
		_drops[i].visible = true
	_splash.global_position = end + Vector3(0, 0.01, 0)
	_splash.emitting = true


## Высота воды в чаше (в мире) и уровень пола — для прицела мышкой.
func water_height() -> float:
	return bowl_position().y


func floor_height() -> float:
	return global_position.y


func _process_flush(delta: float) -> void:
	if _flush_left <= 0.0:
		_button.position.y = _button_y
		return
	_flush_left -= delta
	var k := 1.0 - _flush_left / FLUSH_TIME
	# Кнопка утоплена первые полсекунды; вода плавно меняет цвет с жёлтого на голубой.
	# (Раньше овал воды крутился и вылезал за чашу — смотрелось криво.)
	_button.position.y = _button_y - (0.008 if k < 0.2 else 0.0)
	_yellow = move_toward(_yellow, 0.0, delta / (FLUSH_TIME * 0.8))


func _build_stream() -> void:
	_stream_mat = StandardMaterial3D.new()
	_stream_mat.albedo_color = Color(1.0, 0.86, 0.15, 0.85)
	_stream_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stream_mat.roughness = 0.1
	var sphere := SphereMesh.new()
	sphere.radius = 0.012
	sphere.height = 0.024
	sphere.radial_segments = 6
	sphere.rings = 3
	for i in STREAM_DROPS:
		var drop := MeshInstance3D.new()
		drop.mesh = sphere
		drop.material_override = _stream_mat
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		drop.top_level = true
		drop.visible = false
		add_child(drop)
		_drops.append(drop)
	_splash = CPUParticles3D.new()
	_splash.top_level = true
	_splash.emitting = false
	_splash.amount = 16
	_splash.lifetime = 0.35
	_splash.direction = Vector3.UP
	_splash.spread = 70.0
	_splash.initial_velocity_min = 0.4
	_splash.initial_velocity_max = 0.9
	_splash.gravity = Vector3(0, -6, 0)
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.007
	drop_mesh.height = 0.014
	drop_mesh.radial_segments = 4
	drop_mesh.rings = 2
	drop_mesh.material = _stream_mat
	_splash.mesh = drop_mesh
	add_child(_splash)


## Лужица под промахом: растёт до 0.3 м, через PUDDLE_LIFE сек высыхает.
func _grow_puddle(point: Vector3, delta: float) -> void:
	if _puddle == null or _puddle.global_position.distance_to(point) > 0.25:
		_puddle = MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.5
		disc.bottom_radius = 0.5
		disc.height = 0.004
		disc.radial_segments = 14
		_puddle.mesh = disc
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.2, 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.05
		_puddle.material_override = mat
		_puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_puddle.top_level = true
		_puddle.scale = Vector3(0.05, 1, 0.05)
		add_child(_puddle)
		_puddle.global_position = point
		_puddles.append([_puddle, _time])
	var size := minf(0.6, _puddle.scale.x + delta * 0.12)
	_puddle.scale = Vector3(size, 1, size * 0.8)
	_puddles[-1][1] = _time


## Оттереть губкой лужи рядом с точкой (раньше, чем высохнут сами).
func scrub(point: Vector3, radius: float) -> void:
	for i in range(_puddles.size() - 1, -1, -1):
		var puddle: MeshInstance3D = _puddles[i][0]
		var flat := Vector2(puddle.global_position.x - point.x, puddle.global_position.z - point.z)
		var close := flat.length() < radius + puddle.scale.x * 0.5
		if close and absf(puddle.global_position.y - point.y) < 0.3:
			if puddle == _puddle:
				_puddle = null
			puddle.queue_free()
			_puddles.remove_at(i)


func _dry_puddles() -> void:
	for i in range(_puddles.size() - 1, -1, -1):
		var puddle: MeshInstance3D = _puddles[i][0]
		if _time - float(_puddles[i][1]) < PUDDLE_LIFE:
			continue
		var mat := puddle.material_override as StandardMaterial3D
		mat.albedo_color.a -= 0.4 * get_process_delta_time()
		if mat.albedo_color.a <= 0.0:
			if puddle == _puddle:
				_puddle = null
			puddle.queue_free()
			_puddles.remove_at(i)
