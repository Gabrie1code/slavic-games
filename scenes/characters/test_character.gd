class_name PlayerCharacter
extends CharacterBody3D
## Персонаж игрока: единая модель из частей, окрашенная в цвет игрока, плюс одежда.
##
## Части модели (из tools/blender/character.py): Torso, Head, ArmL, ArmR, LegL, LegR.
## Анимация — кодом: ноги и руки качаются при ходьбе, правая рука поднимается
## и держит предметы, всё тело крутится при атаке.

const ACCELERATION := 40.0
## Прыжок: короткий и «тяжёлый» — гравитация персонажа сильнее стандартной.
const JUMP_VELOCITY := 7.0
const GRAVITY_SCALE := 2.2
## Сила, с которой персонаж толкает незакреплённые вещи (стулья, торшер).
const PUSH_FORCE := 0.5
## Поза сидя: насколько опустить модель и поднять ноги вперёд.
const SIT_DROP := 0.0
const SIT_LEGS := 1.45
## Вид от первого лица: скорость поворота стрелками/клавишами (рад/сек).
const FP_TURN_SPEED := 2.6
const TURN_SPEED := 12.0
const KNOCKBACK_DECAY := 18.0
## Поворот правой руки: опущена / поднята вверх / вытянута в сторону.
const ARM_DOWN := 0.12
const ARM_UP := 2.75
const ARM_SIDE := 1.45
## Ходьба: частота шага и размах рук/ног.
const STEP_FREQUENCY := 2.4
const SWING := 0.65

var player: PlayerData
var spawn_position := Vector3.ZERO

## Настройки, которые меняют мини-игры.
var speed := 6.0
var input_enabled := true
var can_jump := true
var respawn_on_fall := true
var fall_limit := -10.0
## Наклон правой руки вперёд (>0) / назад (<0), когда рука занята (держит предмет).
var arm_pose_x := 0.0
## Сидит ли персонаж (на диване в лобби).
var sitting := false
## Вид от первого лица: движение относительно взгляда.
var first_person := false
## От первого лица: true — A/D шагают вбок (поворот мышью/стиком), false — A/D поворачивают.
var fp_strafe := false
## Наклон взгляда вверх/вниз (для камеры от первого лица).
var fp_pitch := 0.0

var _knockback := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _arm_tween: Tween
var _right_arm_busy := false
var _walk_phase := 0.0
var _idle_time := 0.0
var _primary_material: StandardMaterial3D
## Слот одежды -> надетые куски (чтобы снять при смене).
var _worn: Dictionary = {}
## Слой видимости модели (свою модель камера от первого лица не показывает).
var _render_layer := 1

@onready var visual: Node3D = $Visual
@onready var right_hand: Node3D = Node3D.new()
@onready var _model: Node3D = $Visual/Model
@onready var _name_label: Label3D = $NameLabel
@onready var _parts := {
	"Torso": $Visual/Model/Torso,
	"Head": $Visual/Model/Head,
	"ArmL": $Visual/Model/ArmL,
	"ArmR": $Visual/Model/ArmR,
	"LegL": $Visual/Model/LegL,
	"LegR": $Visual/Model/LegR,
}


## Вызывается сразу после создания персонажа, до добавления в сцену.
func setup(p: PlayerData, spawn: Vector3) -> void:
	player = p
	spawn_position = spawn
	position = spawn
	name = "Player%d" % p.slot


func _ready() -> void:
	_primary_material = StandardMaterial3D.new()
	_primary_material.albedo_color = player.color
	_primary_material.roughness = 0.6
	_recolor(_model)

	# Точка «в руке» — на конце правой руки.
	right_hand.name = "Hand"
	right_hand.position = Vector3(0, -0.42, 0)
	_part("ArmR").add_child(right_hand)
	_part("ArmL").rotation.z = -ARM_DOWN
	_part("ArmR").rotation.z = ARM_DOWN

	apply_outfit(player.outfit)
	_name_label.text = player.display_name
	_name_label.modulate = player.color.lightened(0.3)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * GRAVITY_SCALE * delta

	var move := Vector2.ZERO
	if input_enabled and player.input:
		move = player.input.get_move()
		if can_jump and player.input.is_just_pressed("confirm") and is_on_floor():
			velocity.y = JUMP_VELOCITY

	# Камера смотрит спереди, поэтому «вверх» на экране — это -Z в мире.
	var dir := Vector3(move.x, 0.0, move.y)
	if first_person:
		# От первого лица — относительно взгляда: basis.z смотрит назад, basis.x — вправо.
		if fp_strafe:
			dir = transform.basis.x * move.x + transform.basis.z * move.y
		else:
			rotation.y -= move.x * FP_TURN_SPEED * delta
			dir = transform.basis.z * move.y
	var target := dir * speed
	velocity.x = move_toward(velocity.x - _knockback.x, target.x, ACCELERATION * delta) + _knockback.x
	velocity.z = move_toward(velocity.z - _knockback.z, target.z, ACCELERATION * delta) + _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)

	if dir.length() > 0.1 and not first_person:
		var yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, yaw, TURN_SPEED * delta)

	move_and_slide()
	_push_bodies()

	if respawn_on_fall and global_position.y < fall_limit:
		global_position = spawn_position
		velocity = Vector3.ZERO
		_knockback = Vector3.ZERO


