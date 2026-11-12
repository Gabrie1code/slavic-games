class_name SprayCan
extends RigidBody3D
## Баллончик с краской. Три состояния:
##   STORED — лежит в ящике тумбочки (заморожен, без столкновений);
##   HELD   — в правой руке персонажа (с ним можно бегать). Зажать удар — краска струёй летит
##            туда, куда смотрит прицел, и на стенах/полу/мебели остаются следы (Decal);
##            второе действие (ПКМ) — следующий из 7 цветов, полоса на баллончике того же цвета;
##   LOOSE  — брошен (G): падает и катается; его может подобрать любой игрок «подтвердить».
##            Пролежал на полу LOOSE_LIFE сек — исчезает.

signal gone(can: SprayCan)

enum State { STORED, HELD, LOOSE }

const MODEL := preload("res://assets/models/apartment/spray_can.glb")
const LOOSE_LIFE := 15.0
## В руке: конец руки (как точка Hand у персонажа) и поворот — баллончик стоит почти прямо.
const HAND_POS := Vector3(0, -0.42, 0.02)
const HAND_ROT := Vector3(-PI / 2.0, 0.0, 0.0)
## 7 ярких цветов краски (переключаются по кругу).
const COLORS: Array[Color] = [
	Color("ff2a2a"), Color("ff8c1a"), Color("ffe11a"), Color("2ecc40"),
	Color("1ac8ff"), Color("2a5cff"), Color("b33cff"),
]
const SPLAT := preload("res://assets/textures/fx/paint_splat.png")
## Распылитель (в координатах баллончика) и сколько следов краски всего хранится в мире.
const NOZZLE := Vector3(0, 0.19, -0.012)
const MAX_SPLATS := 350
const SPLAT_STEP := 0.05
const STREAM_TIME := 0.25

## Все следы краски (старые удаляются, когда их больше MAX_SPLATS).
static var _splats: Array[Decal] = []

var color_index := 0

var state := State.STORED
var holder: PlayerData

var _loose_time := 0.0
var _model: Node3D
var _stream: CPUParticles3D
var _last_splat := Vector3.INF
var _splat_time := 0.0


func _ready() -> void:
	add_to_group("spray_can")
	_model = MODEL.instantiate() as Node3D
	add_child(_model)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.035
	cylinder.height = 0.2
	shape.shape = cylinder
	shape.position.y = 0.1
	add_child(shape)
	mass = 0.3
	_stream = _make_stream()
	add_child(_stream)
	tint_stripe(_model, color())
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC # в руке двигается вместе с ней
	_set_loose_physics(false)


func _process(delta: float) -> void:
	if state != State.LOOSE:
		return
	_loose_time += delta
	if _loose_time > LOOSE_LIFE:
		# Исчезает: быстро сжимается.
		_model.scale = Vector3.ONE * maxf(0.01, 1.0 - (_loose_time - LOOSE_LIFE) * 3.0)
		if _loose_time > LOOSE_LIFE + 0.35:
			gone.emit(self)
			queue_free()


## Положить в ящик (родитель — ящик тумбочки).
func store_in(parent: Node3D, pos: Vector3, rot: Vector3) -> void:
	state = State.STORED
	holder = null
	_set_loose_physics(false)
	_move_to(parent)
	position = pos
	rotation = rot


## Взять в руку персонажа.
func hold(p: PlayerData, character: PlayerCharacter) -> void:
	state = State.HELD
	holder = p
	_set_loose_physics(false)
	_move_to(null)
	character.attach_to_part("ArmR", self)
	_stream.layers = 1 # струю видно всем, и самому держащему от первого лица
	position = HAND_POS
	rotation = HAND_ROT
	character.set_arm_pose(0.15, 0.9, 0.2)


## Бросить перед собой: дальше баллончик — обычное физическое тело в мире world.
func drop(character: PlayerCharacter, world: Node3D) -> void:
	var start := global_transform
	state = State.LOOSE
	holder = null
	_loose_time = 0.0
	_move_to(world)
	global_transform = start
	_set_render_layer(_model, 1)
	_set_loose_physics(true)
	stop_spray()
	var forward := -character.global_basis.z
	linear_velocity = forward * 2.2 + Vector3.UP * 1.5
	angular_velocity = Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-6, 6))
	character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2)


