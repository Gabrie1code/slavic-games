class_name WindowView
extends Node3D
## Двор за окном гостиной (видно только от первого лица — слой Apartment.FP_ONLY_LAYER):
## небо (огромная картинка), газон, тропинка, настоящие 3D-хрущёвки напротив, деревья пониже,
## кусты и голуби: ходят по земле, иногда улетают, вместо них прилетают другие.
## Узел ставится в точку под окном (x — центр окна, z — внешняя сторона стены); «вперёд» — −Z.

const COURTYARD := "res://assets/models/courtyard/"
const SKY := preload("res://assets/textures/window/window_sky.png")
const GROUND_Y := -6.0
const PIGEONS := 5
## Где гуляют голуби (x — вбок, z — вглубь от стены).
const PIGEON_AREA := Rect2(-5.0, 5.0, 10.0, 6.0)

var _pigeons: Array[YardPigeon] = []


func _ready() -> void:
	_build_sky()
	_build_ground()
	_build_houses()
	_build_greenery()
	for i in PIGEONS:
		_spawn_pigeon(false)


func _process(delta: float) -> void:
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
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = SKY
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material_override = mat
	quad.position = Vector3(0, 100, -60)
	_add(quad)


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
		(node as GeometryInstance3D).layers = Apartment.FP_ONLY_LAYER
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_set_fp_only(child)
