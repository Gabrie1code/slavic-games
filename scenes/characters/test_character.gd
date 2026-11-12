extends CharacterBody3D
## Временный персонаж-капсула для проверки управления.
## Позже заменим на настоящих персонажей с моделями и анимациями.

const SPEED := 6.0
const ACCELERATION := 40.0
const JUMP_VELOCITY := 6.5
const TURN_SPEED := 12.0
const FALL_LIMIT := -10.0

var player: PlayerData
var spawn_position := Vector3.ZERO

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _body: MeshInstance3D = $Body
@onready var _name_label: Label3D = $NameLabel


## Вызывается сразу после создания персонажа.
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
	_name_label.text = player.display_name
	_name_label.modulate = player.color.lightened(0.3)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var move := Vector2.ZERO
	if player.input:
		move = player.input.get_move()
		if player.input.is_just_pressed("confirm") and is_on_floor():
			velocity.y = JUMP_VELOCITY

	# Камера смотрит спереди, поэтому «вверх» на экране — это -Z в мире.
	var dir := Vector3(move.x, 0.0, move.y)
	var target := dir * SPEED
	velocity.x = move_toward(velocity.x, target.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCELERATION * delta)

	if dir.length() > 0.1:
		var yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, yaw, TURN_SPEED * delta)

	move_and_slide()

	if global_position.y < FALL_LIMIT:
		global_position = spawn_position
		velocity = Vector3.ZERO