func color() -> Color:
	return COLORS[color_index]


## Следующий цвет краски; полоса на баллончике перекрашивается.
func next_color() -> void:
	color_index = (color_index + 1) % COLORS.size()
	tint_stripe(_model, color())


## Покрасить полосу (материал CanStripe) модели баллончика в цвет color.
static func tint_stripe(node: Node, paint: Color) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance and mesh_instance.mesh:
		for i in mesh_instance.mesh.get_surface_count():
			var surface := mesh_instance.mesh.surface_get_material(i)
			if surface and surface.resource_name.begins_with("CanStripe"):
				var stripe := StandardMaterial3D.new()
				stripe.albedo_color = paint
				stripe.roughness = 0.4
				mesh_instance.set_surface_override_material(i, stripe)
	for child in node.get_children():
		tint_stripe(child, paint)


## Красить: струя от распылителя к target. hit — луч попал в стену/пол/мебель (normal — её
## сторона): тогда там остаются следы краски, плотной «дорожкой», пока ведут прицелом.
func spray_at(target: Vector3, normal: Vector3, hit: bool, delta: float) -> void:
	var nozzle := to_global(NOZZLE)
	var to := target - nozzle
	if to.length() < 0.05:
		return
	_stream.global_transform = Transform3D(Basis.looking_at(to.normalized(), _up_for(to)), nozzle)
	var speed := to.length() / STREAM_TIME
	_stream.initial_velocity_min = speed * 0.9
	_stream.initial_velocity_max = speed
	_stream.color = color()
	_stream.emitting = true
	_splat_time += delta
	if hit and (target.distance_to(_last_splat) > SPLAT_STEP or _splat_time > 0.15):
		_splat_time = 0.0
		_last_splat = target
		_place_splat(target, normal)


func stop_spray() -> void:
	_stream.emitting = false
	_last_splat = Vector3.INF


func _place_splat(point: Vector3, normal: Vector3) -> void:
	var decal := Decal.new()
	var size := randf_range(0.16, 0.24)
	decal.size = Vector3(size, 0.3, size)
	decal.texture_albedo = SPLAT
	decal.modulate = color()
	decal.cull_mask = 1 # только стены, пол и мебель (не персонажи)
	get_tree().current_scene.add_child(decal)
	# Decal красит вдоль своей −Y: его +Y смотрит из поверхности.
	var y := normal.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT)
	x = x.normalized().rotated(y, randf() * TAU)
	decal.global_transform = Transform3D(Basis(x, y, x.cross(y)), point)
	_splats.append(decal)
	if _splats.size() > MAX_SPLATS:
		var old: Decal = _splats.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func _up_for(direction: Vector3) -> Vector3:
	return Vector3.UP if absf(direction.normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD


## Струя краски: мелкие капли летят вдоль −Z узла (узел поворачивается к цели).
func _make_stream() -> CPUParticles3D:
	var stream := CPUParticles3D.new()
	stream.top_level = true
	stream.emitting = false
	stream.amount = 60
	stream.lifetime = STREAM_TIME
	stream.direction = Vector3(0, 0, -1)
	stream.spread = 5.0
	stream.gravity = Vector3.ZERO
	stream.scale_amount_min = 0.6
	stream.scale_amount_max = 1.4
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	stream.mesh = mesh
	return stream


func _set_loose_physics(on: bool) -> void:
	freeze = not on
	# Слой 2 — как осколки: катается по полу и мебели, но игрокам под ногами не мешает.
	collision_layer = 2 if on else 0
	collision_mask = 1 if on else 0


func _move_to(parent: Node) -> void:
	if get_parent():
		get_parent().remove_child(self)
	if parent:
		parent.add_child(self)


func _set_render_layer(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_render_layer(child, layer)
