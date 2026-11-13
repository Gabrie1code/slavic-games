class_name ArcadeScreen
extends Node3D
## Экран игрового автомата: спокойная пиксельная «демо-игра» в низком разрешении (96×72),
## как у настоящих автоматов, пока никто не играет. Три вида:
##   0 — падающие разноцветные блоки складываются в стопку;
##   1 — звёзды летят мимо, покачивается ракета, изредка мигает «ВСТАВЬ ЖЕТОН»;
##   2 — змейка ползает за яблоком.
## Рисуется во встроенном SubViewport и показывается на прямоугольнике поверх экрана модели.
## Автомат можно «сломать» кнопкой действия: сыплются искры, экран гаснет и через OFF_TIME сек
## включается снова (как восстанавливается разбитая посуда).
## Молотком экран разбивается (smash): трещины по стеклу, осколки; игра за стеклом идёт дальше;
## через SMASH_TIME сек стекло «восстанавливается».

const W := 96
const H := 72
const OFF_TIME := 8.0
const SMASH_TIME := 10.0
const CRACKS := preload("res://assets/textures/fx/glass_cracks.png")

var _game: PixelGame
var _mat: StandardMaterial3D
var _sparks: CPUParticles3D
var _off_until := 0.0
var _smashed_until := 0.0
var _cracks: MeshInstance3D
var _cracks_mat: StandardMaterial3D
var _shards: CPUParticles3D
var _time := 0.0


## mode — вид демо-игры (0..2), size — размер экрана в метрах.
func setup(mode: int, size: Vector2) -> ArcadeScreen:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(W, H)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	_game = PixelGame.new()
	_game.mode = mode
	viewport.add_child(_game)
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	quad.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = viewport.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # чёткие пиксели
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)
	_mat = mat
	_sparks = _make_sparks()
	add_child(_sparks)
	_build_cracks(size)
	return self


## Работает (экран горит и стекло целое) — только тогда его можно сломать.
func is_working() -> bool:
	return _time >= _off_until and _time >= _smashed_until


## Удар молотком: стекло экрана трескается, сыплются осколки; через SMASH_TIME — снова целое.
func smash() -> void:
	if _time < _smashed_until:
		return
	_smashed_until = _time + SMASH_TIME
	_cracks.visible = true
	# Каждый раз трещины по-другому: картинку отражаем по горизонтали/вертикали (не поворачиваем —
	# иначе углы вылезали за экран).
	_cracks_mat.uv1_scale = Vector3(1.0 if randf() < 0.5 else -1.0, 1.0 if randf() < 0.5 else -1.0,
		1.0)
	_shards.restart()
	_shards.emitting = true


## Сломать: искры, экран мигает и гаснет; через OFF_TIME сек сам включается.
func break_down() -> void:
	if not is_working():
		return
	_off_until = _time + OFF_TIME
	_sparks.restart()
	_sparks.emitting = true


func _process(delta: float) -> void:
	_time += delta
	var since_break := _time - (_off_until - OFF_TIME)
	if not is_working():
		# Первые полсекунды экран судорожно мигает, потом темно.
		var flicker := since_break < 0.5 and randf() < 0.5
		_mat.albedo_color = Color(1.4, 1.4, 1.4) if flicker else Color(0.02, 0.02, 0.03)
		_game.process_mode = Node.PROCESS_MODE_DISABLED
	elif _time - _off_until < 0.4 and _off_until > 0.0:
		# Включился: короткая белая вспышка, как у кинескопа.
		var k := (_time - _off_until) / 0.4
		_mat.albedo_color = Color(2.0, 2.0, 2.0).lerp(Color.WHITE, k)
		_game.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		_mat.albedo_color = Color.WHITE
	_process_smash()


## Разбитое стекло: игра за ним идёт как обычно (экран не гаснет), трещины в конце плавно тают.
func _process_smash() -> void:
	var left := _smashed_until - _time
	if left <= 0.0:
		_cracks.visible = false
		return
	_cracks_mat.albedo_color.a = clampf(left / 0.6, 0.0, 1.0)


func _build_cracks(size: Vector2) -> void:
	_cracks = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size # ровно по экрану
	_cracks.mesh = quad
	_cracks_mat = StandardMaterial3D.new()
	_cracks_mat.albedo_texture = CRACKS
	_cracks_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cracks_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cracks.material_override = _cracks_mat
	_cracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cracks.position.z = 0.004
	_cracks.visible = false
	add_child(_cracks)
	_shards = _make_sparks()
	_shards.amount = 26 # осколки стекла: светло-голубые, падают вниз
	var glass := Gradient.new()
	glass.set_color(0, Color(0.9, 0.97, 1.0))
	glass.set_color(1, Color(0.6, 0.8, 0.9, 0.0))
	_shards.color_ramp = glass
	add_child(_shards)

## Искры: короткий сноп жёлто-белых точек из экрана, падают вниз.
func _make_sparks() -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.amount = 40
	sparks.lifetime = 0.9
	sparks.explosiveness = 0.85
	sparks.direction = Vector3(0, 0.6, 1)
	sparks.spread = 60.0
	sparks.initial_velocity_min = 1.2
	sparks.initial_velocity_max = 3.0
	sparks.gravity = Vector3(0, -9.8, 0)
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	mesh.radial_segments = 4
	mesh.rings = 2
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.vertex_color_use_as_albedo = true
	mesh.material = spark_mat
	sparks.mesh = mesh
	var colors := Gradient.new()
	colors.set_color(0, Color(1.0, 1.0, 0.85))
	colors.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	sparks.color_ramp = colors
	sparks.position = Vector3(0, 0, 0.03)
	return sparks


