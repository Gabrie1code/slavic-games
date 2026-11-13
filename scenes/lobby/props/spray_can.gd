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
## 8 цветов краски (7 ярких и белый; переключаются по кругу).
const COLORS: Array[Color] = [
	Color("ff2a2a"), Color("ff8c1a"), Color("ffe11a"), Color("2ecc40"),
	Color("1ac8ff"), Color("2a5cff"), Color("b33cff"), Color("ffffff"),
]
const SPLAT := preload("res://assets/textures/fx/paint_splat.png")
## Распылитель (в координатах баллончика) и сколько следов краски всего хранится в мире.
const NOZZLE := Vector3(0, 0.19, -0.012)
const MAX_SPLATS := 350
## Краска держится PAINT_LIFE сек, потом плавно пропадает (за PAINT_FADE сек). Пятна исчезают
## в том же порядке, в каком их рисовали, — рисунок «стирается» с того места, откуда начал.
const PAINT_LIFE := 20.0
const PAINT_FADE := 1.5
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
## Струя из «баллончика в кадре» (от первого лица видит только сам держащий): так брызги летят
## из баллончика на экране, а не из настоящей руки где-то сбоку.
var _view_stream: CPUParticles3D
## Слой модели держащего: общую струю (из руки) он сам от первого лица не видит.
var _owner_layer := 1
var _last_splat := Vector3.INF
## Где лежит в ящике (в координатах ящика) — держим там каждый кадр, см. _process.
var _stored_at := Transform3D.IDENTITY
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
	# Брошенный баллончик не укатывается далеко: трение, почти без отскока, гасим вращение.
	linear_damp = 1.5
	angular_damp = 4.0
	var surface := PhysicsMaterial.new()
	surface.friction = 1.0
	surface.bounce = 0.05
	physics_material_override = surface
	_stream = _make_stream()
	add_child(_stream)
	_view_stream = _make_stream()
	add_child(_view_stream)
	tint_stripe(_model, color())
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC # в руке двигается вместе с ней
	_set_loose_physics(false)


func _process(delta: float) -> void:
	if state == State.STORED:
		# Замороженное физическое тело не всегда едет за выдвигаемым ящиком (физика возвращала
		# его на старое место — баллончик оставался у задней стенки). Ставим его сами.
		transform = _stored_at
		return
	if state == State.HELD:
		HandHold.follow(self, 0.09) # ровно в кулаке, как бы ни была повёрнута рука
		return
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
	_stored_at = transform


## Взять в руку персонажа.
func hold(p: PlayerData, character: PlayerCharacter) -> void:
	state = State.HELD
	holder = p
	_set_loose_physics(false)
	_move_to(null)
	character.attach_to_part("ArmR", self)
	_stream.layers = 1 # струю видно всем (от первого лица — см. spray_at: своя струя из кадра)
	_owner_layer = 1 << (p.slot + 1) # слой модели игрока (как в лобби)
	HandHold.place(self, 0.09) # ровно стоит в кулаке, сжат посередине
	character.set_arm_pose(0.15, 0.9, 0.2)


## Бросить перед собой: дальше баллончик — обычное физическое тело в мире world.
## dir — куда бросить (взгляд игрока); Vector3.ZERO — уронить под себя.
func drop(character: PlayerCharacter, world: Node3D, dir: Vector3 = Vector3.ZERO) -> void:
	var start := global_transform
	state = State.LOOSE
	holder = null
	_loose_time = 0.0
	_move_to(world)
	global_transform = start
	_set_render_layer(_model, 1)
	_set_loose_physics(true)
	stop_spray()
	ThrowHelper.launch(self, character, dir)
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
				# Уже своя копия (покраска раньше или «поверх стен» у баллончика в кадре) —
				# меняем только цвет: новая копия теряла «поверх стен», и полоса пряталась
				# за корпусом.
				var current := mesh_instance.get_surface_override_material(i) as BaseMaterial3D
				if current:
					current.albedo_color = paint
					continue
				var stripe := StandardMaterial3D.new()
				stripe.albedo_color = paint
				stripe.roughness = 0.4
				mesh_instance.set_surface_override_material(i, stripe)
	for child in node.get_children():
		tint_stripe(child, paint)


## Красить: струя от распылителя к target. hit — луч попал во что-то (collider; normal — его
## сторона): там остаются следы краски, плотной «дорожкой», пока ведут прицелом. На игроке и
## на посуде след «прилипает» к ним (двигается вместе с ними, смывается, бьётся с посудой).
## view_can — баллончик «в кадре» у камеры держащего (null — вид сверху): тогда сам держащий
## видит струю из него, а остальные — из руки персонажа.
func spray_at(target: Vector3, normal: Vector3, hit: bool, delta: float,
		collider: Object = null, view_can: Node3D = null) -> void:
	if not _aim_stream(_stream, to_global(NOZZLE), target):
		return
	var in_view := view_can != null and view_can.is_visible_in_tree()
	_stream.layers = _owner_layer if in_view else 1
	if in_view:
		_aim_stream(_view_stream, view_can.to_global(NOZZLE), target)
		_view_stream.layers = _layer_of(view_can)
	else:
		_view_stream.emitting = false
	_splat_time += delta
	if hit and (target.distance_to(_last_splat) > SPLAT_STEP or _splat_time > 0.15):
		_splat_time = 0.0
		_last_splat = target
		_place_splat(target, normal, collider)


