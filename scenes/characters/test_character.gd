class_name PlayerCharacter
extends CharacterBody3D
## Временный персонаж-капсула с руками.
## Позже заменим на настоящих персонажей с моделями и анимациями.
##
## Умеет: ходить и прыгать по вводу игрока, поднимать руку, держать предмет,
## крутиться (атака битой), получать отбрасывание.

const ACCELERATION := 40.0
const JUMP_VELOCITY := 6.5
const TURN_SPEED := 12.0
const KNOCKBACK_DECAY := 18.0
## Поворот правой руки: опущена / поднята вверх / вытянута в сторону.
const ARM_DOWN := 0.12
const ARM_UP := 2.75
const ARM_SIDE := 1.45

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

@onready var visual: Node3D = $Visual
@onready var right_hand: Node3D = $Visual/ArmRight/Hand
@onready var _arm_right: Node3D = $Visual/ArmRight
@onready var _arm_left: Node3D = $Visual/ArmLeft
@onready var _body: MeshInstance3D = $Visual/Body
@onready var _name_label: Label3D = $NameLabel


## Вызывается сразу после создания персонажа, до добавления в сцену.
func setup(p: PlayerData, spawn: Vector3) -> void:
	player = p
	spawn_position = spawn
	position = spawn
	name = "Player%d" % p.slot


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = player.color
	mat.roughness = 0.6
	_body.material_override = mat
	for arm in [_arm_left, _arm_right]:
		(arm.get_node("Mesh") as MeshInstance3D).material_override = mat
	_arm_left.rotation.z = -ARM_DOWN
	_arm_right.rotation.z = ARM_DOWN
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


## Отбросить персонажа (например, от удара битой).
func apply_knockback(impulse: Vector3) -> void:
	_knockback += Vector3(impulse.x, 0.0, impulse.z)
	velocity.y = maxf(velocity.y, impulse.y)


## Поднять или опустить правую руку.
func raise_hand(up: bool, time: float = 0.15) -> void:
	set_arm_angle(ARM_UP if up else ARM_DOWN, time)


## Повернуть правую руку на угол (радианы, 0 = вниз).
func set_arm_angle(angle: float, time: float = 0.15) -> void:
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween()
	_arm_tween.tween_property(_arm_right, "rotation:z", angle, time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Взять предмет в правую руку (старый предмет удаляется).
func hold_item(item: Node3D) -> void:
	for child in right_hand.get_children():
		child.queue_free()
	if item:
		right_hand.add_child(item)


## Тело-капсула для покраски (например, продавщица в белом халате).
func set_body_color(color: Color) -> void:
	(_body.material_override as StandardMaterial3D).albedo_color = color
