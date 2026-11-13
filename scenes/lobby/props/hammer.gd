class_name Hammer
extends RigidBody3D
## Молоток из серванта. STORED — лежит на нижней полке тумбы, HELD — в руке, LOOSE — брошен (G):
## его можно подобрать с пола, через LOOSE_LIFE сек он пропадает. ЛКМ с молотком — удар, как
## кулаком, но игровой автомат от него «разбивается» (трещины на экране, см. ArcadeScreen.smash).

enum State { STORED, HELD, LOOSE }

const LOOSE_LIFE := 10.0
## В кулаке: точка (0, 0, 0) модели — середина рукоятки; ручка — вверх по +Y, боёк наверху
## (ударная часть смотрит на −Z, гвоздодёр — на +Z). В руке ручка перпендикулярна руке, вперёд.
const HAND_POS := Vector3(0, -0.44, 0.0)
## Куда в руке смотрит ручка (в осях руки; рука вынесена вперёд на 0.9 рад): в мире это почти
## вертикально вверх с наклоном вперёд ~25° — как держат молоток наготове. Гвоздодёр — назад.
const HAND_UP := Vector3(0.0, 0.22, -0.975)
const HAND_CLAW := Vector3(0.0, 0.975, 0.22)
const GRIP_COLOR := Color("d81e1e")
const STEEL_COLOR := Color("2c3138")

var state := State.STORED
var holder: PlayerData

var _model: Node3D
var _loose_time := 0.0


func _ready() -> void:
	add_to_group("hammer")
	_model = make_model()
	add_child(_model)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.07, 0.4, 0.2) # весь молоток: рукоятка, рукоять и боёк с гвоздодёром
	shape.shape = box
	shape.position.y = 0.125
	add_child(shape)
	mass = 0.6
	angular_damp = 1.5
	var surface := PhysicsMaterial.new()
	surface.friction = 0.9
	surface.bounce = 0.1
	physics_material_override = surface
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_set_loose_physics(false)


## Слесарный молоток-гвоздодёр: красная резиновая рукоятка, тёмная стальная рукоять,
## боёк с круглой ударной частью и раздвоенным гвоздодёром (и для «молотка в кадре»).
static func make_model() -> Node3D:
	var root := Node3D.new()
	root.add_child(_cyl(0.021, 0.15, Vector3.ZERO, GRIP_COLOR, 0.7))                  # рукоятка
	root.add_child(_cyl(0.023, 0.012, Vector3(0, -0.075, 0), GRIP_COLOR, 0.7))        # торец
	root.add_child(_cyl(0.013, 0.19, Vector3(0, 0.17, 0), STEEL_COLOR, 0.35, 0.35))   # рукоять
	root.add_child(_cyl(0.017, 0.025, Vector3(0, 0.27, 0), STEEL_COLOR, 0.35, 0.35))  # шейка
	root.add_child(_box(Vector3(0.04, 0.05, 0.06), Vector3(0, 0.295, 0), STEEL_COLOR, 0.35, 0.35))
	var face := _cyl(0.022, 0.06, Vector3(0, 0.295, -0.055), STEEL_COLOR, 0.3, 0.35) # ударная
	face.rotation.x = PI / 2.0
	root.add_child(face)
	var cap := _cyl(0.025, 0.012, Vector3(0, 0.295, -0.088), STEEL_COLOR, 0.3, 0.35)
	cap.rotation.x = PI / 2.0
	root.add_child(cap)
	for side: float in [-1.0, 1.0]:                                                     # гвоздодёр
		var claw := _box(Vector3(0.013, 0.026, 0.08), Vector3(side * 0.01, 0.288, 0.066),
			STEEL_COLOR, 0.35, 0.35)
		claw.rotation.x = 0.4 # загнут вниз
		root.add_child(claw)
	return root


static func _cyl(radius: float, height: float, pos: Vector3, color: Color, rough: float,
		metal: float = 0.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _mat(color, rough, metal)
	mesh_instance.position = pos
	return mesh_instance


static func _mat(color: Color, rough: float, metal: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	return mat


## metal — не больше 0.35: чистый металл без отражений в игре чёрный.
static func _box(size: Vector3, pos: Vector3, color: Color, rough: float,
		metal: float = 0.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _mat(color, rough, metal)
	mesh_instance.position = pos
	return mesh_instance


func _process(delta: float) -> void:
	if state != State.LOOSE:
		return
	_loose_time += delta
	if _loose_time > LOOSE_LIFE:
		_model.scale = Vector3.ONE * maxf(0.01, 1.0 - (_loose_time - LOOSE_LIFE) * 3.0)
		if _loose_time > LOOSE_LIFE + 0.35:
			queue_free()


## Положить на полку (parent — тумба серванта).
func store_in(parent: Node3D, pos: Vector3, rot: Vector3) -> void:
	state = State.STORED
	holder = null
	_set_loose_physics(false)
	_move_to(parent)
	position = pos
	rotation = rot
	_set_render_layer(_model, 1)


func hold(p: PlayerData, character: PlayerCharacter) -> void:
	state = State.HELD
	holder = p
	_model.scale = Vector3.ONE
	_set_loose_physics(false)
	_move_to(null)
	character.attach_to_part("ArmR", self)
	position = HAND_POS
	basis = Basis(HAND_UP.cross(HAND_CLAW), HAND_UP, HAND_CLAW) # ручка в кулаке, боёк наверху
	character.set_arm_pose(0.15, 0.9, 0.2)


## Бросить (dir — взгляд игрока; Vector3.ZERO — уронить под себя).
func drop(character: PlayerCharacter, world: Node3D, dir: Vector3 = Vector3.ZERO) -> void:
	var start := global_transform
	state = State.LOOSE
	holder = null
	_loose_time = 0.0
	_move_to(world)
	global_transform = start
	_set_render_layer(_model, 1)
	_set_loose_physics(true)
	ThrowHelper.launch(self, character, dir)
	character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2)


## Взмах молотком (рука с молотком резко вперёд-вниз и обратно).
func swing(character: PlayerCharacter) -> void:
	character.set_arm_pose(0.15, 1.75, 0.07)
	await get_tree().create_timer(0.14).timeout
	if is_instance_valid(character) and state == State.HELD:
		character.set_arm_pose(0.15, 0.9, 0.18)


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