## Стереть следы краски рядом с точкой (губка): и на стенах, и на людях, и на посуде.
static func erase_near(point: Vector3, radius: float) -> void:
	for i in range(_splats.size() - 1, -1, -1):
		if not is_instance_valid(_splats[i]):
			_splats.remove_at(i)
			continue
		var decal: Decal = _splats[i]
		if decal.global_position.distance_to(point) < radius:
			decal.queue_free()
			_splats.remove_at(i)


## Смыть всю краску с персонажа (раковина в туалете).
static func clear_paint(node: Node) -> void:
	for child in node.get_children():
		if child is Decal:
			child.queue_free()
		else:
			clear_paint(child)


## Направить струю из nozzle в target (долетает за STREAM_TIME). false — цель слишком близко.
func _aim_stream(stream: CPUParticles3D, nozzle: Vector3, target: Vector3) -> bool:
	var to := target - nozzle
	if to.length() < 0.05:
		return false
	stream.global_transform = Transform3D(Basis.looking_at(to.normalized(), _up_for(to)), nozzle)
	var speed := to.length() / STREAM_TIME
	stream.initial_velocity_min = speed * 0.9
	stream.initial_velocity_max = speed
	stream.color = color()
	stream.emitting = true
	return true


## Слой видимости модели (первый меш внутри).
static func _layer_of(node: Node) -> int:
	if node is VisualInstance3D:
		return (node as VisualInstance3D).layers
	for child in node.get_children():
		var layer := _layer_of(child)
		if layer != 0:
			return layer
	return 0


func stop_spray() -> void:
	_stream.emitting = false
	_view_stream.emitting = false
	_last_splat = Vector3.INF


func _place_splat(point: Vector3, normal: Vector3, collider: Object) -> void:
	var decal := Decal.new()
	var size := randf_range(0.16, 0.24)
	var on_body := collider is PlayerCharacter
	if on_body:
		size *= 0.6 # на человеке пятна поменьше
	decal.size = Vector3(size, 0.3 if not on_body else 0.25, size)
	decal.texture_albedo = SPLAT
	decal.modulate = color()
	# Красим всё: и стены «только от первого лица» (передние), и персонажей; кроме кулаков в кадре.
	decal.cull_mask = 0xFFFFF & ~(0b1111 << 10)
	_cover_older(point, size, decal.modulate)
	_splat_parent(point, collider).add_child(decal)
	# Decal красит вдоль своей −Y: его +Y смотрит из поверхности.
	var y := normal.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT)
	x = x.normalized().rotated(y, randf() * TAU)
	decal.global_transform = Transform3D(Basis(x, y, x.cross(y)), point)
	_splats.append(decal)
	var fade := decal.create_tween()
	fade.tween_property(decal, "modulate:a", 0.0, PAINT_FADE).set_delay(PAINT_LIFE)
	fade.tween_callback(func() -> void:
		_splats.erase(decal) # убрать из списка до удаления — в списке только живые пятна
		decal.queue_free())
	if _splats.size() > MAX_SPLATS:
		# Сначала проверка, потом запись в переменную типа Decal: старое пятно могло уже
		# раствориться само (через 20 сек) — запись удалённого объекта роняла игру.
		var old: Variant = _splats.pop_front()
		if is_instance_valid(old):
			(old as Decal).queue_free()


## Новый цвет всегда поверх: старые пятна ДРУГОГО цвета прямо под новым пятном убираем.
## Иначе Godot смешивает наложенные следы как попало — получалась «каша» из цветов.
## Пятна того же цвета не трогаем: свой цвет на свой и так выглядит ровно.
static func _cover_older(point: Vector3, size: float, paint: Color) -> void:
	for i in range(_splats.size() - 1, -1, -1):
		var old: Variant = _splats[i]
		if not is_instance_valid(old):
			_splats.remove_at(i)
			continue
		var decal := old as Decal
		var same := Color(decal.modulate, 1.0).is_equal_approx(Color(paint, 1.0))
		if not same and decal.global_position.distance_to(point) < size * 0.45:
			decal.queue_free()
			_splats.remove_at(i)


## К чему прицепить след: к ближайшей части тела игрока, к посуде (Breakable) или к миру.
func _splat_parent(point: Vector3, collider: Object) -> Node:
	if collider is PlayerCharacter:
		var character := collider as PlayerCharacter
		var best: Node3D = character
		var best_dist := INF
		for part_name in ["Torso", "Head", "ArmL", "ArmR", "LegL", "LegR"]:
			var part := character.part(part_name)
			var d := part.global_position.distance_to(point)
			if d < best_dist:
				best_dist = d
				best = part
		return best
	if collider is Node and (collider as Node).get_parent() is Breakable:
		return ((collider as Node).get_parent() as Breakable).paint_root()
	return get_tree().current_scene


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
