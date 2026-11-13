class_name TvRemote
extends RigidBody3D
## Пульт от телевизора на диване (один на всё лобби). Ничего не переключает: его можно взять
## в руку («подтвердить»), бросить (G). Брошенный пульт, пролежав на полу дольше BACK_TIME сек,
## сам возвращается на диван.

enum State { HOME, HELD, LOOSE }

const BACK_TIME := 5.0
const SIZE := Vector3(0.06, 0.025, 0.2)
const HAND_POS := Vector3(0, -0.45, 0.04)

var state := State.HOME
var holder: PlayerData
## Где пульт лежит на диване (в координатах квартиры).
var home_position := Vector3.ZERO
var home_yaw := 0.0
## Сейчас исчезает с пола, чтобы появиться на диване (в это время взять нельзя).
var returning := false

var _model: Node3D
var _still_time := 0.0


func _ready() -> void:
	add_to_group("tv_remote")
	_model = make_model()
	add_child(_model)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Форма толще самого пульта: тонкая коробка на скорости проскакивала в пол.
	box.size = SIZE + Vector3(0.02, 0.03, 0.0)
	shape.shape = box
	shape.position.y = SIZE.y / 2.0
	add_child(shape)
	mass = 0.15
	continuous_cd = true # быстрый бросок не «пролетает» сквозь пол
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
	var power := _box(Vector3(0.016, 0.008, 0.016), Vector3(-0.015, SIZE.y, -0.075),
		Color("c62828"), 0.4)
	power.name = "PowerButton"
	root.add_child(power)
	for row in 4:
		for col in 3:
			var pos := Vector3(-0.018 + col * 0.018, SIZE.y, -0.035 + row * 0.022)
			root.add_child(_box(Vector3(0.012, 0.006, 0.012), pos, Color("8a8d91"), 0.6))
	# Окошко инфракрасного глазка спереди.
	root.add_child(_box(Vector3(0.03, 0.012, 0.004), Vector3(0, SIZE.y / 2.0, -SIZE.z / 2.0),
		Color("4a0d12"), 0.15))
	return root


## Нажать красную кнопку на модели пульта: она утапливается и возвращается (ничего не включает).
static func press_button(model: Node) -> void:
	var button := model.find_child("PowerButton", true, false) as Node3D
	if button == null:
		return
	var tween := button.create_tween()
	tween.tween_property(button, "position:y", SIZE.y - 0.005, 0.05)
	tween.tween_property(button, "position:y", SIZE.y, 0.1).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


## Нажать кнопку на этом пульте (в руке — видно всем со стороны).
func press() -> void:
	press_button(_model)


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
		_return_like_restored.call_deferred()


## Вернуться на диван, как вещь после поломки: на полу сжимается и исчезает, на диване
## появляется из точки и «пружинит» до нормального размера (как Breakable).
func _return_like_restored() -> void:
	_set_loose_physics(false)
	returning = true
	var shrink := create_tween()
	shrink.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.2).set_ease(Tween.EASE_IN)
	await shrink.finished
	returning = false
	go_home()
	_model.scale = Vector3.ONE * 0.01
	create_tween().tween_property(_model, "scale", Vector3.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	_model.scale = Vector3.ONE # схватили посреди «восстановления» — сразу нормальный размер
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
	ThrowHelper.launch(self, character, dir)
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
