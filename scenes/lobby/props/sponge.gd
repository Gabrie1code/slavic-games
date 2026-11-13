class_name Sponge
extends RigidBody3D
## Губка с раковины. Как баллончик: STORED — лежит на раковине, HELD — в руке, LOOSE — брошена
## (G): её может подобрать любой, через LOOSE_LIFE сек пропадает. Если губку взяли и не положили
## обратно, через Sink.SPONGE_BACK сек на раковине появляется новая.
## Зажать удар (ЛКМ) — оттирать: смывает краску баллончика и лужи у туалета под прицелом.

enum State { STORED, HELD, LOOSE }

const LOOSE_LIFE := 15.0
const SIZE := Vector3(0.1, 0.045, 0.065)
const HAND_POS := Vector3(0, -0.45, 0.02)
## Радиус, в котором оттирается за раз.
const SCRUB_RADIUS := 0.25

var state := State.STORED
var holder: PlayerData

var _model: Node3D
var _loose_time := 0.0
var _foam: CPUParticles3D


func _ready() -> void:
	add_to_group("sponge")
	_model = make_model()
	add_child(_model)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	shape.position.y = SIZE.y / 2.0
	add_child(shape)
	mass = 0.1
	linear_damp = 2.0
	angular_damp = 5.0
	var surface := PhysicsMaterial.new()
	surface.friction = 1.0
	surface.bounce = 0.0
	physics_material_override = surface
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_foam = _make_foam()
	add_child(_foam)
	_set_loose_physics(false)


## Модель губки: жёлтый поролон и зелёный жёсткий слой сверху (и для «губки в кадре»).
static func make_model() -> Node3D:
	var root := Node3D.new()
	for layer: Array in [[Color("f2cf3d"), 0.033, 0.0165], [Color("2f8a3a"), 0.012, 0.039]]:
		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(SIZE.x, layer[1], SIZE.z)
		mesh_instance.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = layer[0]
		mat.roughness = 0.95
		mesh_instance.material_override = mat
		mesh_instance.position.y = layer[2]
		root.add_child(mesh_instance)
	return root


func _process(delta: float) -> void:
	if state != State.LOOSE:
		return
	_loose_time += delta
	if _loose_time > LOOSE_LIFE:
		_model.scale = Vector3.ONE * maxf(0.01, 1.0 - (_loose_time - LOOSE_LIFE) * 3.0)
		if _loose_time > LOOSE_LIFE + 0.35:
			queue_free()


## Положить на раковину (parent — раковина).
func store_in(parent: Node3D, pos: Vector3) -> void:
	state = State.STORED
	holder = null
	_set_loose_physics(false)
	_move_to(parent)
	position = pos
	rotation = Vector3(0, 0.3, 0)
	_set_render_layer(_model, 1)


func hold(p: PlayerData, character: PlayerCharacter) -> void:
	state = State.HELD
	holder = p
	_set_loose_physics(false)
	_move_to(null)
	character.attach_to_part("ArmR", self)
	_foam.layers = 1 # пену видно всем, и самому от первого лица
	position = HAND_POS
	rotation = Vector3(PI / 2.0, 0, 0)
	character.set_arm_pose(0.15, 0.9, 0.2)


func drop(character: PlayerCharacter, world: Node3D) -> void:
	var start := global_transform
	state = State.LOOSE
	holder = null
	_loose_time = 0.0
	_move_to(world)
	global_transform = start
	_set_render_layer(_model, 1)
	_set_loose_physics(true)
	linear_velocity = -character.global_basis.z * 1.0 + Vector3.UP * 0.8
	character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2)


## Оттереть всё в точке point: краску баллончика (и на людях, и на стенах) и лужи у туалета.
func scrub_at(point: Vector3, toilet: Toilet) -> void:
	SprayCan.erase_near(point, SCRUB_RADIUS)
	if toilet:
		toilet.scrub(point, SCRUB_RADIUS + 0.1)
	_foam.global_position = point
	_foam.emitting = true


func stop_scrub() -> void:
	_foam.emitting = false


## Пена — белые пузырьки там, где трут.
func _make_foam() -> CPUParticles3D:
	var foam := CPUParticles3D.new()
	foam.top_level = true
	foam.emitting = false
	foam.amount = 24
	foam.lifetime = 0.6
	foam.direction = Vector3.UP
	foam.spread = 80.0
	foam.initial_velocity_min = 0.2
	foam.initial_velocity_max = 0.6
	foam.gravity = Vector3(0, -0.5, 0)
	foam.scale_amount_min = 0.5
	foam.scale_amount_max = 1.3
	var mesh := SphereMesh.new()
	mesh.radius = 0.015
	mesh.height = 0.03
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.2
	mesh.material = mat
	foam.mesh = mesh
	return foam


func _set_loose_physics(on: bool) -> void:
	freeze = not on
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
