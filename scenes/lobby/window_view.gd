class_name WindowView
extends Node3D
## Двор за окном гостиной (видно только от первого лица — слой Apartment.FP_ONLY_LAYER):
## небо (огромная картинка), газон, тропинка, настоящие 3D-хрущёвки напротив, деревья пониже,
## кусты и голуби: ходят по земле, иногда улетают, вместо них прилетают другие.
## Время суток — как на часах у игрока (берётся при входе в лобби и идёт дальше): днём голубое
## небо, утром рассвет, вечером закат, ночью темно, звёзды и луна. F8 — промотать на час вперёд
## (проверить, как выглядит ночь днём).
## Узел ставится в точку под окном (x — центр окна, z — внешняя сторона стены); «вперёд» — −Z.

const COURTYARD := "res://assets/models/courtyard/"
const SKY_SHADER := preload("res://scenes/lobby/window_sky.gdshader")
const TINT_SHADER := preload("res://scenes/lobby/window_tint.gdshader")
const CLOUDS := preload("res://assets/textures/window/window_clouds.png")
const GROUND_Y := -6.0
const PIGEONS := 5
## Где гуляют голуби (x — вбок, z — вглубь от стены).
const PIGEON_AREA := Rect2(-5.0, 5.0, 10.0, 6.0)
## Небо (квадрат 600×320 м на 60 м от окна): высота верха и размер — для перевода в UV.
const SKY_TOP := 260.0
const SKY_SIZE := Vector2(600, 320)
const SUNRISE := 6.0
const SUNSET := 20.5
## Время суток по часам: [час, верх неба, у горизонта, облака, «фильтр» двора, ночь 0..1].
const DAY_KEYS: Array = [
	[0.0, Color("050a1c"), Color("0d1630"), Color("2a3044"), Color(0.22, 0.26, 0.42), 1.0],
	[4.5, Color("050a1c"), Color("0d1630"), Color("2a3044"), Color(0.22, 0.26, 0.42), 1.0],
	[5.5, Color("1b2450"), Color("7a4a6e"), Color("6a5470"), Color(0.45, 0.4, 0.55), 0.6],
	[6.5, Color("4a6fb5"), Color("f2a36b"), Color("f5c2a0"), Color(0.95, 0.78, 0.68), 0.0],
	[8.0, Color("5f96d2"), Color("cde8f5"), Color("ffffff"), Color(1, 1, 1), 0.0],
	[17.5, Color("5f96d2"), Color("cde8f5"), Color("ffffff"), Color(1, 1, 1), 0.0],
	[19.0, Color("5478b8"), Color("f7c27a"), Color("ffe2b8"), Color(1.0, 0.86, 0.72), 0.0],
	[20.3, Color("34336e"), Color("f06a3a"), Color("f29a7a"), Color(0.8, 0.56, 0.5), 0.1],
	[21.3, Color("141a40"), Color("4a2a50"), Color("3a3550"), Color(0.36, 0.34, 0.5), 0.6],
	[22.5, Color("050a1c"), Color("0d1630"), Color("2a3044"), Color(0.22, 0.26, 0.42), 1.0],
	[24.0, Color("050a1c"), Color("0d1630"), Color("2a3044"), Color(0.22, 0.26, 0.42), 1.0],
]

## Который час за окном (0..24, с долями).
var hour := 12.0

var _pigeons: Array[YardPigeon] = []
var _sky_mat: ShaderMaterial
## Общий «фильтр» для всех вещей двора (material_overlay) — темнее ночью, теплее на закате.
var _tint_mat: ShaderMaterial
var _sky_quad: MeshInstance3D
var _since_update := 0.0


func _ready() -> void:
	var now := Time.get_time_dict_from_system()
	hour = float(now["hour"]) + float(now["minute"]) / 60.0 + float(now["second"]) / 3600.0
	_tint_mat = ShaderMaterial.new()
	_tint_mat.shader = TINT_SHADER
	_build_sky()
	_build_ground()
	_build_houses()
	_build_greenery()
	for i in PIGEONS:
		_spawn_pigeon(false)


func _process(delta: float) -> void:
	# Время идёт как в жизни; картинку обновляем раз в секунду.
	hour = fmod(hour + delta / 3600.0, 24.0)
	_since_update += delta
	if _since_update > 1.0:
		_since_update = 0.0
		_apply_time()
	_update_pigeons(delta)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F8:
		hour = fmod(hour + 1.0, 24.0)
		_apply_time()


