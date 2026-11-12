class_name PlayerPortrait
extends SubViewportContainer
## Живая миниатюра игрока «как фото на паспорт»: голова и плечи его персонажа (в его одежде
## и цвете), чуть покачивается и поворачивает голову. Свой маленький 3D-мир с прозрачным фоном.

const CHARACTER_SCENE := preload("res://scenes/characters/test_character.tscn")
const PIXELS := 128

var _character: PlayerCharacter
var _time := 0.0


func setup(p: PlayerData, size_px: float) -> PlayerPortrait:
	custom_minimum_size = Vector2(size_px, size_px)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = Vector2i(PIXELS, PIXELS)
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	_character = CHARACTER_SCENE.instantiate()
	_character.setup(p, Vector3.ZERO)
	world.add_child(_character)
	_character.set_physics_process(false)
	_character.input_enabled = false
	_character.show_name(false)
	_character.rotation.y = PI # лицом к камере
	var camera := Camera3D.new()
	camera.fov = 21.0 # голова (1.05–1.62 м) и плечи (~1.08 м)
	world.add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.36, 2.3), Vector3(0, 1.3, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 25, 0)
	world.add_child(light)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 0.95, 0.9)
	environment.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	world.add_child(world_env)
	_time = randf() * 10.0
	return self


func _process(delta: float) -> void:
	if _character == null:
		return
	_time += delta
	# Оглядывается по сторонам и слегка покачивается — «живое» фото.
	_character.rotation.y = PI + sin(_time * 0.7) * 0.25
	_character.part("Head").rotation.y = sin(_time * 1.3) * 0.2