## Анимация ходьбы и дыхания (только визуал, работает и без физики).
func _process(delta: float) -> void:
	_idle_time += delta
	var walk_speed := Vector2(velocity.x, velocity.z).length() if is_physics_processing() else 0.0
	var amount := clampf(walk_speed / 6.0, 0.0, 1.0)
	_walk_phase += delta * STEP_FREQUENCY * TAU * amount
	var swing := sin(_walk_phase) * SWING * amount
	# Ноги и руки качаются навстречу друг другу; в стойке — плавно возвращаются.
	var legs_back := 1.0 - minf(1.0, delta * 10.0)
	if sitting:
		_part("LegL").rotation.x = SIT_LEGS
		_part("LegR").rotation.x = SIT_LEGS
	else:
		_part("LegL").rotation.x = swing if amount > 0.05 else _part("LegL").rotation.x * legs_back
		_part("LegR").rotation.x = -swing if amount > 0.05 else _part("LegR").rotation.x * legs_back
	_part("ArmL").rotation.x = -swing * 0.8
	if not _right_arm_busy:
		_part("ArmR").rotation.x = swing * 0.8
	else:
		_part("ArmR").rotation.x = arm_pose_x
	# Подпрыгивание при шаге и лёгкое «дыхание» в стойке.
	_model.position.y = SIT_DROP if sitting else absf(sin(_walk_phase)) * 0.06 * amount
	_part("Head").rotation.x = sin(_idle_time * 2.0) * 0.04


## Сесть: персонаж ставится в точку (под сиденьем) и поворачивается на yaw.
func sit_at(point: Vector3, yaw: float) -> void:
	sitting = true
	set_physics_process(false)
	velocity = Vector3.ZERO
	global_position = point
	rotation.y = yaw


## Встать с дивана: шаг вперёд и снова обычная физика.
func stand_up() -> void:
	if not sitting:
		return
	sitting = false
	global_position += -global_basis.z * 0.7 + Vector3.UP * 0.1
	set_physics_process(true)


## Толкнуть незакреплённые вещи, в которые упёрся персонаж.
func _push_bodies() -> void:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider() as RigidBody3D
		if body and not body.freeze:
			var push := -hit.get_normal()
			push.y = 0.0
			body.apply_impulse(push * PUSH_FORCE, hit.get_position() - body.global_position)


## Удар рукой: правая рука резко выбрасывается вперёд и возвращается.
## Возвращает false, если рука занята (держит предмет).
func punch() -> bool:
	if _right_arm_busy:
		return false
	set_arm_pose(0.15, 1.65, 0.07)
	_finish_punch()
	return true


func _finish_punch() -> void:
	await get_tree().create_timer(0.16).timeout
	if is_inside_tree():
		set_arm_angle(ARM_DOWN, 0.18)


## Отбросить персонажа (например, от удара битой).
func apply_knockback(impulse: Vector3) -> void:
	_knockback += Vector3(impulse.x, 0.0, impulse.z)
	velocity.y = maxf(velocity.y, impulse.y)


## Поднять или опустить правую руку.
func raise_hand(up: bool, time: float = 0.15) -> void:
	set_arm_angle(ARM_UP if up else ARM_DOWN, time)