func _update_pigeons(delta: float) -> void:
	for pigeon in _pigeons:
		if not is_instance_valid(pigeon) or pigeon.flying:
			continue
		var walking: bool = pigeon.get_meta("walking", false)
		if not walking and randf() < delta * 0.5:
			_walk(pigeon)
		elif randf() < delta * 0.025:
			pigeon.fly_away(pigeon.global_position + Vector3(randf_range(-1, 1), 0, 1))


func _build_sky() -> void:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(600, 320)
	quad.mesh = mesh
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	_sky_mat.set_shader_parameter("clouds", CLOUDS)
	quad.material_override = _sky_mat
	quad.position = Vector3(0, SKY_TOP - SKY_SIZE.y / 2.0, -60)
	_sky_quad = quad
	_add(quad)
	_apply_time()


# ---------------- Время суток ----------------

## Цвета неба, солнце/луна и «фильтр» двора для текущего часа.
func _apply_time() -> void:
	if _sky_mat == null:
		return
	var a: Array = DAY_KEYS[0]
	var b: Array = DAY_KEYS[1]
	for i in DAY_KEYS.size() - 1:
		if hour >= float(DAY_KEYS[i][0]) and hour <= float(DAY_KEYS[i + 1][0]):
			a = DAY_KEYS[i]
			b = DAY_KEYS[i + 1]
			break
	var t := inverse_lerp(float(a[0]), float(b[0]), hour)
	_sky_mat.set_shader_parameter("top_color", (a[1] as Color).lerp(b[1], t))
	_sky_mat.set_shader_parameter("horizon_color", (a[2] as Color).lerp(b[2], t))
	_sky_mat.set_shader_parameter("cloud_color", (a[3] as Color).lerp(b[3], t))
	_tint_mat.set_shader_parameter("tint", (a[4] as Color).lerp(b[4], t))
	_sky_mat.set_shader_parameter("night", lerpf(float(a[5]), float(b[5]), t))
	# Солнце идёт дугой слева направо с SUNRISE до SUNSET, луна — ночью.
	var day_t := inverse_lerp(SUNRISE, SUNSET, hour)
	var sun_up := sin(PI * clampf(day_t, 0.0, 1.0))
	_sky_mat.set_shader_parameter("sun_uv", _arc_uv(day_t, 50.0))
	_sky_mat.set_shader_parameter("sun_alpha", 1.0 if day_t > 0.0 and day_t < 1.0 else 0.0)
	# Низкое солнце — оранжевое.
	_sky_mat.set_shader_parameter("sun_color",
		Color(1.0, 0.55, 0.25).lerp(Color(1.0, 0.96, 0.78), clampf(sun_up * 2.0, 0.0, 1.0)))
	var night_len := 24.0 - SUNSET + SUNRISE
	var moon_t := fposmod(hour - SUNSET, 24.0) / night_len
	_sky_mat.set_shader_parameter("moon_uv", _arc_uv(moon_t, 55.0))
	_sky_mat.set_shader_parameter("moon_alpha", 1.0 if moon_t > 0.0 and moon_t < 1.0 else 0.0)


## Точка дуги на небе (t: 0 — восход слева, 1 — закат справа) в UV квадрата неба.
func _arc_uv(t: float, peak: float) -> Vector2:
	var x := lerpf(-40.0, 40.0, t)
	var y := GROUND_Y + peak * sin(PI * clampf(t, 0.0, 1.0))
	return Vector2(0.5 + x / SKY_SIZE.x, (SKY_TOP - y) / SKY_SIZE.y)


## Газон, тропинка (вдоль окна и к подъезду напротив), бордюрчик.
func _build_ground() -> void:
	_box(Vector3(400, 0.1, 80), Vector3(0, GROUND_Y - 0.05, -40), Color(0.37, 0.5, 0.28))
	var path := Color(0.62, 0.55, 0.45)
	_box(Vector3(60, 0.04, 1.6), Vector3(0, GROUND_Y + 0.02, -7.5), path)
	_box(Vector3(1.4, 0.04, 20), Vector3(3.0, GROUND_Y + 0.02, -18.0), path)
	var curb := Color(0.75, 0.73, 0.68)
	_box(Vector3(60, 0.1, 0.12), Vector3(0, GROUND_Y + 0.05, -6.65), curb)
	_box(Vector3(60, 0.1, 0.12), Vector3(0, GROUND_Y + 0.05, -8.35), curb)


