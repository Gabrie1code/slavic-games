class_name KitchenBottle
extends RigidBody3D
## Бутылка вина со стола на кухне: её можно взять в руку (ЛКМ рядом), «выпить» (ЛКМ в руке —
## подносит ко рту, запрокидывает голову, глотает; раз в 4 сек, см. BottleHand)
## и бросить (G). Брошенная бутылка через
## FLOOR_LIFE сек исчезает. Взяли со стола — через KitchenRoom.BOTTLE_BACK сек на столе новая.
## Модель — tools/blender/kitchen.py (kitchen_bottle): начало — на дне.

enum State { HOME, HELD, LOOSE }

const MODEL := preload("res://assets/models/kitchen/kitchen_bottle.glb")
const FLOOR_LIFE := 7.0
## Где бутылку сжимает кулак (над дном).
const GRIP := 0.12

var state := State.HOME
var holder: PlayerData
## Пьёт прямо сейчас (бутылка запрокинута).
var drinking := false

var _model: Node3D
var _tilt := 0.0
var _loose_time := 0.0


func _ready() -> void:
	add_to_group("kitchen_bottle")
	_model = make_model()
	add_child(_model)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.04
	cylinder.height = 0.32
	shape.shape = cylinder
	shape.position.y = 0.16
	add_child(shape)
	mass = 0.6
	angular_damp = 2.0
	var surface := PhysicsMaterial.new()
	surface.friction = 0.9
	surface.bounce = 0.1
	physics_material_override = surface
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_set_loose_physics(false)


static func make_model() -> Node3D:
	return MODEL.instantiate() as Node3D


func _process(delta: float) -> void:
	if state == State.HELD:
		HandHold.follow(self, GRIP, _tilt)
		return
	if state != State.LOOSE:
		return
	_loose_time += delta
	if _loose_time > FLOOR_LIFE:
		_model.scale = Vector3.ONE * maxf(0.01, 1.0 - (_loose_time - FLOOR_LIFE) * 3.0)
		if _loose_time > FLOOR_LIFE + 0.35:
			queue_free()


func hold(p: PlayerData, character: PlayerCharacter) -> void:
	state = State.HELD
	holder = p
	_set_loose_physics(false)
	var start := global_transform
	if get_parent():
		get_parent().remove_child(self)
	character.attach_to_part("ArmR", self)
	global_transform = start
	HandHold.place(self, GRIP)
	character.set_arm_pose(0.15, 0.9, 0.2)


## «Выпить»: рука подносит бутылку ко рту, голова запрокидывается, три глотка (голова кивает),
## бутылка опускается. view — бутылка «в кадре» у держащего (может быть null); done — когда
## допил (лобби считает выпитое: опьянение, рвота).
func drink(character: PlayerCharacter, view: Node3D, done: Callable) -> void:
	if drinking:
		return
	drinking = true
	character.set_arm_pose(0.5, 2.15, 0.3)
	var tween := create_tween()
	# Поднести ко рту, запрокинуть.
	tween.tween_property(self, "_tilt", -1.3, 0.3).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(character, "head_tilt", 0.2, 0.3)
	tween.tween_property(self, "_tilt", -2.15, 0.25).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(character, "head_tilt", 0.5, 0.25)
	for k in 3: # глотки
		tween.tween_property(character, "head_tilt", 0.4, 0.12)
		tween.tween_property(character, "head_tilt", 0.5, 0.12)
	# Опустить.
	tween.tween_property(self, "_tilt", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(character, "head_tilt", 0.0, 0.35)
	tween.tween_callback(func() -> void:
		drinking = false
		if is_instance_valid(character) and state == State.HELD:
			character.set_arm_pose(0.15, 0.9, 0.25)
		done.call())
	if view:
		_drink_view(view)


## От первого лица: бутылка подъезжает горлышком ко рту (к центру снизу) и запрокидывается,
## на глотках чуть вздрагивает.
func _drink_view(view: Node3D) -> void:
	var start := view.position
	var turn := view.rotation
	var look := view.create_tween()
	look.tween_property(view, "position", Vector3(0.04, -0.2, -0.32), 0.3)
	look.parallel().tween_property(view, "rotation", Vector3(1.3, 0.0, 0.0), 0.3)
	look.tween_property(view, "rotation:x", 2.1, 0.25)
	look.parallel().tween_property(view, "position", Vector3(0.02, -0.14, -0.28), 0.25)
	for k in 3:
		look.tween_property(view, "position:y", -0.13, 0.12)
		look.tween_property(view, "position:y", -0.14, 0.12)
	look.tween_property(view, "position", start, 0.35)
	look.parallel().tween_property(view, "rotation", turn, 0.35)


## Перепил: бутылка пропадает из руки (сжимается) и исчезает.
func vanish(character: PlayerCharacter) -> void:
	state = State.LOOSE
	character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2)
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.25)
	tween.tween_callback(queue_free)


## Бросить туда, куда смотрит игрок (dir); Vector3.ZERO — уронить под себя.
func throw(character: PlayerCharacter, world: Node, dir: Vector3) -> void:
	var start := global_transform
	state = State.LOOSE
	holder = null
	_tilt = 0.0
	get_parent().remove_child(self)
	world.add_child(self)
	global_transform = start
	_set_render_layer(self, 1) # в руке была на слое тела — сам бросивший её бы не видел
	_set_loose_physics(true)
	ThrowHelper.launch(self, character, dir)
	character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2)


func _set_render_layer(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_render_layer(child, layer)


func _set_loose_physics(on: bool) -> void:
	freeze = not on
	collision_layer = 2 if on else 0
	collision_mask = 1 if on else 0
