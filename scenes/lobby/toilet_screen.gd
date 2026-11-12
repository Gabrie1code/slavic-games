class_name ToiletScreen
extends LobbyRoom
## «Сходить в туалет»: вид сбоку на унитаз (своя камера в общем мире лобби — другие игроки
## видят, что происходит). Жёлтой струёй целятся мышкой: куда показывает курсор — туда и
## долетает. Без мыши — влево/вправо (или вверх/вниз). Через USE_TIME сек всё заканчивается
## само; «подтвердить» или «отмена» — закончить раньше. После — перезарядка у унитаза.

const VIEWMODEL_LAYERS := 0b1111 << 10
const USE_TIME := 6.0
const MIN_DISTANCE := 0.15
const MAX_DISTANCE := 1.3
const KEY_AIM_SPEED := 0.6

var toilet: Toilet
var lobby_character: PlayerCharacter

var _time := 0.0
var _distance := 0.55
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
	_camera.global_transform = toilet.side_camera_transform()


func _process(delta: float) -> void:
	_time += delta
	_bar.value = 1.0 - _time / USE_TIME
	var input := player.input
	if input:
		var move := input.get_move() # вправо или вверх — дальше (камера сбоку: «вперёд» — вправо)
		var step := move.x - move.y
		_distance = clampf(_distance + step * KEY_AIM_SPEED * delta, MIN_DISTANCE, MAX_DISTANCE)
	if lobby_character:
		toilet.pour(_stream_origin(), _forward(), _distance, delta)
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


## Откуда льётся: между бёдер, чуть впереди.
func _stream_origin() -> Vector3:
	var hips := (lobby_character.part("LegL").global_position
		+ lobby_character.part("LegR").global_position) / 2.0
	return hips + _forward() * 0.14 - Vector3(0, 0.04, 0)


func _forward() -> Vector3:
	var forward := -lobby_character.global_basis.z
	forward.y = 0.0
	return forward.normalized()


## Курсор над видом: струя долетает до точки под курсором (по горизонтали вперёд).
func _on_view_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or lobby_character == null:
		return
	var origin := _camera.project_ray_origin(motion.position)
	var direction := _camera.project_ray_normal(motion.position)
	# Плоскость, в которой стоит персонаж и унитаз (камера смотрит на неё сбоку).
	var normal := _camera.global_basis.z
	normal.y = 0.0
	var plane := Plane(normal.normalized(), lobby_character.global_position)
	var hit: Variant = plane.intersects_ray(origin, direction)
	if hit == null:
		return
	var point: Vector3 = hit
	var along := (point - _stream_origin()).dot(_forward())
	_distance = clampf(along, MIN_DISTANCE, MAX_DISTANCE)


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
	_camera.fov = 55.0
	# Без кулаков, значков над головами и правой стены туалета (смотрим сквозь неё).
	_camera.cull_mask = 0xFFFFF & ~VIEWMODEL_LAYERS & ~ZoneBadge.OVERHEAD_LAYER \
		& ~ToiletRoom.WALL_LAYER & ~ToiletRoom.WALL_HIGH_LAYER
	viewport.add_child(_camera)
	_camera.current = true

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 20
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var title := Label.new()
	title.text = "Целься мышкой (или ← →)"
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
