class_name PlayerCharacter
extends CharacterBody3D
## Персонаж игрока: единая модель из частей, окрашенная в цвет игрока, плюс одежда.
##
## Части модели (из tools/blender/character.py): Torso, Head, ArmL, ArmR, LegL, LegR.
## Анимация — кодом: ноги и руки качаются при ходьбе, правая рука поднимается
## и держит предметы, всё тело крутится при атаке.

const ACCELERATION := 40.0
const JUMP_VELOCITY := 6.5
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

var _knockback := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _arm_tween: Tween
var _right_arm_busy := false
var _walk_phase := 0.0
var _idle_time := 0.0
var _primary_material: StandardMaterial3D
## Слот одежды -> надетые куски (чтобы снять при смене).
var _worn: Dictionary = {}

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
		velocity.y -= _gravity * delta

	var move := Vector2.ZERO
	if input_enabled and player.input:
		move = player.input.get_move()
		if can_jump and player.input.is_just_pressed("confirm") and is_on_floor():
			velocity.y = JUMP_VELOCITY

	# Камера смотрит спереди, поэтому «вверх» на экране — это -Z в мире.
	var dir := Vector3(move.x, 0.0, move.y)
	var target := dir * speed
	velocity.x = move_toward(velocity.x - _knockback.x, target.x, ACCELERATION * delta) + _knockback.x
	velocity.z = move_toward(velocity.z - _knockback.z, target.z, ACCELERATION * delta) + _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)

	if dir.length() > 0.1:
		var yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, yaw, TURN_SPEED * delta)

	move_and_slide()

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
	_part("LegL").rotation.x = swing if amount > 0.05 else _part("LegL").rotation.x * legs_back
	_part("LegR").rotation.x = -swing if amount > 0.05 else _part("LegR").rotation.x * legs_back
	_part("ArmL").rotation.x = -swing * 0.8
	if not _right_arm_busy:
		_part("ArmR").rotation.x = swing * 0.8
	else:
		_part("ArmR").rotation.x = 0.0
	# Подпрыгивание при шаге и лёгкое «дыхание» в стойке.
	_model.position.y = absf(sin(_walk_phase)) * 0.06 * amount
	_part("Head").rotation.x = sin(_idle_time * 2.0) * 0.04


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
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween()
	_arm_tween.tween_property(_part("ArmR"), "rotation:z", angle, time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Взять предмет в правую руку (старый предмет удаляется).
func hold_item(item: Node3D) -> void:
	for child in right_hand.get_children():
		child.queue_free()
	if item:
		right_hand.add_child(item)
		_right_arm_busy = true


## Перекрасить «основной» цвет (например, белый халат продавщицы).
func set_body_color(color: Color) -> void:
	_primary_material.albedo_color = color


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
		pieces.append(piece_3d)
	item.queue_free()
	_worn[slot] = pieces


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