## Повернуть правую руку на угол (радианы, ARM_DOWN = опущена).
func set_arm_angle(angle: float, time: float = 0.15) -> void:
	_right_arm_busy = absf(angle - ARM_DOWN) > 0.01
	arm_pose_x = 0.0
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween()
	_arm_tween.tween_property(_part("ArmR"), "rotation:z", angle, time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Поза правой руки: angle_z — в сторону (ARM_DOWN = опущена), angle_x — вперёд (>0) / назад.
func set_arm_pose(angle_z: float, angle_x: float, time: float = 0.15) -> void:
	_right_arm_busy = true
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween().set_parallel(true)
	_arm_tween.tween_property(_part("ArmR"), "rotation:z", angle_z, time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_arm_tween.tween_property(self, "arm_pose_x", angle_x, time)


## Взять предмет в правую руку (старый предмет удаляется). Возвращает сам предмет.
func hold_item(item: Node3D) -> Node3D:
	for child in right_hand.get_children():
		child.queue_free()
	if item:
		right_hand.add_child(item)
		_right_arm_busy = true
	return item


## Показать или спрятать имя над головой (в примерочной не нужно).
func show_name(visible_name: bool) -> void:
	_name_label.visible = visible_name


## Слой видимости надписи с именем (например, чтобы её не видел водящий в тумане).
func set_name_layer(layer: int) -> void:
	_name_label.layers = layer


## Перекрасить «основной» цвет (например, белый халат продавщицы).
func set_body_color(color: Color) -> void:
	_primary_material.albedo_color = color


## Перекрасить персонажа в новый цвет игрока (тело, «фирменная» одежда, имя).
func set_player_color(color: Color) -> void:
	_primary_material.albedo_color = color
	_name_label.modulate = color.lightened(0.3)


## Надеть наряд: словарь {Cosmetics.Slot: id вещи}. Пустые слоты — ничего.
func apply_outfit(outfit: Dictionary) -> void:
	for slot: int in Cosmetics.SLOT_NAMES:
		wear(slot, outfit.get(slot, ""))


## Надеть вещь в слот (пустой id — снять).
func wear(slot: int, item_id: String) -> void:
	for piece: Node in _worn.get(slot, []):
		piece.queue_free()
	_worn.erase(slot)
	if item_id == "" or not Cosmetics.ITEMS.has(item_id):
		return
	var item := Cosmetics.load_item(item_id).instantiate()
	var pieces: Array[Node] = []
	# Каждый кусок вещи переезжает внутрь своей части тела.
	for piece: Node in item.get_children():
		if not piece is Node3D or not _parts.has(String(piece.name)):
			continue
		var piece_3d := piece as Node3D
		item.remove_child(piece_3d)
		_part(String(piece.name)).add_child(piece_3d)
		piece_3d.transform = Transform3D.IDENTITY
		_recolor(piece_3d)
		_apply_layer(piece_3d)
		pieces.append(piece_3d)
	item.queue_free()
	_worn[slot] = pieces


## Слой видимости всей модели персонажа (и надетой одежды).
func set_render_layer(layer: int) -> void:
	_render_layer = layer
	_apply_layer(self)


## Смерть: персонаж краснеет, падает навзничь, на глазах крестики, потом плавно исчезает
## (прозрачность растёт) и прячется. Физика не выключается сразу — тело ещё может лететь.
func play_death(fade_delay: float = 0.9, fade_time: float = 1.0) -> void:
	input_enabled = false
	var meshes: Array[GeometryInstance3D] = []
	_collect_geometry(visual, meshes)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1.0, 0.1, 0.05, 0.55)
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mesh in meshes:
		mesh.material_overlay = red
	# Крестики вместо глаз: по две чёрные планки на каждый глаз.
	var cross_mat := StandardMaterial3D.new()
	cross_mat.albedo_color = Color(0.05, 0.02, 0.02)
	cross_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cross_mesh := BoxMesh.new()
	cross_mesh.size = Vector3(0.12, 0.028, 0.012)
	for x in [-0.11, 0.11]:
		for angle in [PI / 4, -PI / 4]:
			var bar := MeshInstance3D.new()
			bar.mesh = cross_mesh
			bar.material_override = cross_mat
			bar.position = Vector3(x, 0.32, -0.322)
			bar.rotation.z = angle
			attach_to_part("Head", bar)
			meshes.append(bar)
	create_tween().tween_property(visual, "rotation:x", PI / 2, 0.45) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# Исчезновение — все части сразу, после падения и паузы.
	var fade := create_tween().set_parallel(true)
	var start := 0.45 + fade_delay
	for mesh in meshes:
		fade.tween_property(mesh, "transparency", 1.0, fade_time).set_delay(start)
	fade.tween_property(_name_label, "modulate:a", 0.0, fade_time).set_delay(start)
	fade.chain().tween_callback(func() -> void:
		visible = false
		set_physics_process(false))


## Подкрасить всего персонажа поверх его цветов (например, синим во льду).
## Прозрачный цвет (alpha = 0) — убрать подкраску.
func set_tint(color: Color) -> void:
	var meshes: Array[GeometryInstance3D] = []
	_collect_geometry(visual, meshes)
	var overlay: StandardMaterial3D = null
	if color.a > 0.0:
		overlay = StandardMaterial3D.new()
		overlay.albedo_color = color
		overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mesh in meshes:
		mesh.material_overlay = overlay


func _collect_geometry(node: Node, out: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D:
		out.append(node as GeometryInstance3D)
	for child in node.get_children():
		_collect_geometry(child, out)


## Прикрепить предмет к части тела (Torso/Head/ArmL/ArmR/LegL/LegR), например трубку к уху.
## Предмет получает слой видимости персонажа (от первого лица своя трубка не мешает обзору).
func attach_to_part(part_name: String, node: Node3D) -> void:
	_part(part_name).add_child(node)
	_apply_layer(node)


func _apply_layer(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = _render_layer
	for child in node.get_children():
		_apply_layer(child)


func _part(part_name: String) -> Node3D:
	return _parts[part_name] as Node3D


## Материал "Primary" на всех мешах внутри node заменяется цветом игрока.
func _recolor(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.mesh.get_surface_count():
			var surface_material := mesh_instance.mesh.surface_get_material(i)
			if surface_material and surface_material.resource_name.begins_with("Primary"):
				mesh_instance.set_surface_override_material(i, _primary_material)
	for child in node.get_children():
		_recolor(child)