## Хрущёвки напротив — настоящие 3D-модели, побольше (дом напротив видно высоким).
func _build_houses() -> void:
	_model("khrushchevka", Vector3(0, GROUND_Y, -32), 0.0, 1.35)
	_model("khrushchevka", Vector3(-46, GROUND_Y, -42), 0.35, 1.35)
	_model("khrushchevka", Vector3(46, GROUND_Y, -40), -0.4, 1.35)


## Деревья пониже и не в центре (не закрывают дом), кусты вдоль тропинки.
func _build_greenery() -> void:
	var trees: Array[Vector3] = [
		Vector3(-7.0, 0, -6.0), Vector3(7.5, 0, -6.5), Vector3(-11.0, 0, -12.0),
		Vector3(11.5, 0, -11.0), Vector3(-5.5, 0, -20.0), Vector3(9.0, 0, -22.0),
	]
	for i in trees.size():
		var model := "tree_poplar" if i % 2 == 0 else "tree_birch"
		_model(model, trees[i] + Vector3(0, GROUND_Y, 0), i * 1.7, 1.0 + (i % 3) * 0.1)
	var bushes: Array[Vector3] = [
		Vector3(-4.0, 0, -5.2), Vector3(-1.5, 0, -5.0), Vector3(1.8, 0, -5.3),
		Vector3(4.5, 0, -5.1), Vector3(-3.0, 0, -9.6), Vector3(5.2, 0, -9.8),
		Vector3(-8.5, 0, -9.4), Vector3(0.5, 0, -10.0),
	]
	for i in bushes.size():
		var model := "bush_round" if i % 2 == 0 else "bush_wide"
		_model(model, bushes[i] + Vector3(0, GROUND_Y, 0), i * 0.9, 1.0 + (i % 3) * 0.15)


# ---------------- Голуби ----------------

func _spawn_pigeon(fly_in: bool) -> void:
	var pigeon := YardPigeon.new()
	add_child(pigeon)
	_set_fp_only(pigeon)
	pigeon.scale = Vector3.ONE * 1.6 # издалека (5–10 м) иначе их почти не видно
	pigeon.flown.connect(_on_pigeon_flown)
	_pigeons.append(pigeon)
	var spot := _random_spot()
	if fly_in:
		pigeon.land_at(spot)
	else:
		pigeon.global_position = spot
		pigeon.rotation.y = randf() * TAU


func _on_pigeon_flown(pigeon: YardPigeon) -> void:
	_pigeons.erase(pigeon)
	get_tree().create_timer(randf_range(4.0, 10.0)).timeout.connect(_spawn_pigeon.bind(true))


## Пройтись пешком в соседнюю точку (короткими шажками, клюя по пути).
func _walk(pigeon: YardPigeon) -> void:
	var from := pigeon.global_position
	var target := from + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
	var local := to_local(target)
	local.x = clampf(local.x, PIGEON_AREA.position.x, PIGEON_AREA.end.x)
	local.z = clampf(local.z, -PIGEON_AREA.end.y, -PIGEON_AREA.position.y)
	target = to_global(local)
	if Vector2(target.x - from.x, target.z - from.z).length() < 0.2:
		return
	pigeon.look_at(Vector3(target.x, from.y, target.z), Vector3.UP)
	pigeon.set_meta("walking", true)
	var tween := pigeon.create_tween()
	tween.tween_property(pigeon, "global_position", target, from.distance_to(target) / 0.5)
	tween.tween_callback(func() -> void: pigeon.set_meta("walking", false))


func _random_spot() -> Vector3:
	var x := randf_range(PIGEON_AREA.position.x, PIGEON_AREA.end.x)
	var z := -randf_range(PIGEON_AREA.position.y, PIGEON_AREA.end.y)
	return to_global(Vector3(x, GROUND_Y, z))


# ---------------- Помощники ----------------

func _model(model_name: String, pos: Vector3, yaw: float, size: float) -> void:
	var node := (load(COURTYARD + model_name + ".glb") as PackedScene).instantiate() as Node3D
	node.position = pos
	node.rotation.y = yaw
	node.scale = Vector3.ONE * size
	_add(node)


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	_add(mesh_instance)


func _add(node: Node3D) -> void:
	add_child(node)
	_set_fp_only(node)


## Только для камер от первого лица и без теней в комнату.
func _set_fp_only(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.layers = Apartment.FP_ONLY_LAYER
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if geometry != _sky_quad:
			geometry.material_overlay = _tint_mat # темнеет вместе с небом
	for child in node.get_children():
		_set_fp_only(child)
