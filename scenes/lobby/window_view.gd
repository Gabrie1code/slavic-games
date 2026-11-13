class_name WindowView
extends Node3D
## Двор за окном гостиной (видно только от первого лица — слой Apartment.FP_ONLY_LAYER):
## небо (огромная картинка), газон, тропинка, настоящие 3D-хрущёвки напротив, деревья пониже,
## кусты и голуби: ходят по земле, иногда улетают, вместо них прилетают другие.
## Время суток — как на часах у игрока (берётся при входе в лобби и идёт дальше): днём голубое
## небо, утром рассвет, вечером закат, ночью темно, звёзды и луна. Всё меняется плавно.
## F8 — плавно промотать на час вперёд (проверить, как выглядит ночь днём).
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
## Окна хрущёвок (tools/blender/courtyard.py): 12 окон в ряд на 5 этажах, лицевая сторона.
const HOUSE_W := 28.0
const HOUSE_FRONT := 5.6 # чуть впереди стекла (5.56), чтобы издалека не мерцало
const HOUSE_FLOOR := 2.7
const HOUSE_COLS := 12
const HOUSE_FLOORS := 5
## Ночью свет в окне горит столько секунд (у каждого окна своё случайное время)…
const LIGHT_ON := Vector2(30.0, 120.0)
## …а погасшее окно загорается снова через столько.
const LIGHT_OFF := Vector2(5.0, 90.0)
const LIGHT_FADE := 1.5
const LIGHT_COLOR := Color(1.0, 0.8, 0.45)

## Время суток: ключевые точки привязаны к восходу и закату ЭТОГО дня (SunCalendar — Россия,
## по дате на компьютере): [от чего («0», «rise», «set», «24»), сдвиг в часах, верх неба,
## у горизонта, облака, «фильтр» двора, ночь 0..1]. Зимой день короче — всё сдвигается само.
const DAY_KEYS: Array = [
	["0", 0.0, Color("050a1c"), Color("0d1630"), Color("2a3044"), Color(0.22, 0.26, 0.42), 1.0],
	["rise", -1.5, Color("050a1c"), Color("0d1630"), Color("2a3044"), Color(0.22, 0.26, 0.42), 1.0],
	["rise", -0.5, Color("1b2450"), Color("7a4a6e"), Color("6a5470"), Color(0.45, 0.4, 0.55), 0.6],
	["rise", 0.5, Color("4a6fb5"), Color("f2a36b"), Color("f5c2a0"), Color(0.95, 0.78, 0.68), 0.0],
	["rise", 2.0, Color("5f96d2"), Color("cde8f5"), Color("ffffff"), Color(1, 1, 1), 0.0],
	["set", -3.0, Color("5f96d2"), Color("cde8f5"), Color("ffffff"), Color(1, 1, 1), 0.0],
	["set", -1.5, Color("5478b8"), Color("f7c27a"), Color("ffe2b8"), Color(1.0, 0.86, 0.72), 0.0],
	["set", -0.2, Color("34336e"), Color("f06a3a"), Color("f29a7a"), Color(0.8, 0.56, 0.5), 0.1],
	["set", 0.8, Color("141a40"), Color("4a2a50"), Color("3a3550"), Color(0.36, 0.34, 0.5), 0.6],
	["set", 2.0, Color("050a1c"), Color("0d1630"), Color("2a3044"), Color(0.22, 0.26, 0.42), 1.0],
	["24", 0.0, Color("050a1c"), Color("0d1630"), Color("2a3044"), Color(0.22, 0.26, 0.42), 1.0],
]

## Который час за окном (0..24, с долями).
var hour := 12.0
## Восход и закат сегодня (часы) и ключи неба на сегодня: [час, цвета…, ночь].
var sunrise := 6.0
var sunset := 20.5
var _keys: Array = []

