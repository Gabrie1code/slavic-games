class_name ToiletScreen
extends LobbyRoom
## «Сходить в туалет»: вид от глаз персонажа на унитаз, приближенный (своя камера в общем мире
## лобби — другие игроки видят, что происходит). Жёлтая струя летит туда, куда показывает курсор
## мыши (в чашу — вода желтеет, мимо — лужа). Без мыши прицел двигают кнопками движения.
## Через USE_TIME сек всё заканчивается само; «подтвердить» или «отмена» — закончить раньше.

const VIEWMODEL_LAYERS := 0b1111 << 10
const USE_TIME := 6.0
## Дальше этого (по полу от персонажа) струя не долетает.
const MAX_DISTANCE := 1.4
const KEY_AIM_SPEED := 0.6

var toilet: Toilet
var lobby_character: PlayerCharacter

var _time := 0.0
## Куда целимся (точка на полу/в чаше; важны x и z).
var _aim := Vector3.ZERO
var _camera: Camera3D
var _view: SubViewportContainer
var _bar: ProgressBar


func setup_for(p: PlayerData, character: PlayerCharacter, the_toilet: Toilet) -> ToiletScreen:
	player = p
	lobby_character = character
	toilet = the_toilet
	return self


func _ready() -> void:
	_build()
	toilet.start_use()
	if lobby_character:
		lobby_character.global_position = toilet.stand_point()
		lobby_character.rotation.y = toilet.stand_yaw()
		lobby_character.velocity = Vector3.ZERO
		lobby_character.set_arm_pose(0.15, 0.55, 0.2)
	_aim = toilet.bowl_position()
	_update_camera()


func _process(delta: float) -> void:
	_time += delta
	_bar.value = 1.0 - _time / USE_TIME
	var input := player.input
	if input:
		# Кнопками: вправо/влево — по X, вверх/вниз — дальше/ближе (камера смотрит на унитаз).
		var move := input.get_move()
		_set_aim(_aim + Vector3(move.x, 0, move.y) * KEY_AIM_SPEED * delta)
	if lobby_character:
		_update_camera()
		toilet.pour(_stream_origin(), _aim, delta)
	var stop := input and _time > 0.3 \
		and (input.is_just_pressed("confirm") or input.is_just_pressed("cancel"))
	if _time >= USE_TIME or stop:
		close()


func close() -> void:
	toilet.stop_use()
	if lobby_character:
		lobby_character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2)
	super.close()


func _exit_tree() -> void:
	if toilet.in_use:
		toilet.stop_use() # игрок вышел из игры прямо в туалете
	# Окно закрыли не кнопкой (любым другим путём) — рука всё равно опускается.
	if is_instance_valid(lobby_character) and lobby_character.is_inside_tree():
		lobby_character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2)


## Откуда льётся: между бёдер, чуть впереди.
func _stream_origin() -> Vector3:
	var hips := (lobby_character.part("LegL").global_position
		+ lobby_character.part("LegR").global_position) / 2.0
	return hips + _forward() * 0.14 - Vector3(0, 0.04, 0)


func _forward() -> Vector3:
	var forward := -lobby_character.global_basis.z
	forward.y = 0.0
	return forward.normalized()


## Камера — глаза персонажа, чуть впереди, смотрит в чашу (как от первого лица, но ближе).
func _update_camera() -> void:
	if lobby_character == null:
		return
	var eye := lobby_character.global_position + Vector3.UP * 1.45 + _forward() * 0.12
	_camera.look_at_from_position(eye, toilet.bowl_position() + Vector3(0, 0.05, 0.05))


## Курсор над видом: струя летит в точку под курсором — в чашу (на уровне воды), иначе на пол.
func _on_view_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or lobby_character == null:
		return
	var origin := _camera.project_ray_origin(motion.position)
	var direction := _camera.project_ray_normal(motion.position)
	var water: Variant = Plane(Vector3.UP, toilet.water_height()).intersects_ray(origin, direction)
	if water != null:
		var point: Vector3 = water
		var bowl := toilet.bowl_position()
		if Vector2(point.x - bowl.x, point.z - bowl.z).length() < Toilet.RIM_RADIUS:
			_set_aim(point)
			return
	var ground: Variant = Plane(Vector3.UP, toilet.floor_height()).intersects_ray(origin, direction)
	if ground != null:
		_set_aim(ground)


## Прицел не дальше MAX_DISTANCE от персонажа и не позади него.
func _set_aim(point: Vector3) -> void:
	if lobby_character == null:
		return
	var from := lobby_character.global_position
	var flat := Vector3(point.x - from.x, 0, point.z - from.z)
	if flat.dot(_forward()) < 0.1:
		flat += _forward() * (0.1 - flat.dot(_forward()))
	if flat.length() > MAX_DISTANCE:
		flat = flat.normalized() * MAX_DISTANCE
	_aim = from + flat


func _build() -> void:
	_view = SubViewportContainer.new()
	_view.stretch = true
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_view_input)
	add_child(_view)
	var viewport := SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_2X
	_view.add_child(viewport)
	_camera = Camera3D.new()
	_camera.fov = 42.0 # приближенно
	# Без своей модели (смотрим из её глаз), кулаков и значков над головами.
	_camera.cull_mask = 0xFFFFF & ~VIEWMODEL_LAYERS & ~ZoneBadge.OVERHEAD_LAYER \
		& ~(1 << (player.slot + 1))
	viewport.add_child(_camera)
	_camera.current = true

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 20
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var title := Label.new()
	title.text = "Целься мышкой (или кнопками движения)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 10)
	top.add_child(title)
	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(360, 18)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("f6c343")
	fill.set_corner_radius_all(6)
	_bar.add_theme_stylebox_override("fill", fill)
	top.add_child(_bar)
	var hint := Label.new()
	hint.text = "Пробел / Enter / A — закончить"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.7
	hint.add_theme_font_size_override("font_size", 20)
	top.add_child(hint)

	var frame := ReferenceRect.new()
	frame.border_color = player.color
	frame.border_width = 4
	frame.editor_only = false
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
