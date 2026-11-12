class_name PodiumStage
extends SubViewportContainer
## 3D-пьедестал экрана итогов: ступени 2 — 1 — 3, на них персонажи игроков в своей одежде.
## Каждый по-своему держит кубок и радуется:
##   1-е — двумя руками поднял кубок над головой и подпрыгивает;
##   2-е — прижимает кубок к груди и машет свободной рукой;
##   3-е — вскинул кубок одной рукой и качает кулаком;
##   4-е — без кубка, стоит рядом с пьедесталом, грустно опустив голову.
## Свой мир (own_world_3d) с прозрачным фоном — сзади видно фон экрана итогов.

const CHARACTER_SCENE := preload("res://scenes/characters/test_character.tscn")
const CUPS: Array[PackedScene] = [
	preload("res://assets/models/props/cup_gold.glb"),
	preload("res://assets/models/props/cup_silver.glb"),
	preload("res://assets/models/props/cup_bronze.glb"),
]
const PLACE_COLORS: Array[Color] = [Color("f6c343"), Color("d9d9d9"), Color("cd8a4b")]
## Ступени: x центра и высота для 1-го, 2-го и 3-го места.
const STEP_X: Array[float] = [0.0, -1.55, 1.55]
const STEP_HEIGHT: Array[float] = [1.0, 0.68, 0.42]
const STEP_SIZE := Vector2(1.5, 1.2)
## Где стоит четвёртый (рядом с пьедесталом, на полу).
const FOURTH_POS := Vector3(3.1, 0, 0.5)
const CUP_SCALE := 0.5
## Ножка кубка у модели на высоте ~0.38 — за неё и держат.
const CUP_GRIP := 0.38


func setup(standings: Array[PlayerData]) -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	_build_lights(world)
	var camera := Camera3D.new()
	camera.fov = 36.0
	world.add_child(camera)
	camera.look_at_from_position(Vector3(0, 2.6, 7.4), Vector3(0, 1.8, 0))
	_add_collider(world, Vector3(20, 0.2, 20), Vector3(0, -0.1, 0)) # пол
	for place in mini(standings.size(), 3):
		_build_step(world, place)
	for place in standings.size():
		_spawn(world, standings[place], place)


## Невидимое твёрдое тело (пол, ступень), чтобы персонажи не проваливались.
func _add_collider(world: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	world.add_child(body)


func _build_lights(world: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.85)
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-45, 25, 0)
	world.add_child(sun)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.86, 0.5)
	spot.light_energy = 4.0
	spot.spot_range = 9.0
	spot.spot_angle = 22.0
	world.add_child(spot)
	spot.look_at_from_position(Vector3(0, 6.5, 2.5), Vector3(0, 1.0, 0))
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 0.9, 0.8)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	world.add_child(world_env)


## Ступень: цветной брусок с большой цифрой спереди.
func _build_step(world: Node3D, place: int) -> void:
	var height := STEP_HEIGHT[place]
	var step := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(STEP_SIZE.x, height, STEP_SIZE.y)
	step.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLACE_COLORS[place].darkened(0.35)
	mat.metallic = 0.3
	mat.roughness = 0.45
	step.material_override = mat
	step.position = Vector3(STEP_X[place], height / 2.0, 0)
	world.add_child(step)
	_add_collider(world, Vector3(STEP_SIZE.x, height, STEP_SIZE.y), step.position)
	# Светлая кромка сверху.
	var rim := MeshInstance3D.new()
	var rim_box := BoxMesh.new()
	rim_box.size = Vector3(STEP_SIZE.x + 0.04, 0.06, STEP_SIZE.y + 0.04)
	rim.mesh = rim_box
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = PLACE_COLORS[place]
	rim.material_override = rim_mat
	rim.position = Vector3(STEP_X[place], height - 0.03, 0)
	world.add_child(rim)
	var number := Label3D.new()
	number.text = str(place + 1)
	number.font_size = 220
	number.outline_size = 24
	number.modulate = PLACE_COLORS[place]
	number.position = Vector3(STEP_X[place], height / 2.0, STEP_SIZE.y / 2.0 + 0.01)
	world.add_child(number)