var _pigeons: Array[YardPigeon] = []
var _sky_mat: ShaderMaterial
## Общий «фильтр» для всех вещей двора (material_overlay) — темнее ночью, теплее на закате.
var _tint_mat: ShaderMaterial
var _sky_quad: MeshInstance3D
## Окна с огоньками: материал (яркость — его прозрачность), горит ли, сколько до смены.
var _win_mats: Array[StandardMaterial3D] = []
var _win_level := PackedFloat32Array()
var _win_on := PackedByteArray()
var _win_timer := PackedFloat32Array()
## Сколько ещё часов «промотать» плавно (F8 — час за 3 секунды, без рывка).
var _skip_left := 0.0


func _ready() -> void:
	var now := Time.get_time_dict_from_system()
	hour = float(now["hour"]) + float(now["minute"]) / 60.0 + float(now["second"]) / 3600.0
	var sun := SunCalendar.today()
	sunrise = sun.x
	sunset = sun.y
	_build_keys()
	_tint_mat = ShaderMaterial.new()
	_tint_mat.shader = TINT_SHADER
	_build_sky()
	_build_ground()
	_build_houses()
	_build_greenery()
	for i in PIGEONS:
		_spawn_pigeon(false)


func _process(delta: float) -> void:
	# Время идёт как в жизни; небо пересчитывается каждый кадр — всё меняется плавно.
	var skip := minf(_skip_left, delta / 3.0)
	_skip_left -= skip
	hour = fmod(hour + delta / 3600.0 + skip, 24.0)
	_apply_time()
	_update_pigeons(delta)
	_update_windows(delta)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F8:
		_skip_left += 1.0


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

## Ключи неба на сегодня: часы от восхода/заката, по порядку (короткий зимний день не ломает
## порядок — каждый следующий хотя бы на 3 минуты позже предыдущего).
func _build_keys() -> void:
	_keys.clear()
	var last := -1.0
	for key: Array in DAY_KEYS:
		var base := {"0": 0.0, "rise": sunrise, "set": sunset, "24": 24.0}
		var at := clampf(float(base[key[0]]) + float(key[1]), 0.0, 24.0)
		if key[0] != "24":
			at = maxf(at, last + 0.05)
		last = at
		_keys.append([at] + key.slice(2))


## Между какими ключами сейчас: [ключ до, ключ после, доля 0..1 (сглаженная)].
func _key_pair() -> Array:
	var a: Array = _keys[0]
	var b: Array = _keys[1]
	for i in _keys.size() - 1:
		if hour >= float(_keys[i][0]) and hour <= float(_keys[i + 1][0]):
			a = _keys[i]
			b = _keys[i + 1]
			break
	# smoothstep — без «рывков» скорости на стыках ключевых часов.
	return [a, b, smoothstep(0.0, 1.0, inverse_lerp(float(a[0]), float(b[0]), hour))]


## Цвета неба, солнце/луна и «фильтр» двора для текущего часа.
func _apply_time() -> void:
	if _sky_mat == null:
		return
	var pair := _key_pair()
	var a: Array = pair[0]
	var b: Array = pair[1]
	var t: float = pair[2]
	_sky_mat.set_shader_parameter("top_color", (a[1] as Color).lerp(b[1], t))
	_sky_mat.set_shader_parameter("horizon_color", (a[2] as Color).lerp(b[2], t))
	_sky_mat.set_shader_parameter("cloud_color", (a[3] as Color).lerp(b[3], t))
	_tint_mat.set_shader_parameter("tint", (a[4] as Color).lerp(b[4], t))
	_sky_mat.set_shader_parameter("night", lerpf(float(a[5]), float(b[5]), t))
	# Солнце идёт дугой слева направо от восхода до заката, луна — ночью.
	var day_t := inverse_lerp(sunrise, sunset, hour)
	var sun_up := sin(PI * clampf(day_t, 0.0, 1.0))
	_sky_mat.set_shader_parameter("sun_uv", _arc_uv(day_t, 50.0))
	# Солнце и луна появляются и исчезают у горизонта плавно, а не вспышкой.
	_sky_mat.set_shader_parameter("sun_alpha", clampf(sun_up * 6.0, 0.0, 1.0))
	# Низкое солнце — оранжевое.
	_sky_mat.set_shader_parameter("sun_color",
		Color(1.0, 0.55, 0.25).lerp(Color(1.0, 0.96, 0.78), clampf(sun_up * 2.0, 0.0, 1.0)))
	var night_len := 24.0 - sunset + sunrise
	var moon_t := fposmod(hour - sunset, 24.0) / night_len
	_sky_mat.set_shader_parameter("moon_uv", _arc_uv(moon_t, 55.0))
	var moon_up := sin(PI * clampf(moon_t, 0.0, 1.0))
	_sky_mat.set_shader_parameter("moon_alpha", clampf(moon_up * 6.0, 0.0, 1.0))