## Сама «игра»: рисует пиксели раз в такт (TICK), без резких вспышек.
class PixelGame extends Node2D:
	const TICK := 0.25
	const CELL := 8
	const COLS := 12
	const ROWS := 9
	const COLORS: Array[Color] = [
		Color("ff6b5a"), Color("f6c343"), Color("8fd694"), Color("6fb3ff"), Color("d08cff"),
	]

	var mode := 0
	var _t := 0.0
	var _time := 0.0
	# Блоки: занятые клетки (Vector2i -> цвет) и падающий кусок.
	var _grid: Dictionary = {}
	var _piece: Array[Vector2i] = []
	var _piece_color := Color.WHITE
	# Звёзды: [x, y, скорость].
	var _stars: Array[Vector3] = []
	# Змейка.
	var _snake: Array[Vector2i] = []
	var _apple := Vector2i.ZERO

	func _ready() -> void:
		for i in 28:
			_stars.append(Vector3(randf() * 96, randf() * 72, randf_range(8, 30)))
		_reset_snake()
		_new_piece()

	func _process(delta: float) -> void:
		_time += delta
		for i in _stars.size():
			var s := _stars[i]
			s.x -= s.z * delta
			if s.x < 0:
				s = Vector3(96, randf() * 72, s.z)
			_stars[i] = s
		_t += delta
		if _t >= TICK:
			_t = 0.0
			if mode == 0:
				_step_blocks()
			elif mode == 2:
				_step_snake()
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 96, 72), Color("0b1220"))
		match mode:
			0:
				_draw_blocks()
			1:
				_draw_space()
			_:
				_draw_snake()
		# Полосы развёртки: каждая третья строка чуть темнее.
		for y in range(0, 72, 3):
			draw_line(Vector2(0, y), Vector2(96, y), Color(0, 0, 0, 0.18))

	# ---------- Блоки ----------
	func _new_piece() -> void:
		var shapes := [
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
			[Vector2i(0, 0)],
		]
		var x := randi_range(0, COLS - 3)
		_piece.clear()
		var shape: Array = shapes.pick_random()
		for cell: Vector2i in shape:
			_piece.append(cell + Vector2i(x, -1))
		_piece_color = COLORS.pick_random()

	func _step_blocks() -> void:
		var blocked := false
		for cell in _piece:
			var below := cell + Vector2i(0, 1)
			if below.y >= ROWS or _grid.has(below):
				blocked = true
		if not blocked:
			for i in _piece.size():
				_piece[i] += Vector2i(0, 1)
			return
		for cell in _piece:
			_grid[cell] = _piece_color
			if cell.y <= 2:
				_grid.clear() # стопка доросла до верха — начинаем заново
				break
		_new_piece()

	func _draw_blocks() -> void:
		for cell: Vector2i in _grid:
			_block(cell, _grid[cell])
		for cell in _piece:
			_block(cell, _piece_color)

	func _block(cell: Vector2i, color: Color) -> void:
		if cell.y < 0:
			return
		var r := Rect2(cell.x * CELL, cell.y * CELL, CELL - 1, CELL - 1)
		draw_rect(r, color)
		draw_rect(Rect2(r.position, Vector2(CELL - 1, 2)), color.lightened(0.4))

	# ---------- Космос ----------
	func _draw_space() -> void:
		for s in _stars:
			var c := 0.35 + s.z / 40.0
			draw_rect(Rect2(int(s.x), int(s.y), 1, 1), Color(c, c, c + 0.1))
		var y := 36 + int(sin(_time * 1.6) * 6)
		draw_rect(Rect2(20, y - 2, 12, 5), Color("d9d9d9"))      # корпус ракеты
		draw_rect(Rect2(32, y - 1, 3, 3), Color("ff6b5a"))       # нос
		draw_rect(Rect2(18, y - 4, 4, 2), Color("6fb3ff"))       # крылья
		draw_rect(Rect2(18, y + 3, 4, 2), Color("6fb3ff"))
		var flame := Color("f6c343") if int(_time * 8) % 2 == 0 else Color("ff9f43")
		draw_rect(Rect2(15, y - 1, 3, 3), flame)
		if fmod(_time, 3.0) < 1.6: # надпись появляется ненадолго и спокойно
			draw_string(ThemeDB.fallback_font, Vector2(14, 66), "ВСТАВЬ ЖЕТОН",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("f6c343"))

	# ---------- Змейка ----------
	func _reset_snake() -> void:
		_snake = [Vector2i(4, 4), Vector2i(3, 4), Vector2i(2, 4)]
		_place_apple()

	func _place_apple() -> void:
		_apple = Vector2i(randi_range(0, COLS - 1), randi_range(0, ROWS - 1))
		while _snake.has(_apple):
			_apple = Vector2i(randi_range(0, COLS - 1), randi_range(0, ROWS - 1))

	func _step_snake() -> void:
		var head := _snake[0]
		var best := head
		var best_dist := 1 << 20
		for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = head + dir
			if next.x < 0 or next.y < 0 or next.x >= COLS or next.y >= ROWS or _snake.has(next):
				continue
			var dist := absi(next.x - _apple.x) + absi(next.y - _apple.y)
			if dist < best_dist:
				best_dist = dist
				best = next
		if best == head:
			_reset_snake() # зажали сами себя — заново
			return
		_snake.push_front(best)
		if best == _apple:
			_place_apple()
			if _snake.size() > 14:
				_reset_snake()
		else:
			_snake.pop_back()

	func _draw_snake() -> void:
		_block(_apple, Color("ff6b5a"))
		for i in _snake.size():
			_block(_snake[i], Color("8fd694") if i > 0 else Color("c8f7c5"))
