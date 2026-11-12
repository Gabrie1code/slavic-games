class_name SprayCan
extends RigidBody3D
## Баллончик с краской. Три состояния:
##   STORED — лежит в ящике тумбочки (заморожен, без столкновений);
##   HELD   — в правой руке персонажа (с ним можно бегать; удар — «пшикнуть» облачком краски);
##   LOOSE  — брошен (G): падает и катается; его может подобрать любой игрок «подтвердить».
##            Пролежал на полу LOOSE_LIFE сек — исчезает.

signal gone(can: SprayCan)

enum State { STORED, HELD, LOOSE }

const MODEL := preload("res://assets/models/apartment/spray_can.glb")
const LOOSE_LIFE := 15.0
## В руке: конец руки (как точка Hand у персонажа) и поворот — баллончик стоит почти прямо.
const HAND_POS := Vector3(0, -0.42, 0.02)
const HAND_ROT := Vector3(-PI / 2.0, 0.0, 0.0)

var state := State.STORED
var holder: PlayerData

var _loose_time := 0.0
var _model: Node3D


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
	var forward := -character.global_basis.z
	linear_velocity = forward * 2.2 + Vector3.UP * 1.5
	angular_velocity = Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-6, 6))
	character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2)


## «Пшик»: облачко краски цвета игрока перед распылителем, в сторону forward.
func spray(color: Color, forward: Vector3) -> void:
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.explosiveness = 0.6
	puff.amount = 30
	puff.lifetime = 0.9
	puff.direction = Vector3(0, 0, -1)
	puff.spread = 18.0
	puff.initial_velocity_min = 1.5
	puff.initial_velocity_max = 2.6
	puff.gravity = Vector3(0, -0.6, 0)
	puff.damping_min = 2.0
	puff.damping_max = 3.0
	puff.scale_amount_min = 0.6
	puff.scale_amount_max = 1.6
	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	puff.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0, Color(color, 0.9))
	fade.set_color(1, Color(color, 0.0))
	puff.color_ramp = fade
	get_tree().current_scene.add_child(puff)
	# Струя — от распылителя наверху баллончика туда, куда смотрит владелец.
	puff.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP),
		to_global(Vector3(0, 0.19, 0)))
	puff.emitting = true
	get_tree().create_timer(1.5).timeout.connect(puff.queue_free)


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