func _spawn(world: Node3D, p: PlayerData, place: int) -> void:
	var character: PlayerCharacter = CHARACTER_SCENE.instantiate()
	var pos := FOURTH_POS + Vector3(0.9 * (place - 3), 0, 0)
	if place < 3:
		pos = Vector3(STEP_X[place], STEP_HEIGHT[place], 0)
	character.setup(p, pos)
	world.add_child(character)
	# Физику выключаем после _ready персонажа (иначе Godot включит её обратно и он упадёт:
	# ступени — только картинка, без столкновений).
	# Физику выключаем ещё и на следующем кадре (Godot включает её сам при появлении); а на
	# случай, если она всё же работает, под ногами есть пол и ступени со столкновениями.
	character.ready.connect(character.set_physics_process.bind(false))
	character.ready.connect(func() -> void: character.set_physics_process.call_deferred(false))
	character.respawn_on_fall = false
	character.input_enabled = false
	character.rotation.y = PI # лицом к камере
	var cup: Node3D = null
	if place < 3:
		cup = CUPS[place].instantiate() as Node3D
		cup.scale = Vector3.ONE * CUP_SCALE
		world.add_child(cup)
	var pose := Pose.new()
	pose.character = character
	pose.cup = cup
	pose.place = place
	pose.base_y = pos.y
	world.add_child(pose)


## Поза и радость одного персонажа. Работает после анимации персонажа (process_priority),
## поэтому её повороты рук не перебиваются «дыханием» и шагами.
class Pose extends Node:
	var character: PlayerCharacter
	var cup: Node3D
	var place := 0
	var base_y := 0.0
	var _time := 0.0

	func _ready() -> void:
		process_priority = 100
		_time = randf() * 2.0

	func _process(delta: float) -> void:
		_time += delta
		var arm_l := character.part("ArmL")
		var arm_r := character.part("ArmR")
		var head := character.part("Head")
		match place:
			0:
				# Подпрыгивает, кубок двумя руками над головой.
				character.position.y = base_y + absf(sin(_time * 4.5)) * 0.28
				arm_r.rotation = Vector3(0.0, 0.0, 2.75)
				arm_l.rotation = Vector3(0.0, 0.0, -2.75)
				head.rotation.x = 0.25 # смотрит вверх, на кубок
				_hold_between(arm_l, arm_r)
			1:
				# Кубок у груди, свободной рукой машет.
				character.position.y = base_y + absf(sin(_time * 3.0)) * 0.05
				arm_r.rotation = Vector3(1.35, 0.0, 0.55)
				arm_l.rotation = Vector3(0.0, 0.0, -2.2 - sin(_time * 7.0) * 0.45)
				head.rotation.x = 0.1
				_hold_in(arm_r, 0.0)
			2:
				# Кубок вскинут одной рукой, другой качает кулаком.
				character.position.y = base_y + absf(sin(_time * 3.6)) * 0.1
				arm_r.rotation = Vector3(0.0, 0.0, 2.25)
				arm_l.rotation = Vector3(0.9 + sin(_time * 8.0) * 0.5, 0.0, -0.6)
				head.rotation.x = 0.15
				_hold_in(arm_r, 0.0)
			_:
				# Без кубка: голова опущена, иногда вздыхает и качает головой.
				arm_r.rotation = Vector3(0.0, 0.0, 0.08)
				arm_l.rotation = Vector3(0.0, 0.0, -0.08)
				head.rotation = Vector3(-0.45, sin(_time * 1.3) * 0.25, 0.0)

	## Кубок за ножку в конце руки, всегда стоит ровно (не наклоняется с рукой).
	func _hold_in(arm: Node3D, extra_y: float) -> void:
		var hand := arm.global_transform * Vector3(0, -0.42, 0)
		_set_cup(hand + Vector3(0, extra_y, 0))

	## Кубок между двумя поднятыми руками.
	func _hold_between(arm_a: Node3D, arm_b: Node3D) -> void:
		var a := arm_a.global_transform * Vector3(0, -0.42, 0)
		var b := arm_b.global_transform * Vector3(0, -0.42, 0)
		_set_cup((a + b) / 2.0)

	func _set_cup(grip: Vector3) -> void:
		if cup == null:
			return
		cup.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * CUP_SCALE),
			grip - Vector3(0, CUP_GRIP * CUP_SCALE, 0))
