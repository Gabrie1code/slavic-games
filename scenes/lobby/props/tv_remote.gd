class_name TvRemote
extends RigidBody3D
## Пульт от телевизора на диване (один на всё лобби). Ничего не переключает: его можно взять
## в руку («подтвердить»), бросить (G). Брошенный пульт, пролежав на полу дольше BACK_TIME сек,
## сам возвращается на диван.

enum State { HOME, HELD, LOOSE }

const BACK_TIME := 5.0
const SIZE := Vector3(0.06, 0.025, 0.2)
const HAND_POS := Vector3(0, -0.45, 0.04)
const THROW_SPEED := 4.5

var state := State.HOME
var holder: PlayerData
## Где пульт лежит на диване (в координатах квартиры).
var home_position := Vector3.ZERO
var home_yaw := 0.0

var _model: Node3D
var _still_time := 0.0


func _ready() -> void:
	add_to_group("tv_remote")
	_model = make_model()
	add_child(_model)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	shape.position.y = SIZE.y / 2.0
	add_child(shape)
	mass = 0.15
	angular_damp = 1.5
	var surface := PhysicsMaterial.new()
	surface.friction = 0.8
	surface.bounce = 0.25
	physics_material_override = surface
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	go_home()


## Модель: чёрный корпус, серые кнопки, красная кнопка включения (и для «пульта в кадре»).
static func make_model() -> Node3D:
	var root := Node3D.new()
	root.add_child(_box(SIZE, Vector3(0, SIZE.y / 2.0, 0), Color("1c1c1e"), 0.5))
	root.add_child(_box(Vector3(0.016, 0.008, 0.016), Vector3(-0.015, SIZE.y, -0.075),
		Color("c62828"), 0.4))
	for row in 4:
		for col in 3:
			var pos := Vector3(-0.018 + col * 0.018, SIZE.y, -0.035 + row * 0.022)
			root.add_child(_box(Vector3(0.012, 0.006, 0.012), pos, Color("8a8d91"), 0.6))
	# Окошко инфракрасного глазка спереди.
	root.add_child(_box(Vector3(0.03, 0.012, 0.004), Vector3(0, SIZE.y / 2.0, -SIZE.z / 2.0),
		Color("4a0d12"), 0.15))
	return root


static func _box(size: Vector3, pos: Vector3, color: Color, rough: float) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	return mesh_instance


func _physics_process(delta: float) -> void:
	if state != State.LOOSE:
		return
	# Считаем, сколько пульт уже лежит без движения (на полу или где упал).
	if linear_velocity.length() < 0.15:
		_still_time += delta
	else:
		_still_time = 0.0
	if _still_time > BACK_TIME or global_position.y < -5.0:
		state = State.HOME # чтобы не вызвать дважды; перенос узла — после физического кадра
		go_home.call_deferred()


## Вернуться на диван.
func go_home() -> void:
	state = State.HOME
	holder = null
	_set_loose_physics(false)
	_move_to(_home_parent())
	position = home_position
	rotation = Vector3(0, home_yaw, 0)
	_set_render_layer(_model, 1)


func hold(p: PlayerData, character: PlayerCharacter) -> void:
	state = State.HELD
	holder = p
	_set_loose_physics(false)
	_move_to(null)
	character.attach_to_part("ArmR", self)
	position = HAND_POS
	rotation = Vector3(PI / 2.0, 0, 0)
	character.set_arm_pose(0.15, 0.9, 0.2)


## Бросить вперёд по взгляду (dir — куда смотрит камера или персонаж).
func throw(character: PlayerCharacter, dir: Vector3) -> void:
	var start := global_transform
	state = State.LOOSE
	holder = null
	_still_time = 0.0
	_move_to(_home_parent())
	global_transform = start
	_set_render_layer(_model, 1)
	_set_loose_physics(true)
	linear_velocity = dir.normalized() * THROW_SPEED + Vector3.UP * 1.5
	angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2)


func _home_parent() -> Node:
	return get_meta("home_parent") as Node if has_meta("home_parent") else get_parent()


func _set_loose_physics(on: bool) -> void:
	freeze = not on
	collision_layer = 2 if on else 0
	collision_mask = 1 if on else 0


func _move_to(parent: Node) -> void:
	if get_parent() == parent:
		return
	if get_parent():
		get_parent().remove_child(self)
	if parent:
		parent.add_child(self)


func _set_render_layer(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_render_layer(child, layer)