## На улице вечер или ночь — в квартире пора включать свет (LobbyLamp).
func is_dark() -> bool:
	return hour >= sunset - 0.5 or hour < sunrise + 0.5 # полчаса до заката — уже сумерки


## Насколько светло на улице (1 — день, 0 — ночь): для солнца в комнате.
func daylight() -> float:
	if _keys.is_empty():
		return 1.0
	var pair := _key_pair()
	return 1.0 - lerpf(float(pair[0][5]), float(pair[1][5]), float(pair[2]))


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
	_add_window_lights(_model("khrushchevka", Vector3(0, GROUND_Y, -32), 0.0, 1.35))
	_add_window_lights(_model("khrushchevka", Vector3(-46, GROUND_Y, -42), 0.35, 1.35))
	_add_window_lights(_model("khrushchevka", Vector3(46, GROUND_Y, -40), -0.4, 1.35))


## Свет в окнах дома: тёплый прямоугольник на каждом стекле (две половинки — между ними рама).
## Сам по себе невидим (прозрачный); ночью загорается в случайных окнах (_update_windows).
func _add_window_lights(house: Node3D) -> void:
	for f in HOUSE_FLOORS:
		for c in HOUSE_COLS:
			if f == 0 and c in [2, 6, 10]:
				continue # подъезды
			var x := -HOUSE_W / 2.0 + 1.2 + c * (HOUSE_W - 2.4) / (HOUSE_COLS - 1)
			var y := 0.6 + f * HOUSE_FLOOR + 1.45
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(LIGHT_COLOR, 0.0)
			for side: float in [-1.0, 1.0]:
				var quad := MeshInstance3D.new()
				var mesh := QuadMesh.new()
				mesh.size = Vector2(0.5, 1.15)
				quad.mesh = mesh
				quad.material_override = mat
				quad.position = Vector3(x + side * 0.28, y, HOUSE_FRONT)
				quad.layers = Apartment.FP_ONLY_LAYER # без «фильтра» двора: ночью свет яркий
				quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				house.add_child(quad)
			_win_mats.append(mat)
			_win_level.append(0.0)
			_win_on.append(0)
			# Сразу ночью уже горит примерно каждое третье окно, остальные загорятся позже.
			_win_timer.append(randf_range(0.0, LIGHT_OFF.y))
			if randf() < 0.35:
				_win_on[_win_on.size() - 1] = 1
				_win_timer[_win_timer.size() - 1] = randf_range(0.0, LIGHT_ON.y)


## Ночью окна по одному плавно загораются и гаснут — каждое по своему случайному таймеру
## (горит 30–120 сек). Днём свет во всех окнах плавно гаснет.
func _update_windows(delta: float) -> void:
	var night := is_dark()
	for i in _win_mats.size():
		_win_timer[i] -= delta
		if _win_timer[i] <= 0.0:
			_win_on[i] = 1 - _win_on[i]
			var range_s := LIGHT_ON if _win_on[i] == 1 else LIGHT_OFF
			_win_timer[i] = randf_range(range_s.x, range_s.y)
		var target := 0.9 if night and _win_on[i] == 1 else 0.0
		var level := move_toward(_win_level[i], target, delta / LIGHT_FADE)
		if level != _win_level[i]:
			_win_level[i] = level
			_win_mats[i].albedo_color.a = level


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

func _model(model_name: String, pos: Vector3, yaw: float, size: float) -> Node3D:
	var node := (load(COURTYARD + model_name + ".glb") as PackedScene).instantiate() as Node3D
	node.position = pos
	node.rotation.y = yaw
	node.scale = Vector3.ONE * size
	_add(node)
	return node


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
